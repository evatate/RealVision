import 'package:get_it/get_it.dart';
import 'audio_service.dart';
import 'camera_service.dart';
import 'health_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // lazy loading
  getIt.registerLazySingleton<AudioService>(() => AudioService());
  getIt.registerFactory<CameraService>(() => CameraService());
  getIt.registerLazySingleton<HealthService>(() => HealthService());
}