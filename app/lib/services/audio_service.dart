import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/constants.dart';

class AudioService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  
  Future<void> initialize() async {
    await _speechToText.initialize();
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(AppConstants.speechRate);
    await _flutterTts.setVolume(AppConstants.speechVolume);
    await _flutterTts.setPitch(AppConstants.speechPitch);
  }
  
  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }
  
  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onError,
  }) async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        _isListening = true;
        await _speechToText.listen(
          onResult: (result) {
            onResult(result.recognizedWords);
          },
          listenMode: ListenMode.dictation,
        );
      } else {
        onError?.call('Speech recognition not available');
      }
    }
  }
  
  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
    }
  }
  
  bool get isListening => _isListening;
  
  void dispose() {
    _speechToText.cancel();
  }
}
