import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/constants.dart';
import 'dart:async';
import 'dart:io';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'cha_transcript_builder.dart';
import '../utils/logger.dart';

class AudioService {
    /// Check microphone permission status
    Future<bool> checkMicrophonePermission() async {
      // Use speech_to_text for permission check
      try {
        final status = await _speechToText.hasPermission;
        return status;
      } catch (e) {
        AppLogger.logger.info('Microphone permission check error: $e');
        return false;
      }
    }
  bool _restartPending = false;
  void Function(String)? _statusHandler;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String? _recordingPath;
  bool _recorderIsOpen = false;

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isInitialized = false;
  String _accumulatedTranscript = '';
  Timer? _keepAliveTimer;
  Timer? _watchdogTimer;
  final List<SpeechSegment> _segments = [];
  DateTime? _lastResultTime;
  DateTime? _sessionStartTime;
  String _currentPartialTranscript = '';

  // Platform-specific: Use WAV recording on iOS only
  bool get _shouldRecordWAV => Platform.isIOS;

  /// Start WAV audio recording and return the file path (iOS only)
  Future<String?> startRecording() async {
    if (!_shouldRecordWAV) {
      AppLogger.logger.info('[SpeechTest] WAV recording skipped on Android (using speech-to-text only)');
      return null;
    }

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

  /// Stop WAV audio recording and return the file path (iOS only)
  Future<String?> stopRecording() async {
    if (!_shouldRecordWAV) {
      AppLogger.logger.info('[SpeechTest] WAV recording skipped on Android');
      return null;
    }

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

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _statusHandler = (status) async {
        AppLogger.logger.info('Speech status: $status');
        final isAndroid = Platform.isAndroid;
        if (isAndroid && _isListening && status == 'done') {
          if (_restartPending) {
            AppLogger.logger.info('Speech recognizer restart already pending, skipping.');
            return;
          }
          _restartPending = true;
          AppLogger.logger.info('Speech recognizer ended (status: $status), restarting immediately...');
          // Immediate restart on Android, no delay
          await Future.delayed(const Duration(milliseconds: 100));
          if (_isListening && !_speechToText.isListening) {
            AppLogger.logger.info('Restarting speech session from status handler...');
            await _startListeningSession(_lastOnResult!, _lastOnError);
          }
          _restartPending = false;
        }
      };
      
      bool available = await _speechToText.initialize(
        onError: (error) {
          AppLogger.logger.info('Speech init error: $error');
        },
        onStatus: (status) {
          if (_statusHandler != null) _statusHandler!(status);
        },
      );
      
      if (!available) {
        AppLogger.logger.info('Speech recognition not available');
      }
      
      // TTS configuration
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(AppConstants.speechRate);
      await _flutterTts.setVolume(AppConstants.speechVolume);
      await _flutterTts.setPitch(AppConstants.speechPitch);
      if (Platform.isIOS) {
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }
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
  
  // Store last handlers for auto-restart
  Function(String)? _lastOnResult;
  Function(String)? _lastOnError;
  
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
    _currentPartialTranscript = '';
    _segments.clear();
    _lastResultTime = null;
    _sessionStartTime = DateTime.now();
    _lastOnResult = onResult;
    _lastOnError = onError;
    
    // watchdog to autorestart on Android
    if (Platform.isAndroid) {
      _startWatchdog(onResult, onError);
    } else {
      _startKeepAlive(onResult, onError);
    }
    
    await _startListeningSession(onResult, onError);
  }

  Future<void> _startListeningSession(
    Function(String) onResult,
    Function(String)? onError,
  ) async {
    if (!_isListening) return;
    
    try {
      final isAndroid = Platform.isAndroid;

      final listenDuration = isAndroid ? Duration(seconds: 55) : Duration(seconds: 120);
      final pauseDuration = isAndroid ? Duration(seconds: 5) : Duration(seconds: 30);

      // Prevent overlapping sessions
      if (_speechToText.isListening) {
        await _speechToText.stop();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      AppLogger.logger.info('Starting speech session - listenFor: ${listenDuration.inSeconds}s, pauseFor: ${pauseDuration.inSeconds}s');

      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          final now = DateTime.now();

          if (result.finalResult) {
            final newText = result.recognizedWords.trim();
            if (newText.isNotEmpty) {
              // Check for duplicates
              final words = _accumulatedTranscript.split(' ');
              final newWords = newText.split(' ');
              bool isDuplicate = false;
              
              if (words.length >= newWords.length) {
                final lastWords = words.sublist(words.length - newWords.length);
                isDuplicate = lastWords.join(' ') == newText;
              }
              
              if (!isDuplicate) {
                _accumulatedTranscript += ' $newText';
                
                if (_lastResultTime != null && _sessionStartTime != null) {
                  final segmentStart = _lastResultTime!.difference(_sessionStartTime!);
                  final segmentEnd = now.difference(_sessionStartTime!);
                  _segments.add(
                    SpeechSegment(
                      text: newText,
                      start: segmentStart,
                      end: segmentEnd,
                    ),
                  );
                }
                _lastResultTime = now;
              }
              _currentPartialTranscript = '';
            }
          } else {
            _currentPartialTranscript = result.recognizedWords;
          }
          
          final displayTranscript = _accumulatedTranscript.trim();
          final partialText = _currentPartialTranscript.trim();
          final fullText = partialText.isNotEmpty 
              ? '$displayTranscript $partialText'
              : displayTranscript;
          onResult(fullText.trim());
        },
        listenFor: listenDuration,
        pauseFor: pauseDuration,
        localeId: 'en_US',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          onDevice: false,
          listenMode: ListenMode.confirmation,
        ),
        onSoundLevelChange: (level) {
          // Activity detected
        },
        cancelOnError: false,
      );
    } catch (e) {
      AppLogger.logger.info('Listen session error: $e');
      onError?.call(e.toString());
    }
  }
  
  void _startKeepAlive(Function(String) onResult, Function(String)? onError) {
    _keepAliveTimer?.cancel();
    
    final isAndroid = Platform.isAndroid;
    // android, stay ahead of timeout
    final keepAliveInterval = isAndroid ? Duration(seconds: 5) : Duration(seconds: 90);
    
    _keepAliveTimer = Timer.periodic(keepAliveInterval, (timer) async {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      
      AppLogger.logger.info('Keep-alive timer: Restarting speech (${isAndroid ? "Android" : "iOS"})...');
      
      try {
        if (_speechToText.isListening) {
          await _speechToText.stop();
        }
        await Future.delayed(const Duration(milliseconds: 200));
        if (!_isListening) return;
        await _startListeningSession(onResult, onError);
      } catch (e) {
        AppLogger.logger.info('Keep-alive restart error: $e');
        onError?.call(e.toString());
      }
    });
  }
  
  void _startWatchdog(Function(String) onResult, Function(String)? onError) {
    _watchdogTimer?.cancel();
    
    // Check every 3 seconds if speech recognition stopped unexpectedly
    _watchdogTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      
      // If not listening and not restarting, force restart
      if (!_speechToText.isListening && !_restartPending) {
        AppLogger.logger.info('Watchdog: Speech stopped unexpectedly, restarting...');
        _restartPending = true;
        try {
          await Future.delayed(const Duration(milliseconds: 100));
          if (_isListening) {
            await _startListeningSession(onResult, onError);
          }
        } catch (e) {
          AppLogger.logger.info('Watchdog restart error: $e');
        }
        _restartPending = false;
      }
    });
  }
  
  Future<void> stopListening() async {
    _isListening = false;
    _keepAliveTimer?.cancel();
    _watchdogTimer?.cancel();
    _lastOnResult = null;
    _lastOnError = null;
    _restartPending = false;
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }

  List<SpeechSegment> getSegments() => List.unmodifiable(_segments);

  void resetSegments() {
    _segments.clear();
    _lastResultTime = null;
    _sessionStartTime = null;
    _accumulatedTranscript = '';
    _currentPartialTranscript = '';
  }
  
  String getAccumulatedTranscript() => _accumulatedTranscript.trim();
  
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  
  void dispose() {
    _isListening = false;
    _keepAliveTimer?.cancel();
    _watchdogTimer?.cancel();
    _speechToText.cancel();
    _flutterTts.stop();
    if (_recorderIsOpen) {
      _recorder.closeRecorder();
      _recorderIsOpen = false;
    }
  }
}