import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:io' show Platform;
import '../utils/logger.dart';

class FaceDetectionService {
  late final FaceDetector _faceDetector;

  bool _isProcessing = false;
  int _frameCounter = 0;

  /// Process every frame during assessment, skip some during idle
  static const int _assessmentFrameSkipRate = 0; // Process every frame during tests
  static const int _idleFrameSkipRate = 3; // Process every 3rd frame when idle
  
  bool _isAssessmentActive = false;
  
  // Enhanced stability: keep last result for longer, with confidence decay
  FaceDetectionResult? _lastResult;
  int _lastResultAge = 0;
  static const int _maxResultAge = 10; // Keep result for ~0.5 seconds at 20fps
  
  // Track consecutive detections for stability
  int _consecutiveDetections = 0;
  int _consecutiveNonDetections = 0;
  static const int _detectionConfirmThreshold = 1; // changed from 2 to 1
  static const int _nonDetectionConfirmThreshold = 3; // changed from 5 to 3

  FaceDetectionService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.05, // Slightly more permissive for varied distances
      ),
    );
  }

  void setAssessmentActive(bool active) {
    _isAssessmentActive = active;
    if (active) {
      _frameCounter = 0; // Reset counter when starting assessment
    }
  }

  /// Main face detection entry point with improved frame persistence
  Future<FaceDetectionResult> detectFace(
    CameraImage image,
    InputImageRotation rotation,
  ) async {
    _frameCounter++;
    
    // Dynamic frame skip rate based on assessment state
    final skipRate = _isAssessmentActive ? _assessmentFrameSkipRate : _idleFrameSkipRate;
    
    // If we're skipping this frame, return last result if it's recent
    if (_frameCounter % (skipRate + 1) != 0) {
      _lastResultAge++;
      if (_lastResult != null && _lastResultAge <= _maxResultAge) {
        return _lastResult!;
      }
      // If result is too old, return "not detected" but keep trying
      return FaceDetectionResult(faceDetected: false);
    }

    // If already processing, return cached result
    if (_isProcessing) {
      _lastResultAge++;
      if (_lastResult != null && _lastResultAge <= _maxResultAge) {
        return _lastResult!;
      }
      return FaceDetectionResult(faceDetected: false);
    }

    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image, rotation);
      if (inputImage == null) {
        _isProcessing = false;
        _lastResultAge++;
        return _lastResult ?? FaceDetectionResult(faceDetected: false);
      }

      final faces = await _faceDetector.processImage(inputImage);

      FaceDetectionResult result;
      
      if (faces.isEmpty) {
        _consecutiveNonDetections++;
        _consecutiveDetections = 0;
        
        // Only report non-detection after consecutive failures (reduces flickering)
        if (_consecutiveNonDetections >= _nonDetectionConfirmThreshold) {
          result = FaceDetectionResult(faceDetected: false);
          _lastResult = result;
          _lastResultAge = 0;
        } else {
          // Keep reporting last known good result during brief detection failures
          if (_lastResult != null && _lastResult!.faceDetected) {
            result = _lastResult!;
          } else {
            result = FaceDetectionResult(faceDetected: false);
          }
        }
      } else {
        _consecutiveDetections++;
        _consecutiveNonDetections = 0;
        
        final face = faces.first;
        final smileProbability = face.smilingProbability ?? 0.0;

        // Mirror bounding box horizontally for iOS front camera
        Rect? mirroredBox = face.boundingBox;
        if (Platform.isIOS) {
          final double left = 1.0 - mirroredBox.right;
          final double right = 1.0 - mirroredBox.left;
          mirroredBox = Rect.fromLTRB(left, mirroredBox.top, right, mirroredBox.bottom);
        }
        
        // Only report detection after consecutive successes (reduces false positives)
        if (_consecutiveDetections >= _detectionConfirmThreshold || 
            (_lastResult != null && _lastResult!.faceDetected)) {
          result = FaceDetectionResult(
            faceDetected: true,
            isSmiling: smileProbability > 0.7,
            smilingProbability: smileProbability,
            boundingBox: mirroredBox,
            leftEyeOpenProbability: face.leftEyeOpenProbability,
            rightEyeOpenProbability: face.rightEyeOpenProbability,
          );
          
          _lastResult = result;
          _lastResultAge = 0;
        } else {
          // Building confidence, keep showing previous result
          result = _lastResult ?? FaceDetectionResult(faceDetected: false);
        }
      }
      
      return result;
      
    } catch (e) {
      AppLogger.logger.severe('Face detection error: $e');
      _lastResultAge++;
      // On error, keep using last result if available
      return _lastResult ?? FaceDetectionResult(faceDetected: false);
    } finally {
      _isProcessing = false;
    }
  }

  /// Converts CameraImage → InputImage with improved error handling
  InputImage? _convertCameraImage(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    try {
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      
      if (Platform.isAndroid) {
        // Android uses NV21 format
        final inputImageData = InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        );
        
        return InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: inputImageData,
        );
      } else {
        // iOS uses BGRA8888
        try {
          // Calculate total size needed
          int totalSize = 0;
          for (final plane in image.planes) {
            totalSize += plane.bytes.length;
          }
          
          // Concatenate all planes
          final bytes = Uint8List(totalSize);
          int offset = 0;
          for (final plane in image.planes) {
            bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
            offset += plane.bytes.length;
          }
          
          final inputImageData = InputImageMetadata(
            size: imageSize,
            rotation: rotation,
            format: InputImageFormat.bgra8888,
            bytesPerRow: image.planes.first.bytesPerRow,
          );
          
          return InputImage.fromBytes(
            bytes: bytes,
            metadata: inputImageData,
          );
        } catch (e) {
          AppLogger.logger.warning('iOS image conversion failed: $e');
          return null;
        }
      }
    } catch (e) {
      AppLogger.logger.severe('Image conversion error: $e');
      return null;
    }
  }

  void dispose() {
    _faceDetector.close();
    _lastResult = null;
  }
}

/// Face detection result model
class FaceDetectionResult {
  final bool faceDetected;
  final bool isSmiling;
  final double smilingProbability;
  final Rect? boundingBox;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;

  FaceDetectionResult({
    required this.faceDetected,
    this.isSmiling = false,
    this.smilingProbability = 0.0,
    this.boundingBox,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
  });
}