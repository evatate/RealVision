import os
import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.impute import SimpleImputer
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, roc_auc_score, classification_report, confusion_matrix


CSV_PATH = "speech/features/speech_features_enhanced_semantic.csv"
OUT_DIR = "speech/models/rf_v1"

os.makedirs(OUT_DIR, exist_ok=True)


# load
df = pd.read_csv(CSV_PATH)
df["transcript"] = df["transcript"].fillna("")


# text features
df["transcript_length"] = df["transcript"].astype(str).apply(len)
df["word_count"] = df["transcript"].astype(str).apply(lambda x: len(x.split()))
df["avg_word_len"] = df.apply(
    lambda r: (len(str(r["transcript"])) / r["word_count"]) if r["word_count"] > 0 else 0,
    axis=1
)
text_features = ["transcript_length", "word_count", "avg_word_len"]

# Feature set
numeric_cols = ["age"]  # keep MMSE OUT
acoustic_cols = [c for c in df.columns if c.startswith("acoustic_")]

feature_cols = numeric_cols + acoustic_cols + text_features

X = df[feature_cols]
y = df["label"].values


# Train / test split
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)


# Fit preprocessing on train only
imputer = SimpleImputer(strategy="mean")
scaler = StandardScaler()

X_train_imp = imputer.fit_transform(X_train)
X_train_scaled = scaler.fit_transform(X_train_imp)

X_test_imp = imputer.transform(X_test)
X_test_scaled = scaler.transform(X_test_imp)


# Train model
clf = RandomForestClassifier(
    n_estimators=200,
    max_depth=10,
    min_samples_split=5,
    max_features="sqrt",
    random_state=42,
    n_jobs=-1
)

clf.fit(X_train_scaled, y_train)


# Evaluate
pred = clf.predict(X_test_scaled)
prob = clf.predict_proba(X_test_scaled)[:, 1]

acc = accuracy_score(y_test, pred)
auc = roc_auc_score(y_test, prob)

print("\n==== Speech RF Model (features-only) ====")
print("Accuracy:", acc)
print("ROC AUC:", auc)
print("\nConfusion Matrix:\n", confusion_matrix(y_test, pred))
print("\nReport:\n", classification_report(y_test, pred))


# Save artifacts
joblib.dump(clf, os.path.join(OUT_DIR, "rf_model.joblib"))
joblib.dump(imputer, os.path.join(OUT_DIR, "imputer.joblib"))
joblib.dump(scaler, os.path.join(OUT_DIR, "scaler.joblib"))
joblib.dump(feature_cols, os.path.join(OUT_DIR, "feature_cols.joblib"))

# Store info for debugging/reproduce
with open(os.path.join(OUT_DIR, "meta.txt"), "w") as f:
    f.write(f"CSV_PATH={CSV_PATH}\n")
    f.write(f"n_rows={len(df)}\n")
    f.write(f"n_features={len(feature_cols)}\n")
    f.write(f"acc={acc}\nauc={auc}\n")

print(f"\nSaved artifacts to: {OUT_DIR}/")
