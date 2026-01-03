import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

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
  
  // Performance optimization
  int _frameCounter = 0;
  static const int _normalFrameSkipRate = 1;
  static const int _backgroundFrameSkipRate = 2;
  
  int get _currentFrameSkipRate => _isAssessmentActive ? _normalFrameSkipRate : _backgroundFrameSkipRate;
  bool _isAssessmentActive = false;
  
  // Stability
  GazePoint? _lastGazePoint;
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
  
  /// Track user's gaze relative to target position
  Future<GazePoint?> trackGaze(
    CameraImage image,
    Offset targetPosition,
    Size screenSize,
    InputImageRotation rotation,
  ) async {
    // Skip frames to reduce processing load
    _frameCounter++;
    
    if (_frameCounter % _currentFrameSkipRate != 0) {
      _lastResultAge++;
      if (_lastGazePoint != null && _lastResultAge <= _maxResultAge) {
        return _lastGazePoint!;
      }
      return null;
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
      
      final gazePoint = GazePoint(
        eyePosition: normalizedGaze,
        targetPosition: targetPosition,
        timestamp: DateTime.now(),
        distance: distance,
        headPoseX: headPitch,
        headPoseY: headYaw,
        headPoseZ: headRoll,
      );
      
      _isProcessing = false;
      
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
  
  void recordGazePoint(GazePoint point) {
    _gazeData.add(point);
  }
  
  List<GazePoint> getGazeData() {
    return List.from(_gazeData);
  }
  
  double _calculateDistance(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  /// Convert CameraImage to InputImage
  InputImage? _convertCameraImage(CameraImage image, InputImageRotation rotation) {
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
      
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) 
          ?? InputImageFormat.bgra8888;
      
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
      AppLogger.logger.severe('Error converting camera image: $e');
      return null;
    }
  }
  
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
    
    double maxFixationDuration = 0.0;
    double currentFixationDuration = 0.0;
    const fixationThreshold = 0.25; // Increased from 0.15 to be more lenient
    
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
    
    // Convert milliseconds to seconds
    maxFixationDuration = maxFixationDuration / 1000.0;
    
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
  
  Map<String, dynamic> getProsaccadeMetrics() {
    if (_gazeData.isEmpty) {
      return {
        'accuracy': 0.0,
        'meanLatency': 0.0,
        'meanSaccades': 0.0,
      };
    }
    
    final trials = <List<GazePoint>>[];
    List<GazePoint> currentTrial = [_gazeData[0]];
    
    // Group data by trials - detect when target moves to peripheral position
    for (int i = 1; i < _gazeData.length; i++) {
      final currentTarget = _gazeData[i].targetPosition;
      final prevTarget = _gazeData[i - 1].targetPosition;
      
      // Check if this is a transition to peripheral target (away from center)
      final isCenterPrev = _calculateDistance(prevTarget, const Offset(0.5, 0.5)) < 0.01;
      final isPeripheralCurrent = _calculateDistance(currentTarget, const Offset(0.5, 0.5)) > 0.1;
      
      if (isCenterPrev && isPeripheralCurrent) {
        // Start new trial when peripheral target appears
        if (currentTrial.isNotEmpty) {
          trials.add(currentTrial);
        }
        currentTrial = [_gazeData[i]];
      } else {
        currentTrial.add(_gazeData[i]);
      }
    }
    if (currentTrial.isNotEmpty) {
      trials.add(currentTrial);
    }
    
    int successfulTrials = 0;
    double totalLatency = 0.0;
    double totalSaccades = 0.0;
    
    const double TARGET_THRESHOLD = 0.15; // Increased threshold for success
    
    for (final trial in trials) {
      if (trial.isEmpty) continue;
      
      // Find when peripheral target appeared (first point in trial)
      final targetOnset = trial.first.timestamp;
      
      // Check if gaze reached target within reasonable time
      final reachedPoints = trial.where((p) => p.distance < TARGET_THRESHOLD).toList();
      if (reachedPoints.isNotEmpty) {
        successfulTrials++;
        
        final firstReach = reachedPoints.first;
        final latency = firstReach.timestamp.difference(targetOnset).inMilliseconds;
        
        // Only count reasonable latencies (under 1 second)
        if (latency > 0 && latency < 1000) {
          totalLatency += latency;
        }
        
        int saccades = 0;
        for (int i = 1; i < trial.length; i++) {
          final movement = _calculateDistance(trial[i].eyePosition, trial[i - 1].eyePosition);
          if (movement > 0.03) { // Increased threshold for saccade detection
            saccades++;
          }
        }
        totalSaccades += saccades;
      }
    }
    
    final accuracy = trials.isNotEmpty ? successfulTrials / trials.length : 0.0;
    final meanLatency = successfulTrials > 0 ? totalLatency / successfulTrials : 0.0;
    final meanSaccades = successfulTrials > 0 ? totalSaccades / successfulTrials : 0.0;
    
    return {
      'accuracy': accuracy,
      'meanLatency': meanLatency,
      'meanSaccades': meanSaccades,
      'totalTrials': trials.length,
      'successfulTrials': successfulTrials,
    };
  }
  
  Map<String, dynamic> getSmoothPursuitMetrics() {
    if (_gazeData.length < 10) {
      return {
        'pursuitGain': 0.0,
        'proportionPursuing': 0.0,
        'catchUpSaccades': 0,
        'totalDataPoints': _gazeData.length,
      };
    }

    // For smooth pursuit, analyze the sinusoidal target movement
    // Target moves as: position = 0.5 + 0.2 * sin(2π * f * t)
    // Velocity = 0.2 * 2π * f * cos(2π * f * t)

    double totalGain = 0.0;
    int gainSamples = 0;
    int pursuingCount = 0;
    int catchUpSaccades = 0;
    int totalSamples = 0;

    // Assume frequency based on trial pattern (0.25 or 0.5 Hz)
    // We'll estimate it from the data or use a reasonable default
    const double assumedFrequency = 0.375; // Average of 0.25 and 0.5
    const double amplitude = 0.2;
    const double maxTargetVelocity = amplitude * 2 * math.pi * assumedFrequency;

    for (int i = 2; i < _gazeData.length; i++) {
      final timeDiff = _gazeData[i].timestamp.difference(_gazeData[i - 1].timestamp).inMilliseconds / 1000.0;
      if (timeDiff <= 0 || timeDiff > 0.1) continue; // Skip invalid or large time gaps

      totalSamples++;

      // Calculate eye velocity (smoothed over 3 points for stability)
      final eyeMovement1 = _calculateDistance(_gazeData[i].eyePosition, _gazeData[i - 1].eyePosition);
      final eyeMovement2 = _calculateDistance(_gazeData[i - 1].eyePosition, _gazeData[i - 2].eyePosition);
      final eyeVelocity = (eyeMovement1 + eyeMovement2) / (2 * timeDiff);

      // Calculate target velocity based on sinusoidal movement
      // For position = 0.5 + A * sin(ωt), velocity = A * ω * cos(ωt)
      final targetPos = _gazeData[i].targetPosition.dx; // Assume horizontal for now
      final normalizedPos = (targetPos - 0.5) / amplitude; // Should be between -1 and 1

      if (normalizedPos.abs() <= 1.0) { // Valid sinusoidal position
        final cosValue = math.sqrt(1 - normalizedPos * normalizedPos); // cos(arcsin(x)) = sqrt(1-x²)
        final targetVelocity = amplitude * 2 * math.pi * assumedFrequency * cosValue;

        if (targetVelocity > 0.01) { // Target is moving significantly
          // Calculate gain (eye velocity / target velocity)
          final gain = eyeVelocity / targetVelocity;

          // Only count reasonable gains (filter out noise and saccades)
          if (gain > 0.1 && gain < 3.0) {
            totalGain += gain;
            gainSamples++;
          }

          // Count as pursuing if eye velocity is at least 20% of target velocity
          // and the eye is reasonably close to the target
          if (eyeVelocity > 0.2 * targetVelocity && _gazeData[i].distance < 0.15) {
            pursuingCount++;
          }
        }
      }

      // Detect catch-up saccades: large eye movements when far from target
      final eyeMovement = _calculateDistance(_gazeData[i].eyePosition, _gazeData[i - 1].eyePosition);
      if (eyeMovement > 0.03 && _gazeData[i].distance > 0.1) {
        catchUpSaccades++;
      }
    }

    final pursuitGain = gainSamples > 0 ? totalGain / gainSamples : 0.0;
    final proportionPursuing = totalSamples > 0 ? pursuingCount / totalSamples : 0.0;

    return {
      'pursuitGain': pursuitGain,
      'proportionPursuing': proportionPursuing,
      'catchUpSaccades': catchUpSaccades,
      'totalDataPoints': _gazeData.length,
    };
  }
  
  void clearData() {
    _gazeData.clear();
  }
  
  void dispose() {
    _faceDetector.close();
    _gazeData.clear();
    _driftSamples.clear();
  }
}