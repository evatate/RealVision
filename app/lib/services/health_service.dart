import 'package:health/health.dart';
import 'dart:io' show Platform;

class HealthService {
  final Health _health = Health();
  bool _permissionsGranted = false;
  
  List<HealthDataType> _getSupportedTypes() {
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
  
  /// Requests health data permissions with retry logic
  Future<bool> requestPermissions() async {
    // Check if already granted
    if (_permissionsGranted) return true;
    
    final types = _getSupportedTypes();
    final permissions = types.map((type) => HealthDataAccess.READ).toList();
    
    try {
      // First check if permissions already exist
      bool? hasPermissions = await _health.hasPermissions(types, permissions: permissions);
      
      if (hasPermissions == true) {
        _permissionsGranted = true;
        print('Health permissions already granted');
        return true;
      }
      
      // Request authorization with retry
      bool? granted = false;
      int attempts = 0;
      
      while (!granted! && attempts < 3) {
        attempts++;
        print('Requesting health permissions (attempt $attempts)...');
        
        granted = await _health.requestAuthorization(
          types,
          permissions: permissions,
        );
        
        if (granted == true) {
          _permissionsGranted = true;
          print('Health permissions granted on attempt $attempts');
          return true;
        }
        
        // Wait before retry
        if (attempts < 3) {
          await Future.delayed(Duration(seconds: 1));
        }
      }
      
      print('Health permissions denied after $attempts attempts');
      return false;
      
    } catch (e) {
      print('Error requesting health permissions: $e');
      
      // Platform-specific guidance
      if (Platform.isAndroid) {
        print('Android: Install Google Fit or Samsung Health');
        print('Then go to Settings > Apps > RealVision > Permissions');
      } else if (Platform.isIOS) {
        print('iOS: Enable in Settings > Privacy > Health');
      }
      
      return false;
    }
  }
  
  /// Gets gait/walking data from the health platform
  Future<Map<String, dynamic>> getGaitData({
    required DateTime start,
    required DateTime end,
  }) async {
    // Ensure permissions before fetching
    if (!_permissionsGranted) {
      bool granted = await requestPermissions();
      if (!granted) {
        return {
          'steps': 0,
          'distance': 0.0,
          'avgSpeed': 0.0,
          'cadence': 0.0,
          'durationMinutes': 0.0,
          'platform': Platform.isAndroid ? 'Android' : 'iOS',
          'error': 'Permissions not granted',
          'message': 'Please grant health permissions and try again',
        };
      }
    }
    
    final types = _getSupportedTypes();
    
    try {
      // Fetch health data
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
          'message': 'No walking data detected. Make sure you walked during the test.',
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
      
      double avgSpeed;
      if (speeds.isNotEmpty) {
        avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
      } else if (totalDistance > 0 && durationMinutes > 0) {
        avgSpeed = totalDistance / durationMinutes;
      } else {
        avgSpeed = 0.0;
      }
      
      double cadence = durationMinutes > 0 ? totalSteps / durationMinutes : 0;
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
  
  double _calculateVariability(List<double> values) {
    if (values.length < 2) return 0.0;
    
    double mean = values.reduce((a, b) => a + b) / values.length;
    double sumSquaredDiff = values
        .map((v) => (v - mean) * (v - mean))
        .reduce((a, b) => a + b);
    double variance = sumSquaredDiff / values.length;
    
    return variance;
  }
  
  String _getPlatformSpecificErrorMessage() {
    if (Platform.isAndroid) {
      return 'Android: Install Google Fit and grant permissions in Settings > Apps > RealVision';
    } else if (Platform.isIOS) {
      return 'iOS: Enable permissions in Settings > Privacy > Health';
    } else {
      return 'Health data not available on this platform';
    }
  }
  
  Future<bool> isHealthDataAvailable() async {
    try {
      if (Platform.isAndroid) {
        return await _health.hasPermissions(_getSupportedTypes()) ?? false;
      } else if (Platform.isIOS) {
        return true;
      }
      return false;
    } catch (e) {
      print('Error checking health availability: $e');
      return false;
    }
  }
}