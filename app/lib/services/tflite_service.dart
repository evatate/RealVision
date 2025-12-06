import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class TFLiteService {
  Interpreter? _speechInterpreter;
  Interpreter? _eyeInterpreter;
  Interpreter? _facialInterpreter;
  Interpreter? _gaitInterpreter;
  
  Future<void> loadModels() async {
    try {
      _speechInterpreter = await Interpreter.fromAsset('assets/models/speech_model.tflite');
      _eyeInterpreter = await Interpreter.fromAsset('assets/models/eye_model.tflite');
      _facialInterpreter = await Interpreter.fromAsset('assets/models/facial_model.tflite');
      _gaitInterpreter = await Interpreter.fromAsset('assets/models/gait_model.tflite');
    } catch (e) {
      print('Error loading models: $e');
      // Models may not exist yet - this is expected during development
    }
  }
  
  Future<Map<String, dynamic>> runSpeechInference(Float32List features) async {
    if (_speechInterpreter == null) {
      return {'prediction': 0, 'confidence': 0.0, 'error': 'Model not loaded'};
    }
    
    try {
      var output = List.filled(1, 0.0).reshape([1, 1]);
      _speechInterpreter!.run(features.reshape([1, features.length]), output);
      
      return {
        'prediction': output[0][0] > 0.5 ? 1 : 0,
        'confidence': output[0][0],
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  Future<Map<String, dynamic>> runEyeInference(Float32List features) async {
    if (_eyeInterpreter == null) {
      return {'prediction': 0, 'confidence': 0.0, 'error': 'Model not loaded'};
    }
    
    try {
      var output = List.filled(1, 0.0).reshape([1, 1]);
      _eyeInterpreter!.run(features.reshape([1, features.length]), output);
      
      return {
        'prediction': output[0][0] > 0.5 ? 1 : 0,
        'confidence': output[0][0],
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  Future<Map<String, dynamic>> runFacialInference(Float32List features) async {
    if (_facialInterpreter == null) {
      return {'prediction': 0, 'confidence': 0.0, 'error': 'Model not loaded'};
    }
    
    try {
      var output = List.filled(1, 0.0).reshape([1, 1]);
      _facialInterpreter!.run(features.reshape([1, features.length]), output);
      
      return {
        'prediction': output[0][0] > 0.5 ? 1 : 0,
        'confidence': output[0][0],
        'smileIndex': output[0][0],
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  Future<Map<String, dynamic>> runGaitInference(Float32List features) async {
    if (_gaitInterpreter == null) {
      return {'prediction': 0, 'confidence': 0.0, 'error': 'Model not loaded'};
    }
    
    try {
      var output = List.filled(1, 0.0).reshape([1, 1]);
      _gaitInterpreter!.run(features.reshape([1, features.length]), output);
      
      return {
        'prediction': output[0][0] > 0.5 ? 1 : 0,
        'confidence': output[0][0],
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  void dispose() {
    _speechInterpreter?.close();
    _eyeInterpreter?.close();
    _facialInterpreter?.close();
    _gaitInterpreter?.close();
  }
}