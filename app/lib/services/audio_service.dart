import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'dart:async';
import 'dart:io' show Platform;

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
      
      // Platform-specific TTS configuration
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(AppConstants.speechRate);
      await _flutterTts.setVolume(AppConstants.speechVolume);
      await _flutterTts.setPitch(AppConstants.speechPitch);
      
      if (Platform.isIOS) {
        // iOS-specific settings
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      } else if (Platform.isAndroid) {
        // Android-specific settings to prevent audio focus issues
        await _flutterTts.setVoice({"name": "en-us-x-sfg#male_1-local", "locale": "en-US"});
      }
      
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
        listenFor: Platform.isAndroid ? Duration(seconds: 60) : Duration(seconds: 120), // Shorter for Android
        pauseFor: Platform.isAndroid ? Duration(seconds: 45) : Duration(seconds: 30),   // Even more pause tolerance for Android
        localeId: 'en_US',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          onDevice: Platform.isAndroid, // Use on-device for Android to avoid network timeouts
          listenMode: Platform.isAndroid ? ListenMode.dictation : ListenMode.confirmation, // Dictation for Android
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
    // Platform-specific keep-alive timing
    int keepAliveSeconds = Platform.isAndroid ? 90 : 90; // Less frequent restarts for Android
    
    // Restart listening periodically to prevent timeout
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(Duration(seconds: keepAliveSeconds), (timer) async {
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
          listenFor: Platform.isAndroid ? Duration(seconds: 60) : Duration(seconds: 120),
          pauseFor: Platform.isAndroid ? Duration(seconds: 15) : Duration(seconds: 30),
          localeId: 'en_US',
          listenOptions: SpeechListenOptions(
            partialResults: true,
            onDevice: Platform.isAndroid,
            listenMode: Platform.isAndroid ? ListenMode.dictation : ListenMode.confirmation,
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