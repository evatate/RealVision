import 'package:health/health.dart';

class HealthService {
  final Health _health = Health();
  
  Future<bool> requestPermissions() async {
    // Request health permissions
    final types = [
      HealthDataType.STEPS,
      HealthDataType.DISTANCE_WALKING_RUNNING,
      // WALKING_SPEED is not available in current health package version
      // We'll calculate it from distance and time
    ];
    
    final permissions = types.map((type) => HealthDataAccess.READ).toList();
    
    try {
      bool? granted = await _health.requestAuthorization(types, permissions: permissions);
      return granted ?? false;
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }
  
  Future<Map<String, dynamic>> getGaitData({
    required DateTime start,
    required DateTime end,
  }) async {
    final types = [
      HealthDataType.STEPS,
      HealthDataType.DISTANCE_WALKING_RUNNING,
    ];
    
    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: types,
      );
      
      // Process gait data
      int totalSteps = 0;
      double totalDistance = 0;
      
      for (var point in healthData) {
        if (point.type == HealthDataType.STEPS) {
          totalSteps += (point.value as num).toInt();
        } else if (point.type == HealthDataType.DISTANCE_WALKING_RUNNING) {
          totalDistance += (point.value as num).toDouble();
        }
      }
      
      // Calculate average walking speed manually
      double durationMinutes = end.difference(start).inSeconds / 60.0;
      double avgSpeed = durationMinutes > 0 ? totalDistance / durationMinutes : 0;
      double cadence = durationMinutes > 0 ? totalSteps / durationMinutes : 0;
      
      return {
        'steps': totalSteps,
        'distance': totalDistance,
        'avgSpeed': avgSpeed,
        'cadence': cadence,
        'durationMinutes': durationMinutes,
      };
    } catch (e) {
      print('Error getting gait data: $e');
      return {
        'steps': 0,
        'distance': 0.0,
        'avgSpeed': 0.0,
        'cadence': 0.0,
        'error': e.toString(),
      };
    }
  }
}