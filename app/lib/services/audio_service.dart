import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/constants.dart';

class AudioService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      bool available = await _speechToText.initialize(
        onError: (error) => print('Speech init error: $error'),
        onStatus: (status) => print('Speech status: $status'),
      );
      
      if (!available) {
        print('Speech recognition not available');
      }
      
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(AppConstants.speechRate);
      await _flutterTts.setVolume(AppConstants.speechVolume);
      await _flutterTts.setPitch(AppConstants.speechPitch);
      _isInitialized = true;
    } catch (e) {
      print('Audio service initialization error: $e');
    }
  }
  
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS error: $e');
    }
  }
  
  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onError,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (!_speechToText.isAvailable) {
      onError?.call('Speech recognition not available');
      return;
    }
    
    if (_isListening) {
      await stopListening();
    }
    
    try {
      _isListening = true;
      
      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
          
          if (result.finalResult && _isListening) {
            Future.delayed(Duration(milliseconds: 500), () {
              if (_isListening) {
                _restartListening(onResult, onError);
              }
            });
          }
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 5), 
        localeId: 'en_US',
        cancelOnError: false,
      );
    } catch (e) {
      print('Listen error: $e');
      _isListening = false;
      onError?.call(e.toString());
    }
  }
  
  Future<void> _restartListening(
    Function(String) onResult,
    Function(String)? onError,
  ) async {
    if (!_isListening) return;
    
    try {
      await _speechToText.stop();
      await Future.delayed(Duration(milliseconds: 300));
      
      if (_isListening) {
        await _speechToText.listen(
          onResult: (result) {
            onResult(result.recognizedWords);
            if (result.finalResult && _isListening) {
              Future.delayed(Duration(milliseconds: 500), () {
                if (_isListening) {
                  _restartListening(onResult, onError);
                }
              });
            }
          },
          listenFor: Duration(seconds: 30),
          pauseFor: Duration(seconds: 5),
          localeId: 'en_US',
          cancelOnError: false,
        );
      }
    } catch (e) {
      print('Restart listen error: $e');
      onError?.call(e.toString());
    }
  }
  
  Future<void> stopListening() async {
    _isListening = false;
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }
  
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  
  void dispose() {
    _isListening = false;
    _speechToText.cancel();
    _flutterTts.stop();
  }
}