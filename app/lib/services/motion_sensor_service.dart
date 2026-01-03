import 'package:sensors_plus/sensors_plus.dart';
import '../utils/logger.dart';
import 'dart:async';
import 'dart:math';

class MotionSensorService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  
  List<AccelerometerEvent> _accelerometerData = [];
  List<GyroscopeEvent> _gyroscopeData = [];
  
  int _stepCount = 0;
  bool _isPeakDetected = false;
  DateTime? _lastStepTime;
  
  // Step detection thresholds
  static const double STEP_THRESHOLD = 11.5; // Acceleration magnitude threshold
  static const int MIN_STEP_INTERVAL_MS = 200; // Minimum time between steps
  
  /// Start recording motion data
  void startRecording() {
    AppLogger.logger.info('Starting motion sensor recording...');
    _stepCount = 0;
    _accelerometerData.clear();
    _gyroscopeData.clear();
    
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
  void _detectStep(AccelerometerEvent event) {
    // Calculate magnitude of acceleration
    double magnitude = sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );
    
    // Check for step peak
    if (magnitude > STEP_THRESHOLD && !_isPeakDetected) {
      // Check minimum time between steps
      final now = DateTime.now();
      if (_lastStepTime == null || 
          now.difference(_lastStepTime!).inMilliseconds > MIN_STEP_INTERVAL_MS) {
        _stepCount++;
        _lastStepTime = now;
        _isPeakDetected = true;
        AppLogger.logger.fine('Step detected! Total: $_stepCount');
      }
    } else if (magnitude < STEP_THRESHOLD) {
      _isPeakDetected = false;
    }
    
  }
  
  /// Stop recording and get results
  Map<String, dynamic> stopRecording(DateTime startTime, DateTime endTime) {
    AppLogger.logger.info('Stopping motion sensor recording...');
    
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    
    final durationMinutes = endTime.difference(startTime).inSeconds / 60.0;
    final cadence = durationMinutes > 0 ? _stepCount / durationMinutes : 0.0;
    
    // Calculate gait metrics
    final metrics = _calculateGaitMetrics();
    
    return {
      'steps': _stepCount,
      'durationMinutes': durationMinutes,
      'cadence': cadence,
      'accelerometerSamples': _accelerometerData.length,
      'gyroscopeSamples': _gyroscopeData.length,
      'dataSource': 'Motion Sensors (Accelerometer + Gyroscope)',
      'platform': 'Real-time sensor data',
      ...metrics,
    };
  }
  
  /// Calculate advanced gait metrics from sensor data
  Map<String, dynamic> _calculateGaitMetrics() {
    if (_accelerometerData.length < 2) {
      return {
        'avgAcceleration': 0.0,
        'accelerationVariability': 0.0,
        'rotationRate': 0.0,
      };
    }
    
    // Calculate average acceleration magnitude
    List<double> magnitudes = _accelerometerData.map((e) {
      return sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    }).toList();
    
    double avgAcceleration = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
    
    // Calculate acceleration variability (standard deviation)
    double sumSquaredDiff = magnitudes
        .map((m) => pow(m - avgAcceleration, 2).toDouble())
        .reduce((a, b) => a + b);
    double accelerationVariability = sqrt(sumSquaredDiff / magnitudes.length);
    
    // Calculate rotation rate from gyroscope
    double avgRotation = 0.0;
    if (_gyroscopeData.isNotEmpty) {
      List<double> rotationMagnitudes = _gyroscopeData.map((e) {
        return sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      }).toList();
      avgRotation = rotationMagnitudes.reduce((a, b) => a + b) / rotationMagnitudes.length;
    }
    
    return {
      'avgAcceleration': avgAcceleration,
      'accelerationVariability': accelerationVariability,
      'rotationRate': avgRotation,
      'message': 'Gait metrics calculated from motion sensors',
    };
  }
  
  /// Get current step count (for live display)
  int get currentStepCount => _stepCount;
  
  void dispose() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
  }
}