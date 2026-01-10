import 'dart:math';
import 'dart:ui';
import '../utils/logger.dart';

/// Fixed data models for eye tracking feature extraction based on clinical papers

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
  final String taskType;
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
  final double timestamp;
  final Offset eyePosition;
  final Offset targetPosition;
  final double distance;
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
  final double fixationStability;
  final double fixationDuration;
  final int largeIntrusiveSaccades;
  final int squareWaveJerks;
  final double saccadeLatency;
  final double saccadeAccuracy;
  final double meanSaccadesPerTrial;
  final double pursuitGain;
  final double proportionPursuing;
  final int catchUpSaccades;
  final double overallAccuracy;
  final double taskCompletionRate;

  EyeTrackingFeatures({
    required this.fixationStability,
    required this.fixationDuration,
    required this.largeIntrusiveSaccades,
    required this.squareWaveJerks,
    required this.saccadeLatency,
    required this.saccadeAccuracy,
    required this.meanSaccadesPerTrial,
    required this.pursuitGain,
    required this.proportionPursuing,
    required this.catchUpSaccades,
    required this.overallAccuracy,
    required this.taskCompletionRate,
  });

  Map<String, dynamic> toJson() => {
    'fixationStability': fixationStability,
    'fixationDuration': fixationDuration,
    'largeIntrusiveSaccades': largeIntrusiveSaccades,
    'squareWaveJerks': squareWaveJerks,
    'saccadeLatency': saccadeLatency,
    'saccadeAccuracy': saccadeAccuracy,
    'meanSaccadesPerTrial': meanSaccadesPerTrial,
    'pursuitGain': pursuitGain,
    'proportionPursuing': proportionPursuing,
    'catchUpSaccades': catchUpSaccades,
    'overallAccuracy': overallAccuracy,
    'taskCompletionRate': taskCompletionRate,
  };

  factory EyeTrackingFeatures.fromJson(Map<String, dynamic> json) {
    return EyeTrackingFeatures(
      fixationStability: json['fixationStability']?.toDouble() ?? 0.0,
      fixationDuration: json['fixationDuration']?.toDouble() ?? 0.0,
      largeIntrusiveSaccades: json['largeIntrusiveSaccades']?.toInt() ?? 0,
      squareWaveJerks: json['squareWaveJerks']?.toInt() ?? 0,
      saccadeLatency: json['saccadeLatency']?.toDouble() ?? 0.0,
      saccadeAccuracy: json['saccadeAccuracy']?.toDouble() ?? 0.0,
      meanSaccadesPerTrial: json['meanSaccadesPerTrial']?.toDouble() ?? 0.0,
      pursuitGain: json['pursuitGain']?.toDouble() ?? 0.0,
      proportionPursuing: json['proportionPursuing']?.toDouble() ?? 0.0,
      catchUpSaccades: json['catchUpSaccades']?.toInt() ?? 0,
      overallAccuracy: json['overallAccuracy']?.toDouble() ?? 0.0,
      taskCompletionRate: json['taskCompletionRate']?.toDouble() ?? 0.0,
    );
  }
}

class EyeTrackingFeatureExtraction {
  static const double fixationThreshold = 0.15; // Tightened from 0.25
  static const int minFramesForAnalysis = 30; // Increased from 5
  
  // Physiologically plausible ranges
  static const double minSaccadeLatency = 150.0; // ms - minimum human reaction time
  static const double maxSaccadeLatency = 800.0; // ms - maximum reasonable latency
  static const double saccadeVelocityThreshold = 0.05; // Movement threshold for saccade detection
  static const double pursuitVelocityThreshold = 0.02; // Minimum velocity for pursuit

