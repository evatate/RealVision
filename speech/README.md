# RealVision: Speech Pipeline

This module implements the **speech-based ADRD screening pipeline** used in the RealVision platform. The pipeline processes spontaneous speech collected via the RealVision mobile application and extracts clinically motivated acoustic and linguistic features for machine-learning–based screening and cognitive score estimation.

The speech pipeline is **fully deployed and operational**, running automatically on **AWS EC2 instances** as part of the production system.

---

## Current Status

- Feature extraction complete  
- Random Forest classifier trained  
- ~84% cross-validated accuracy on ADReSS-2020  
- Automatic cloud execution on AWS EC2  
- Integrated with mobile app audio ingestion  
- Ready for clinical trial deployment  

---

## Data Sources

### 1. Research Dataset
**ADReSS-2020 (Alzheimer’s Dementia Recognition through Spontaneous Speech)**  
Task: Cookie Theft picture description  
Labels: AD vs healthy control + MMSE  

This dataset was used to develop and validate the baseline speech model.

---

### 2. Mobile Application Data
- Audio recorded via the RealVision mobile app
- Format: `.wav`
- Sampling rate standardized prior to feature extraction
- Uploaded securely to AWS for processing

---

## Cloud Execution Architecture

The speech pipeline runs **automatically on AWS EC2** as part of the RealVision backend infrastructure:

- Audio files are uploaded to **private S3 buckets**
- EC2 instances:
  - Transcribe speech
  - Extract features
  - Run trained ML models
- Results are stored in secure databases and returned to the application

This architecture mirrors cloud-based processing pipelines used in prior validated mobile cognitive assessment systems.

---

## Transcription

### Whisper (Open Source)

All mobile-recorded `.wav` files are transcribed using **Whisper**, an open-source automatic speech recognition (ASR) model.

- Robust to background noise and speaker variability
- Well-suited for spontaneous, conversational speech
- Consistent transcription across devices and environments

Whisper outputs are used as input for:
- Linguistic feature extraction
- Pause and fluency analysis
- Optional semantic modeling

---

### Project Structure

Expected directory layout for feature extraction:

```
speech/
│
├── data/
│   ├── train/
│   │   ├── Normalised_audio-chunks/
│   │   │   ├── cc/
│   │   │   │   ├── S001.wav
│   │   │   │   └── ...
│   │   │   └── cd/
│   │   │       ├── S101.wav
│   │   │       └── ...
│   │   ├── transcription/
│   │   │   ├── cc/
│   │   │   │   ├── S001.cha
│   │   │   └── cd/
│   │   │       ├── S101.cha
│   │   │       └── ...
│   │   ├── cc_meta_data.txt
│   │   └── cd_meta_data.txt
│
└── features/
    └── speech_features_enhanced_semantic.csv
```

Each transcript (`.cha`) shares its 4-digit ID (e.g., `S001`) with the corresponding metadata row.

---

### Dependencies

Install the required libraries:

```bash
pip install pandas numpy librosa opensmile scikit-learn
```

Make sure you have `openSMILE` configured for the **eGeMAPS v2** feature set.
This script uses the official `opensmile` Python bindings.

---

### Acoustic/Linguistic feature extraction

1. Load metadata

2. Process transcripts (`.cha` files)
    - encodes pauses as tokens
    - expands repetition of words
    - marks statements of "uh" and "um"
    - extracts word count and pause counts

3. Extracts acoustic features (`.wav` files)
    - eGeMAPS features via openSMILE
    - energy and pitch
    - MFCC k-means summarization
    - pause statistics
    - speech rates

4. Produces csv file
    - merges transcript text + stats + acoustics + metadata into one dataframe.
    - produces one row per subject with columns:

     ```
     subject_id, label, age, gender, mmse,
     transcript, acoustic_0 … acoustic_130,
     text_word_count, text_pause_short_count, …
     ```
   * Saves to:

     ```
     speech/features/speech_features_enhanced_semantic.csv
     ```


### Notes on Design

* **Repetitions preserved:** Linguistically relevant to Alzheimer’s symptoms.
* **Filled pauses kept** (`UH`, `UM`): Paper found people with Alzheimer's are more likely to say `uh` than `um`
* **Pauses encoded explicitly**: Longer pauses with Alzheimer's, can analyze with DistilBERT
* **Gender made numeric**: Easier inclusion in ML models, 1 if female and 0 if male
* **eGeMAPS + ADR fusion**: Matches ADReSS acoustic setups

---

### How to Run

Simply execute from the root directory:

```bash
python speech_pipeline.py
```

The script saves the combined feature table.

---

## Complete Pipeline

### 1. Audio Transcription
- `.wav` files transcribed using Whisper
- Timestamps preserved
- Output normalized for downstream NLP processing

---

### 2. Linguistic Feature Extraction
From transcripts:
- Word counts
- Vocabulary richness metrics
- Filled pauses (`UH`, `UM`)
- Explicit pause encoding
- Repetition statistics

Design choices reflect established speech markers of Alzheimer’s disease [1].

---

### 3. Acoustic Feature Extraction
From raw audio:
- eGeMAPS v2 acoustic features (openSMILE)
- Pitch and energy statistics
- MFCC-based summaries
- Speech rate and pause duration metrics

---

## Machine Learning Model

- **Model:** Random Forest  
- **Inputs:** Acoustic + linguistic features  
- **Task:** AD vs Control classification  
- **Performance:** ~84% accuracy (cross-validation)  

The Random Forest model was selected for:
- Strong performance on tabular clinical features
- Lower overfitting risk compared to deep end-to-end models
- Interpretability and robustness

MMSE regression is supported using the same feature set.

---

## Design Rationale

- **Spontaneous speech:** More reflective of real-world cognition than structured tasks  
- **Feature-based ML:** Improves generalizability and clinical trust  
- **Cloud execution:** Enables scalable, device-independent processing  
- **Whisper ASR:** Robust transcription without reliance on third-party APIs  

These design choices are consistent with prior mobile AI-based cognitive screening studies.

---

## How It Runs (Production)

1. Mobile app records speech
2. Audio uploaded securely to AWS S3
3. EC2 instance triggers:
   - Whisper transcription
   - Feature extraction
   - Model inference
4. Results stored and returned to the app

---

## Disclaimer

This module is part of a **research and screening platform**.  
It does not provide medical diagnoses and is intended for clinical evaluation only.