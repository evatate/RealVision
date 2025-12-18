import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/constants.dart';

class AudioService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isInitialized = false;
  Function(String)? _currentOnResult;
  Function(String)? _currentOnError;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      bool available = await _speechToText.initialize(
        onError: (error) {
          print('Speech init error: $error');
          // Auto-restart on "no match" error
          if (error.errorMsg == 'error_no_match' && _isListening) {
            print('No match detected, restarting...');
            Future.delayed(Duration(milliseconds: 500), () {
              if (_isListening && _currentOnResult != null) {
                _restartListening(_currentOnResult!, _currentOnError);
              }
            });
          }
        },
        onStatus: (status) {
          print('Speech status: $status');
          // Auto-restart when recognition stops
          if (status == 'done' && _isListening) {
            Future.delayed(Duration(milliseconds: 500), () {
              if (_isListening && _currentOnResult != null) {
                _restartListening(_currentOnResult!, _currentOnError);
              }
            });
          }
        },
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
    
    // Store callbacks for auto-restart
    _currentOnResult = onResult;
    _currentOnError = onError;
    
    if (_isListening) {
      await stopListening();
      await Future.delayed(Duration(milliseconds: 500));
    }
    
    try {
      _isListening = true;
      
      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenFor: Duration(seconds: 60), // Long timeout
        pauseFor: Duration(seconds: 10),  // Long pause before stopping
        localeId: 'en_US',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          onDevice: false,
          listenMode: ListenMode.confirmation,
        ),
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
    
    print('Restarting speech recognition...');
    
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
        await Future.delayed(Duration(milliseconds: 300));
      }
      
      if (!_isListening) return;
      
      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenFor: Duration(seconds: 60),
        pauseFor: Duration(seconds: 10),
        localeId: 'en_US',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          onDevice: false,
          listenMode: ListenMode.confirmation,
        ),
      );
    } catch (e) {
      print('Restart listen error: $e');
      onError?.call(e.toString());
    }
  }
  
  Future<void> stopListening() async {
    _isListening = false;
    _currentOnResult = null;
    _currentOnError = null;
    
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }
  
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  
  void dispose() {
    _isListening = false;
    _currentOnResult = null;
    _currentOnError = null;
    _speechToText.cancel();
    _flutterTts.stop();
  }
}