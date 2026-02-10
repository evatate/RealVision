# RealVision: Multimodal Machine Learning for ADRD Screening

RealVision is a fully deployed, cross-platform (iOS and Android) mobile application for multimodal screening of Alzheimer’s Disease and Related Dementias (ADRD). The system integrates four behavioral and neurological indicators that have been independently validated in prior machine learning and clinical research:

1. Speech and prosodic impairments
2. Abnormal eye movement characteristics
3. Reduced facial expressiveness
4. Gait instability and changes in walking biomechanics

The project consists of a complete pipeline including data acquisition, multimodal feature extraction, supervised machine learning architectures, and deployment to a patient-facing mobile application.

RealVision is designed as a **screening and research tool**, not a diagnostic system. The platform will be used in clinical validation studies.

---

## Clinical Motivation

Clinical diagnosis of ADRD typically occurs years after symptom onset due to:
- Limited access to neurological testing
- Subtle early-phase behavioral changes
- Lack of scalable continuous monitoring options

Prior work has shown that individual modalities can identify ADRD characteristics with strong statistical significance:
- Speech analysis approaches ~83% classification accuracy on standardized datasets
- Eye movement metrics achieve up to ~95% discrimination in controlled oculomotor tasks
- Gait speed and variability decline years before clinical diagnosis  
- Facial expressiveness, including smile dynamics, differs significantly between ADRD/MCI and healthy controls  

RealVision unifies these signals into a single, patient-facing smartphone application, enabling scalable, low-burden cognitive screening outside traditional clinical environments.

---

## System Overview

RealVision follows a **feature-based multimodal ML architecture**, prioritizing interpretability and clinical generalizability over end-to-end deep learning.

| Modality | Input | Feature Extraction | Output |
|--------|------|------------------|--------|
| **Speech** | Audio + transcript | Acoustic, linguistic, semantic features | Cognitive risk score + MMSE regression |
| **Eye Tracking** | Front camera video | Fixation stability, saccade latency, pursuit error | Oculomotor impairment score |
| **Facial Expressions** | Front camera video | Smile index dynamics, facial variability | Facial expressiveness score |
| **Gait** | Accelerometer and Gyroscope | Speed, cadence, variability | Gait unsteadiness score |

---

## Mobile Application

**Fully functional on both iOS and Android**

The mobile app implements:
- A guided speech recording task
- Three eye-tracking tasks (fixation, pro-saccade, smooth pursuit)  
- A standardized smile test (two 15-second trials)  
- A 2-minute walking test using device health APIs  

The UI is intentionally simple and voice-guided to support older adults and first-time users, consistent with prior clinical tablet-based studies and guides for dementia-friendly design.

---

## Cloud Infrastructure & Security

RealVision is deployed entirely on **Amazon Web Services (AWS)**:

- **Private S3 buckets** for encrypted storage of video, audio, and sensor data  
- **EC2 instances** for model inference and batch processing  
- **API Gateway + Lambda** for secure request handling  
- Structured data stored in managed relational databases  

All data handling follows **HIPAA-compliant architecture patterns**, including:
- Encrypted data at rest and in transit  
- Restricted IAM access policies
- Separation of identifiers from behavioral data  

This deployment mirrors cloud-based architectures used in prior validated mobile cognitive assessment systems.

---

## Current Project Status

### Speech Pipeline (Completed)
- ADReSS-2020 feature extraction
- Acoustic (eGeMAPS), linguistic, and pause-based features
- Random Forest classifier trained
- ~84% cross-validated accuracy

### Facial Expression Pipeline (Completed)
- Frame-level smile index (0–100)
- Time-series feature extraction from standardized smile tests
- Smile strength, variability, reaction time, and contrast metrics

### Eye Tracking Pipeline (Completed)
- Smartphone-based eye landmark tracking
- Relative oculomotor features (stability, latency, pursuit error)
- Task design aligned with prior eye-movement studies

### Gait Pipeline (Completed)
- Walking speed, cadence, and variability from HealthKit / Health Connect
- Session-level gait unsteadiness metrics

### Beta Testing (Completed)
- Critical bug fixes

### Current Work
- Final preparation for clinical trials

---

## Tech Stack

| Layer | Tools and Frameworks |
|------|---------------------|
| Mobile App | Flutter (iOS & Android) |
| ML Model Development | Python, PyTorch, Transformers, scikit-learn |
| Speech Feature Extraction | openSMILE, librosa, NLP preprocessing |
| Computer Vision | MediaPipe, TensorFlow Lite |
| Cloud | AWS (S3, EC2, Lambda, API Gateway) |
| Security | HIPAA-aligned AWS architecture |

---

## Deployment

RealVision is currently available on the App Store and pending approval on the Google Play Store. It currently requires a
partiicpant ID provided by research staff.

__

## Disclaimer

RealVision is a **research and screening tool only**.  
It does not provide medical diagnoses and should not be used as a standalone clinical decision system.