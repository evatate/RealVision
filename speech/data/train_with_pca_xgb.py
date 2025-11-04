import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, StratifiedKFold, RandomizedSearchCV
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.impute import SimpleImputer
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from xgboost import XGBClassifier
from lightgbm import LGBMClassifier
import joblib

# === 1. Load data ===
df = pd.read_csv("speech_features_enhanced_semantic.csv")

if "label" not in df.columns:
    raise ValueError("No 'label' column found in CSV")

X = df.drop(columns=["label"])
y = df["label"]

print(f"Loaded {len(X)} samples with {X.shape[1]} features")

# === 2. Clean & scale ===
X = X.dropna(axis=1, how="all")
imputer = SimpleImputer(strategy="mean")
X_imputed = imputer.fit_transform(X)

scaler = StandardScaler()
X_scaled = scaler.fit_transform(X_imputed)

# === 3. Split train/validation ===
X_train, X_val, y_train, y_val = train_test_split(
    X_scaled, y, test_size=0.2, stratify=y, random_state=42
)

# === 4. Try both with and without PCA ===
pca_versions = {"no_pca": None, "pca50": PCA(n_components=50, random_state=42)}

best_model = None
best_acc = 0.0
results = []

for name, pca in pca_versions.items():
    print(f"\n--- Running configuration: {name} ---")
    if pca:
        X_train_pca = pca.fit_transform(X_train)
        X_val_pca = pca.transform(X_val)
    else:
        X_train_pca, X_val_pca = X_train, X_val

    # === 5. Define models ===
    models = {
        "xgb": XGBClassifier(
            eval_metric="logloss",
            use_label_encoder=False,
            random_state=42
        ),
        "lgbm": LGBMClassifier(random_state=42)
    }

    param_grids = {
        "xgb": {
            "n_estimators": [100, 300, 500],
            "max_depth": [3, 4, 5, 6],
            "learning_rate": [0.005, 0.01, 0.05, 0.1],
            "subsample": [0.6, 0.8, 1.0],
            "colsample_bytree": [0.6, 0.8, 1.0],
        },
        "lgbm": {
            "n_estimators": [100, 300, 500],
            "max_depth": [-1, 5, 7, 9],
            "learning_rate": [0.005, 0.01, 0.05, 0.1],
            "num_leaves": [15, 31, 63],
            "subsample": [0.6, 0.8, 1.0],
        },
    }

    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

    for model_name, model in models.items():
        print(f"\n🔍 Tuning {model_name.upper()} ({name}) ...")
        search = RandomizedSearchCV(
            model,
            param_distributions=param_grids[model_name],
            n_iter=20,
            scoring="accuracy",
            cv=cv,
            n_jobs=-1,
            verbose=1,
            random_state=42,
        )
        search.fit(X_train_pca, y_train)

        best_params = search.best_params_
        y_pred = search.best_estimator_.predict(X_val_pca)
        acc = accuracy_score(y_val, y_pred)
        print(f"✅ {model_name.upper()} {name} accuracy: {acc:.3f}")
        print("Best params:", best_params)
        print(classification_report(y_val, y_pred, digits=3))
        print("Confusion matrix:\n", confusion_matrix(y_val, y_pred))

        results.append((name, model_name, acc, best_params))

        if acc > best_acc:
            best_acc = acc
            best_model = (search.best_estimator_, scaler, pca, model_name, name)

# === 6. Save best model ===
if best_model:
    model, scaler, pca, m_name, pca_name = best_model
    save_name = f"speech_best_{m_name}_{pca_name}.joblib"
    joblib.dump((model, scaler, pca), save_name)
    print(f"\n🏆 Saved best model ({m_name} + {pca_name}) to {save_name} — Accuracy: {best_acc:.3f}")
else:
    print("No model trained successfully.")

# === 7. Summary table ===
print("\nSummary of results:")
for name, model_name, acc, params in sorted(results, key=lambda x: -x[2]):
    print(f"{model_name.upper():<6} {name:<8}  acc={acc:.3f}  params={params}")