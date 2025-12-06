# RealVision - ADRD Assessment App

A Flutter application for multimodal Alzheimer's Disease and Related Dementias (ADRD) assessment using machine learning.

## Features

- **Speech Assessment**: Cookie Theft picture description with acoustic and linguistic analysis
- **Eye Tracking**: Fixation stability, pro-saccade, and smooth pursuit tests
- **Facial Expression**: Smile index analysis
- **Gait Analysis**: Walking pattern assessment via HealthKit/Health Connect

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

6. Later we will add TFLite models:
   - Place your `.tflite` model files in `assets/models/`

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

### Platform-Specific Setup

#### iOS:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Set your development team in Signing & Capabilities
3. Enable HealthKit capability
4. Build and run from Xcode or VS Code

#### Android:
1. Enable Health Connect in your Android device settings
2. Grant necessary permissions when prompted
3. Run from VS Code or Android Studio

## Project Structure

- `lib/screens/` - UI screens for each test
- `lib/services/` - Business logic (camera, audio, health, ML)
- `lib/models/` - Data models
- `lib/widgets/` - Reusable UI components
- `lib/utils/` - Constants and utilities
- `assets/` - Images and ML models

## Development Notes

### Adding ML Models
When the TensorFlow Lite models are ready:
1. Convert to `.tflite` format
2. Place in `assets/models/`
3. Update `TFLiteService` to use actual model inputs/outputs

### Testing
```bash
flutter test
```

### Building for Release
```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release
```

## Dementia-Friendly Design Principles Given by Vedant
- Large fonts (24-48px)
- High contrast colors
- Audio instructions at 0.8x speed
- Linear navigation with breadcrumbs
- Generous button spacing
- Sans-serif fonts