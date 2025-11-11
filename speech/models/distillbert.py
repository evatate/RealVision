import os
import numpy as np
import pandas as pd
import torch
from torch.utils.data import Dataset, DataLoader
from transformers import (
    DistilBertTokenizer, 
    DistilBertForSequenceClassification,
    get_linear_schedule_with_warmup
)
from torch.optim import AdamW 
from sklearn.model_selection import LeaveOneGroupOut
from sklearn.metrics import accuracy_score, f1_score, classification_report, confusion_matrix
from sklearn.preprocessing import StandardScaler
from sklearn.impute import SimpleImputer
import joblib
from tqdm import tqdm
import warnings
warnings.filterwarnings('ignore')

# ========================
# CONFIGURATION
# ========================
FEATURES_FILE = "speech/features/speech_features_enhanced_semantic.csv"
MAX_LENGTH = 256
BATCH_SIZE = 4
LEARNING_RATE = 2e-5
NUM_EPOCHS = 15 #
N_ENSEMBLE = 5  # reduced to 5 for testing, papers suggest increase to 25-50 for full performance
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
torch.backends.cudnn.benchmark = True  # optional GPU speedup

print(f"\nDevice: {DEVICE}")
print(f"Ensemble size: {N_ENSEMBLE} seeds")

# ========================
# 1. LOAD DATA
# ========================
print("\nLoading features.")
df = pd.read_csv(FEATURES_FILE)
df = df.dropna(subset=["transcript"])  # remove empty transcripts
df['transcript'] = df['transcript'].astype(str)

print(f"  Loaded {len(df)} subjects")
print(f"  Control: {(df['label'] == 0).sum()}")
print(f"  AD: {(df['label'] == 1).sum()}")

# ========================
# 2. PREPARE AUXILIARY FEATURES
# ========================
print("\nPreparing auxiliary features.")
acoustic_cols = [c for c in df.columns if c.startswith('acoustic_')]
text_stat_cols = [c for c in df.columns if c.startswith('text_')]
meta_cols = ['age', 'gender', 'mmse']

# Ensure all meta columns exist
for col in meta_cols:
    if col not in df.columns:
        df[col] = np.nan

feature_cols = acoustic_cols + text_stat_cols + meta_cols
X_features = df[feature_cols].values

# Impute missing values
imputer = SimpleImputer(strategy='median')
X_features = imputer.fit_transform(X_features)

# Scale features
scaler = StandardScaler()
X_features = scaler.fit_transform(X_features)

print(f"  Total auxiliary features: {X_features.shape[1]}")

# ========================
# 3. CUSTOM DATASET
# ========================
class ADDataset(Dataset):
    def __init__(self, texts, labels, auxiliary_features, tokenizer, max_length):
        self.texts = texts
        self.labels = labels
        self.auxiliary_features = auxiliary_features
        self.tokenizer = tokenizer
        self.max_length = max_length
    
    def __len__(self):
        return len(self.texts)
    
    def __getitem__(self, idx):
        text = str(self.texts[idx])
        label = self.labels[idx]
        aux_feat = self.auxiliary_features[idx]
        
        encoding = self.tokenizer(
            text,
            truncation=True,
            padding='max_length',
            max_length=self.max_length,
            return_tensors='pt'
        )
        
        return {
            'input_ids': encoding['input_ids'].flatten(),
            'attention_mask': encoding['attention_mask'].flatten(),
            'auxiliary_features': torch.FloatTensor(aux_feat),
            'labels': torch.LongTensor([label])
        }

# ========================
# 4. MODEL WITH FUSION + LAYERNORM
# ========================
class DistilBERTWithFusion(torch.nn.Module):
    def __init__(self, n_auxiliary_features, dropout=0.3):
        super().__init__()
        self.distilbert = DistilBertForSequenceClassification.from_pretrained(
            'distilbert-base-uncased',
            num_labels=2
        )
        self.norm = torch.nn.LayerNorm(768 + n_auxiliary_features)  # LayerNorm for stability
        self.fusion = torch.nn.Sequential(
            torch.nn.Linear(768 + n_auxiliary_features, 256),
            torch.nn.ReLU(),
            torch.nn.Dropout(dropout),
            torch.nn.Linear(256, 2)
        )
    
    def forward(self, input_ids, attention_mask, auxiliary_features):
        outputs = self.distilbert.distilbert(
            input_ids=input_ids,
            attention_mask=attention_mask
        )
        pooled = torch.mean(outputs.last_hidden_state, dim=1)
        combined = torch.cat([pooled, auxiliary_features], dim=1)
        combined = self.norm(combined)  # LayerNorm applied
        logits = self.fusion(combined)
        return logits

# ========================
# 5. TRAIN & EVALUATE FUNCTIONS
# ========================
def train_model(train_loader, model, optimizer, scheduler, device):
    model.train()
    total_loss = 0
    # Wrap batches with tqdm for progress bar
    for batch in tqdm(train_loader, desc="    Training batches", leave=False):
        optimizer.zero_grad()
        input_ids = batch['input_ids'].to(device)
        attention_mask = batch['attention_mask'].to(device)
        auxiliary_features = batch['auxiliary_features'].to(device)
        labels = batch['labels'].flatten().to(device)
        
        logits = model(input_ids, attention_mask, auxiliary_features)
        loss_fn = torch.nn.CrossEntropyLoss(weight=torch.FloatTensor([1.0, 1.0]).to(device))
        loss = loss_fn(logits, labels)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        optimizer.step()
        scheduler.step()
        
        total_loss += loss.item()
    
    return total_loss / len(train_loader)

