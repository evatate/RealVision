class AppConstants {
  // Test durations
  static const int fixationDuration = 10; // seconds per trial
  static const int fixationTrials = 3; // 3 test trials
  
  static const int smilePhaseDuration = 15; // seconds
  static const int speechTestDuration = 120; // seconds (2 minutes)
  static const int gaitTestDuration = 120; // seconds (2 minutes)
  
  // Eye tracking parameters
  static const int prosaccadePracticeTrials = 4;
  static const int prosaccadeTestTrials = 40;
  
  static const int smoothPursuitPracticeTrials = 2;
  static const int smoothPursuitTestTrials = 12;
  
  // Text to speech settings
  static const double speechRate = 0.6; // slow for dementia friendly
  static const double speechVolume = 1.0;
  static const double speechPitch = 1.0;
  
  // Speech to text settings
  static const int pauseThreshold = 3000; // Milliseconds to wait before finalizing
  
  // Button spacing (for dementia-friendly design)
  static const double buttonSpacing = 32.0;
  static const double buttonPadding = 32.0;
  
  // Font sizes
  static const double titleFontSize = 48.0;
  static const double headingFontSize = 36.0;
  static const double bodyFontSize = 24.0;
  static const double buttonFontSize = 28.0;
}