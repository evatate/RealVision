import 'dart:math';

/// Data models for gait analysis feature extraction based on clinical papers

class GaitSessionData {
  final String participantId;
  final String sessionId;
  final DateTime timestamp;
  final List<GaitTrialData> trials;
  final GaitFeatures features;

  GaitSessionData({
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

  factory GaitSessionData.fromJson(Map<String, dynamic> json) {
    return GaitSessionData(
      participantId: json['participantId'],
      sessionId: json['sessionId'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      trials: (json['trials'] as List).map((t) => GaitTrialData.fromJson(t)).toList(),
      features: GaitFeatures.fromJson(json['features']),
    );
  }
}

class GaitTrialData {
  final int trialNumber;
  final List<GaitFrame> frames;
  final double duration; // seconds
  final int stepCount;

  GaitTrialData({
    required this.trialNumber,
    required this.frames,
    required this.duration,
    required this.stepCount,
  });

  Map<String, dynamic> toJson() => {
    'trialNumber': trialNumber,
    'frames': frames.map((f) => f.toJson()).toList(),
    'duration': duration,
    'stepCount': stepCount,
  };

  factory GaitTrialData.fromJson(Map<String, dynamic> json) {
    return GaitTrialData(
      trialNumber: json['trialNumber'],
      frames: (json['frames'] as List).map((f) => GaitFrame.fromJson(f)).toList(),
      duration: json['duration'],
      stepCount: json['stepCount'],
    );
  }
}

class GaitFrame {
  final double timestamp; // seconds from trial start
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double accelerationMagnitude;
  final bool isStep;

  GaitFrame({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.accelerationMagnitude,
    required this.isStep,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'accelX': accelX,
    'accelY': accelY,
    'accelZ': accelZ,
    'gyroX': gyroX,
    'gyroY': gyroY,
    'gyroZ': gyroZ,
    'accelerationMagnitude': accelerationMagnitude,
    'isStep': isStep,
  };

  factory GaitFrame.fromJson(Map<String, dynamic> json) {
    return GaitFrame(
      timestamp: json['timestamp'],
      accelX: json['accelX'],
      accelY: json['accelY'],
      accelZ: json['accelZ'],
      gyroX: json['gyroX'],
      gyroY: json['gyroY'],
      gyroZ: json['gyroZ'],
      accelerationMagnitude: json['accelerationMagnitude'],
      isStep: json['isStep'],
    );
  }
}

class GaitFeatures {
  // Temporal features
  final double cadence; // steps per minute
  final double stepTime; // seconds per step
  final double stepTimeVariability; // coefficient of variation

  // Spatial features
  final double strideLength; // estimated stride length (normalized)
  final double strideLengthVariability;

  // Rhythm features
  final double gaitRegularity; // autocorrelation of acceleration
  final double gaitSymmetry; // symmetry between left/right steps

  // Stability features
  final double accelerationVariability; // RMS of acceleration magnitude
  final double jerk; // rate of change of acceleration

  // Overall performance
  final double gaitSpeed; // estimated walking speed
  final double gaitQualityScore; // composite score

  GaitFeatures({
    required this.cadence,
    required this.stepTime,
    required this.stepTimeVariability,
    required this.strideLength,
    required this.strideLengthVariability,
    required this.gaitRegularity,
    required this.gaitSymmetry,
    required this.accelerationVariability,
    required this.jerk,
    required this.gaitSpeed,
    required this.gaitQualityScore,
  });

  Map<String, dynamic> toJson() => {
    'cadence': cadence,
    'stepTime': stepTime,
    'stepTimeVariability': stepTimeVariability,
    'strideLength': strideLength,
    'strideLengthVariability': strideLengthVariability,
    'gaitRegularity': gaitRegularity,
    'gaitSymmetry': gaitSymmetry,
    'accelerationVariability': accelerationVariability,
    'jerk': jerk,
    'gaitSpeed': gaitSpeed,
    'gaitQualityScore': gaitQualityScore,
  };

  factory GaitFeatures.fromJson(Map<String, dynamic> json) {
    return GaitFeatures(
      cadence: json['cadence'],
      stepTime: json['stepTime'],
      stepTimeVariability: json['stepTimeVariability'],
      strideLength: json['strideLength'],
      strideLengthVariability: json['strideLengthVariability'],
      gaitRegularity: json['gaitRegularity'],
      gaitSymmetry: json['gaitSymmetry'],
      accelerationVariability: json['accelerationVariability'],
      jerk: json['jerk'],
      gaitSpeed: json['gaitSpeed'],
      gaitQualityScore: json['gaitQualityScore'],
    );
  }
}

class GaitFeatureExtraction {
  static const double gravity = 9.81; // m/s²
  static const int minFramesForAnalysis = 50;

  /// Extract features from a single trial
  static GaitFeatures extractTrialFeatures(GaitTrialData trial) {
    if (trial.frames.length < minFramesForAnalysis || trial.stepCount < 2) {
      return GaitFeatures(
        cadence: 0.0,
        stepTime: 0.0,
        stepTimeVariability: 0.0,
        strideLength: 0.0,
        strideLengthVariability: 0.0,
        gaitRegularity: 0.0,
        gaitSymmetry: 0.0,
        accelerationVariability: 0.0,
        jerk: 0.0,
        gaitSpeed: 0.0,
        gaitQualityScore: 0.0,
      );
    }

    // Extract step timings
    final stepTimestamps = trial.frames.where((f) => f.isStep).map((f) => f.timestamp).toList();
    final stepTimes = <double>[];

    for (int i = 1; i < stepTimestamps.length; i++) {
      stepTimes.add(stepTimestamps[i] - stepTimestamps[i-1]);
    }

    // Temporal features
    final cadence = trial.duration > 0 ? (trial.stepCount / trial.duration) * 60.0 : 0.0;
    final avgStepTime = stepTimes.isNotEmpty ? stepTimes.reduce((a, b) => a + b) / stepTimes.length : 0.0;

    final stepTimeVariability = stepTimes.isNotEmpty && avgStepTime > 0
        ? _calculateCoefficientOfVariation(stepTimes, avgStepTime)
        : 0.0;

    // Spatial features (estimated from acceleration patterns)
    final strideLength = _estimateStrideLength(trial.frames, stepTimes);
    final strideLengthVariability = _calculateStrideVariability(trial.frames);

    // Rhythm features
    final gaitRegularity = _calculateGaitRegularity(trial.frames);
    final gaitSymmetry = _calculateGaitSymmetry(trial.frames, stepTimes);

    // Stability features
    final accelerationVariability = _calculateAccelerationVariability(trial.frames);
    final jerk = _calculateJerk(trial.frames);

    // Overall performance
    final gaitSpeed = cadence * strideLength * 0.01; // rough estimate in m/min
    final gaitQualityScore = _calculateGaitQualityScore(
      cadence, stepTimeVariability, gaitRegularity, accelerationVariability,
    );

    return GaitFeatures(
      cadence: cadence,
      stepTime: avgStepTime,
      stepTimeVariability: stepTimeVariability,
      strideLength: strideLength,
      strideLengthVariability: strideLengthVariability,
      gaitRegularity: gaitRegularity,
      gaitSymmetry: gaitSymmetry,
      accelerationVariability: accelerationVariability,
      jerk: jerk,
      gaitSpeed: gaitSpeed,
      gaitQualityScore: gaitQualityScore,
    );
  }

  static double _calculateCoefficientOfVariation(List<double> values, double mean) {
    if (values.isEmpty || mean == 0) return 0.0;

    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(variance);
    return stdDev / mean;
  }

  static double _estimateStrideLength(List<GaitFrame> frames, List<double> stepTimes) {
    if (frames.isEmpty || stepTimes.isEmpty) return 0.0;

    // Estimate stride length from acceleration patterns
    final avgStepTime = stepTimes.reduce((a, b) => a + b) / stepTimes.length;
    final avgMagnitude = frames.map((f) => f.accelerationMagnitude).reduce((a, b) => a + b) / frames.length;

    // Rough estimation: stride length proportional to step time and acceleration
    return avgStepTime * sqrt(avgMagnitude / gravity) * 100; // normalized scale
  }

  static double _calculateStrideVariability(List<GaitFrame> frames) {
    if (frames.length < 10) return 0.0;

    // Calculate variability in acceleration patterns between steps
    final magnitudes = frames.map((f) => f.accelerationMagnitude).toList();
    final mean = magnitudes.reduce((a, b) => a + b) / magnitudes.length;

    final variance = magnitudes.map((m) => pow(m - mean, 2)).reduce((a, b) => a + b) / magnitudes.length;
    final stdDev = sqrt(variance);

    return mean > 0 ? stdDev / mean : 0.0;
  }

  static double _calculateGaitRegularity(List<GaitFrame> frames) {
    if (frames.length < minFramesForAnalysis) return 0.0;

    // Calculate autocorrelation of vertical acceleration (simplified)
    final signal = frames.map((f) => f.accelY).toList();
    final mean = signal.reduce((a, b) => a + b) / signal.length;

    // Simple autocorrelation at lag equal to estimated step period
    final estimatedPeriod = (frames.last.timestamp - frames.first.timestamp) / (frames.where((f) => f.isStep).length / 2.0);
    final lag = max(1, (estimatedPeriod / (frames.last.timestamp - frames.first.timestamp) * frames.length).round());

    if (lag >= signal.length) return 0.0;

    double correlation = 0.0;
    int count = 0;

    for (int i = 0; i < signal.length - lag; i++) {
      correlation += (signal[i] - mean) * (signal[i + lag] - mean);
      count++;
    }

    if (count == 0) return 0.0;

    correlation /= count;

    // Normalize by signal variance
    final variance = signal.map((s) => pow(s - mean, 2)).reduce((a, b) => a + b) / signal.length;
    final normalizedCorrelation = variance > 0 ? correlation / variance : 0.0;

    return max(0.0, min(1.0, normalizedCorrelation));
  }

  static double _calculateGaitSymmetry(List<GaitFrame> frames, List<double> stepTimes) {
    if (stepTimes.length < 4) return 0.0;

    // Calculate symmetry between consecutive steps (left vs right, estimate)
    double symmetrySum = 0.0;
    int symmetryCount = 0;

    for (int i = 2; i < stepTimes.length; i += 2) {
      if (i + 1 < stepTimes.length) {
        final symmetry = min(stepTimes[i], stepTimes[i + 1]) / max(stepTimes[i], stepTimes[i + 1]);
        symmetrySum += symmetry;
        symmetryCount++;
      }
    }

    return symmetryCount > 0 ? symmetrySum / symmetryCount : 0.0;
  }

  static double _calculateAccelerationVariability(List<GaitFrame> frames) {
    if (frames.isEmpty) return 0.0;

    final magnitudes = frames.map((f) => f.accelerationMagnitude).toList();
    final mean = magnitudes.reduce((a, b) => a + b) / magnitudes.length;

    final variance = magnitudes.map((m) => pow(m - mean, 2)).reduce((a, b) => a + b) / magnitudes.length;
    return sqrt(variance);
  }

  static double _calculateJerk(List<GaitFrame> frames) {
    if (frames.length < 3) return 0.0;

    double totalJerk = 0.0;
    int count = 0;

    for (int i = 2; i < frames.length; i++) {
      final dt1 = frames[i-1].timestamp - frames[i-2].timestamp;
      final dt2 = frames[i].timestamp - frames[i-1].timestamp;

      if (dt1 > 0 && dt2 > 0) {
        final accel1 = frames[i-1].accelerationMagnitude;
        final accel2 = frames[i-2].accelerationMagnitude;
        final accel3 = frames[i].accelerationMagnitude;

        // Calculate jerk (rate of change of acceleration)
        final jerkValue = (accel3 - 2 * accel1 + accel2) / (dt1 * dt2);
        totalJerk += jerkValue.abs();
        count++;
      }
    }

    return count > 0 ? totalJerk / count : 0.0;
  }

  static double _calculateGaitQualityScore(
    double cadence,
    double stepTimeVariability,
    double gaitRegularity,
    double accelerationVariability,
  ) {
    // Normalize and combine metrics into a composite score
    // Higher scores indicate better gait quality

    // Cadence score (optimal range: 80-120 steps/min)
    final cadenceScore = cadence >= 80 && cadence <= 120 ? 1.0 :
                        cadence >= 60 && cadence <= 140 ? 0.7 : 0.3;

    // Variability score (lower is better)
    final variabilityScore = max(0.0, 1.0 - stepTimeVariability * 2);

    // Regularity score (higher is better)
    final regularityScore = gaitRegularity;

    // Stability score (lower acceleration variability is better)
    final stabilityScore = max(0.0, 1.0 - accelerationVariability / 5.0);

    // Weighted average
    return (cadenceScore * 0.3 + variabilityScore * 0.3 + regularityScore * 0.2 + stabilityScore * 0.2);
  }

  /// Extract aggregate features across all trials
  static GaitFeatures extractSessionFeatures(GaitSessionData session) {
    if (session.trials.isEmpty) {
      return GaitFeatures(
        cadence: 0.0,
        stepTime: 0.0,
        stepTimeVariability: 0.0,
        strideLength: 0.0,
        strideLengthVariability: 0.0,
        gaitRegularity: 0.0,
        gaitSymmetry: 0.0,
        accelerationVariability: 0.0,
        jerk: 0.0,
        gaitSpeed: 0.0,
        gaitQualityScore: 0.0,
      );
    }

    final trialFeatures = session.trials.map((trial) => extractTrialFeatures(trial)).toList();

    // Average across trials
    final cadence = trialFeatures.map((f) => f.cadence).reduce((a, b) => a + b) / trialFeatures.length;
    final stepTime = trialFeatures.map((f) => f.stepTime).reduce((a, b) => a + b) / trialFeatures.length;
    final stepTimeVariability = trialFeatures.map((f) => f.stepTimeVariability).reduce((a, b) => a + b) / trialFeatures.length;
    final strideLength = trialFeatures.map((f) => f.strideLength).reduce((a, b) => a + b) / trialFeatures.length;
    final strideLengthVariability = trialFeatures.map((f) => f.strideLengthVariability).reduce((a, b) => a + b) / trialFeatures.length;
    final gaitRegularity = trialFeatures.map((f) => f.gaitRegularity).reduce((a, b) => a + b) / trialFeatures.length;
    final gaitSymmetry = trialFeatures.map((f) => f.gaitSymmetry).reduce((a, b) => a + b) / trialFeatures.length;
    final accelerationVariability = trialFeatures.map((f) => f.accelerationVariability).reduce((a, b) => a + b) / trialFeatures.length;
    final jerk = trialFeatures.map((f) => f.jerk).reduce((a, b) => a + b) / trialFeatures.length;
    final gaitSpeed = trialFeatures.map((f) => f.gaitSpeed).reduce((a, b) => a + b) / trialFeatures.length;
    final gaitQualityScore = trialFeatures.map((f) => f.gaitQualityScore).reduce((a, b) => a + b) / trialFeatures.length;

    return GaitFeatures(
      cadence: cadence,
      stepTime: stepTime,
      stepTimeVariability: stepTimeVariability,
      strideLength: strideLength,
      strideLengthVariability: strideLengthVariability,
      gaitRegularity: gaitRegularity,
      gaitSymmetry: gaitSymmetry,
      accelerationVariability: accelerationVariability,
      jerk: jerk,
      gaitSpeed: gaitSpeed,
      gaitQualityScore: gaitQualityScore,
    );
  }
}