  static EyeTrackingFeatures extractSessionFeatures(EyeTrackingSessionData session) {
    if (session.trials.isEmpty) {
      return getEmptyFeatures();
    }

    AppLogger.logger.info('=== EXTRACTING FEATURES FROM ${session.trials.length} TRIALS ===');

    final fixationTrials = session.trials.where((t) => t.taskType == 'fixation').toList();
    final prosaccadeTrials = session.trials.where((t) => t.taskType == 'prosaccade').toList();
    final pursuitTrials = session.trials.where((t) => t.taskType == 'pursuit').toList();

    AppLogger.logger.info('Fixation: ${fixationTrials.length}, Prosaccade: ${prosaccadeTrials.length}, Pursuit: ${pursuitTrials.length}');

    final fixationMetrics = _getFixationMetrics(fixationTrials);
    final prosaccadeMetrics = _getProsaccadeMetrics(prosaccadeTrials);
    final pursuitMetrics = _getSmoothPursuitMetrics(pursuitTrials);

    final overallAccuracy = _calculateOverallAccuracy(
      fixationMetrics['meanDistance'] ?? 1.0,
      prosaccadeMetrics['accuracy'] ?? 0.0,
      pursuitMetrics['pursuitGain'] ?? 0.0,
    );

    final taskCompletionRate = session.trials.where((t) => t.qualityScore > 0.5).length / session.trials.length;

    AppLogger.logger.info('=== FINAL FEATURES ===');
    AppLogger.logger.info('Fixation stability: ${(1.0 - (fixationMetrics['meanDistance'] ?? 1.0)).toStringAsFixed(3)}');
    AppLogger.logger.info('Saccade latency: ${prosaccadeMetrics['meanLatency']?.toStringAsFixed(1) ?? 0} ms');
    AppLogger.logger.info('Saccade accuracy: ${((prosaccadeMetrics['accuracy'] ?? 0.0) * 100).toStringAsFixed(1)}%');
    AppLogger.logger.info('Pursuit gain: ${pursuitMetrics['pursuitGain']?.toStringAsFixed(2) ?? 0}');
    AppLogger.logger.info('Task completion: ${(taskCompletionRate * 100).toStringAsFixed(1)}%');

    return EyeTrackingFeatures(
      fixationStability: 1.0 - (fixationMetrics['meanDistance'] ?? 1.0),
      fixationDuration: fixationMetrics['maxFixationDuration'] ?? 0.0,
      largeIntrusiveSaccades: (fixationMetrics['largeIntrusiveSaccades'] ?? 0).toInt(),
      squareWaveJerks: (fixationMetrics['squareWaveJerks'] ?? 0).toInt(),
      saccadeLatency: prosaccadeMetrics['meanLatency'] ?? 0.0,
      saccadeAccuracy: prosaccadeMetrics['accuracy'] ?? 0.0,
      meanSaccadesPerTrial: prosaccadeMetrics['meanSaccades'] ?? 0.0,
      pursuitGain: pursuitMetrics['pursuitGain'] ?? 0.0,
      proportionPursuing: pursuitMetrics['proportionPursuing'] ?? 0.0,
      catchUpSaccades: (pursuitMetrics['catchUpSaccades'] ?? 0).toInt(),
      overallAccuracy: overallAccuracy,
      taskCompletionRate: taskCompletionRate,
    );
  }

