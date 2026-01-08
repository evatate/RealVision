import 'package:sensors_plus/sensors_plus.dart';
import '../utils/logger.dart';
import 'dart:async';
import 'dart:math';
import '../models/gait_data.dart';

class MotionSensorService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  final List<GaitFrame> _gaitFrames = [];
  final List<AccelerometerEvent> _accelerometerData = [];
  final List<GyroscopeEvent> _gyroscopeData = [];

  int _stepCount = 0;
  bool _isPeakDetected = false;
  DateTime? _lastStepTime;
  DateTime? _recordingStartTime;

  // Step detection thresholds
  static const double stepThreshold = 11.5; // Acceleration magnitude threshold
  static const int minStepIntervalMs = 200; // Minimum time between steps
  
  /// Start recording motion data
  void startRecording() {
    AppLogger.logger.info('Starting motion sensor recording...');
    _stepCount = 0;
    _gaitFrames.clear();
    _accelerometerData.clear();
    _gyroscopeData.clear();
    _recordingStartTime = DateTime.now();

    // Listen to accelerometer (for step detection)
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: Duration(milliseconds: 50), // 20 Hz
    ).listen((AccelerometerEvent event) {
      _accelerometerData.add(event);
      _detectStep(event);
    });

    // Listen to gyroscope (for movement quality)
    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: Duration(milliseconds: 50),
    ).listen((GyroscopeEvent event) {
      _gyroscopeData.add(event);
    });
  }
  
  /// Detect steps from accelerometer data using peak detection
  void _detectStep(AccelerometerEvent accelEvent) {
    if (_recordingStartTime == null) return;

    // Calculate magnitude of acceleration
    double magnitude = sqrt(
      accelEvent.x * accelEvent.x +
      accelEvent.y * accelEvent.y +
      accelEvent.z * accelEvent.z
    );

    // Find closest gyroscope reading (by timestamp)
    GyroscopeEvent? closestGyro = _findClosestGyroscopeEvent(accelEvent);

    // Create gait frame
    final timestamp = DateTime.now().difference(_recordingStartTime!).inMilliseconds / 1000.0;

    final gaitFrame = GaitFrame(
      timestamp: timestamp,
      accelX: accelEvent.x,
      accelY: accelEvent.y,
      accelZ: accelEvent.z,
      gyroX: closestGyro?.x ?? 0.0,
      gyroY: closestGyro?.y ?? 0.0,
      gyroZ: closestGyro?.z ?? 0.0,
      accelerationMagnitude: magnitude,
      isStep: false, // Will be set below if step is detected
    );

    _gaitFrames.add(gaitFrame);

    // Check for step peak
    if (magnitude > stepThreshold && !_isPeakDetected) {
      // Check minimum time between steps
      final now = DateTime.now();
      if (_lastStepTime == null ||
          now.difference(_lastStepTime!).inMilliseconds > minStepIntervalMs) {
        _stepCount++;
        _lastStepTime = now;
        _isPeakDetected = true;

        // Mark this frame as a step
        _gaitFrames.last = GaitFrame(
          timestamp: timestamp,
          accelX: accelEvent.x,
          accelY: accelEvent.y,
          accelZ: accelEvent.z,
          gyroX: closestGyro?.x ?? 0.0,
          gyroY: closestGyro?.y ?? 0.0,
          gyroZ: closestGyro?.z ?? 0.0,
          accelerationMagnitude: magnitude,
          isStep: true,
        );

        AppLogger.logger.fine('Step detected! Total: $_stepCount');
      }
    } else if (magnitude < stepThreshold) {
      _isPeakDetected = false;
    }
  }

  /// Find the closest gyroscope event by timestamp
  GyroscopeEvent? _findClosestGyroscopeEvent(AccelerometerEvent accelEvent) {
    if (_gyroscopeData.isEmpty) return null;
    return _gyroscopeData.last;
  }
  
  /// Stop recording and get results as GaitTrialData
  GaitTrialData stopRecording(DateTime startTime, DateTime endTime) {
    AppLogger.logger.info('Stopping motion sensor recording...');

    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();

    final duration = endTime.difference(startTime).inSeconds.toDouble();

    // Extract features from the collected frames
    final features = GaitFeatureExtraction.extractTrialFeatures(
      GaitTrialData(
        trialNumber: 1, // Single trial for now
        frames: _gaitFrames,
        duration: duration,
        stepCount: _stepCount,
      )
    );

    final trialData = GaitTrialData(
      trialNumber: 1,
      frames: _gaitFrames,
      duration: duration,
      stepCount: _stepCount,
    );

    AppLogger.logger.info('==== WALKING TEST RESULTS ====');
    AppLogger.logger.info('Steps: $_stepCount');
    AppLogger.logger.info('Duration: ${duration.toStringAsFixed(1)} s');
    AppLogger.logger.info('Cadence: ${features.cadence.toStringAsFixed(1)} steps/min');
    AppLogger.logger.info('Step Time: ${features.stepTime.toStringAsFixed(2)} s');
    AppLogger.logger.info('Gait Regularity: ${features.gaitRegularity.toStringAsFixed(3)}');
    AppLogger.logger.info('Gait Quality Score: ${features.gaitQualityScore.toStringAsFixed(3)}');
    AppLogger.logger.info('==============================');

    return trialData;
  }
  
  /// Get current step count (for live display)
  int get currentStepCount => _stepCount;

  /// Get current gait frames (for analysis)
  List<GaitFrame> get gaitFrames => _gaitFrames;

  void dispose() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
  }
}