# model.py
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler
from sklearn.feature_selection import mutual_info_classif

# === 1. Load data ===
df = pd.read_csv("speech_features_enhanced_semantic.csv")

if "label" not in df.columns:
    raise ValueError("No 'label' column found in CSV")

X = df.drop(columns=["label"])
y = df["label"]

# === 2. Clean & scale ===
X = X.dropna(axis=1, how="all")
imputer = SimpleImputer(strategy="mean")
X_imputed = imputer.fit_transform(X)

scaler = StandardScaler()
X_scaled = scaler.fit_transform(X_imputed)

# === 3. Variance diagnostics ===
variances = np.var(X_scaled, axis=0)
plt.hist(np.log1p(variances), bins=50)
plt.title("Feature Variance Distribution")
plt.xlabel("log(variance)")
plt.ylabel("Count")
plt.show()

# === 4. Mutual information diagnostics ===
mi = mutual_info_classif(X_scaled, y)
top_idx = np.argsort(mi)[::-1][:50]

plt.bar(range(50), mi[top_idx])
plt.title("Top 50 Feature Importances by Mutual Information")
plt.xlabel("Feature rank")
plt.ylabel("Mutual Information")
plt.show()

print("\nTop 10 features by mutual information:")
for i, idx in enumerate(top_idx[:10]):
    print(f"{i+1:2d}. Feature {idx} — MI={mi[idx]:.4f}")