  static Map<String, dynamic> _getFixationMetrics(List<EyeTrackingTrialData> trials) {
    if (trials.isEmpty) {
      return {
        'largeIntrusiveSaccades': 0,
        'squareWaveJerks': 0,
        'maxFixationDuration': 0.0,
        'meanDistance': 0.0,
        'stdDistance': 0.0,
      };
    }

    final allFrames = <EyeTrackingFrame>[];
    for (final trial in trials) {
      allFrames.addAll(trial.frames);
    }

    if (allFrames.isEmpty) {
      return {
        'largeIntrusiveSaccades': 0,
        'squareWaveJerks': 0,
        'maxFixationDuration': 0.0,
        'meanDistance': 0.0,
        'stdDistance': 0.0,
      };
    }

    // Count large intrusive saccades (>5% screen movement)
    int largeIntrusiveSaccades = 0;
    bool inSaccade = false;
    
    for (int i = 1; i < allFrames.length; i++) {
      final movement = _calculateDistance(
        allFrames[i].eyePosition,
        allFrames[i - 1].eyePosition,
      );
      
      if (movement > 0.05 && !inSaccade) {
        largeIntrusiveSaccades++;
        inSaccade = true;
      } else if (movement < 0.02) {
        inSaccade = false;
      }
    }

    // Count square wave jerks (pairs of small saccades in opposite directions)
    int squareWaveJerks = 0;
    
    for (int i = 3; i < allFrames.length; i++) {
      final move1 = _calculateDistance(
        allFrames[i - 2].eyePosition,
        allFrames[i - 3].eyePosition,
      );
      final move2 = _calculateDistance(
        allFrames[i].eyePosition,
        allFrames[i - 1].eyePosition,
      );
      
      if (move1 > 0.015 && move1 < 0.05 && move2 > 0.015 && move2 < 0.05) {
        final timeDiff = (allFrames[i].timestamp - allFrames[i - 2].timestamp) * 1000;
        
        final dx1 = allFrames[i - 2].eyePosition.dx - allFrames[i - 3].eyePosition.dx;
        final dx2 = allFrames[i].eyePosition.dx - allFrames[i - 1].eyePosition.dx;
        final dy1 = allFrames[i - 2].eyePosition.dy - allFrames[i - 3].eyePosition.dy;
        final dy2 = allFrames[i].eyePosition.dy - allFrames[i - 1].eyePosition.dy;
        
        final dotProduct = dx1 * dx2 + dy1 * dy2;
        
        if (timeDiff > 100 && timeDiff < 500 && dotProduct < 0) {
          squareWaveJerks++;
        }
      }
    }

    // Calculate max fixation duration
    double maxFixationDuration = 0.0;
    double currentFixationDuration = 0.0;

    for (int i = 1; i < allFrames.length; i++) {
      if (allFrames[i].distance < fixationThreshold) {
        final duration = (allFrames[i].timestamp - allFrames[i - 1].timestamp) * 1000;
        currentFixationDuration += duration;
      } else {
        if (currentFixationDuration > maxFixationDuration) {
          maxFixationDuration = currentFixationDuration;
        }
        currentFixationDuration = 0.0;
      }
    }

    if (currentFixationDuration > maxFixationDuration) {
      maxFixationDuration = currentFixationDuration;
    }

    maxFixationDuration = maxFixationDuration / 1000.0; // Convert to seconds

    // Calculate mean and std of distances
    final distances = allFrames.map((f) => f.distance).toList();
    final meanDistance = distances.reduce((a, b) => a + b) / distances.length;
    final variance = distances.map((d) => pow(d - meanDistance, 2)).reduce((a, b) => a + b) / distances.length;
    final stdDistance = sqrt(variance);

    AppLogger.logger.info('Fixation: $largeIntrusiveSaccades large saccades, $squareWaveJerks SWJ, max duration: ${maxFixationDuration.toStringAsFixed(2)}s');

    return {
      'largeIntrusiveSaccades': largeIntrusiveSaccades,
      'squareWaveJerks': squareWaveJerks,
      'maxFixationDuration': maxFixationDuration,
      'meanDistance': meanDistance,
      'stdDistance': stdDistance,
      'totalDataPoints': allFrames.length,
    };
  }

