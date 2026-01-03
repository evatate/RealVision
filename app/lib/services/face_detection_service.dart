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

  /// Process every Nth frame to reduce load
  static const int _frameSkipRate = 2; // Process every 2nd frame (15 FPS)
  
  // Stability: keep last result for a few frames to reduce flickering
  FaceDetectionResult? _lastResult;
  int _lastResultAge = 0;
  static const int _maxResultAge = 5; // Keep result for 5 frames (~0.3 seconds)

  FaceDetectionService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.1, // 10% of image, better for front camera
      ),
    );
  }

  /// Main face detection entry point
  Future<FaceDetectionResult> detectFace(
    CameraImage image,
    InputImageRotation rotation,
  ) async {
    _frameCounter++;
    
    // If we're skipping this frame, return last result if it's recent
    if (_frameCounter % _frameSkipRate != 0) {
      _lastResultAge++;
      if (_lastResult != null && _lastResultAge <= _maxResultAge) {
        return _lastResult!;
      }
      return FaceDetectionResult(faceDetected: false);
    }

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
        _lastResultAge++;
        return _lastResult ?? FaceDetectionResult(faceDetected: false);
      }

      final faces = await _faceDetector.processImage(inputImage);

      FaceDetectionResult result;
      if (faces.isEmpty) {
        AppLogger.logger.fine('No faces detected in image');
        result = FaceDetectionResult(faceDetected: false);
      } else {
        AppLogger.logger.fine('Detected ${faces.length} face(s)');
        final face = faces.first;
        final smileProbability = face.smilingProbability ?? 0.0;
        
        result = FaceDetectionResult(
          faceDetected: true,
          isSmiling: smileProbability > 0.7,
          smilingProbability: smileProbability,
          boundingBox: face.boundingBox,
          leftEyeOpenProbability: face.leftEyeOpenProbability,
          rightEyeOpenProbability: face.rightEyeOpenProbability,
        );
      }
      
      // Update stability tracking
      _lastResult = result;
      _lastResultAge = 0;
      
      return result;
      
    } catch (e) {
      AppLogger.logger.severe('Face detection error: $e');
      _lastResultAge++;
      return _lastResult ?? FaceDetectionResult(faceDetected: false);
    } finally {
      _isProcessing = false;
    }
  }

  /// Converts CameraImage → InputImage
  InputImage? _convertCameraImage(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    try {
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      
      // Platform-specific handling
      if (Platform.isAndroid) {
        // Android uses NV21 format, pass planes directly
        final inputImageData = InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        );
        
        // For Android, use fromBytes with the Y plane
        return InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: inputImageData,
        );
      } else {
        // iOS uses BGRA8888, concatenate planes
        int totalSize = 0;
        for (final plane in image.planes) {
          totalSize += plane.bytes.length;
        }
        
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
      }
    } catch (e) {
      AppLogger.logger.severe('Image conversion error: $e');
      return null;
    }
  }

  void dispose() {
    _faceDetector.close();
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