import os
import re
import pandas as pd
import librosa
import numpy as np
from pathlib import Path
import opensmile
from sklearn.cluster import KMeans

# ========================
# PATHS
# ========================
TRAIN_AUDIO_PATH = "speech/data/train/Normalised_audio-chunks"
TRAIN_TRANS_PATH = "speech/data/train/transcription"
META_FILES = {
    "cc": "speech/data/train/cc_meta_data.txt",
    "cd": "speech/data/train/cd_meta_data.txt"
}
CATEGORIES = ["cc", "cd"]

# ========================
# LOAD METADATA
# ========================
print("Loading metadata.")
meta_data = {}
for label in CATEGORIES:
    # Read with proper semicolon delimiter and handle whitespace
    df_meta = pd.read_csv(
        META_FILES[label], 
        sep=";", 
        skipinitialspace=True,
        engine='python'
    )
    
    # Strip whitespace from column names
    df_meta.columns = df_meta.columns.str.strip()
    
    # Handle different possible column names
    if 'ID' in df_meta.columns:
        df_meta = df_meta.rename(columns={'ID': 'participant_id'})
    
    # Strip whitespace from all string columns
    for col in df_meta.select_dtypes(include=['object']).columns:
        df_meta[col] = df_meta[col].str.strip()
    
    # Convert gender to numeric
    df_meta['gender'] = df_meta['gender'].apply(
        lambda x: 1 if str(x).lower() == 'female' else 0
    )
    
    # Ensure MMSE is numeric (handle 'NA' strings)
    if 'mmse' in df_meta.columns:
        df_meta['mmse'] = pd.to_numeric(df_meta['mmse'], errors='coerce')
    
    meta_data[label] = df_meta.set_index("participant_id")
    print(f"  {label}: {len(df_meta)} subjects, columns: {list(df_meta.columns)}")

# ========================
# TRANSCRIPT PROCESSING
# ========================
def process_transcript_with_pauses(file_path):
    """
    Process CHAT transcript following ADReSS best practices:
    - Remove interviewer turns
    - Expand repetitions [x N]
    - Encode pauses as tokens (, for short, . for medium, ... for long)
    - Preserve filled pauses (uh, um)
    """
    if not os.path.exists(file_path):
        return "", {}
    
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Extract participant lines only (remove *INV:)
    participant_lines = []
    for line in lines:
        if line.startswith('*PAR:'):
            # Remove *PAR: prefix
            text = line.replace('*PAR:', '').strip()
            participant_lines.append(text)
    
    text = ' '.join(participant_lines).lower()
    
    # Expand repetitions: "word [x 3]" -> "word word word"
    def expand_repeat(match):
        word = match.group(1)
        count = int(match.group(2))
        return ' '.join([word] * count)
    text = re.sub(r'(\w+)\s*\[x\s*(\d+)\]', expand_repeat, text)
    
    # Remove other CHAT annotations but keep content
    #text = re.sub(r'\[.*?\]', '', text)  # Remove all bracket annotations
    #text = re.sub(r'[<>()]', '', text)   # Remove angle brackets and parens

    text = re.sub(r'\[[^\]]*\]', '', text)  # bracket removal
    text = re.sub(r'[<>()]', '', text)     
    text = re.sub(r'\+["/]+', '', text)     # remove +"" and +//

    # Remove ELAN-style timestamps: start and end
    text = re.sub(r'\x15\d+_\d+\x15', ' ', text)

    # Remove other CLAN artifacts
    text = re.sub(r'\+["/]+', '', text)
    
    # Encode pauses 
    # Long pause (multiple newlines or explicit markers) -> ...
    text = re.sub(r'\n\n+', ' ... ', text)
    # Medium pause -> .
    text = re.sub(r'\n', ' . ', text)
    # Short pause (multiple spaces) -> ,
    text = re.sub(r'\s{3,}', ' , ', text)
    
    # Preserve filled pauses as tokens
    text = re.sub(r'\buh\b', 'UH', text, flags=re.IGNORECASE)
    text = re.sub(r'\bum\b', 'UM', text, flags=re.IGNORECASE)

    
    # Clean up whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    
    # Extract basic statistics
    stats = {
        'word_count': len(text.split()),
        'pause_short_count': text.count(','),
        'pause_medium_count': text.count('.') - text.count('...') * 3,
        'pause_long_count': text.count('...'),
        'filled_pause_count': text.count('UH') + text.count('UM'),
    }
    
    return text, stats

