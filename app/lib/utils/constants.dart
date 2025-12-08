class AppConstants {
  static const int fixationDuration = 10;
  static const int fixationTrials = 3; 
  
  // practice trial
  static const bool includePracticeTrial = true; // if true, adds 1 practice trial
  
  static const int smilePhaseDuration = 15;
  static const int smileTestRepetitions = 2;
  static const int speechTestDuration = 120;
  static const int gaitTestDuration = 120;
  
  static const int prosaccadePracticeTrials = 4;
  static const int prosaccadeTestTrials = 40;
  
  static const int smoothPursuitPracticeTrials = 2;
  static const int smoothPursuitTestTrials = 12;
  
  // TTS settings
  static const double speechRate = 0.5; // slow, dementia friendly
  static const double speechVolume = 1.0;
  static const double speechPitch = 1.0;
  
  // Delay between audio instructions
  static const int audioInstructionDelay = 1000; // 1 second delay
  
  static const double buttonSpacing = 33.0;
  static const double buttonPadding = 24.0;
  
  static const double titleFontSize = 40.0;
  static const double headingFontSize = 32.0;
  static const double bodyFontSize = 30.0;
  static const double buttonFontSize = 30.0;
}