import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, StratifiedKFold, RandomizedSearchCV
from sklearn.preprocessing import StandardScaler
from sklearn.impute import SimpleImputer
from sklearn.feature_selection import VarianceThreshold, mutual_info_classif
from sklearn.metrics import classification_report, confusion_matrix, f1_score
from xgboost import XGBClassifier
import joblib

# Load data
df = pd.read_csv("speech_features_enhanced_semantic.csv")
if "label" not in df.columns:
    raise ValueError("No 'label' column found in CSV")

X = df.drop(columns=["label"])
y = df["label"]
print(f"Loaded {len(X)} samples with {X.shape[1]} features")

# feature cleaning
X = X.dropna(axis=1, how="all")
imputer = SimpleImputer(strategy="mean")
X_imputed = imputer.fit_transform(X)

# remove near-constant features
var_thresh = VarianceThreshold(threshold=1e-4)
X_var = var_thresh.fit_transform(X_imputed)
print(f"Kept {X_var.shape[1]} features after variance filtering")

# select top features
mi_scores = mutual_info_classif(X_var, y, random_state=42)
mi_ranking = np.argsort(mi_scores)[::-1]
top_k = min(50, len(mi_ranking))
X_top = X_var[:, mi_ranking[:top_k]]
print(f"Selected top {top_k} features by mutual information")

# feature engineering: ratios of top features
X_fe = X_top.copy()
for i in range(X_top.shape[1]-1):
    X_fe = np.column_stack([X_fe, X_top[:, i] / (X_top[:, i+1] + 1e-6)])
print(f"Features after engineered ratios: {X_fe.shape[1]}")

# scaling
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X_fe)

# train/validation split
X_train, X_val, y_train, y_val = train_test_split(
    X_scaled, y, test_size=0.2, stratify=y, random_state=42
)

# XGBoost model & hyperparameter tuning
xgb_model = XGBClassifier(use_label_encoder=False, eval_metric="logloss", random_state=42)

param_grid = {
    "n_estimators": [400, 500, 600],
    "max_depth": [5, 6],
    "learning_rate": [0.05, 0.1],
    "subsample": [0.8, 0.9],
    "colsample_bytree": [0.8, 1.0],
    "scale_pos_weight": [0.9, 1.0],
    "reg_alpha": [0.01, 0.05],
    "reg_lambda": [1.0, 1.5],
    "min_child_weight": [1, 2]
}

cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

search = RandomizedSearchCV(
    xgb_model,
    param_distributions=param_grid,
    n_iter=20,
    scoring="f1",
    cv=cv,
    n_jobs=-1,
    verbose=1,
    random_state=42,
)
search.fit(X_train, y_train)

# evaluate best model
best_model = search.best_estimator_
y_pred = best_model.predict(X_val)
f1 = f1_score(y_val, y_pred)
acc = (y_val == y_pred).mean()

print(f"\nBest XGB no_pca F1: {f1:.3f}, Accuracy: {acc:.3f}")
print("Best params:", search.best_params_)
print(classification_report(y_val, y_pred, digits=3))
print("Confusion matrix:\n", confusion_matrix(y_val, y_pred))

# save model
save_name = "speech_best_xgb_no_pca.joblib"
joblib.dump((best_model, scaler, var_thresh, mi_ranking[:top_k]), save_name)
print(f"\nSaved best model to {save_name} — F1: {f1:.3f}")

