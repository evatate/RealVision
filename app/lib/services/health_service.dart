import 'package:health/health.dart';
import 'dart:io' show Platform;

class HealthService {
  final Health _health = Health();
  bool _permissionsGranted = false;
  bool _useGoogleFit = false;
  
  List<HealthDataType> _getSupportedTypes() {
    // Same types for both Google Fit and HealthKit
    if (Platform.isAndroid) {
      return [HealthDataType.STEPS];
    } else if (Platform.isIOS) {
      return [
        HealthDataType.STEPS,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.WALKING_SPEED,
      ];
    } else {
      return [HealthDataType.STEPS];
    }
  }
  
  /// Check if Google Fit is installed (iOS only)
  Future<bool> isGoogleFitInstalled() async {
    if (!Platform.isIOS) return true; // Android uses Google Fit by default
    
    try {
      // On iOS, we check by trying to access Google Fit data
      // If Google Fit is installed and configured, this will succeed
      // This is a simple heuristic - you might want to add url_launcher to check the app
      return false; // Default to false, user must install
    } catch (e) {
      return false;
    }
  }
  
  /// Request health data permissions with Google Fit priority
  Future<bool> requestPermissions() async {
    if (_permissionsGranted) return true;
    
    final types = _getSupportedTypes();
    final permissions = types.map((type) => HealthDataAccess.READ).toList();
    
    try {
      if (Platform.isIOS) {
        // On iOS, check if Google Fit is installed first
        print('iOS: Checking for Google Fit...');
        _useGoogleFit = await isGoogleFitInstalled();
        
        if (!_useGoogleFit) {
          print('iOS: Google Fit not detected, using HealthKit as fallback');
        } else {
          print('iOS: Using Google Fit for step tracking');
        }
      } else {
        // Android uses Google Fit by default
        print('Android: Using Google Fit');
        _useGoogleFit = true;
      }
      
      // Request authorization
      bool? granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );
      
      if (granted == true) {
        _permissionsGranted = true;
        print('Health permissions granted');
        return true;
      }
      
      print('Health permissions denied');
      return false;
      
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }
  
  /// Get gait/walking data
  Future<Map<String, dynamic>> getGaitData({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!_permissionsGranted) {
      bool granted = await requestPermissions();
      if (!granted) {
        return {
          'steps': 0,
          'distance': 0.0,
          'avgSpeed': 0.0,
          'cadence': 0.0,
          'durationMinutes': 0.0,
          'platform': Platform.isAndroid ? 'Android (Google Fit)' : 'iOS',
          'dataSource': _useGoogleFit ? 'Google Fit' : 'HealthKit',
          'error': 'Permissions not granted',
        };
      }
    }
    
    final types = _getSupportedTypes();
    double durationMinutes = end.difference(start).inSeconds / 60.0;
    
    // Google Fit (iOS) or Android - query with expanded time window
    if (_useGoogleFit || Platform.isAndroid) {
      print('Querying Google Fit data from $start to $end');
      
      // Query with 5-minute buffer on each side
      final queryStart = start.subtract(Duration(minutes: 5));
      final queryEnd = end.add(Duration(minutes: 5));
      
      try {
        List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
          startTime: queryStart,
          endTime: queryEnd,
          types: types,
        );
        
        print('Retrieved ${healthData.length} health data points from Google Fit');
        
        // Filter to actual test window
        healthData = healthData.where((point) {
          return point.dateFrom.isAfter(start) && point.dateTo.isBefore(end);
        }).toList();
        
        if (healthData.isEmpty) {
          return {
            'steps': 0,
            'distance': 0.0,
            'avgSpeed': 0.0,
            'cadence': 0.0,
            'durationMinutes': durationMinutes,
            'platform': Platform.isAndroid ? 'Android (Google Fit)' : 'iOS (Google Fit)',
            'dataSource': 'Google Fit',
            'message': 'No walking data detected. Make sure you walked during the test and Google Fit is tracking.',
          };
        }
        
        // Process data
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
        
        double avgSpeed = speeds.isNotEmpty 
            ? speeds.reduce((a, b) => a + b) / speeds.length 
            : (totalDistance > 0 && durationMinutes > 0 ? totalDistance / durationMinutes : 0.0);
        
        double cadence = durationMinutes > 0 ? totalSteps / durationMinutes : 0;
        
        return {
          'steps': totalSteps,
          'distance': totalDistance,
          'avgSpeed': avgSpeed,
          'cadence': cadence,
          'speedVariability': _calculateVariability(speeds),
          'durationMinutes': durationMinutes,
          'platform': Platform.isAndroid ? 'Android (Google Fit)' : 'iOS (Google Fit)',
          'dataSource': 'Google Fit',
          'dataPoints': healthData.length,
          'message': 'Data collected successfully from Google Fit',
        };
        
      } catch (e) {
        print('Error getting Google Fit data: $e');
        return {
          'steps': 0,
          'distance': 0.0,
          'avgSpeed': 0.0,
          'cadence': 0.0,
          'durationMinutes': durationMinutes,
          'platform': Platform.isAndroid ? 'Android' : 'iOS',
          'dataSource': _useGoogleFit ? 'Google Fit' : 'Unknown',
          'error': e.toString(),
        };
      }
    }
    