# ========================
# ACOUSTIC FEATURES (eGeMAPS + ADR)
# ========================
print("\nSetting up acoustic feature extractors.")

# Initialize openSMILE for eGeMAPS
smile = opensmile.Smile(
    feature_set=opensmile.FeatureSet.eGeMAPSv02,
    feature_level=opensmile.FeatureLevel.Functionals,
)

def extract_acoustic_features_enhanced(audio_path):
    """
    Extract comprehensive acoustic features:
    - eGeMAPS (88 features) via openSMILE
    - ADR summarization (k-means on MFCCs)
    - Pause and speech rate statistics
    """
    try:
        # Load audio
        y, sr = librosa.load(audio_path, sr=16000)
        duration = librosa.get_duration(y=y, sr=sr)
        
        # eGeMAPS features
        try:
            egemaps = smile.process_file(audio_path)
            egemaps_values = egemaps.values.flatten()
        except:
            egemaps_values = np.zeros(88)
        
        # Basic prosodic features
        # Energy
        rms = librosa.feature.rms(y=y)[0]
        energy_mean = np.mean(rms)
        energy_std = np.std(rms)
        
        # Pitch (F0) via librosa
        f0 = librosa.yin(y, fmin=75, fmax=500, sr=sr)
        f0_voiced = f0[f0 > 0]
        pitch_mean = np.mean(f0_voiced) if len(f0_voiced) > 0 else 0
        pitch_std = np.std(f0_voiced) if len(f0_voiced) > 0 else 0
        
        # ADR summarization (k-means on MFCCs)
        # Extract frame-level MFCCs
        mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13, hop_length=160, n_fft=400)
        mfccs_frames = mfccs.T  # (n_frames, 13)
        
        # Simple k-means summarization (k=30 as per papers)
        if mfccs_frames.shape[0] > 30:
            kmeans = KMeans(n_clusters=30, random_state=42, n_init=10)
            cluster_labels = kmeans.fit_predict(mfccs_frames)
            # Histogram of cluster assignments
            adr_histogram = np.bincount(cluster_labels, minlength=30) / len(cluster_labels)
        else:
            adr_histogram = np.zeros(30)
        
        # Pause statistics
        # Detect silent intervals (below threshold)
        intervals = librosa.effects.split(y, top_db=30)
        if len(intervals) > 1:
            pause_durations = []
            for i in range(len(intervals) - 1):
                pause_start = intervals[i][1] / sr
                pause_end = intervals[i+1][0] / sr
                pause_durations.append(pause_end - pause_start)
            
            total_pause_time = sum(pause_durations)
            pause_count = len(pause_durations)
            mean_pause = np.mean(pause_durations) if pause_durations else 0
            
            # Count pauses by bins
            pause_short = sum(1 for p in pause_durations if p < 0.5)
            pause_medium = sum(1 for p in pause_durations if 0.5 <= p < 1.0)
            pause_long = sum(1 for p in pause_durations if p >= 1.0)
        else:
            total_pause_time = 0
            pause_count = 0
            mean_pause = 0
            pause_short = pause_medium = pause_long = 0
        
        # Speaking time
        total_speech_time = duration - total_pause_time
        speech_rate = total_speech_time / duration if duration > 0 else 0
        
        # Combine all features
        features = np.concatenate([
            egemaps_values,  # 88 features
            [energy_mean, energy_std, pitch_mean, pitch_std],  # 4 features
            adr_histogram,  # 30 features
            [duration, total_pause_time, pause_count, mean_pause],  # 4 features
            [pause_short, pause_medium, pause_long],  # 3 features
            [speech_rate, total_speech_time],  # 2 features
        ])
        
        return features
        
    except Exception as e:
        print(f"  Error processing {audio_path}: {e}")
        # Return zeros with correct dimensionality
        return np.zeros(88 + 4 + 30 + 4 + 3 + 2)  # 131 features total

