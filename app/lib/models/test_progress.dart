import 'package:flutter/foundation.dart';
import '../services/aws_storage_service.dart';

class TestProgress with ChangeNotifier {
  // Serialization
  Map<String, dynamic> toMap() => {
    'speechCompleted': _speechCompleted,
    'fixationCompleted': _fixationCompleted,
    'prosaccadeCompleted': _prosaccadeCompleted,
    'pursuitCompleted': _pursuitCompleted,
    'smileCompleted': _smileCompleted,
    'gaitCompleted': _gaitCompleted,
    // You can add more fields as needed
  };

  static TestProgress fromMap(Map<String, dynamic> map) {
    final progress = TestProgress();
    progress._speechCompleted = map['speechCompleted'] ?? false;
    progress._fixationCompleted = map['fixationCompleted'] ?? false;
    progress._prosaccadeCompleted = map['prosaccadeCompleted'] ?? false;
    progress._pursuitCompleted = map['pursuitCompleted'] ?? false;
    progress._smileCompleted = map['smileCompleted'] ?? false;
    progress._gaitCompleted = map['gaitCompleted'] ?? false;
    // You can add more fields as needed
    return progress;
  }
  bool _speechCompleted = false;
  bool _fixationCompleted = false;
  bool _prosaccadeCompleted = false;
  bool _pursuitCompleted = false;
  bool _smileCompleted = false;
  bool _gaitCompleted = false;
  
  SpeechAnalysis? _speechAnalysis;

  bool get speechCompleted => _speechCompleted;
  bool get fixationCompleted => _fixationCompleted;
  bool get prosaccadeCompleted => _prosaccadeCompleted;
  bool get pursuitCompleted => _pursuitCompleted;
  bool get smileCompleted => _smileCompleted;
  bool get gaitCompleted => _gaitCompleted;
  
  SpeechAnalysis? get speechAnalysis => _speechAnalysis;
  
  bool get eyeTrackingCompleted => _fixationCompleted && _prosaccadeCompleted && _pursuitCompleted;
  
  bool get allTestsCompleted => 
      _speechCompleted && 
      eyeTrackingCompleted && 
      _smileCompleted && 
      _gaitCompleted;

  void markSpeechCompleted() {
    _speechCompleted = true;
    notifyListeners();
  }

  void completeSpeechTest(SpeechAnalysis analysis) {
    _speechAnalysis = analysis;
    _speechCompleted = true;
    notifyListeners();
  }

  void markFixationCompleted() {
    _fixationCompleted = true;
    notifyListeners();
  }

  void markProsaccadeCompleted() {
    _prosaccadeCompleted = true;
    notifyListeners();
  }

  void markPursuitCompleted() {
    _pursuitCompleted = true;
    notifyListeners();
  }

  void markSmileCompleted() {
    _smileCompleted = true;
    notifyListeners();
  }

  void markGaitCompleted() {
    _gaitCompleted = true;
    notifyListeners();
  }

  void resetProgress() {
    _speechCompleted = false;
    _fixationCompleted = false;
    _prosaccadeCompleted = false;
    _pursuitCompleted = false;
    _smileCompleted = false;
    _gaitCompleted = false;
    _speechAnalysis = null;
    notifyListeners();
  }
}