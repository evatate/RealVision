import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  
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
    ResolutionPreset.medium, // Changed from 'high'
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.yuv420, // More efficient
  );
    
    await _controller!.initialize();
  }
  
  CameraController? get controller => _controller;
  
  Future<void> dispose() async {
    await _controller?.dispose();
  }
  
  Future<void> startImageStream(Function(CameraImage) onImage) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }
    await _controller!.startImageStream(onImage);
  }
  
  Future<void> stopImageStream() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }
}