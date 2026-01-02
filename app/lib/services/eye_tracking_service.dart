import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';

// Data class for background qprocessing
class _ProcessingData {
  final CameraImage image;
  final Offset targetPosition;
  final Size screenSize;
  final Offset driftOffset;
  final bool isCollectingDriftData;
  final InputImageRotation rotation;

  _ProcessingData({
    required this.image,
    required this.targetPosition,
    required this.screenSize,
    required this.driftOffset,
    required this.isCollectingDriftData,
    required this.rotation,
  });
}

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
  final List<GazePoint> _gazeData = [];
  
  // Drift correction variables
  Offset _driftOffset = Offset.zero;
  bool _isCollectingDriftData = false;
  final List<Offset> _driftSamples = [];
  
  // Performance optimization: adaptive frame processing
  int _frameCounter = 0;
  static const int _normalFrameSkipRate = 1; // Full processing during critical assessment periods
  static const int _backgroundFrameSkipRate = 2; // Better responsiveness during non-assessment periods
  
  int get _currentFrameSkipRate => _isAssessmentActive ? _normalFrameSkipRate : _backgroundFrameSkipRate;
  bool _isAssessmentActive = false; // Set this based on trial state
  
  // Stability: keep last result for a few frames to reduce flickering
  GazePoint? _lastGazePoint;
  int _lastResultAge = 0;
  static const int _maxResultAge = 5; // Keep result for 5 frames (~0.3 seconds)
  
  EyeTrackingService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        minFaceSize: 0.1, // Match face detection service
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  // Background processing function for ML inference
  static Future<GazePoint?> _processImageInBackground(_ProcessingData data) async {
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        minFaceSize: 0.1, // Match face detection service
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    try {
      final inputImage = _convertCameraImageStatic(data.image, data.rotation);
      if (inputImage == null) return null;

      final List<Face> faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) return null;

      final face = faces.first;
      
      // Get key landmarks
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      final noseBase = face.landmarks[FaceLandmarkType.noseBase];
      
      if (leftEye == null || rightEye == null || noseBase == null) return null;
      
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
      var screenX = eyeCenter.dx / data.image.width.toDouble();
      var screenY = eyeCenter.dy / data.image.height.toDouble();
      
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
      screenX += data.driftOffset.dx;
      screenY += data.driftOffset.dy;
      
      // Clamp to valid range
      screenX = screenX.clamp(0.0, 1.0);
      screenY = screenY.clamp(0.0, 1.0);
      
      final normalizedGaze = Offset(screenX, screenY);
      
      // Calculate distance from gaze to target
      final distance = _calculateDistanceStatic(normalizedGaze, data.targetPosition);
      
      final gazePoint = GazePoint(
        eyePosition: normalizedGaze,
        targetPosition: data.targetPosition,
        timestamp: DateTime.now(),
        distance: distance,
        headPoseX: headPitch,
        headPoseY: headYaw,
        headPoseZ: headRoll,
      );
      
      return gazePoint;
      
    } catch (e) {
      // Note: Can't use AppLogger in isolate, so we return null on error
      return null;
    } finally {
      faceDetector.close();
    }
  }

  // Static version of _convertCameraImage for background processing
  static InputImage? _convertCameraImageStatic(CameraImage image, InputImageRotation rotation) {
    try {
      // Calculate total size and concatenate all planes
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
      
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      
      // Use actual image format instead of hardcoding
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) 
          ?? InputImageFormat.bgra8888; // fallback for iOS
      
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
      return null;
    }
  }

  // Static version of _calculateDistance for background processing
  static double _calculateDistanceStatic(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  /// Set assessment active state for adaptive processing
  void setAssessmentActive(bool active) {
    _isAssessmentActive = active;
  }
  
  /// Start collecting drift correction data
  void startDriftCorrection() {
    _isCollectingDriftData = true;
    _driftSamples.clear();
  }
  
  /// Finalize drift correction by calculating offset
  void finalizeDriftCorrection() {
    if (_driftSamples.isEmpty) {
      _driftOffset = Offset.zero;
    } else {
      // Calculate mean offset from center (0.5, 0.5)
      final meanX = _driftSamples.map((o) => o.dx).reduce((a, b) => a + b) / _driftSamples.length;
      final meanY = _driftSamples.map((o) => o.dy).reduce((a, b) => a + b) / _driftSamples.length;
      
      // Drift offset is how far off from center the gaze was
      _driftOffset = Offset(0.5 - meanX, 0.5 - meanY);
      
      AppLogger.logger.info('Drift correction: offset = (${_driftOffset.dx.toStringAsFixed(3)}, ${_driftOffset.dy.toStringAsFixed(3)})');
    }
    
    _isCollectingDriftData = false;
    _driftSamples.clear();
  }
  
  /// Track user's gaze relative to target position
  Future<GazePoint?> trackGaze(
    CameraImage image,
    Offset targetPosition,
    Size screenSize,
    InputImageRotation rotation,
  ) async {
    // Skip frames to reduce processing load
    _frameCounter++;
    
    // If we're skipping this frame, return last result if it's recent
    if (_frameCounter % _currentFrameSkipRate != 0) {
      _lastResultAge++;
      if (_lastGazePoint != null && _lastResultAge <= _maxResultAge) {
        return _lastGazePoint!;
      }
      return null; // Skip this frame
    }
    
    if (_isProcessing) {
      _lastResultAge++;
      if (_lastGazePoint != null && _lastResultAge <= _maxResultAge) {
        return _lastGazePoint!;
      }
      return null;
    }
    
    _isProcessing = true;
    
    try {
      // Process image in background isolate to avoid blocking main thread
      final processingData = _ProcessingData(
        image: image,
        targetPosition: targetPosition,
        screenSize: screenSize,
        driftOffset: _driftOffset,
        isCollectingDriftData: _isCollectingDriftData,
        rotation: rotation,
      );
      
      //AppLogger.logger.fine('Starting background gaze processing');
      final gazePoint = await compute(_processImageInBackground, processingData);
      //AppLogger.logger.fine('Background gaze processing result: ${gazePoint != null ? 'success' : 'null'}');
      
      _isProcessing = false;
      
      if (gazePoint == null) {
        _lastResultAge++;
        if (_lastGazePoint != null && _lastResultAge <= _maxResultAge) {
          return _lastGazePoint!;
        }
        return null;
      }
      
      // If collecting drift data, store raw gaze position
      if (_isCollectingDriftData) {
        _driftSamples.add(gazePoint.eyePosition);
      }
      
      // Update stability tracking
      _lastGazePoint = gazePoint;
      _lastResultAge = 0;
      
      return gazePoint;
      
    } catch (e) {
      AppLogger.logger.severe('Gaze tracking error: $e');
      _isProcessing = false;
      _lastResultAge++;
      if (_lastGazePoint != null && _lastResultAge <= _maxResultAge) {
        return _lastGazePoint!;
      }
      return null;
    }
  }
  
  /// Record a gaze point for later analysis
  void recordGazePoint(GazePoint point) {
    _gazeData.add(point);
  }
  
  /// Get all recorded gaze data
  List<GazePoint> getGazeData() {
    return List.from(_gazeData);
  }
  
  /// Calculate Euclidean distance between two points
  double _calculateDistance(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  /// Get fixation stability metrics
  Map<String, dynamic> getFixationMetrics() {
    if (_gazeData.isEmpty) {
      return {
        'largeIntrusiveSaccades': 0,
        'squareWaveJerks': 0,
        'maxFixationDuration': 0.0,
        'meanDistance': 0.0,
        'stdDistance': 0.0,
      };
    }
    
    // Debug: print sample data
    if (_gazeData.length > 10) {
      AppLogger.logger.fine('Sample gaze data (first 5 points):');
      for (int i = 0; i < math.min(5, _gazeData.length); i++) {
        AppLogger.logger.fine('  Eye: (${_gazeData[i].eyePosition.dx.toStringAsFixed(3)}, ${_gazeData[i].eyePosition.dy.toStringAsFixed(3)}), '
              'Target: (${_gazeData[i].targetPosition.dx.toStringAsFixed(3)}, ${_gazeData[i].targetPosition.dy.toStringAsFixed(3)}), '
              'Distance: ${_gazeData[i].distance.toStringAsFixed(3)}, '
              'Head Pitch: ${_gazeData[i].headPoseX.toStringAsFixed(1)}°');
      }
    }
    
    // Large intrusive saccades (>2° visual angle, approx 0.035 in normalized coords)
    int largeIntrusiveSaccades = 0;
    for (int i = 1; i < _gazeData.length; i++) {
      final movement = _calculateDistance(
        _gazeData[i].eyePosition,
        _gazeData[i - 1].eyePosition,
      );
      if (movement > 0.035) {
        largeIntrusiveSaccades++;
      }
    }
    
    // Square wave jerks detection
    int squareWaveJerks = 0;
    for (int i = 2; i < _gazeData.length; i++) {
      final move1 = _calculateDistance(
        _gazeData[i - 1].eyePosition,
        _gazeData[i - 2].eyePosition,
      );
      final move2 = _calculateDistance(
        _gazeData[i].eyePosition,
        _gazeData[i - 1].eyePosition,
      );
      
      if (move1 > 0.01 && move1 < 0.035 && move2 > 0.01 && move2 < 0.035) {
        final timeDiff = _gazeData[i].timestamp.difference(_gazeData[i - 1].timestamp).inMilliseconds;
        if (timeDiff < 300) {
          squareWaveJerks++;
        }
      }
    }
    
    // Maximum fixation duration
    double maxFixationDuration = 0.0;
    double currentFixationDuration = 0.0;
    const fixationThreshold = 0.05;
    
    for (int i = 1; i < _gazeData.length; i++) {
      if (_gazeData[i].distance < fixationThreshold) {
        final duration = _gazeData[i].timestamp.difference(_gazeData[i - 1].timestamp).inMilliseconds;
        currentFixationDuration += duration;
      } else {
        if (currentFixationDuration > maxFixationDuration) {
          maxFixationDuration = currentFixationDuration;
        }
        currentFixationDuration = 0.0;
      }
    }
    
    if (currentFixationDuration > maxFixationDuration) {
      maxFixationDuration = currentFixationDuration;
    }
    
    // Mean and std of distance from target
    final distances = _gazeData.map((p) => p.distance).toList();
    final meanDistance = distances.reduce((a, b) => a + b) / distances.length;
    final variance = distances.map((d) => math.pow(d - meanDistance, 2)).reduce((a, b) => a + b) / distances.length;
    final stdDistance = math.sqrt(variance);
    
    return {
      'largeIntrusiveSaccades': largeIntrusiveSaccades,
      'squareWaveJerks': squareWaveJerks,
      'maxFixationDuration': maxFixationDuration,
      'meanDistance': meanDistance,
      'stdDistance': stdDistance,
      'totalDataPoints': _gazeData.length,
    };
  }
  
  /// Get pro-saccade metrics
  Map<String, dynamic> getProsaccadeMetrics() {
    if (_gazeData.isEmpty) {
      return {
        'accuracy': 0.0,
        'meanLatency': 0.0,
        'meanSaccades': 0.0,
      };
    }
    
    // Group data by trials (target changes indicate new trials)
    final trials = <List<GazePoint>>[];
    List<GazePoint> currentTrial = [_gazeData[0]];
    
    for (int i = 1; i < _gazeData.length; i++) {
      if (_calculateDistance(_gazeData[i].targetPosition, _gazeData[i - 1].targetPosition) > 0.1) {
        trials.add(currentTrial);
        currentTrial = [_gazeData[i]];
      } else {
        currentTrial.add(_gazeData[i]);
      }
    }
    trials.add(currentTrial);
    
    int successfulTrials = 0;
    double totalLatency = 0.0;
    double totalSaccades = 0.0;
    
    const double TARGET_THRESHOLD = 0.10;
    
    for (final trial in trials) {
      if (trial.isEmpty) continue;
      
      // Check if target was reached
      final reachedTarget = trial.any((p) => p.distance < TARGET_THRESHOLD);
      if (reachedTarget) {
        successfulTrials++;
        
        // Find time to reach target
        final firstReach = trial.firstWhere((p) => p.distance < TARGET_THRESHOLD);
        final latency = firstReach.timestamp.difference(trial.first.timestamp).inMilliseconds;
        totalLatency += latency;
        
        // Count saccades
        int saccades = 0;
        for (int i = 1; i < trial.length; i++) {
          final movement = _calculateDistance(trial[i].eyePosition, trial[i - 1].eyePosition);
          if (movement > 0.02) {
            saccades++;
          }
        }
        totalSaccades += saccades;
      }
    }
    
    final accuracy = successfulTrials / trials.length;
    final meanLatency = successfulTrials > 0 ? totalLatency / successfulTrials : 0.0;
    final meanSaccades = successfulTrials > 0 ? totalSaccades / successfulTrials : 0.0;
    
    AppLogger.logger.info('Pro-saccade: $successfulTrials successful out of ${trials.length} trials');
    
    return {
      'accuracy': accuracy,
      'meanLatency': meanLatency,
      'meanSaccades': meanSaccades,
      'totalTrials': trials.length,
      'successfulTrials': successfulTrials,
    };
  }
  
  /// Get smooth pursuit metrics
  Map<String, dynamic> getSmoothPursuitMetrics() {
    if (_gazeData.length < 2) {
      return {
        'pursuitGain': 0.0,
        'proportionPursuing': 0.0,
        'catchUpSaccades': 0,
      };
    }
    
    double totalEyeVelocity = 0.0;
    double totalTargetVelocity = 0.0;
    int pursuingCount = 0;
    int catchUpSaccades = 0;
    
    for (int i = 1; i < _gazeData.length; i++) {
      final timeDiff = _gazeData[i].timestamp.difference(_gazeData[i - 1].timestamp).inMilliseconds / 1000.0;
      if (timeDiff == 0) continue;
      
      // Eye velocity
      final eyeMovement = _calculateDistance(
        _gazeData[i].eyePosition,
        _gazeData[i - 1].eyePosition,
      );
      final eyeVelocity = eyeMovement / timeDiff;
      
      // Target velocity
      final targetMovement = _calculateDistance(
        _gazeData[i].targetPosition,
        _gazeData[i - 1].targetPosition,
      );
      final targetVelocity = targetMovement / timeDiff;
      
      // Consider as "pursuing" if eye velocity > 0.5 * target velocity
      if (targetVelocity > 0 && eyeVelocity > 0.5 * targetVelocity) {
        totalEyeVelocity += eyeVelocity;
        totalTargetVelocity += targetVelocity;
        pursuingCount++;
      }
      
      // Catch-up saccades
      if (eyeMovement > 0.03 && _gazeData[i].distance > 0.05) {
        catchUpSaccades++;
      }
    }
    
    final pursuitGain = totalTargetVelocity > 0 ? totalEyeVelocity / totalTargetVelocity : 0.0;
    final proportionPursuing = pursuingCount / (_gazeData.length - 1);
    
    return {
      'pursuitGain': pursuitGain,
      'proportionPursuing': proportionPursuing,
      'catchUpSaccades': catchUpSaccades,
      'totalDataPoints': _gazeData.length,
    };
  }
  
  /// Clear all recorded gaze data
  void clearData() {
    _gazeData.clear();
  }
  
  void dispose() {
    _faceDetector.close();
    _gazeData.clear();
    _driftSamples.clear();
  }
}