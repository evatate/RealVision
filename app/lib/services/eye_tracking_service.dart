import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io' show Platform;
import '../models/eye_tracking_data.dart';

class GazePoint {
  final Offset eyePosition;
  final Offset targetPosition;
  final DateTime timestamp;
  final double distance;
  final double headPoseX;
  final double headPoseY;
  final double headPoseZ;
  
  GazePoint({
    required this.eyePosition,
    required this.targetPosition,
    required this.timestamp,
    required this.distance,
    required this.headPoseX,
    required this.headPoseY,
    required this.headPoseZ,
  });
}

class EyeTrackingService {
  late FaceDetector _faceDetector;
  bool _isProcessing = false;
  final List<EyeTrackingFrame> _eyeTrackingFrames = [];
  DateTime? _trialStartTime;
  String _currentTaskType = 'fixation';
  Offset _currentTargetPosition = Offset.zero;

  // Drift correction variables
  Offset _driftOffset = Offset.zero;
  bool _isCollectingDriftData = false;
  final List<Offset> _driftSamples = [];

  // Performance optimization
  int _frameCounter = 0;
  static const int _normalFrameSkipRate = 1;
  static const int _backgroundFrameSkipRate = 2;

  int get _currentFrameSkipRate => _isAssessmentActive ? _normalFrameSkipRate : _backgroundFrameSkipRate;
  bool _isAssessmentActive = false;

  // Stability
  EyeTrackingFrame? _lastFrame;
  int _lastResultAge = 0;
  static const int _maxResultAge = 5;
  
