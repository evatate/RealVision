import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/constants.dart';
import 'dart:async';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'cha_transcript_builder.dart';
import '../utils/logger.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String? _recordingPath;
  bool _recorderIsOpen = false;

  /// Start WAV audio recording and return the file path
  Future<String?> startRecording() async {
    AppLogger.logger.info('[SpeechTest] init');
    try {
      if (_recorder.isRecording) {
        AppLogger.logger.warning('[SpeechTest] Attempted to start recording while already recording.');
        return _recordingPath;
      }
      if (!_recorderIsOpen) {
        await _recorder.openRecorder();
        _recorderIsOpen = true;
      }
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/speech_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.startRecorder(
        toFile: filePath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        bitRate: 128000,
      );
      _recordingPath = filePath;
      AppLogger.logger.info('[SpeechTest] recording started');
      return filePath;
    } catch (e) {
      AppLogger.logger.info('Error starting WAV recording: $e');
      return null;
    }
  }


  /// Stop WAV audio recording and return the file path
  Future<String?> stopRecording() async {
    try {
      if (!_recorder.isRecording) {
        AppLogger.logger.warning('[SpeechTest] Attempted to stop recording when not recording.');
        return _recordingPath;
      }
      await _recorder.stopRecorder();
      if (_recorderIsOpen) {
        await _recorder.closeRecorder();
        _recorderIsOpen = false;
      }
      AppLogger.logger.info('[SpeechTest] recording stopped');
      if (_recordingPath != null) {
        AppLogger.logger.info('[SpeechTest] file saved: $_recordingPath');
      }
      return _recordingPath;
    } catch (e) {
      AppLogger.logger.info('Error stopping WAV recording: $e');
    }
    return null;
  }
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isInitialized = false;
  String _accumulatedTranscript = '';
  Timer? _keepAliveTimer;
  final List<SpeechSegment> _segments = [];
  DateTime? _lastResultTime;

  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      bool available = await _speechToText.initialize(
        onError: (error) {
          AppLogger.logger.info('Speech init error: $error');
        },
        onStatus: (status) {
          AppLogger.logger.info('Speech status: $status');
        },
      );

      if (!available) {
        AppLogger.logger.info('Speech recognition not available');
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
      AppLogger.logger.info('Audio service initialization error: $e');
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
      AppLogger.logger.info('TTS error: $e');
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
    _segments.clear();
    _lastResultTime = null;

    // Start keep-alive mechanism
    _startKeepAlive(onResult, onError);

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          final now = DateTime.now();

          if (result.finalResult) {
            _accumulatedTranscript += ' ${result.recognizedWords}';

            if (_lastResultTime != null) {
              _segments.add(
                SpeechSegment(
                  text: result.recognizedWords,
                  start: Duration(
                    milliseconds: _lastResultTime!.millisecondsSinceEpoch,
                  ),
                  end: Duration(
                    milliseconds: now.millisecondsSinceEpoch,
                  ),
                ),
              );
            }

            _lastResultTime = now;
          }

            final currentTranscript =
              "$_accumulatedTranscript ${result.recognizedWords}";
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
      AppLogger.logger.info('Listen error: $e');
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
              _accumulatedTranscript += ' ${result.recognizedWords}';
            }
            String currentTranscript = "$_accumulatedTranscript ${result.recognizedWords}";
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
        AppLogger.logger.info('Keep-alive restart error: $e');
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

  List<SpeechSegment> getSegments() => List.unmodifiable(_segments);

void resetSegments() {
  _segments.clear();
  _lastResultTime = null;
}

  
  String getAccumulatedTranscript() => _accumulatedTranscript.trim();
  
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  
  void dispose() {
    _isListening = false;
    _keepAliveTimer?.cancel();
    _speechToText.cancel();
    _flutterTts.stop();
    if (_recorderIsOpen) {
      _recorder.closeRecorder();
      _recorderIsOpen = false;
    }
  }
}