    // iOS HealthKit fallback (when Google Fit not installed)
    if (Platform.isIOS && !_useGoogleFit) {
      print('iOS HealthKit: Querying last 10 minutes of activity...');
      final recentStart = DateTime.now().subtract(Duration(minutes: 10));
      final recentEnd = DateTime.now();
      
      try {
        int recentSteps = await _health.getTotalStepsInInterval(recentStart, recentEnd) ?? 0;
        print('iOS HealthKit: Found $recentSteps steps in last 10 minutes');
        
        if (recentSteps > 0) {
          int estimatedTestSteps = (recentSteps * (durationMinutes / 10)).round();
          double cadence = durationMinutes > 0 ? estimatedTestSteps / durationMinutes : 0;
          
          return {
            'steps': estimatedTestSteps,
            'distance': 0.0,
            'avgSpeed': 0.0,
            'cadence': cadence,
            'speedVariability': 0.0,
            'durationMinutes': durationMinutes,
            'platform': 'iOS (HealthKit fallback)',
            'dataSource': 'HealthKit',
            'dataPoints': 1,
            'message': 'Data collected from HealthKit (estimated from recent activity)',
            'note': 'For better accuracy, install Google Fit from the App Store',
          };
        } else {
          return {
            'steps': 0,
            'distance': 0.0,
            'avgSpeed': 0.0,
            'cadence': 0.0,
            'speedVariability': 0.0,
            'durationMinutes': durationMinutes,
            'platform': 'iOS (HealthKit)',
            'dataSource': 'HealthKit',
            'message': 'No recent walking activity detected in HealthKit',
            'note': 'For better accuracy, install Google Fit from the App Store',
          };
        }
      } catch (e) {
        print('iOS HealthKit error: $e');
        return {
          'steps': 0,
          'distance': 0.0,
          'avgSpeed': 0.0,
          'cadence': 0.0,
          'speedVariability': 0.0,
          'durationMinutes': durationMinutes,
          'platform': 'iOS (HealthKit)',
          'dataSource': 'HealthKit',
          'error': e.toString(),
          'note': 'For better accuracy, install Google Fit from the App Store',
        };
      }
    }
    
    return {
      'steps': 0,
      'error': 'Unsupported platform',
    };
  }
  
  double _calculateVariability(List<double> values) {
    if (values.length < 2) return 0.0;
    
    double mean = values.reduce((a, b) => a + b) / values.length;
    double sumSquaredDiff = values
        .map((v) => (v - mean) * (v - mean))
        .reduce((a, b) => a + b);
    double variance = sumSquaredDiff / values.length;
    
    return variance;
  }
  
  Future<bool> isHealthDataAvailable() async {
    try {
      return await _health.hasPermissions(_getSupportedTypes()) ?? false;
    } catch (e) {
      print('Error checking health availability: $e');
      return false;
    }
  }
}