import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

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
  
  EyeTrackingService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }
  
  /// Track user's gaze relative to target position
  Future<GazePoint?> trackGaze(
    CameraImage image,
    Offset targetPosition,
    Size screenSize,
  ) async {
    if (_isProcessing) return null;
    
    _isProcessing = true;
    
    try {
      final inputImage = _convertCameraImage(image, InputImageRotation.rotation0deg);
      if (inputImage == null) {
        _isProcessing = false;
        return null;
      }
      
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      
      _isProcessing = false;
      
      if (faces.isEmpty) return null;
      
      final face = faces.first;
      
      // Get eye landmarks
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      
      if (leftEye == null || rightEye == null) return null;
      
      // Calculate average eye position (gaze point estimation)
      final eyeCenter = Offset(
        (leftEye.position.x + rightEye.position.x) / 2.0,
        (leftEye.position.y + rightEye.position.y) / 2.0,
      );
      
      // Normalize to screen coordinates (0-1 range)
      final normalizedEye = Offset(
        eyeCenter.dx / image.width.toDouble(),
        eyeCenter.dy / image.height.toDouble(),
      );
      
      // Calculate distance from gaze to target
      final distance = _calculateDistance(normalizedEye, targetPosition);
      
      // Get head pose angles
      final headEulerAngleX = face.headEulerAngleX ?? 0.0;
      final headEulerAngleY = face.headEulerAngleY ?? 0.0;
      final headEulerAngleZ = face.headEulerAngleZ ?? 0.0;
      
      final gazePoint = GazePoint(
        eyePosition: normalizedEye,
        targetPosition: targetPosition,
        timestamp: DateTime.now(),
        distance: distance,
        headPoseX: headEulerAngleX,
        headPoseY: headEulerAngleY,
        headPoseZ: headEulerAngleZ,
      );
      
      return gazePoint;
      
    } catch (e) {
      print('Gaze tracking error: $e');
      _isProcessing = false;
      return null;
    }
  }
  
  /// Record a gaze point for later analysis
  void recordGazePoint(GazePoint point) {
    _gazeData.add(point);
  }
  
  /// Calculate Euclidean distance between two points
  double _calculateDistance(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  /// Get fixation stability metrics (from research paper)
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
    
    // Square wave jerks detection (simplified)
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
      
      // Check if it's a small saccade away then back
      if (move1 > 0.01 && move1 < 0.035 && move2 > 0.01 && move2 < 0.035) {
        final timeDiff = _gazeData[i].timestamp.difference(_gazeData[i - 1].timestamp).inMilliseconds;
        if (timeDiff < 300) {
          squareWaveJerks++;
        }
      }
    }
    
    // Maximum fixation duration (longest continuous period near target)
    double maxFixationDuration = 0.0;
    double currentFixationDuration = 0.0;
    const fixationThreshold = 0.025; // About 1.5° visual angle
    
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
  
  /// Get pro-saccade metrics (from research paper)
  Map<String, dynamic> getProsaccadeMetrics() {
    if (_gazeData.isEmpty) {
      return {
        'accuracy': 0.0,
        'meanLatency': 0.0,
        'meanSaccades': 0.0,
      };
    }
    
    // Group data by trials (assuming target changes indicate new trials)
    final trials = <List<GazePoint>>[];
    List<GazePoint> currentTrial = [_gazeData[0]];
    
    for (int i = 1; i < _gazeData.length; i++) {
      if (_calculateDistance(_gazeData[i].targetPosition, _gazeData[i - 1].targetPosition) > 0.1) {
        // Target changed, new trial
        trials.add(currentTrial);
        currentTrial = [_gazeData[i]];
      } else {
        currentTrial.add(_gazeData[i]);
      }
    }
    trials.add(currentTrial);
    
    // Calculate metrics per trial
    int successfulTrials = 0;
    double totalLatency = 0.0;
    double totalSaccades = 0.0;
    
    for (final trial in trials) {
      if (trial.isEmpty) continue;
      
      // Check if target was reached (within 1.5° visual angle)
      final reachedTarget = trial.any((p) => p.distance < 0.025);
      if (reachedTarget) {
        successfulTrials++;
        
        // Find time to reach target
        final firstReach = trial.firstWhere((p) => p.distance < 0.025);
        final latency = firstReach.timestamp.difference(trial.first.timestamp).inMilliseconds;
        totalLatency += latency;
        
        // Count saccades (significant movements)
        int saccades = 0;
        for (int i = 1; i < trial.length; i++) {
          final movement = _calculateDistance(trial[i].eyePosition, trial[i - 1].eyePosition);
          if (movement > 0.015) {
            saccades++;
          }
        }
        totalSaccades += saccades;
      }
    }
    
    final accuracy = successfulTrials / trials.length;
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
  
  /// Get smooth pursuit metrics (from research paper)
  Map<String, dynamic> getSmoothPursuitMetrics() {
    if (_gazeData.length < 2) {
      return {
        'pursuitGain': 0.0,
        'proportionPursuing': 0.0,
        'catchUpSaccades': 0,
      };
    }
    
    // Calculate eye velocity and target velocity
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
      
      // Catch-up saccades (rapid movements when eye falls behind)
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
    _gazeData.clear();
  }
}