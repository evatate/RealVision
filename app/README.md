# RealVision - ADRD Assessment App

A Flutter application for multimodal Alzheimer's Disease and Related Dementias (ADRD) assessment using machine learning.

---

## Features

The app walks users through a checklist-style assessment consisting of:

### Speech Test
- Shows the Cookie Theft image
- Records spoken responses directly from the device microphone
- Audio is sent to private AWS S3 buckets for later ML transcription and analysis

### Eye Tracking Tests
Uses the front-facing camera:
- **Fixation Stability:** stare at a crosshair without blinking
- **Pro-saccade Test:** quickly look toward appearing targets
- **Smooth Pursuit:** track a moving dot across the screen
- Sends JSONs to S3 data bin  
These tasks reflect oculomotor impairments associated with ADRD.

### Smile Test
- Prompts: “Smile” → “Return to neutral”
- Records facial muscle movement
- Sends JSON labeled with participant ID to S3 data bin

### Walking Test — Gait Analysis
- Prompts the user to walk normally for 2 minutes
- Collects step and movement data via phone sensors (accelerometer/gyroscope)
- Detects gait irregularities linked to cognitive decline
- Sends JSONs of gait features to S3 data bin

As tasks are completed, checkmarks appear. When finished, the “View Results” button will be available.

## Dementia-Friendly Design Principles
- Large fonts (24-48px)
- High contrast colors
- Audio instructions at 0.8x speed
- Linear navigation with breadcrumbs
- Generous button spacing
- Sans-serif fonts

---

## Status of Testing Across Platforms

| Platform | Status |
|---------|--------|
| **Android** | Awaiting Google Play acceptance |
| **iOS** | Published to the App Store |

---

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Xcode (for iOS development)
- Android Studio (for Android development)
- VS Code with Flutter extension

### Installation

1. Clone or create the project:
```bash
flutter create realvision
cd realvision
```

2. Copy all the files from this artifact into the project directory

3. Install dependencies:
```bash
flutter pub get
```

4. For iOS: Install CocoaPods dependencies
```bash
cd ios
pod install
cd ..
```

5. Add the Cookie Theft image:
   - Place `cookie_theft.png` in `assets/images/`

### Running the App

#### In VS Code:
1. Open the project folder in VS Code
2. Start an emulator
3. Press F5 or click "Run" → "Start Debugging"
4. Select the target device

#### Command line:
```bash
# List available devices
flutter devices

# Run on connected device
flutter run

# Run on specific device
flutter run -d <device-id>

# Run in release mode
flutter run --release
```

## Project Structure

- `lib/screens/` - UI screens for each test
- `lib/services/` - Core logic (camera, audio, motion, storage)
- `lib/models/` - Data models (calculating features)
- `lib/widgets/` - Reusable UI components
- `lib/utils/` - Constants and utilities
- `assets/` - Images and ML models