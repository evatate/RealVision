import 'dart:math';
import 'dart:ui';

/// Data models for eye tracking feature extraction based on clinical papers

class EyeTrackingSessionData {
  final String participantId;
  final String sessionId;
  final DateTime timestamp;
  final List<EyeTrackingTrialData> trials;
  final EyeTrackingFeatures features;

  EyeTrackingSessionData({
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

  factory EyeTrackingSessionData.fromJson(Map<String, dynamic> json) {
    return EyeTrackingSessionData(
      participantId: json['participantId'],
      sessionId: json['sessionId'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      trials: (json['trials'] as List).map((t) => EyeTrackingTrialData.fromJson(t)).toList(),
      features: EyeTrackingFeatures.fromJson(json['features']),
    );
  }
}

class EyeTrackingTrialData {
  final int trialNumber;
  final String taskType; // 'fixation', 'prosaccade', 'pursuit'
  final List<EyeTrackingFrame> frames;
  final double qualityScore;

  EyeTrackingTrialData({
    required this.trialNumber,
    required this.taskType,
    required this.frames,
    required this.qualityScore,
  });

  Map<String, dynamic> toJson() => {
    'trialNumber': trialNumber,
    'taskType': taskType,
    'frames': frames.map((f) => f.toJson()).toList(),
    'qualityScore': qualityScore,
  };

  factory EyeTrackingTrialData.fromJson(Map<String, dynamic> json) {
    return EyeTrackingTrialData(
      trialNumber: json['trialNumber'],
      taskType: json['taskType'],
      frames: (json['frames'] as List).map((f) => EyeTrackingFrame.fromJson(f)).toList(),
      qualityScore: json['qualityScore'],
    );
  }
}

class EyeTrackingFrame {
  final double timestamp; // seconds from trial start
  final Offset eyePosition;
  final Offset targetPosition;
  final double distance; // distance between eye and target
  final double headPoseX;
  final double headPoseY;
  final double headPoseZ;

  EyeTrackingFrame({
    required this.timestamp,
    required this.eyePosition,
    required this.targetPosition,
    required this.distance,
    required this.headPoseX,
    required this.headPoseY,
    required this.headPoseZ,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'eyePosition': {'dx': eyePosition.dx, 'dy': eyePosition.dy},
    'targetPosition': {'dx': targetPosition.dx, 'dy': targetPosition.dy},
    'distance': distance,
    'headPoseX': headPoseX,
    'headPoseY': headPoseY,
    'headPoseZ': headPoseZ,
  };

  factory EyeTrackingFrame.fromJson(Map<String, dynamic> json) {
    return EyeTrackingFrame(
      timestamp: json['timestamp'],
      eyePosition: Offset(json['eyePosition']['dx'], json['eyePosition']['dy']),
      targetPosition: Offset(json['targetPosition']['dx'], json['targetPosition']['dy']),
      distance: json['distance'],
      headPoseX: json['headPoseX'],
      headPoseY: json['headPoseY'],
      headPoseZ: json['headPoseZ'],
    );
  }
}

class EyeTrackingFeatures {
  // Fixation stability metrics
  final double fixationStability; // RMS error during fixation task
  final double fixationDuration; // average time maintaining fixation

  // Saccade metrics (pro-saccade task)
  final double saccadeLatency; // average reaction time to target jump
  final double saccadeAccuracy; // average distance error at saccade end
  final double saccadeVelocity; // average peak velocity

  // Smooth pursuit metrics
  final double pursuitGain; // ratio of eye velocity to target velocity
  final double pursuitStability; // consistency of pursuit tracking

  // Overall performance
  final double overallAccuracy; // combined accuracy across all tasks
  final double taskCompletionRate; // percentage of trials completed successfully

  EyeTrackingFeatures({
    required this.fixationStability,
    required this.fixationDuration,
    required this.saccadeLatency,
    required this.saccadeAccuracy,
    required this.saccadeVelocity,
    required this.pursuitGain,
    required this.pursuitStability,
    required this.overallAccuracy,
    required this.taskCompletionRate,
  });

  Map<String, dynamic> toJson() => {
    'fixationStability': fixationStability,
    'fixationDuration': fixationDuration,
    'saccadeLatency': saccadeLatency,
    'saccadeAccuracy': saccadeAccuracy,
    'saccadeVelocity': saccadeVelocity,
    'pursuitGain': pursuitGain,
    'pursuitStability': pursuitStability,
    'overallAccuracy': overallAccuracy,
    'taskCompletionRate': taskCompletionRate,
  };

  factory EyeTrackingFeatures.fromJson(Map<String, dynamic> json) {
    return EyeTrackingFeatures(
      fixationStability: json['fixationStability'],
      fixationDuration: json['fixationDuration'],
      saccadeLatency: json['saccadeLatency'],
      saccadeAccuracy: json['saccadeAccuracy'],
      saccadeVelocity: json['saccadeVelocity'],
      pursuitGain: json['pursuitGain'],
      pursuitStability: json['pursuitStability'],
      overallAccuracy: json['overallAccuracy'],
      taskCompletionRate: json['taskCompletionRate'],
    );
  }
}

class EyeTrackingFeatureExtraction {
  static const double FIXATION_THRESHOLD = 0.05; // 5% of screen
  static const double SACCADE_VELOCITY_THRESHOLD = 50.0; // deg/s
  static const int MIN_FRAMES_FOR_ANALYSIS = 10;

  /// Extract features from a single trial
  static Map<String, double> extractTrialFeatures(EyeTrackingTrialData trial) {
    if (trial.frames.length < MIN_FRAMES_FOR_ANALYSIS) {
      return {
        'qualityScore': 0.0,
        'stability': 0.0,
        'latency': 0.0,
        'accuracy': 0.0,
        'velocity': 0.0,
      };
    }

    switch (trial.taskType) {
      case 'fixation':
        return _extractFixationFeatures(trial.frames);
      case 'prosaccade':
        return _extractProsaccadeFeatures(trial.frames);
      case 'pursuit':
        return _extractPursuitFeatures(trial.frames);
      default:
        return {'qualityScore': 0.0, 'stability': 0.0, 'latency': 0.0, 'accuracy': 0.0, 'velocity': 0.0};
    }
  }

  static Map<String, double> _extractFixationFeatures(List<EyeTrackingFrame> frames) {
    // Calculate RMS error from target position
    double sumSquaredError = 0.0;
    for (var frame in frames) {
      final error = frame.distance;
      sumSquaredError += error * error;
    }
    final rmsError = sqrt(sumSquaredError / frames.length);

    // Calculate stability (inverse of RMS error, normalized)
    final stability = max(0.0, 1.0 - (rmsError / FIXATION_THRESHOLD));

    return {
      'qualityScore': stability,
      'stability': stability,
      'latency': 0.0, // Not applicable for fixation
      'accuracy': 1.0 - rmsError, // Higher is better
      'velocity': 0.0, // Not applicable for fixation
    };
  }

  static Map<String, double> _extractProsaccadeFeatures(List<EyeTrackingFrame> frames) {
    if (frames.length < MIN_FRAMES_FOR_ANALYSIS) {
      return {'qualityScore': 0.0, 'stability': 0.0, 'latency': 0.0, 'accuracy': 0.0, 'velocity': 0.0};
    }

    // Find saccade onset (when distance starts decreasing rapidly)
    int saccadeStartIndex = 0;
    double maxDistance = 0.0;
    for (int i = 0; i < frames.length; i++) {
      if (frames[i].distance > maxDistance) {
        maxDistance = frames[i].distance;
        saccadeStartIndex = i;
      }
    }

    // Calculate latency (time from trial start to saccade onset)
    final latency = frames[saccadeStartIndex].timestamp;

    // Calculate accuracy (final distance to target)
    final finalAccuracy = 1.0 - frames.last.distance;

    // Calculate peak velocity during saccade
    double maxVelocity = 0.0;
    for (int i = 1; i < frames.length; i++) {
      final dt = frames[i].timestamp - frames[i-1].timestamp;
      if (dt > 0) {
        final velocity = frames[i].distance / dt;
        maxVelocity = max(maxVelocity, velocity);
      }
    }

    final qualityScore = (finalAccuracy + (latency < 0.5 ? 1.0 : 0.0)) / 2.0;

    return {
      'qualityScore': qualityScore,
      'stability': 0.0, // Not applicable for saccades
      'latency': latency,
      'accuracy': finalAccuracy,
      'velocity': maxVelocity,
    };
  }

  static Map<String, double> _extractPursuitFeatures(List<EyeTrackingFrame> frames) {
    if (frames.length < MIN_FRAMES_FOR_ANALYSIS) {
      return {'qualityScore': 0.0, 'stability': 0.0, 'latency': 0.0, 'accuracy': 0.0, 'velocity': 0.0};
    }

    // Calculate pursuit gain (correlation between eye and target movement)
    double sumEyeVelocity = 0.0;
    double sumTargetVelocity = 0.0;
    int validFrames = 0;

    for (int i = 1; i < frames.length; i++) {
      final dt = frames[i].timestamp - frames[i-1].timestamp;
      if (dt > 0) {
        final eyeVelocity = (frames[i].eyePosition - frames[i-1].eyePosition).distance / dt;
        final targetVelocity = (frames[i].targetPosition - frames[i-1].targetPosition).distance / dt;

        sumEyeVelocity += eyeVelocity;
        sumTargetVelocity += targetVelocity;
        validFrames++;
      }
    }

    final avgEyeVelocity = validFrames > 0 ? sumEyeVelocity / validFrames : 0.0;
    final avgTargetVelocity = validFrames > 0 ? sumTargetVelocity / validFrames : 0.0;
    final pursuitGain = avgTargetVelocity > 0 ? avgEyeVelocity / avgTargetVelocity : 0.0;

    // Calculate stability (consistency of tracking)
    double sumSquaredError = 0.0;
    for (var frame in frames) {
      sumSquaredError += frame.distance * frame.distance;
    }
    final rmsError = sqrt(sumSquaredError / frames.length);
    final stability = max(0.0, 1.0 - (rmsError / FIXATION_THRESHOLD));

    final qualityScore = (pursuitGain + stability) / 2.0;

    return {
      'qualityScore': qualityScore,
      'stability': stability,
      'latency': 0.0, // Not applicable for pursuit
      'accuracy': pursuitGain,
      'velocity': avgEyeVelocity,
    };
  }

  /// Extract aggregate features across all trials
  static EyeTrackingFeatures extractSessionFeatures(EyeTrackingSessionData session) {
    if (session.trials.isEmpty) {
      return EyeTrackingFeatures(
        fixationStability: 0.0,
        fixationDuration: 0.0,
        saccadeLatency: 0.0,
        saccadeAccuracy: 0.0,
        saccadeVelocity: 0.0,
        pursuitGain: 0.0,
        pursuitStability: 0.0,
        overallAccuracy: 0.0,
        taskCompletionRate: 0.0,
      );
    }

    // Separate trials by type
    final fixationTrials = session.trials.where((t) => t.taskType == 'fixation').toList();
    final prosaccadeTrials = session.trials.where((t) => t.taskType == 'prosaccade').toList();
    final pursuitTrials = session.trials.where((t) => t.taskType == 'pursuit').toList();

    // Extract features for each trial type
    final fixationFeatures = fixationTrials.map((t) => extractTrialFeatures(t)).toList();
    final prosaccadeFeatures = prosaccadeTrials.map((t) => extractTrialFeatures(t)).toList();
    final pursuitFeatures = pursuitTrials.map((t) => extractTrialFeatures(t)).toList();

    // Calculate aggregate metrics
    final fixationStability = fixationFeatures.isNotEmpty
        ? fixationFeatures.map((f) => f['stability']!).reduce((a, b) => a + b) / fixationFeatures.length
        : 0.0;

    final fixationDuration = fixationFeatures.isNotEmpty
        ? fixationFeatures.map((f) => f['qualityScore']!).reduce((a, b) => a + b) / fixationFeatures.length
        : 0.0;

    final saccadeLatency = prosaccadeFeatures.isNotEmpty
        ? prosaccadeFeatures.map((f) => f['latency']!).reduce((a, b) => a + b) / prosaccadeFeatures.length
        : 0.0;

    final saccadeAccuracy = prosaccadeFeatures.isNotEmpty
        ? prosaccadeFeatures.map((f) => f['accuracy']!).reduce((a, b) => a + b) / prosaccadeFeatures.length
        : 0.0;

    final saccadeVelocity = prosaccadeFeatures.isNotEmpty
        ? prosaccadeFeatures.map((f) => f['velocity']!).reduce((a, b) => a + b) / prosaccadeFeatures.length
        : 0.0;

    final pursuitGain = pursuitFeatures.isNotEmpty
        ? pursuitFeatures.map((f) => f['accuracy']!).reduce((a, b) => a + b) / pursuitFeatures.length
        : 0.0;

    final pursuitStability = pursuitFeatures.isNotEmpty
        ? pursuitFeatures.map((f) => f['stability']!).reduce((a, b) => a + b) / pursuitFeatures.length
        : 0.0;

    // Overall metrics
    final allFeatures = [...fixationFeatures, ...prosaccadeFeatures, ...pursuitFeatures];
    final overallAccuracy = allFeatures.isNotEmpty
        ? allFeatures.map((f) => f['accuracy']!).reduce((a, b) => a + b) / allFeatures.length
        : 0.0;

    final taskCompletionRate = session.trials.isNotEmpty
        ? session.trials.where((t) => t.qualityScore > 0.5).length / session.trials.length
        : 0.0;

    return EyeTrackingFeatures(
      fixationStability: fixationStability,
      fixationDuration: fixationDuration,
      saccadeLatency: saccadeLatency,
      saccadeAccuracy: saccadeAccuracy,
      saccadeVelocity: saccadeVelocity,
      pursuitGain: pursuitGain,
      pursuitStability: pursuitStability,
      overallAccuracy: overallAccuracy,
      taskCompletionRate: taskCompletionRate,
    );
  }
}