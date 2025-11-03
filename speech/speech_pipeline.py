import os
import pandas as pd
import librosa
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
from sentence_transformers import SentenceTransformer

# -------------------------------
# Paths
# -------------------------------
audio_path = "../data/train/Normalised_audio-chunks"
trans_path = "../data/train/transcription"
meta_files = {"cc": "../data/train/cc_meta_data.txt", "cd": "../data/train/cd_meta_data.txt"}
categories = ["cc", "cd"]

categories = ["cc", "cd"]  # cc=control, cd=dementia
data = []

# -------------------------------
# Load meta-data
# -------------------------------
meta_data = {}
for label in categories:
    df_meta = pd.read_csv(meta_files[label], sep=";", header=None, engine='python')
    df_meta = df_meta.apply(lambda x: x.str.strip() if x.dtype == "object" else x)
    df_meta = df_meta.iloc[:, :3]  # keep only first 3 columns
    df_meta.columns = ["participant_id", "age", "gender"]
    df_meta['participant_id'] = df_meta['participant_id'].str.strip()
    df_meta['gender'] = df_meta['gender'].apply(lambda x: 1 if x.lower() == 'female' else 0)
    meta_data[label] = df_meta.set_index("participant_id")

# -------------------------------
# Load BERT model for semantic embeddings
# -------------------------------
bert_model = SentenceTransformer('all-MiniLM-L6-v2')  # lightweight & fast

# -------------------------------
# Feature extraction functions
# -------------------------------
def extract_acoustic_features(audio_path):
    try:
        y, sr = librosa.load(audio_path, sr=16000)
        mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
        mfccs_mean = np.mean(mfccs, axis=1)
        energy = np.mean(librosa.feature.rms(y=y))
        snd = parselmouth.Sound(audio_path)
        pitch = snd.to_pitch()
        pitch_mean = pitch.selected_array['frequency'].mean()
        point_process = parselmouth.praat.call(snd, "To PointProcess (periodic, cc)", 75, 500)
        jitter = parselmouth.praat.call(point_process, "Get jitter (local)", 0, 0.02, 1.3)
        shimmer = parselmouth.praat.call([snd, point_process], "Get shimmer (local)", 0, 0.02, 1.3, 1.6)
        return np.concatenate([mfccs_mean, [energy, pitch_mean, jitter, shimmer]])
    except:
        # return zeros if audio missing or failed
        return np.zeros(18)  # 13 MFCC + 4 prosodic + 1 energy (same length as before)

def extract_linguistic_features(transcript_path):
    try:
        with open(transcript_path, 'r', encoding='utf-8') as f:
            text = f.read()
        words = text.split()
        word_count = len(words)
        unique_words = len(set(words))
        ttr = unique_words / word_count if word_count > 0 else 0
        # Semantic embedding
        embedding = bert_model.encode(text)
        return np.concatenate([[word_count, ttr], embedding])
    except:
        # return zeros if transcript missing
        return np.zeros(2 + 384)  # 2 linguistic + 384 embedding dims (MiniLM-L6-v2)

# -------------------------------
# Collect audio/transcript files and labels
# -------------------------------
data = []
for label in categories:
    folder = os.path.join(audio_path, label)
    for file in os.listdir(folder):
        if file.endswith(".wav"):
            participant_id = file.replace(".wav", "").strip()
            transcript_file = os.path.join(trans_path, label, participant_id + ".cha")
            if participant_id in meta_data[label].index:
                age = meta_data[label].loc[participant_id, "age"]
                gender = meta_data[label].loc[participant_id, "gender"]
                mmse = meta_data[label].loc[participant_id, "MMSE"] if "MMSE" in meta_data[label].columns else np.nan
            else:
                age, gender, mmse = np.nan, np.nan, np.nan
            data.append({
                "participant_id": participant_id,
                "label": 0 if label=="cc" else 1,
                "audio_path": os.path.join(folder, file),
                "transcript_path": transcript_file,
                "age": age,
                "gender": gender,
                "MMSE": mmse
            })

df = pd.DataFrame(data)
print(f"Found {len(df)} audio files.")

# -------------------------------
# Extract features
# -------------------------------
features = []
for idx, row in df.iterrows():
    acoustic = extract_acoustic_features(row['audio_path'])
    linguistic = extract_linguistic_features(row['transcript_path'])
    meta = [row['age'], row['gender'], row['MMSE']]
    features.append(np.concatenate([acoustic, linguistic, meta]))

feature_df = pd.DataFrame(features)
labels = df['label'].values
print(f"Feature table shape: {feature_df.shape}")

# -------------------------------
# Train baseline model
# -------------------------------
X_train, X_val, y_train, y_val = train_test_split(feature_df.values, labels, test_size=0.2, random_state=42)
clf = RandomForestClassifier(n_estimators=200, random_state=42)
clf.fit(X_train, y_train)
y_pred = clf.predict(X_val)
print("Validation Accuracy:", accuracy_score(y_val, y_pred))

# -------------------------------
# Save features
# -------------------------------
feature_df['label'] = labels
feature_df.to_csv("../data/speech_features_enhanced_semantic.csv", index=False)
print("Saved enhanced features with semantic embeddings to CSV.")