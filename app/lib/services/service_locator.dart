import 'package:get_it/get_it.dart';
import 'audio_service.dart';
import 'camera_service.dart';
import 'health_service.dart';
import 'eye_tracking_service.dart';
import 'motion_sensor_service.dart';
import 'aws_auth_service.dart'; 
import 'aws_storage_service.dart';
import 'data_export_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // AWS Services
  getIt.registerLazySingleton<AWSAuthService>(() => AWSAuthService());
  getIt.registerLazySingleton<AWSStorageService>(
    () => AWSStorageService(getIt<AWSAuthService>()),
  );

  // Data Export Service
  getIt.registerLazySingleton<DataExportService>(
    () => DataExportService(awsStorage: getIt<AWSStorageService>()),
  );

  /// App Services
  getIt.registerLazySingleton<AudioService>(() => AudioService());
  getIt.registerFactory<CameraService>(() => CameraService());
  getIt.registerLazySingleton<HealthService>(() => HealthService());
  getIt.registerFactory<EyeTrackingService>(() => EyeTrackingService());
  getIt.registerFactory<MotionSensorService>(() => MotionSensorService());
}