  static Map<String, dynamic> _getProsaccadeMetrics(List<EyeTrackingTrialData> trials) {
    if (trials.isEmpty) {
      return {
        'accuracy': 0.0,
        'meanLatency': 0.0,
        'meanSaccades': 0.0,
      };
    }

    AppLogger.logger.info('=== PROSACCADE ANALYSIS (${trials.length} trials) ===');

    int successfulTrials = 0;
    List<double> validLatencies = [];
    List<int> saccadeCounts = [];
    const double targetThreshold = 0.25; // changed from 0.15 to 0.25
    const int minFramesForProsaccade = 15; // changed from 30
    const int minFramesAfterJump = 3;

    for (final trial in trials) {
      if (trial.frames.length < minFramesForProsaccade) {
        AppLogger.logger.info('Trial ${trial.trialNumber}: SKIPPED (only ${trial.frames.length} frames)');
        continue;
      }

      // DEBUG: Log first few frames to see target positions
      AppLogger.logger.info('=== Trial ${trial.trialNumber} DEBUG ===');
      for (int i = 0; i < min(5, trial.frames.length); i++) {
        final f = trial.frames[i];
        AppLogger.logger.info('  Frame $i: target=(${f.targetPosition.dx.toStringAsFixed(3)}, ${f.targetPosition.dy.toStringAsFixed(3)}), eye=(${f.eyePosition.dx.toStringAsFixed(3)}, ${f.eyePosition.dy.toStringAsFixed(3)}), dist=${f.distance.toStringAsFixed(3)}');
      }

        // DEBUG: Check for ANY movement in target position
      double maxTargetMovement = 0.0;
      for (int i = 1; i < trial.frames.length; i++) {
        final movement = _calculateDistance(
          trial.frames[i].targetPosition,
          trial.frames[i - 1].targetPosition,
        );
        if (movement > maxTargetMovement) {
          maxTargetMovement = movement;
          AppLogger.logger.info('  Max target movement so far: ${maxTargetMovement.toStringAsFixed(4)} at frame $i');
          AppLogger.logger.info('    From (${trial.frames[i-1].targetPosition.dx.toStringAsFixed(3)}, ${trial.frames[i-1].targetPosition.dy.toStringAsFixed(3)}) to (${trial.frames[i].targetPosition.dx.toStringAsFixed(3)}, ${trial.frames[i].targetPosition.dy.toStringAsFixed(3)})');
        }
      }
      AppLogger.logger.info('  Trial ${trial.trialNumber}: Max target movement across all frames = ${maxTargetMovement.toStringAsFixed(4)}');

      // Detect target jumps by finding large position changes
      List<int> targetJumpIndices = [0]; // Start is always a position
      double largestJump = 0.0;
      for (int i = 1; i < trial.frames.length; i++) {
        final targetMovement = _calculateDistance(
          trial.frames[i].targetPosition,
          trial.frames[i - 1].targetPosition,
        );
        if (targetMovement > largestJump) {
          largestJump = targetMovement;
        }
        if (targetMovement > 0.1) { // Target jumped
          targetJumpIndices.add(i);
        }
      }

      // Ensure every trial has a proper target jump (displacement >= 0.1)
      if (largestJump < 0.1 || targetJumpIndices.length < 2) {
        AppLogger.logger.info('Trial ${trial.trialNumber}: No proper target jump detected (largest jump=${largestJump.toStringAsFixed(3)})');
        continue;
      }

      // Analyze the segment after the first target jump (central → peripheral)
      final jumpIdx = targetJumpIndices[1];
      final peripheralTarget = trial.frames[jumpIdx].targetPosition;

      // Find frames after the jump
      final postJumpFrames = trial.frames.sublist(jumpIdx);

      if (postJumpFrames.length < minFramesAfterJump) {
        AppLogger.logger.info('Trial ${trial.trialNumber}: Not enough frames after jump (${postJumpFrames.length})');
        continue;
      }

      // Find when gaze first enters target ROI
      int? firstReachIdx;
      for (int i = 1; i < postJumpFrames.length; i++) {
        final dist = _calculateDistance(postJumpFrames[i].eyePosition, peripheralTarget);
        if (dist < targetThreshold) {
          firstReachIdx = i;
          break;
        }
      }

      if (firstReachIdx == null) {
        AppLogger.logger.info('Trial ${trial.trialNumber}: Target never reached');
        final firstFrameDist = _calculateDistance(postJumpFrames[0].eyePosition, peripheralTarget);
        if (firstFrameDist < targetThreshold) {
          AppLogger.logger.info('Trial ${trial.trialNumber}: Eye already at target (anticipatory, dist=${firstFrameDist.toStringAsFixed(3)})');
        } else {
          AppLogger.logger.info('Trial ${trial.trialNumber}: Target never reached (min dist=${firstFrameDist.toStringAsFixed(3)})');
        }
        continue;
      }

      // Calculate latency
      final latencyMs = (postJumpFrames[firstReachIdx].timestamp - postJumpFrames[0].timestamp) * 1000;

      // DEBUG: Log latency calculation
      AppLogger.logger.info('Trial ${trial.trialNumber} latency calc: firstReachIdx=$firstReachIdx, timestamps: ${postJumpFrames[0].timestamp.toStringAsFixed(3)}→${postJumpFrames[firstReachIdx].timestamp.toStringAsFixed(3)}, latency=${latencyMs.toStringAsFixed(0)}ms');

      // changed to accept latencies from 50ms to 1000ms (was 150-800ms)
      if (latencyMs < 50.0 || latencyMs > 1000.0) {
        AppLogger.logger.info('Trial ${trial.trialNumber}: Latency ${latencyMs.toStringAsFixed(0)}ms out of range (100-1000ms)');
        continue;
      }

      // Count saccades (rapid movements) in the post-jump period
      int saccadeCount = 0;
      bool inSaccade = false;
      
      for (int i = 1; i < postJumpFrames.length && i <= firstReachIdx + 5; i++) {
        final movement = _calculateDistance(
          postJumpFrames[i].eyePosition,
          postJumpFrames[i - 1].eyePosition,
        );
        
        if (movement > saccadeVelocityThreshold && !inSaccade) {
          saccadeCount++;
          inSaccade = true;
        } else if (movement < 0.01) {
          inSaccade = false;
        }
      }

      successfulTrials++;
      validLatencies.add(latencyMs);
      saccadeCounts.add(saccadeCount);

      AppLogger.logger.info('Trial ${trial.trialNumber}: ✓ latency=${latencyMs.toStringAsFixed(0)}ms, saccades=$saccadeCount');
    }

    final accuracy = trials.isNotEmpty ? successfulTrials / trials.length : 0.0;
    final meanLatency = validLatencies.isNotEmpty 
        ? validLatencies.reduce((a, b) => a + b) / validLatencies.length 
        : 0.0;
    final meanSaccades = saccadeCounts.isNotEmpty
        ? saccadeCounts.reduce((a, b) => a + b) / saccadeCounts.length
        : 0.0;

    AppLogger.logger.info('PROSACCADE SUMMARY: $successfulTrials/${trials.length} valid (${(accuracy * 100).toStringAsFixed(1)}%)');
    AppLogger.logger.info('Mean latency: ${meanLatency.toStringAsFixed(1)}ms, Mean saccades: ${meanSaccades.toStringAsFixed(1)}');

    return {
      'accuracy': accuracy,
      'meanLatency': meanLatency,
      'meanSaccades': meanSaccades,
      'totalTrials': trials.length,
      'successfulTrials': successfulTrials,
    };
  }

