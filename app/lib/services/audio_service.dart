import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'dart:async';
import 'dart:io' show Platform, File;

class AudioService {
  final FlutterTts _flutterTts = FlutterTts();
  FlutterSoundRecorder? _audioRecorder;
  bool _isRecording = false;
  bool _isInitialized = false;
  String? _currentRecordingPath;
  Timer? _recordingTimer;
  
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _audioRecorder = FlutterSoundRecorder();

      // Open the recorder
      await _audioRecorder!.openRecorder();

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
      AppLogger.logger.info('Audio service initialized successfully');
    } catch (e) {
      AppLogger.logger.severe('Audio service initialization error: $e');
      rethrow;
    }
  }  Future<void> speak(String text) async {
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
  
  Future<String?> startRecording() async {
    if (!_isInitialized || _audioRecorder == null) {
      await initialize();
    }

    if (_isRecording) {
      AppLogger.logger.warning('Already recording');
      return null;
    }

    try {
      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = path.join(tempDir.path, 'speech_recording_$timestamp.wav');

      AppLogger.logger.info('Starting audio recording to: $_currentRecordingPath');

      await _audioRecorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );

      _isRecording = true;

      AppLogger.logger.info('Audio recording started');
      return _currentRecordingPath;

    } catch (e) {
      AppLogger.logger.severe('Recording start error: $e');
      return null;
    }
  }  Future<String?> stopRecording() async {
    if (!_isRecording || _audioRecorder == null) {
      AppLogger.logger.warning('Not currently recording');
      return null;
    }

    try {
      final path = await _audioRecorder!.stopRecorder();
      _isRecording = false;

      if (path != null && await File(path).exists()) {
        final fileSize = await File(path).length();
        AppLogger.logger.info('Recording stopped. File: $path, Size: $fileSize bytes');
        return path;
      } else {
        AppLogger.logger.warning('Recording file not found');
        return null;
      }

    } catch (e) {
      AppLogger.logger.severe('Recording stop error: $e');
      _isRecording = false;
      return null;
    }
  }
  
  String? getCurrentRecordingPath() => _currentRecordingPath;

  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;
  
  void dispose() {
    _recordingTimer?.cancel();
    if (_isRecording && _audioRecorder != null) {
      _audioRecorder!.stopRecorder();
    }
    _audioRecorder?.closeRecorder();
    _flutterTts.stop();
  }
}