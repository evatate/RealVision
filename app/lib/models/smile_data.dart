import 'dart:math';

/// Data models for smile test feature extraction based on clinical papers

class SmileSessionData {
  final String participantId;
  final String sessionId;
  final DateTime timestamp;
  final List<SmileTrialData> trials;
  final SmileFeatures features;

  SmileSessionData({
    required this.participantId,
    required this.sessionId,
    required this.timestamp,
    required this.trials,
    required this.features,
  });

  Map<String, dynamic> toJson() => {
    'participantId': participantId,
    'sessionId': sessionId,
    'timestamp': timestamp.toIso8601String(),
    'trials': trials.map((t) => t.toJson()).toList(),
    'features': features.toJson(),
  };

  factory SmileSessionData.fromJson(Map<String, dynamic> json) {
    return SmileSessionData(
      participantId: json['participantId'],
      sessionId: json['sessionId'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      trials: (json['trials'] as List).map((t) => SmileTrialData.fromJson(t)).toList(),
      features: SmileFeatures.fromJson(json['features']),
    );
  }
}

class SmileTrialData {
  final int trialNumber;
  final List<SmileFrame> frames;

  SmileTrialData({
    required this.trialNumber,
    required this.frames,
  });

  Map<String, dynamic> toJson() => {
    'trialNumber': trialNumber,
    'frames': frames.map((f) => f.toJson()).toList(),
  };

  factory SmileTrialData.fromJson(Map<String, dynamic> json) {
    return SmileTrialData(
      trialNumber: json['trialNumber'],
      frames: (json['frames'] as List).map((f) => SmileFrame.fromJson(f)).toList(),
    );
  }
}

class SmileFrame {
  final double timestamp; // seconds from trial start
  final double smileIndex; // 0-100 from ML Kit
  final String phase; // 'neutral' or 'smile'

  SmileFrame({
    required this.timestamp,
    required this.smileIndex,
    required this.phase,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'smileIndex': smileIndex,
    'phase': phase,
  };

  factory SmileFrame.fromJson(Map<String, dynamic> json) {
    return SmileFrame(
      timestamp: json['timestamp'],
      smileIndex: json['smileIndex'],
      phase: json['phase'],
    );
  }
}

class SmileFeatures {
  // Duration features
  final double smilingDuration; // seconds spent smiling (>50 threshold)
  final double proportionSmiling; // smiling_duration / 15 seconds

  // Reaction features
  final double timeToSmile; // latency from smile instruction to first smile

  // Amplitude & variability
  final double meanSmileIndex;
  final double maxSmileIndex;
  final double minSmileIndex;
  final double stdSmileIndex;

  // Contrast features
  final double smileNeutralDifference; // mean(smile) - mean(neutral)

  SmileFeatures({
    required this.smilingDuration,
    required this.proportionSmiling,
    required this.timeToSmile,
    required this.meanSmileIndex,
    required this.maxSmileIndex,
    required this.minSmileIndex,
    required this.stdSmileIndex,
    required this.smileNeutralDifference,
  });

  Map<String, dynamic> toJson() => {
    'smilingDuration': smilingDuration,
    'proportionSmiling': proportionSmiling,
    'timeToSmile': timeToSmile,
    'meanSmileIndex': meanSmileIndex,
    'maxSmileIndex': maxSmileIndex,
    'minSmileIndex': minSmileIndex,
    'stdSmileIndex': stdSmileIndex,
    'smileNeutralDifference': smileNeutralDifference,
  };

  factory SmileFeatures.fromJson(Map<String, dynamic> json) {
    return SmileFeatures(
      smilingDuration: json['smilingDuration'],
      proportionSmiling: json['proportionSmiling'],
      timeToSmile: json['timeToSmile'],
      meanSmileIndex: json['meanSmileIndex'],
      maxSmileIndex: json['maxSmileIndex'],
      minSmileIndex: json['minSmileIndex'],
      stdSmileIndex: json['stdSmileIndex'],
      smileNeutralDifference: json['smileNeutralDifference'],
    );
  }
}

class SmileFeatureExtraction {
  static const double SMILE_THRESHOLD = 50.0;
  static const double PHASE_DURATION = 15.0; // seconds