def evaluate_model(val_loader, model, device):
    model.eval()
    predictions, true_labels = [], []
    with torch.no_grad():
        for batch in val_loader:
            input_ids = batch['input_ids'].to(device)
            attention_mask = batch['attention_mask'].to(device)
            auxiliary_features = batch['auxiliary_features'].to(device)
            labels = batch['labels'].flatten().to(device)
            logits = model(input_ids, attention_mask, auxiliary_features)
            preds = torch.argmax(logits, dim=1)
            predictions.extend(preds.cpu().numpy())
            true_labels.extend(labels.cpu().numpy())
    acc = accuracy_score(true_labels, predictions)
    f1 = f1_score(true_labels, predictions)
    return acc, f1, predictions, true_labels

# ========================
# 6. LOSO CROSS-VALIDATION WITH ENSEMBLE
# ========================
print("\nSetting up LOSO CV.")

texts = df['transcript'].values
labels = df['label'].values
tokenizer = DistilBertTokenizer.from_pretrained('distilbert-base-uncased')

# use only participant prefix for LOSO
groups = df['subject_id'].apply(lambda x: x.split('-')[0]).values
logo = LeaveOneGroupOut()
n_splits = logo.get_n_splits(groups=groups)
print(f"  LOSO splits: {n_splits} participants")

cv_results = []

for fold_idx, (train_idx, val_idx) in enumerate(logo.split(texts, labels, groups=groups)):
    val_subject = df.iloc[val_idx[0]]['subject_id'].split('-')[0]  # participant prefix
    print(f"\n--- Fold {fold_idx + 1}/{n_splits} ---")
    print(f"  Validation participant: {val_subject}")
    
    X_train, X_val = texts[train_idx], texts[val_idx]
    y_train, y_val = labels[train_idx], labels[val_idx]
    feat_train, feat_val = X_features[train_idx], X_features[val_idx]
    
    fold_predictions = []
    
    for seed in range(N_ENSEMBLE):
        print(f"  Seed {seed + 1}/{N_ENSEMBLE}...", end=' ')
        torch.manual_seed(seed)
        np.random.seed(seed)
        
        train_dataset = ADDataset(X_train, y_train, feat_train, tokenizer, MAX_LENGTH)
        val_dataset = ADDataset(X_val, y_val, feat_val, tokenizer, MAX_LENGTH)
        
        train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True)
        val_loader = DataLoader(val_dataset, batch_size=1, shuffle=False)
        
        model = DistilBERTWithFusion(n_auxiliary_features=X_features.shape[1])
        model.to(DEVICE)
        
        optimizer = AdamW(model.parameters(), lr=LEARNING_RATE, weight_decay=0.01)
        total_steps = len(train_loader) * NUM_EPOCHS
        scheduler = get_linear_schedule_with_warmup(
            optimizer,
            num_warmup_steps=int(0.1 * total_steps),
            num_training_steps=total_steps
        )
        
        best_f1 = 0
        patience, patience_counter = 3, 0
        best_model_state = model.state_dict().copy()
        
        for epoch in range(NUM_EPOCHS):
            train_loss = train_model(train_loader, model, optimizer, scheduler, DEVICE)
            val_acc, val_f1, _, _ = evaluate_model(val_loader, model, DEVICE)
            
            if val_f1 > best_f1:
                best_f1 = val_f1
                patience_counter = 0
                best_model_state = model.state_dict().copy()
            else:
                patience_counter += 1
            
            if patience_counter >= patience:
                break
        
        model.load_state_dict(best_model_state)
        _, _, preds, _ = evaluate_model(val_loader, model, DEVICE)
        fold_predictions.append(preds[0])
        print(f"F1={best_f1:.3f}")
    
    ensemble_pred = int(np.round(np.mean(fold_predictions)))
    cv_results.append({
        'subject_id': val_subject,
        'true_label': y_val[0],
        'pred_label': ensemble_pred,
        'confidence': np.mean(fold_predictions)
    })
    print(f"  Ensemble prediction: {ensemble_pred} (true: {y_val[0]})")

# ========================
# 7. EVALUATION
# ========================
print("\nLOSO Cross-Validation Results:")
df_cv = pd.DataFrame(cv_results)
cv_acc = accuracy_score(df_cv['true_label'], df_cv['pred_label'])
cv_f1 = f1_score(df_cv['true_label'], df_cv['pred_label'])

print(f"\n  LOSO Accuracy: {cv_acc:.3f}")
print(f"  LOSO F1: {cv_f1:.3f}")
print("\nClassification Report:")
print(classification_report(df_cv['true_label'], df_cv['pred_label'], target_names=['Control', 'AD'], digits=3))

print("\nConfusion Matrix:")
cm = confusion_matrix(df_cv['true_label'], df_cv['pred_label'])
print(f"              Predicted")
print(f"           Control   AD")
print(f"Actual Control  {cm[0,0]:3d}   {cm[0,1]:3d}")
print(f"       AD       {cm[1,0]:3d}   {cm[1,1]:3d}")

# ========================
# 8. SAVE ARTIFACTS
# ========================
print("\nSaving artifacts...")
artifacts = {
    'scaler': scaler,
    'imputer': imputer,
    'feature_cols': feature_cols,
    'n_auxiliary_features': X_features.shape[1],
    'cv_accuracy': cv_acc,
    'cv_f1': cv_f1,
    'cv_results': df_cv
}
joblib.dump(artifacts, "distilbert_loso_artifacts.joblib")
df_cv.to_csv("loso_cv_results.csv", index=False)

# Save BERT embeddings (optional)
torch.save(model.distilbert.distilbert.embeddings.word_embeddings.weight, "bert_embeddings.pt")

print("Artifacts saved")
print("\n" + "=" * 80)
print(f"COMPLETE - LOSO CV F1: {cv_f1:.3f}")
print("=" * 80)
