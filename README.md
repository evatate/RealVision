# RealVision

A multimodal ML project to detect Alzheimer's Disease and Related Dementias (ADRD) 
from four behavioral indicators: gait, speech, eye movement, and facial expressions.

## Current Progress: ADReSS Speech Feature Extraction Pipeline

This pipeline (`speech_pipline.py`) processes the **ADReSS (Alzheimer’s Dementia Recognition through Spontaneous Speech)** dataset to extract synchronized acoustic and linguistic features, merge them with the training participant metadata, and output a single machine-learning–ready CSV file.

---

### Project Structure

Expected directory layout so far:

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

### What the Script Does

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


### Notes on Design so far (can be improved upon later if necessary)

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

### Next Steps

1. Train DistilBERT semantic embeddings on transcript column and add to our acoustic/linguistic features (ideally ensembling for better results)
2. Combine features and then experiment with classifiers like logistic regression and SVM
3. MMSE regression and evaluate RMSE
4. Cross validation + ensembling
5. Test on test data provided