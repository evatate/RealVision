# RealVision: Multimodal Machine Learning for ADRD Screening

RealVision is a research-driven platform for early detection and monitoring of Alzheimer’s Disease and Related Dementias (ADRD). The system combines four independent behavioral and neurological indicators known to correlate with cognitive decline:

1. Speech and prosodic impairments
2. Abnormal eye movement characteristics
3. Reduced facial expressiveness
4. Gait instability and changes in walking biomechanics

The project consists of a complete pipeline including data acquisition, multimodal feature extraction, supervised machine learning architectures, and deployment to a patient-facing mobile application.

---

## Clinical Motivation

Clinical diagnosis of ADRD typically occurs years after symptom onset due to:
- Limited access to neurological testing
- Subtle early-phase behavioral changes
- Lack of scalable continuous monitoring options

Prior work has shown that individual modalities can identify ADRD characteristics with strong statistical significance:
- Speech analysis approaches ~83% classification accuracy on standardized datasets
- Eye movement metrics achieve up to ~95% discrimination in early-onset studies
- Gait changes are detectable years before cognitive symptoms are reported
- Facial muscle activation (e.g., smiling) differs significantly between ADRD/MCI and healthy controls

RealVision unifies these signals into a single multimodal screening framework intended for use in non-clinical environments.

---

## System Overview

The RealVision pipeline includes the following components:

| Component | Input | Feature Extraction | Output |
|----------|------|------------------|--------|
| Speech Processing | Audio + transcript | Linguistic, acoustic, semantic embeddings | AD vs control predictions, MMSE regression |
| Eye Tracking | Camera video | Fixation stability, saccade metrics, pursuit error | Oculomotor impairment score |
| Facial Analysis | Camera video | Face landmark motion, smile index | Facial expressiveness score |
| Gait Analysis | Mobile sensors | Step asymmetry, stride variability, speed | Gait instability score |

The final product is an ensemble model integrating scores from all modalities to estimate ADRD likelihood.

---

## Current Progress

### Speech Pipeline
Completed:
- Data ingestion from ADReSS-2020 dataset
- openSMILE eGeMAPS v2 acoustic feature extraction
- Linguistic feature engineering from CHAT transcripts
- Participant metadata integration into unified ML table

In Progress:
- DistilBERT-based semantic feature extraction and fusion
- MMSE regression and classifier improvement
- Cross-validation and generalizability testing

### Mobile Application
Completed:
- Fully functional Android prototype with:
  - Speech recording workflow
  - Three eye-tracking tasks
  - Smile test recording pipeline
  - Gait/step capture using Health Connect

In Progress:
- iOS feature testing (HealthKit and camera calibration)
- Integration of TensorFlow Lite models for on-device inference
- Final scoring and results presentation UI

### Remaining Modalities (Models)
In Development:
- Eye-tracking signal processing
- Facial expression dynamics modeling
- Gait biomechanics feature processing

---

## Tech Stack

| Layer | Tools and Frameworks |
|------|---------------------|
| ML Model Development | Python, PyTorch, Transformers, scikit-learn |
| Speech Feature Extraction | openSMILE, librosa, NLP preprocessing |
| Mobile Sensor Data Capture | HealthKit (iOS), Health Connect (Android) |
| Computer Vision | TensorFlow Lite, MediaPipe (planned) |
| App Development | Flutter SDK (cross-platform), Dart |

---

## Research Deliverables

1. Full multimodal dataset aligned to clinical cognition metadata
2. ML models for each modality + final ensemble classifier
3. On-device inference pipeline optimized for mobile hardware
4. Performance benchmarks against known ADRD datasets
5. Publication of methodology and findings