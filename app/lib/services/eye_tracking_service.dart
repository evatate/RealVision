import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:collection';
import '../models/eye_tracking_data.dart';

class PursuitQuality {
  final double gain;
  final double rmsError;
  final int catchUpSaccades;
  final bool isClinicallyAcceptable;
  PursuitQuality({
    required this.gain,
    required this.rmsError,
    required this.catchUpSaccades,
    required this.isClinicallyAcceptable,
  });
}

double computeRmsError(List<EyeTrackingFrame> frames) {
  if (frames.isEmpty) return 0.0;
  final squared = frames.map((f) => f.distance * f.distance);
  return math.sqrt(squared.reduce((a, b) => a + b) / frames.length);
}

PursuitQuality evaluatePursuit(List<EyeTrackingFrame> frames, {double? gain, int? catchUpSaccades}) {
  final rms = computeRmsError(frames);
  final g = gain ?? 0.0;
  final saccades = catchUpSaccades ?? 0;
  final isAcceptable = g >= 0.5 && rms <= 0.4 && saccades <= frames.length / 15;
  return PursuitQuality(
    gain: g,
    rmsError: rms,
    catchUpSaccades: saccades,
    isClinicallyAcceptable: isAcceptable,
  );
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

// Helper class for frame queue
class _FrameQueueItem {
  final CameraImage image;
  final Offset targetPosition;
  final Size screenSize;
  final InputImageRotation rotation;
  final Completer<EyeTrackingFrame?> completer;
  _FrameQueueItem(this.image, this.targetPosition, this.screenSize, this.rotation, this.completer);
}

class EyeTrackingService {
          void logRawGazeDiagnostics() {
            if (_rawGazeX.isEmpty || _rawGazeY.isEmpty) return;
            final minX = _rawGazeX.reduce(math.min);
            final maxX = _rawGazeX.reduce(math.max);
            final minY = _rawGazeY.reduce(math.min);
            final maxY = _rawGazeY.reduce(math.max);
            AppLogger.logger.info('Raw gaze X range: min=$minX, max=$maxX');
            AppLogger.logger.info('Raw gaze Y range: min=$minY, max=$maxY');
            AppLogger.logger.info('Calibration min/max: X=($_calibMinX,$_calibMaxX), Y=($_calibMinY,$_calibMaxY)');
            _rawGazeX.clear();
            _rawGazeY.clear();
          }
        // Set by UI to indicate if front camera is active
        bool isFrontCamera = true;
      // For diagnostics: store raw gaze values for each trial
      final List<double> _rawGazeX = [];
      final List<double> _rawGazeY = [];

      // Calibration: store min/max for normalization
      double? _calibMinX, _calibMaxX, _calibMinY, _calibMaxY;
    void logPursuitMetrics(List<EyeTrackingFrame> frames, {double? gain, int? catchUpSaccades}) {
      final pq = evaluatePursuit(frames, gain: gain, catchUpSaccades: catchUpSaccades);
      AppLogger.logger.info('Pursuit metrics: gain=${pq.gain.toStringAsFixed(2)}, rmsError=${pq.rmsError.toStringAsFixed(3)}, catchUpSaccades=${pq.catchUpSaccades}, clinicallyAcceptable=${pq.isClinicallyAcceptable}');
    }
  late FaceDetector _faceDetector;
  // use a queue for frames
  final Queue<_FrameQueueItem> _frameQueue = Queue<_FrameQueueItem>();
  bool _isWorkerActive = false;
  final List<EyeTrackingFrame> _eyeTrackingFrames = [];
  DateTime? _trialStartTime;
  String _currentTaskType = 'fixation';

  // Drift correction
  Offset _driftOffset = Offset.zero;
  bool _isCollectingDriftData = false;
  final List<Offset> _driftSamples = [];

  // Frame processing
  bool _isAssessmentActive = false;

  // Enhanced stability
  EyeTrackingFrame? _lastFrame;
  
  // Track frame processing stats
  int _processedFrames = 0;
  int _skippedFrames = 0;
  DateTime? _lastStatsLog;
  
  EyeTrackingService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        minFaceSize: 0.05,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }
  
  void setAssessmentActive(bool active) {
    _isAssessmentActive = active;
    if (active) {
      _processedFrames = 0;
      _skippedFrames = 0;
      _lastStatsLog = DateTime.now();
      AppLogger.logger.info('Eye tracking assessment activated - processing ALL frames');
    } else {
      _logProcessingStats();
    }
  }

  void _logProcessingStats() {
    if (_processedFrames + _skippedFrames > 0) {
      final total = _processedFrames + _skippedFrames;
      final processRate = (_processedFrames / total * 100).toStringAsFixed(1);
      AppLogger.logger.info('Frame processing: $_processedFrames/$total ($processRate%) - ${_eyeTrackingFrames.length} frames recorded');
    }
  }

  void setTaskType(String taskType) {
    _currentTaskType = taskType;
  }

  void startTrial() {
    _trialStartTime = DateTime.now();
    _eyeTrackingFrames.clear();
    _processedFrames = 0;
    _skippedFrames = 0;
    AppLogger.logger.info('Started trial: $_currentTaskType');
  }

  /// Track user's gaze with improved frame processing
  Future<EyeTrackingFrame?> trackGaze(
    CameraImage image,
    Offset targetPosition,
    Size screenSize,
    InputImageRotation rotation,
  ) async {
    final completer = Completer<EyeTrackingFrame?>();
    _frameQueue.add(_FrameQueueItem(image, targetPosition, screenSize, rotation, completer));
    _processFrameQueue();
    return completer.future;
  }

  void _processFrameQueue() {
    if (_isWorkerActive || _frameQueue.isEmpty) return;
    _isWorkerActive = true;
    _processNextFrame();
  }

  void _processNextFrame() async {
    if (_frameQueue.isEmpty) {
      _isWorkerActive = false;
      return;
    }
    final item = _frameQueue.removeFirst();

    // Log processing stats periodically
    if (_lastStatsLog != null && 
        DateTime.now().difference(_lastStatsLog!).inSeconds >= 5) {
      _logProcessingStats();
      _lastStatsLog = DateTime.now();
    }

    try {
      final inputImage = _convertCameraImage(item.image, item.rotation);
      if (inputImage == null) {
        _skippedFrames++;
        item.completer.complete(_lastFrame);
        _processNextFrame();
        return;
      }

      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        _skippedFrames++;
        item.completer.complete(_lastFrame);
        _processNextFrame();
        return;
      }

      final face = faces.first;

      // Get key landmarks
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      final noseBase = face.landmarks[FaceLandmarkType.noseBase];

      if (leftEye == null || rightEye == null || noseBase == null) {
        _skippedFrames++;
        item.completer.complete(_lastFrame);
        _processNextFrame();
        return;
      }

      // Calculate eye center
      final eyeCenter = Offset(
        (leftEye.position.x + rightEye.position.x) / 2.0,
        (leftEye.position.y + rightEye.position.y) / 2.0,
      );

      // Log raw gaze values for diagnostics
      _rawGazeX.add(eyeCenter.dx);
      _rawGazeY.add(eyeCenter.dy);

      // Optionally update calibration min/max
      _calibMinX = (_calibMinX == null) ? eyeCenter.dx : math.min(_calibMinX!, eyeCenter.dx);
      _calibMaxX = (_calibMaxX == null) ? eyeCenter.dx : math.max(_calibMaxX!, eyeCenter.dx);
      _calibMinY = (_calibMinY == null) ? eyeCenter.dy : math.min(_calibMinY!, eyeCenter.dy);
      _calibMaxY = (_calibMaxY == null) ? eyeCenter.dy : math.max(_calibMaxY!, eyeCenter.dy);

      // Get head pose angles
      final headPitch = face.headEulerAngleX ?? 0.0;
      final headYaw = face.headEulerAngleY ?? 0.0;
      final headRoll = face.headEulerAngleZ ?? 0.0;

      // Map raw eye center directly to screen coordinates for overlay (no normalization)
      double screenX = eyeCenter.dx / item.image.width.toDouble();
      double screenY = eyeCenter.dy / item.image.height.toDouble();

      // Mirror horizontally for iOS front camera only
      if (Platform.isIOS && isFrontCamera) {
        screenX = 1.0 - screenX;
      }

      // Enhanced head pose corrections (tuned for clinical accuracy)
      final pitchCorrection = headPitch * -0.030;
      screenY += pitchCorrection;

      final yawCorrection = headYaw * 0.020;
      screenX -= yawCorrection;

      // Eye position in face correction
      final faceBox = face.boundingBox;
      final eyePositionInFace = (eyeCenter.dy - faceBox.top) / faceBox.height;
      if (eyePositionInFace > 0.4) {
        screenY -= (eyePositionInFace - 0.4) * 0.15;
      }

      // Apply drift correction
      screenX += _driftOffset.dx;
      screenY += _driftOffset.dy;

      // Clamp to valid range
      screenX = screenX.clamp(0.0, 1.0);
      screenY = screenY.clamp(0.0, 1.0);

      final normalizedGaze = Offset(screenX, screenY);

      // Calculate distance from gaze to target (both normalized)
      final distance = _calculateDistance(normalizedGaze, item.targetPosition);

      // Create EyeTrackingFrame with precise timestamp
      final timestamp = _trialStartTime != null
          ? DateTime.now().difference(_trialStartTime!).inMilliseconds / 1000.0
          : 0.0;

      final frame = EyeTrackingFrame(
        timestamp: timestamp,
        eyePosition: normalizedGaze,
        targetPosition: item.targetPosition,
        distance: distance, // normalized units
        headPoseX: headPitch,
        headPoseY: headYaw,
        headPoseZ: headRoll,
      );

      // Store frame if trial is active
      if (_trialStartTime != null && _isAssessmentActive) {
        _eyeTrackingFrames.add(frame);
      }

      // Collect drift data if needed
      if (_isCollectingDriftData) {
        _driftSamples.add(frame.eyePosition);
      }

      // Update stability tracking
      _lastFrame = frame;
      _processedFrames++;

      item.completer.complete(frame);
    } catch (e) {
      AppLogger.logger.severe('Gaze tracking error: $e');
      _skippedFrames++;
      item.completer.complete(_lastFrame);
    }
    // Continue processing next frame
    _processNextFrame();
  }

  EyeTrackingTrialData completeTrial() {
    _logProcessingStats();
    
    final trialData = EyeTrackingTrialData(
      trialNumber: 1,
      taskType: _currentTaskType,
      frames: List.from(_eyeTrackingFrames),
      qualityScore: _calculateTrialQualityScore(),
    );

    AppLogger.logger.info('Completed trial: $_currentTaskType - ${trialData.frames.length} frames, quality: ${(trialData.qualityScore * 100).toStringAsFixed(1)}%');

    _trialStartTime = null;
    _eyeTrackingFrames.clear();

    return trialData;
  }

  double _calculateTrialQualityScore() {
    if (_eyeTrackingFrames.isEmpty) return 0.0;

    // Quality based on:
    // 1. Data quantity (prefer 60+ frames for 10s trial at ~6fps effective)
    // 2. Tracking accuracy (distance to target)
    // 3. Data consistency (no large gaps)

    final frameCount = _eyeTrackingFrames.length;
    final avgDistance = _eyeTrackingFrames
        .map((f) => f.distance)
        .reduce((a, b) => a + b) / frameCount;

    // Check for temporal gaps
    int largeGaps = 0;
    for (int i = 1; i < _eyeTrackingFrames.length; i++) {
      final gap = _eyeTrackingFrames[i].timestamp - _eyeTrackingFrames[i - 1].timestamp;
      if (gap > 0.3) largeGaps++; // Gap > 300ms
    }

    // Platform-adaptive expected frame count
    double duration = 0.0;
    if (_eyeTrackingFrames.length > 1) {
      duration = _eyeTrackingFrames.last.timestamp - _eyeTrackingFrames.first.timestamp;
    }
    double expectedFramesForPlatform;
    if (Platform.isIOS) {
      // Use 12.5 fps as a reasonable iOS default
      expectedFramesForPlatform = duration * 12.5;
    } else {
      // Assume 60 fps for Android/desktop
      expectedFramesForPlatform = 60.0;
    }
    expectedFramesForPlatform = expectedFramesForPlatform.clamp(10.0, 120.0); // avoid division by zero/negative
    final quantityScore = math.min(frameCount / expectedFramesForPlatform, 1.0).clamp(0.0, 1.0);

    // Accuracy score: lower distance is better, but 0 distance means no valid data
    final accuracyScore = avgDistance > 0 ? math.max(0.0, 1.0 - avgDistance * 1.5) : 0.0;

    // Consistency score: penalize large gaps
    final gapPenalty = (largeGaps / frameCount).clamp(0.0, 0.5);
    final consistencyScore = math.max(0.0, 1.0 - gapPenalty * 2);

    final finalScore = (quantityScore * 0.4 + accuracyScore * 0.4 + consistencyScore * 0.2);

    AppLogger.logger.info('Quality breakdown: quantity=${(quantityScore * 100).toStringAsFixed(0)}% (${frameCount}f/${expectedFramesForPlatform.toStringAsFixed(1)}f), accuracy=${(accuracyScore * 100).toStringAsFixed(0)}%, consistency=${(consistencyScore * 100).toStringAsFixed(0)}% (${largeGaps}g)');

    return finalScore;
  }

  void startDriftCorrection() {
    _isCollectingDriftData = true;
    _driftSamples.clear();
    AppLogger.logger.info('Started drift correction');
  }

  void finalizeDriftCorrection() {
    if (_driftSamples.isEmpty) {
      _driftOffset = Offset.zero;
      AppLogger.logger.warning('No drift samples collected');
    } else {
      final meanX = _driftSamples.map((o) => o.dx).reduce((a, b) => a + b) / _driftSamples.length;
      final meanY = _driftSamples.map((o) => o.dy).reduce((a, b) => a + b) / _driftSamples.length;

      _driftOffset = Offset(0.5 - meanX, 0.5 - meanY);

      AppLogger.logger.info('Drift correction applied: (${_driftOffset.dx.toStringAsFixed(3)}, ${_driftOffset.dy.toStringAsFixed(3)}) from ${_driftSamples.length} samples');
    }

    _isCollectingDriftData = false;
    _driftSamples.clear();
  }
  
  double _calculateDistance(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  /// Convert CameraImage to InputImage with improved error handling
  InputImage? _convertCameraImage(CameraImage image, InputImageRotation rotation) {
    try {
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      
      if (Platform.isAndroid) {
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
        // iOS - handle plane concatenation carefully
        try {
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
  
  void clearData() {
    _eyeTrackingFrames.clear();
    _frameQueue.clear();
    _trialStartTime = null;
    _processedFrames = 0;
    _skippedFrames = 0;
  }

  void dispose() {
    _faceDetector.close();
    _eyeTrackingFrames.clear();
    _driftSamples.clear();
  }
}