import 'package:get_it/get_it.dart';
import 'audio_service.dart';
import 'camera_service.dart';
import 'health_service.dart';
import 'eye_tracking_service.dart';
import 'motion_sensor_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<AudioService>(() => AudioService());
  getIt.registerFactory<CameraService>(() => CameraService());
  getIt.registerLazySingleton<HealthService>(() => HealthService());
  getIt.registerFactory<EyeTrackingService>(() => EyeTrackingService());
  getIt.registerFactory<MotionSensorService>(() => MotionSensorService());
}