  /// Extract features from a single trial
  static SmileFeatures extractTrialFeatures(SmileTrialData trial) {
    // Separate phases
    final smilePhase = trial.frames.where((f) => f.phase == 'smile').toList();
    final neutralPhase = trial.frames.where((f) => f.phase == 'neutral').toList();

    // Duration features
    final smilingFrames = smilePhase.where((f) => f.smileIndex > SMILE_THRESHOLD).length;
    final smilingDuration = smilingFrames / 30.0; // assuming 30 fps
    final proportionSmiling = smilingDuration / PHASE_DURATION;

    // Reaction time: first frame that crosses threshold after smile instruction
    double timeToSmile = PHASE_DURATION; // default to max if never smiled
    for (var frame in smilePhase) {
      if (frame.smileIndex > SMILE_THRESHOLD) {
        timeToSmile = frame.timestamp;
        break;
      }
    }

    // Amplitude & variability for smile phase
    if (smilePhase.isEmpty) {
      return SmileFeatures(
        smilingDuration: 0.0,
        proportionSmiling: 0.0,
        timeToSmile: PHASE_DURATION,
        meanSmileIndex: 0.0,
        maxSmileIndex: 0.0,
        minSmileIndex: 0.0,
        stdSmileIndex: 0.0,
        smileNeutralDifference: 0.0,
      );
    }

    final smileIndices = smilePhase.map((f) => f.smileIndex).toList();
    final meanSmile = smileIndices.reduce((a, b) => a + b) / smileIndices.length;
    final maxSmile = smileIndices.reduce((a, b) => a > b ? a : b);
    final minSmile = smileIndices.reduce((a, b) => a < b ? a : b);

    // Standard deviation
    final variance = smileIndices.map((s) => pow(s - meanSmile, 2)).reduce((a, b) => a + b) / smileIndices.length;
    final stdSmile = sqrt(variance);

    // Contrast features
    double smileNeutralDifference = 0.0;
    if (neutralPhase.isNotEmpty) {
      final neutralIndices = neutralPhase.map((f) => f.smileIndex).toList();
      final meanNeutral = neutralIndices.reduce((a, b) => a + b) / neutralIndices.length;
      smileNeutralDifference = meanSmile - meanNeutral;
    }

    return SmileFeatures(
      smilingDuration: smilingDuration,
      proportionSmiling: proportionSmiling,
      timeToSmile: timeToSmile,
      meanSmileIndex: meanSmile,
      maxSmileIndex: maxSmile,
      minSmileIndex: minSmile,
      stdSmileIndex: stdSmile,
      smileNeutralDifference: smileNeutralDifference,
    );
  }

  /// Extract aggregate features across all trials
  static SmileFeatures extractSessionFeatures(SmileSessionData session) {
    if (session.trials.isEmpty) {
      return SmileFeatures(
        smilingDuration: 0.0,
        proportionSmiling: 0.0,
        timeToSmile: PHASE_DURATION,
        meanSmileIndex: 0.0,
        maxSmileIndex: 0.0,
        minSmileIndex: 0.0,
        stdSmileIndex: 0.0,
        smileNeutralDifference: 0.0,
      );
    }

    final trialFeatures = session.trials.map((trial) => extractTrialFeatures(trial)).toList();

    // Average across trials
    final smilingDuration = trialFeatures.map((f) => f.smilingDuration).reduce((a, b) => a + b) / trialFeatures.length;
    final proportionSmiling = trialFeatures.map((f) => f.proportionSmiling).reduce((a, b) => a + b) / trialFeatures.length;
    final timeToSmile = trialFeatures.map((f) => f.timeToSmile).reduce((a, b) => a + b) / trialFeatures.length;
    final meanSmileIndex = trialFeatures.map((f) => f.meanSmileIndex).reduce((a, b) => a + b) / trialFeatures.length;
    final maxSmileIndex = trialFeatures.map((f) => f.maxSmileIndex).reduce((a, b) => a + b) / trialFeatures.length;
    final minSmileIndex = trialFeatures.map((f) => f.minSmileIndex).reduce((a, b) => a + b) / trialFeatures.length;
    final stdSmileIndex = trialFeatures.map((f) => f.stdSmileIndex).reduce((a, b) => a + b) / trialFeatures.length;
    final smileNeutralDifference = trialFeatures.map((f) => f.smileNeutralDifference).reduce((a, b) => a + b) / trialFeatures.length;

    return SmileFeatures(
      smilingDuration: smilingDuration,
      proportionSmiling: proportionSmiling,
      timeToSmile: timeToSmile,
      meanSmileIndex: meanSmileIndex,
      maxSmileIndex: maxSmileIndex,
      minSmileIndex: minSmileIndex,
      stdSmileIndex: stdSmileIndex,
      smileNeutralDifference: smileNeutralDifference,
    );
  }
}