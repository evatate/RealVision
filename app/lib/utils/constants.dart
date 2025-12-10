class AppConstants {
  static const int fixationDuration = 10;
  static const int fixationPracticeTrials = 1; // 1 practice
  static const int fixationTestTrials = 3;     // 3 test trials
  
  static const int smilePracticeRepetitions = 1; // 1 practice
  static const int smileTestRepetitions = 2;     // 2 test runs
  static const int smilePhaseDuration = 15;
  
  static const int speechTestDuration = 120;
  static const int gaitTestDuration = 120;
  
  static const int prosaccadePracticeTrials = 4;
  static const int prosaccadeTestTrials = 10; // 40 for production
  
  static const int smoothPursuitPracticeTrials = 2;
  static const int smoothPursuitTestTrials = 6; // 12 for production
  
  // TTS settings (VERY SLOW + LOUDER)
  static const double speechRate = 0.4; // Even slower!
  static const double speechVolume = 1.0; // Already max, phone will be louder
  static const double speechPitch = 1.0;
  
  static const int audioInstructionDelay = 1500; // 1.5 second delay
  
  static const double buttonSpacing = 33.0;
  static const double buttonPadding = 24.0;
  
  // Increased font sizes
  static const double titleFontSize = 40.0;
  static const double testTitleFontSize = 30.0;
  static const double headingFontSize = 32.0;
  static const double bodyFontSize = 30.0;
  static const double buttonFontSize = 30.0;
}