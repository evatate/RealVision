import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';

class FaceDetectionService {
  late FaceDetector _faceDetector;
  bool _isProcessing = false;
  
  FaceDetectionService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }
  
  /// Process camera image and detect faces
  Future<FaceDetectionResult> detectFace(CameraImage image, InputImageRotation rotation) async {
    if (_isProcessing) {
      return FaceDetectionResult(
        faceDetected: false,
        isSmiling: false,
        smilingProbability: 0.0,
      );
    }
    
    _isProcessing = true;
    
    try {
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _convertCameraImage(image, rotation);
      if (inputImage == null) {
        _isProcessing = false;
        return FaceDetectionResult(faceDetected: false);
      }
      
      // Detect faces
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      
      _isProcessing = false;
      
      if (faces.isEmpty) {
        return FaceDetectionResult(faceDetected: false);
      }
      
      final face = faces.first;
      
      // Check if smiling (classification returns probability 0-1)
      final smileProbability = face.smilingProbability ?? 0.0;
      final isSmiling = smileProbability > 0.7; // 70% threshold
      
      return FaceDetectionResult(
        faceDetected: true,
        isSmiling: isSmiling,
        smilingProbability: smileProbability,
        boundingBox: face.boundingBox,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
      );
      
    } catch (e) {
      print('Face detection error: $e');
      _isProcessing = false;
      return FaceDetectionResult(faceDetected: false);
    }
  }
  
  /// Convert CameraImage to InputImage
  InputImage? _convertCameraImage(CameraImage image, InputImageRotation rotation) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) 
          ?? InputImageFormat.nv21;
      
      final planeData = image.planes.map((Plane plane) {
        return InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: inputImageFormat,
          bytesPerRow: plane.bytesPerRow,
        );
      }).toList();
      
      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );
      
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageMetadata,
      );
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }
  
  void dispose() {
    _faceDetector.close();
  }
}

/// Result from face detection
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