  static Map<String, dynamic> _getSmoothPursuitMetrics(List<EyeTrackingTrialData> trials) {
    if (trials.isEmpty) {
      return {
        'pursuitGain': 0.0,
        'proportionPursuing': 0.0,
        'catchUpSaccades': 0,
      };
    }

    AppLogger.logger.info('=== SMOOTH PURSUIT ANALYSIS (${trials.length} trials) ===');

    List<double> gainSamples = [];
    int pursuingFrames = 0;
    int totalFrames = 0;
    int catchUpSaccades = 0;

    for (final trial in trials) {
      if (trial.frames.length < minFramesForAnalysis) {
        AppLogger.logger.info('Trial ${trial.trialNumber}: SKIPPED (only ${trial.frames.length} frames)');
        continue;
      }

      int trialPursuingFrames = 0;
      int trialTotalFrames = 0;
      List<double> trialGains = [];

      // Analyze frame-by-frame pursuit
      for (int i = 2; i < trial.frames.length; i++) {
        final dt = trial.frames[i].timestamp - trial.frames[i - 1].timestamp;
        if (dt <= 0 || dt > 0.1) continue; // Skip invalid frames

        trialTotalFrames++;
        totalFrames++;

        // Calculate velocities using 2-frame averaging for stability
        final targetDx1 = trial.frames[i].targetPosition.dx - trial.frames[i - 1].targetPosition.dx;
        final targetDy1 = trial.frames[i].targetPosition.dy - trial.frames[i - 1].targetPosition.dy;
        final targetDx2 = trial.frames[i - 1].targetPosition.dx - trial.frames[i - 2].targetPosition.dx;
        final targetDy2 = trial.frames[i - 1].targetPosition.dy - trial.frames[i - 2].targetPosition.dy;
        
        final targetVelX = (targetDx1 + targetDx2) / (2 * dt);
        final targetVelY = (targetDy1 + targetDy2) / (2 * dt);
        final targetSpeed = sqrt(targetVelX * targetVelX + targetVelY * targetVelY);

        final eyeDx1 = trial.frames[i].eyePosition.dx - trial.frames[i - 1].eyePosition.dx;
        final eyeDy1 = trial.frames[i].eyePosition.dy - trial.frames[i - 1].eyePosition.dy;
        final eyeDx2 = trial.frames[i - 1].eyePosition.dx - trial.frames[i - 2].eyePosition.dx;
        final eyeDy2 = trial.frames[i - 1].eyePosition.dy - trial.frames[i - 2].eyePosition.dy;
        
        final eyeVelX = (eyeDx1 + eyeDx2) / (2 * dt);
        final eyeVelY = (eyeDy1 + eyeDy2) / (2 * dt);
        final eyeSpeed = sqrt(eyeVelX * eyeVelX + eyeVelY * eyeVelY);

        // Calculate pursuit gain when target is moving
        if (targetSpeed > pursuitVelocityThreshold) {
          final gain = eyeSpeed / targetSpeed;
          
          // Only accept physiologically plausible gains
          if (gain > 0.1 && gain < 2.0) {
            gainSamples.add(gain);
            trialGains.add(gain);
          }

          // Check if actively pursuing: eye moving in same direction as target AND close to target
          final dotProduct = eyeVelX * targetVelX + eyeVelY * targetVelY;
          final directionMatch = dotProduct > 0; // Moving in same direction
          final closeToTarget = trial.frames[i].distance < 0.30;
          final eyeMoving = eyeSpeed > (pursuitVelocityThreshold * 1.5);

          if (directionMatch && closeToTarget && eyeMoving) {
            pursuingFrames++;
            trialPursuingFrames++;
          }
        }

        // Detect catch-up saccades: fast movement while far from target
        final rapidMovement = _calculateDistance(
          trial.frames[i].eyePosition,
          trial.frames[i - 1].eyePosition,
        );
        
        if (rapidMovement > 0.04 && trial.frames[i].distance > 0.15) {
          catchUpSaccades++;
        }
      }

      if (trialGains.isNotEmpty && trialTotalFrames > 0) {
        final trialMeanGain = trialGains.reduce((a, b) => a + b) / trialGains.length;
        final trialPursuitProp = trialPursuingFrames / trialTotalFrames;
        AppLogger.logger.info('Trial ${trial.trialNumber}: gain=${trialMeanGain.toStringAsFixed(2)}, pursuing=${(trialPursuitProp * 100).toStringAsFixed(1)}%');
      }
    }

    final pursuitGain = gainSamples.isNotEmpty 
        ? gainSamples.reduce((a, b) => a + b) / gainSamples.length 
        : 0.0;
    final proportionPursuing = totalFrames > 0 
        ? pursuingFrames / totalFrames 
        : 0.0;

    AppLogger.logger.info('PURSUIT SUMMARY: gain=${pursuitGain.toStringAsFixed(2)}, pursuing=${(proportionPursuing * 100).toStringAsFixed(1)}%, catch-up=$catchUpSaccades');
    AppLogger.logger.info('Total frames analyzed: $totalFrames, gain samples: ${gainSamples.length}');

    return {
      'pursuitGain': pursuitGain,
      'proportionPursuing': proportionPursuing,
      'catchUpSaccades': catchUpSaccades,
      'totalDataPoints': totalFrames,
    };
  }

  static double _calculateDistance(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return sqrt(dx * dx + dy * dy);
  }

  static double _calculateOverallAccuracy(double fixationDistance, double prosaccadeAccuracy, double pursuitGain) {
    final fixationScore = max(0.0, 1.0 - fixationDistance);
    final pursuitScore = min(pursuitGain, 1.0); // Cap at 1.0
    return (fixationScore + prosaccadeAccuracy + pursuitScore) / 3.0;
  }

  static EyeTrackingFeatures getEmptyFeatures() {
    return EyeTrackingFeatures(
      fixationStability: 0.0,
      fixationDuration: 0.0,
      largeIntrusiveSaccades: 0,
      squareWaveJerks: 0,
      saccadeLatency: 0.0,
      saccadeAccuracy: 0.0,
      meanSaccadesPerTrial: 0.0,
      pursuitGain: 0.0,
      proportionPursuing: 0.0,
      catchUpSaccades: 0,
      overallAccuracy: 0.0,
      taskCompletionRate: 0.0,
    );
  }
}