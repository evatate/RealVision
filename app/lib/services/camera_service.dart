import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  late final InputImageRotation _imageRotation;
  
    Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras!.isEmpty) {
      throw Exception('No cameras available');
    }
    
    // Use front camera for facial and eye tracking
    final frontCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );
    
    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );
    
    await _controller!.initialize();
    
    // Lock orientation for consistent aspect ratio
    //await _controller!.lockCaptureOrientation();

    _imageRotation = _rotationFromSensor(frontCamera.sensorOrientation);
  }

  InputImageRotation _rotationFromSensor(int sensorOrientation) { 
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

  
  CameraController? get controller => _controller;
  
  Future<void> dispose() async {
    await _controller?.dispose();
  }

  Future<void> startImageStream(
  Function(CameraImage image, InputImageRotation rotation) onImage,
  ) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }
    await _controller!.startImageStream((image) {
      onImage(image, _imageRotation);
    });
  }

  
  Future<void> stopImageStream() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }
}