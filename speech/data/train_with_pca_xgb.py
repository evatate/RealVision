import pandas as pd
import numpy as np
from sklearn.model_selection import StratifiedKFold, GridSearchCV
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.impute import SimpleImputer
from xgboost import XGBClassifier
import joblib

# Load data
df = pd.read_csv("speech_features_enhanced_semantic.csv")

if "label" not in df.columns:
    raise ValueError("No 'label' column found. Please ensure your CSV has one.")

X = df.drop(columns=["label"])
y = df["label"]

print(f"Loaded {len(X)} samples with {X.shape[1]} features")

# Preprocess
X = X.dropna(axis=1, how="all")  # drop columns that are all NaN
imputer = SimpleImputer(strategy="mean")
X_imputed = imputer.fit_transform(X)

scaler = StandardScaler()
X_scaled = scaler.fit_transform(X_imputed)

pca = PCA(n_components=50, random_state=42)
X_pca = pca.fit_transform(X_scaled)
print(f"PCA reduced to {X_pca.shape[1]} components, explaining {pca.explained_variance_ratio_.sum():.2%} of variance")

# Define base model
xgb = XGBClassifier(
    eval_metric='logloss',
    use_label_encoder=False,
    random_state=42
)

# Define hyperparameter grid
param_grid = {
    'n_estimators': [100, 200, 400],
    'max_depth': [3, 5, 7],
    'learning_rate': [0.01, 0.05, 0.1],
    'subsample': [0.8, 1.0],
    'colsample_bytree': [0.8, 1.0]
}

# Run grid search with 5-fold cross validation
cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

grid = GridSearchCV(
    estimator=xgb,
    param_grid=param_grid,
    scoring='accuracy',
    cv=cv,
    n_jobs=-1,
    verbose=2
)

grid.fit(X_pca, y)

print(f"\nBest parameters: {grid.best_params_}")
print(f"Best cross-validation accuracy: {grid.best_score_:.3f}")

# Retrain on full data with best parameters and save
best_model = grid.best_estimator_
best_model.fit(X_pca, y)

joblib.dump((best_model, scaler, pca), "speech_xgb_model_tuned.joblib")
print("Saved tuned model, scaler, and PCA to speech_xgb_model_tuned.joblib")

