import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'dart:async';

class AudioService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isInitialized = false;
  String _accumulatedTranscript = '';
  Timer? _keepAliveTimer;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      bool available = await _speechToText.initialize(
        onError: (error) {
          AppLogger.logger.warning('Speech init error: $error');
        },
        onStatus: (status) {
          AppLogger.logger.info('Speech status: $status');
        },
      );
      
      if (!available) {
        AppLogger.logger.warning('Speech recognition not available');
      }
      
      // iOS-specific TTS configuration
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(AppConstants.speechRate);
      await _flutterTts.setVolume(AppConstants.speechVolume);
      await _flutterTts.setPitch(AppConstants.speechPitch);
      
      // iOS-specific settings
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
      
      _isInitialized = true;
    } catch (e) {
      AppLogger.logger.severe('Audio service initialization error: $e');
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
      AppLogger.logger.severe('TTS error: $e');
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
    
    _isListening = true;
    _accumulatedTranscript = '';
    
    // Start keep-alive mechanism
    _startKeepAlive(onResult, onError);
    
    try {
      await _speechToText.listen(
        onResult: (result) {
          // Accumulate transcript
          if (result.finalResult) {
            _accumulatedTranscript += ' ' + result.recognizedWords;
          }
          // Always send back accumulated + current partial
          String currentTranscript = _accumulatedTranscript + ' ' + result.recognizedWords;
          onResult(currentTranscript.trim());
        },
        listenFor: Duration(seconds: 120), // 2 minutes max per session
        pauseFor: Duration(seconds: 30),   // Very long pause tolerance
        localeId: 'en_US',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          onDevice: false,
          listenMode: ListenMode.confirmation,
        ),
      );
    } catch (e) {
      AppLogger.logger.severe('Listen error: $e');
      _isListening = false;
      _keepAliveTimer?.cancel();
      onError?.call(e.toString());
    }
  }
  
  void _startKeepAlive(Function(String) onResult, Function(String)? onError) {
    // Restart listening every 90 seconds to prevent timeout
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(Duration(seconds: 90), (timer) async {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      
      AppLogger.logger.info('Keep-alive: Restarting speech recognition...');
      
      try {
        // Stop current session
        if (_speechToText.isListening) {
          await _speechToText.stop();
        }
        
        // Small delay
        await Future.delayed(Duration(milliseconds: 200));
        
        if (!_isListening) return;
        
        // Restart
        await _speechToText.listen(
          onResult: (result) {
            if (result.finalResult) {
              _accumulatedTranscript += ' ' + result.recognizedWords;
            }
            String currentTranscript = _accumulatedTranscript + ' ' + result.recognizedWords;
            onResult(currentTranscript.trim());
          },
          listenFor: Duration(seconds: 120),
          pauseFor: Duration(seconds: 30),
          localeId: 'en_US',
          listenOptions: SpeechListenOptions(
            partialResults: true,
            onDevice: false,
            listenMode: ListenMode.confirmation,
          ),
        );
      } catch (e) {
        AppLogger.logger.severe('Keep-alive restart error: $e');
        onError?.call(e.toString());
      }
    });
  }
  
  Future<void> stopListening() async {
    _isListening = false;
    _keepAliveTimer?.cancel();
    
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }
  
  String getAccumulatedTranscript() => _accumulatedTranscript.trim();
  
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  
  void dispose() {
    _isListening = false;
    _keepAliveTimer?.cancel();
    _speechToText.cancel();
    _flutterTts.stop();
  }
}