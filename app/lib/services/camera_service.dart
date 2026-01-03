import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'dart:io' show Platform;
import '../utils/logger.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  InputImageRotation? _imageRotation;
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return; // Already initialized
    
    _cameras = await availableCameras();
    if (_cameras!.isEmpty) {
      throw Exception('No cameras available');
    }
    
    // Use front camera for facial and eye tracking
    final frontCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );
    
    // Choose image format based on platform
    final imageFormatGroup = Platform.isAndroid 
        ? ImageFormatGroup.nv21      // Android uses NV21
        : ImageFormatGroup.bgra8888;  // iOS uses BGRA8888
    
    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: imageFormatGroup,
    );
    
    await _controller!.initialize();
    _imageRotation = _rotationFromSensor(frontCamera.sensorOrientation);
    _isInitialized = true;
    
    AppLogger.logger.info('📷 Camera initialized: ${Platform.isAndroid ? "Android (NV21)" : "iOS (BGRA8888)"}');
  }

  InputImageRotation _rotationFromSensor(int sensorOrientation) {
    // Android and iOS handle rotation differently
    if (Platform.isAndroid) {
      // Android front camera
      switch (sensorOrientation) {
        case 90:
          return InputImageRotation.rotation90deg;
        case 180:
          return InputImageRotation.rotation180deg;
        case 270:
          return InputImageRotation.rotation270deg;
        default:
          return InputImageRotation.rotation0deg;
      }
    } else {
      // iOS front camera - typically 270 degrees
      switch (sensorOrientation) {
        case 90:
          return InputImageRotation.rotation90deg;
        case 180:
          return InputImageRotation.rotation180deg;
        case 270:
          return InputImageRotation.rotation270deg;
        default:
          return InputImageRotation.rotation0deg;
      }
    }
  }
  
  CameraController? get controller => _controller;
  
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _imageRotation = null;
    _isInitialized = false;
  }

  Future<void> startImageStream(
    Function(CameraImage image, InputImageRotation rotation) onImage,
  ) async {
    if (_controller == null || !_controller!.value.isInitialized || _imageRotation == null) {
      throw Exception('Camera not initialized');
    }
    await _controller!.startImageStream((image) {
      onImage(image, _imageRotation!);
    });
  }
  
  Future<void> stopImageStream() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }
}