  EyeTrackingService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        minFaceSize: 0.1,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }
  
  void setAssessmentActive(bool active) {
    _isAssessmentActive = active;
  }

  void setTaskType(String taskType) {
    _currentTaskType = taskType;
  }

  void setTargetPosition(Offset position) {
    _currentTargetPosition = position;
  }

  void startTrial() {
    _trialStartTime = DateTime.now();
    _eyeTrackingFrames.clear();
    AppLogger.logger.info('Started eye tracking trial: $_currentTaskType');
  }

  /// Track user's gaze and return EyeTrackingFrame
  Future<EyeTrackingFrame?> trackGaze(
    CameraImage image,
    Offset targetPosition,
    Size screenSize,
    InputImageRotation rotation,
  ) async {
    // Skip frames to reduce processing load
    _frameCounter++;

    if (_frameCounter % _currentFrameSkipRate != 0) {
      return _lastFrame;
    }

    if (_isProcessing) {
      return _lastFrame;
    }

    _isProcessing = true;

    try {
      // Convert camera image to InputImage
      final inputImage = _convertCameraImage(image, rotation);
      if (inputImage == null) {
        _isProcessing = false;
        return null;
      }

      // Detect faces
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        _isProcessing = false;
        return null;
      }

      final face = faces.first;

      // Get key landmarks
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      final noseBase = face.landmarks[FaceLandmarkType.noseBase];

      if (leftEye == null || rightEye == null || noseBase == null) {
        _isProcessing = false;
        return null;
      }

      // Calculate eye center
      final eyeCenter = Offset(
        (leftEye.position.x + rightEye.position.x) / 2.0,
        (leftEye.position.y + rightEye.position.y) / 2.0,
      );

      // Get head pose angles
      final headPitch = face.headEulerAngleX ?? 0.0;
      final headYaw = face.headEulerAngleY ?? 0.0;
      final headRoll = face.headEulerAngleZ ?? 0.0;

      // Map camera frame to screen coordinates
      var screenX = eyeCenter.dx / image.width.toDouble();
      var screenY = eyeCenter.dy / image.height.toDouble();

      // Apply head pose corrections
      final pitchCorrection = headPitch * -0.025;
      screenY += pitchCorrection;

      final yawCorrection = headYaw * 0.015;
      screenX -= yawCorrection;

      // Eye position in face correction
      final faceBox = face.boundingBox;
      final eyePositionInFace = (eyeCenter.dy - faceBox.top) / faceBox.height;
      if (eyePositionInFace > 0.4) {
        screenY -= (eyePositionInFace - 0.4) * 0.1;
      }

      // Apply drift correction
      screenX += _driftOffset.dx;
      screenY += _driftOffset.dy;

      // Clamp to valid range
      screenX = screenX.clamp(0.0, 1.0);
      screenY = screenY.clamp(0.0, 1.0);

      final normalizedGaze = Offset(screenX, screenY);

      // Calculate distance from gaze to target
      final distance = _calculateDistance(normalizedGaze, targetPosition);

      // Create EyeTrackingFrame
      final timestamp = _trialStartTime != null
          ? DateTime.now().difference(_trialStartTime!).inMilliseconds / 1000.0
          : 0.0;

      final frame = EyeTrackingFrame(
        timestamp: timestamp,
        eyePosition: normalizedGaze,
        targetPosition: targetPosition,
        distance: distance,
        headPoseX: headPitch,
        headPoseY: headYaw,
        headPoseZ: headRoll,
      );

      // Store frame if trial is active
      if (_trialStartTime != null) {
        _eyeTrackingFrames.add(frame);
      }

      // If collecting drift data, store raw gaze position
      if (_isCollectingDriftData) {
        _driftSamples.add(frame.eyePosition);
      }

      // Update stability tracking
      _lastFrame = frame;

      _isProcessing = false;
      return frame;

    } catch (e) {
      AppLogger.logger.severe('Gaze tracking error: $e');
      _isProcessing = false;
      return _lastFrame;
    }
  }
  
  EyeTrackingTrialData completeTrial() {
    final trialData = EyeTrackingTrialData(
      trialNumber: 1, // Will be set by the screen
      taskType: _currentTaskType,
      frames: List.from(_eyeTrackingFrames),
      qualityScore: _calculateTrialQualityScore(),
    );

    _trialStartTime = null;
    _eyeTrackingFrames.clear();

    AppLogger.logger.info('Completed eye tracking trial: $_currentTaskType with ${trialData.frames.length} frames');
    return trialData;
  }

  double _calculateTrialQualityScore() {
    if (_eyeTrackingFrames.isEmpty) return 0.0;

    // Calculate quality based on data consistency and tracking stability
    final avgDistance = _eyeTrackingFrames.map((f) => f.distance).reduce((a, b) => a + b) / _eyeTrackingFrames.length;
    final frameCount = _eyeTrackingFrames.length;

    // Quality score based on data quantity and accuracy
    final quantityScore = math.min(frameCount / 100.0, 1.0); // Prefer at least 100 frames
    final accuracyScore = math.max(0.0, 1.0 - avgDistance * 2.0); // Lower distance is better

    return (quantityScore + accuracyScore) / 2.0;
  }

  void startDriftCorrection() {
    _isCollectingDriftData = true;
    _driftSamples.clear();
  }

  void finalizeDriftCorrection() {
    if (_driftSamples.isEmpty) {
      _driftOffset = Offset.zero;
    } else {
      final meanX = _driftSamples.map((o) => o.dx).reduce((a, b) => a + b) / _driftSamples.length;
      final meanY = _driftSamples.map((o) => o.dy).reduce((a, b) => a + b) / _driftSamples.length;

      _driftOffset = Offset(0.5 - meanX, 0.5 - meanY);

      AppLogger.logger.info('Drift correction: offset = (${_driftOffset.dx.toStringAsFixed(3)}, ${_driftOffset.dy.toStringAsFixed(3)})');
    }

    _isCollectingDriftData = false;
    _driftSamples.clear();
  }
  
  double _calculateDistance(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  /// Convert CameraImage to InputImage
  InputImage? _convertCameraImage(CameraImage image, InputImageRotation rotation) {
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
      AppLogger.logger.severe('Error converting camera image: $e');
      return null;
    }
  }
  
  void clearData() {
    _eyeTrackingFrames.clear();
    _trialStartTime = null;
  }

  void dispose() {
    _faceDetector.close();
    _eyeTrackingFrames.clear();
    _driftSamples.clear();
  }
}