# ========================
# COLLECT DATA WITH SUBJECT-LEVEL ORGANIZATION
# ========================
print("\n[Collecting training data (subject-level).")
subjects_data = []

for label in CATEGORIES:
    audio_folder = os.path.join(TRAIN_AUDIO_PATH, label)
    trans_folder = os.path.join(TRAIN_TRANS_PATH, label)
    
    # Get all audio files for this category
    audio_files = [f for f in os.listdir(audio_folder) if f.endswith('.wav')]
    
    for audio_file in audio_files:
        # Extract participant ID (subject ID)
        participant_id = audio_file.replace('.wav', '').strip()
        
        # Use only first 4 characters for metadata lookup
        base_id = participant_id[:4]

        # Get metadata
        if base_id in meta_data[label].index:
            age = meta_data[label].loc[base_id, 'age']
            gender = meta_data[label].loc[base_id, 'gender']
            mmse = meta_data[label].loc[base_id, 'mmse'] if 'mmse' in meta_data[label].columns else np.nan
        else:
            age, gender, mmse = np.nan, np.nan, np.nan
        
        # Paths
        audio_path = os.path.join(audio_folder, audio_file)
        trans_path = os.path.join(trans_folder, base_id + '.cha')
        
        subjects_data.append({
            'subject_id': participant_id,
            'label': 0 if label == 'cc' else 1,
            'audio_path': audio_path,
            'transcript_path': trans_path,
            'age': age,
            'gender': gender,
            'mmse': mmse
        })

df_subjects = pd.DataFrame(subjects_data)
print(f"Total subjects: {len(df_subjects)}")
print(f"  Control (cc): {(df_subjects['label'] == 0).sum()}")
print(f"  Dementia (cd): {(df_subjects['label'] == 1).sum()}")

# ========================
# EXTRACT FEATURES
# ========================
print("\nExtracting features for all subjects.")
all_features = []

for idx, row in df_subjects.iterrows():
    print(f"  Processing {row['subject_id']} ({idx+1}/{len(df_subjects)})", end='\r')
    
    # Acoustic features
    acoustic_feats = extract_acoustic_features_enhanced(row['audio_path'])
    
    # Linguistic features
    text, text_stats = process_transcript_with_pauses(row['transcript_path'])
    
    # Combine
    feature_dict = {
        'subject_id': row['subject_id'],
        'label': row['label'],
        'age': row['age'],
        'gender': row['gender'],
        'mmse': row['mmse'],
        'transcript': text,  # Save for BERT
    }
    
    # Add acoustic features
    for i, val in enumerate(acoustic_feats):
        feature_dict[f'acoustic_{i}'] = val
    
    # Add text statistics
    for key, val in text_stats.items():
        feature_dict[f'text_{key}'] = val
    
    all_features.append(feature_dict)

df_features = pd.DataFrame(all_features)
print(f"\n  Feature extraction complete: {df_features.shape}")

# ========================
# SAVE
# ========================
print("\nSaving features.")
output_dir = Path("speech/features")
output_dir.mkdir(parents=True, exist_ok=True)

# Save full dataframe
df_features.to_csv(output_dir / "speech_features_enhanced_semantic.csv", index=False)
print(f"Saved to {output_dir / 'speech_features_enhanced_semantic.csv'}")
