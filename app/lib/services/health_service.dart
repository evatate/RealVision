import 'package:health/health.dart';
import 'dart:io' show Platform;

class HealthService {
  final Health _health = Health();
  
  /// Determines which health data types are supported on this platform
  List<HealthDataType> _getSupportedTypes() {
    if (Platform.isAndroid) {
      // Android Health Connect only supports STEPS reliably
      return [
        HealthDataType.STEPS,
      ];
    } else if (Platform.isIOS) {
      // iOS HealthKit supports more types
      return [
        HealthDataType.STEPS,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.WALKING_SPEED,
      ];
    } else {
      // fallback for other platforms
      return [HealthDataType.STEPS];
    }
  }
  
  /// Requests health data permissions
  /// returns true if permissions granted, false otherwise
  Future<bool> requestPermissions() async {
    final types = _getSupportedTypes();
    final permissions = types.map((type) => HealthDataAccess.READ).toList();
    
    try {
      // request authorization
      bool? granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );
      
      if (granted == true) {
        print('Health permissions granted for: $types');
        return true;
      } else {
        print('Health permissions denied or not granted');
        return false;
      }
    } catch (e) {
      print('Error requesting health permissions: $e');
      
      // show platform-specific error messages
      if (Platform.isAndroid) {
        print('Android: Make sure Google Fit or Samsung Health is installed');
      } else if (Platform.isIOS) {
        print('iOS: Make sure HealthKit is enabled in app capabilities');
      }
      
      return false;
    }
  }
  
  /// Gets gait/walking data from the health platform
  /// Works on both Android (Health Connect) and iOS (HealthKit)
  Future<Map<String, dynamic>> getGaitData({
    required DateTime start,
    required DateTime end,
  }) async {
    final types = _getSupportedTypes();
    
    try {
      // Fetch health data from the platform
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: types,
      );
      
      if (healthData.isEmpty) {
        return {
          'steps': 0,
          'distance': 0.0,
          'avgSpeed': 0.0,
          'cadence': 0.0,
          'durationMinutes': 0.0,
          'platform': Platform.isAndroid ? 'Android' : 'iOS',
          'message': 'No data available. Make sure you walked during the test period.',
        };
      }
      
      // Process the data
      int totalSteps = 0;
      double totalDistance = 0.0;
      List<double> speeds = [];
      
      for (var point in healthData) {
        if (point.type == HealthDataType.STEPS) {
          totalSteps += (point.value as num).toInt();
        } else if (point.type == HealthDataType.DISTANCE_WALKING_RUNNING) {
          totalDistance += (point.value as num).toDouble();
        } else if (point.type == HealthDataType.WALKING_SPEED) {
          speeds.add((point.value as num).toDouble());
        }
      }
      
      // Calculate metrics
      double durationMinutes = end.difference(start).inSeconds / 60.0;
      
      // Calculate average speed
      double avgSpeed;
      if (speeds.isNotEmpty) {
        // iOS: Use actual walking speed from HealthKit
        avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
      } else if (totalDistance > 0 && durationMinutes > 0) {
        // Android: Calculate speed from distance and time
        avgSpeed = totalDistance / durationMinutes; // meters per minute
      } else {
        avgSpeed = 0.0;
      }
      
      // Calculate cadence (steps per minute)
      double cadence = durationMinutes > 0 ? totalSteps / durationMinutes : 0;
      
      // Calculate speed variability (standard deviation)
      double speedVariability = _calculateVariability(speeds);
      
      return {
        'steps': totalSteps,
        'distance': totalDistance,
        'avgSpeed': avgSpeed,
        'cadence': cadence,
        'speedVariability': speedVariability,
        'durationMinutes': durationMinutes,
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
        'dataPoints': healthData.length,
        'message': 'Data collected successfully',
      };
      
    } catch (e) {
      print('Error getting gait data: $e');
      
      return {
        'steps': 0,
        'distance': 0.0,
        'avgSpeed': 0.0,
        'cadence': 0.0,
        'speedVariability': 0.0,
        'durationMinutes': 0.0,
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
        'error': e.toString(),
        'message': _getPlatformSpecificErrorMessage(),
      };
    }
  }
  
  /// Calculates standard deviation (variability) of a list of values
  double _calculateVariability(List<double> values) {
    if (values.length < 2) return 0.0;
    
    double mean = values.reduce((a, b) => a + b) / values.length;
    double sumSquaredDiff = values
        .map((v) => (v - mean) * (v - mean))
        .reduce((a, b) => a + b);
    double variance = sumSquaredDiff / values.length;
    
    return variance; // Return variance (or use sqrt(variance) for standard deviation)
  }
  
  /// Returns platform-specific error message
  String _getPlatformSpecificErrorMessage() {
    if (Platform.isAndroid) {
      return 'Android: Install Google Fit or Samsung Health and grant permissions in Settings';
    } else if (Platform.isIOS) {
      return 'iOS: Enable HealthKit permissions in Settings → Privacy → Health';
    } else {
      return 'Health data not available on this platform';
    }
  }
  
  /// Checks if health data is available on this platform
  Future<bool> isHealthDataAvailable() async {
    try {
      if (Platform.isAndroid) {
        // Check if Health Connect is available
        return await _health.hasPermissions(_getSupportedTypes()) ?? false;
      } else if (Platform.isIOS) {
        // HealthKit is always available on iOS devices
        return true;
      }
      return false;
    } catch (e) {
      print('Error checking health availability: $e');
      return false;
    }
  }
}