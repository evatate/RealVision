import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

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
  final double fixationStability; // RMS error during fixation task (0-1, higher is better)
  final double fixationDuration; // max time maintaining fixation (seconds)
  final int largeIntrusiveSaccades; // count of large unwanted saccades during fixation
  final int squareWaveJerks; // count of square wave jerks during fixation

  // Saccade metrics (pro-saccade task)
  final double saccadeLatency; // average reaction time to target jump (ms)
  final double saccadeAccuracy; // success rate reaching targets (0-1)
  final double meanSaccadesPerTrial; // average number of saccades per trial

  // Smooth pursuit metrics
  final double pursuitGain; // ratio of eye velocity to target velocity
  final double proportionPursuing; // proportion of time actively pursuing (0-1)
  final int catchUpSaccades; // count of corrective saccades during pursuit

  // Overall performance
  final double overallAccuracy; // combined accuracy across all tasks (0-1)
  final double taskCompletionRate; // percentage of trials completed successfully (0-1)

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
  static const double FIXATION_THRESHOLD = 0.25;
  static const int MIN_FRAMES_FOR_ANALYSIS = 5;

  /// Extract aggregate features across all trials - THIS IS THE MAIN METHOD
  static EyeTrackingFeatures extractSessionFeatures(EyeTrackingSessionData session) {
    if (session.trials.isEmpty) {
      return getEmptyFeatures();
    }

    AppLogger.logger.info('DEBUG: Extracting features from ${session.trials.length} trials');

    // Separate trials by task type
    final fixationTrials = session.trials.where((t) => t.taskType == 'fixation').toList();
    final prosaccadeTrials = session.trials.where((t) => t.taskType == 'prosaccade').toList();
    final pursuitTrials = session.trials.where((t) => t.taskType == 'pursuit').toList();

    AppLogger.logger.info('DEBUG: Fixation trials: ${fixationTrials.length}');
    AppLogger.logger.info('DEBUG: Prosaccade trials: ${prosaccadeTrials.length}');
    AppLogger.logger.info('DEBUG: Pursuit trials: ${pursuitTrials.length}');

    // Extract metrics using the WORKING methods from original code
    final fixationMetrics = _getFixationMetrics(fixationTrials);
    final prosaccadeMetrics = _getProsaccadeMetrics(prosaccadeTrials);
    final pursuitMetrics = _getSmoothPursuitMetrics(pursuitTrials);

    AppLogger.logger.info('DEBUG: Fixation metrics: $fixationMetrics');
    AppLogger.logger.info('DEBUG: Prosaccade metrics: $prosaccadeMetrics');
    AppLogger.logger.info('DEBUG: Pursuit metrics: $pursuitMetrics');

    // Calculate overall metrics
    final overallAccuracy = _calculateOverallAccuracy(
      fixationMetrics['meanDistance'] ?? 1.0,
      prosaccadeMetrics['accuracy'] ?? 0.0,
      pursuitMetrics['pursuitGain'] ?? 0.0,
    );

    final taskCompletionRate = session.trials.where((t) => t.qualityScore > 0.5).length / session.trials.length;

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

    // Combine all frames from all fixation trials
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

    // Count large intrusive saccades (movements > 5% of screen during fixation)
    // Only count distinct saccades, not every frame of a saccade
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
        inSaccade = false; // Reset when movement is small
      }
    }

    // Count square wave jerks, pairs of small saccades in opposite directions
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
      
      // Both movements should be small saccades
      if (move1 > 0.015 && move1 < 0.05 && move2 > 0.015 && move2 < 0.05) {
        final timeDiff = (allFrames[i].timestamp - allFrames[i - 2].timestamp) * 1000;
        
        // Check if they're in roughly opposite directions
        final dx1 = allFrames[i - 2].eyePosition.dx - allFrames[i - 3].eyePosition.dx;
        final dx2 = allFrames[i].eyePosition.dx - allFrames[i - 1].eyePosition.dx;
        final dy1 = allFrames[i - 2].eyePosition.dy - allFrames[i - 3].eyePosition.dy;
        final dy2 = allFrames[i].eyePosition.dy - allFrames[i - 1].eyePosition.dy;
        
        // Dot product < 0 means opposite directions
        final dotProduct = dx1 * dx2 + dy1 * dy2;
        
        if (timeDiff > 100 && timeDiff < 500 && dotProduct < 0) {
          squareWaveJerks++;
        }
      }
    }

    // Calculate max fixation duration
    double maxFixationDuration = 0.0;
    double currentFixationDuration = 0.0;
    const fixationThreshold = FIXATION_THRESHOLD;

    for (int i = 1; i < allFrames.length; i++) {
      if (allFrames[i].distance < fixationThreshold) {
        final duration = (allFrames[i].timestamp - allFrames[i - 1].timestamp) * 1000; // ms
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

    // Convert to seconds
    maxFixationDuration = maxFixationDuration / 1000.0;

    // Calculate mean and std of distances
    final distances = allFrames.map((f) => f.distance).toList();
    final meanDistance = distances.reduce((a, b) => a + b) / distances.length;
    final variance = distances.map((d) => pow(d - meanDistance, 2)).reduce((a, b) => a + b) / distances.length;
    final stdDistance = sqrt(variance);

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

    int successfulTrials = 0;
    double totalLatency = 0.0;
    double totalSaccades = 0.0;

    const double TARGET_THRESHOLD = 0.15;

    for (final trial in trials) {
      if (trial.frames.isEmpty) continue;

      // Group frames into continuous segments based on target position
      List<List<EyeTrackingFrame>> segments = [];
      List<EyeTrackingFrame> currentSegment = [trial.frames[0]];
      Offset lastTargetPos = trial.frames[0].targetPosition;

      for (int i = 1; i < trial.frames.length; i++) {
        final currentTargetPos = trial.frames[i].targetPosition;
        final targetMoved = _calculateDistance(currentTargetPos, lastTargetPos) > 0.05;
        
        if (targetMoved) {
          segments.add(currentSegment);
          currentSegment = [trial.frames[i]];
          lastTargetPos = currentTargetPos;
        } else {
          currentSegment.add(trial.frames[i]);
        }
      }
      if (currentSegment.isNotEmpty) segments.add(currentSegment);

      // Find the peripheral target segment
      List<EyeTrackingFrame>? peripheralSegment;
      for (var segment in segments) {
        if (segment.isEmpty) continue;
        final targetPos = segment.first.targetPosition;
        final distFromCenter = _calculateDistance(targetPos, const Offset(0.5, 0.5));
        if (distFromCenter > 0.1) {
          peripheralSegment = segment;
          break;
        }
      }

      if (peripheralSegment == null || peripheralSegment.isEmpty) continue;

      // Check if gaze reached target
      final reachedFrames = peripheralSegment.where((f) => f.distance < TARGET_THRESHOLD).toList();
      
      if (reachedFrames.isNotEmpty) {
        successfulTrials++;

        // Calculate latency: time from first frame of peripheral segment to first reach
        final targetOnset = peripheralSegment.first.timestamp;
        final firstReach = reachedFrames.first.timestamp;
        final latency = (firstReach - targetOnset) * 1000; // ms

        // Only count realistic latencies
        if (latency >= 150 && latency < 800) {
          totalLatency += latency;
        }

        // Count saccades in peripheral segment
        int saccades = 0;
        for (int i = 1; i < peripheralSegment.length; i++) {
          final movement = _calculateDistance(
            peripheralSegment[i].eyePosition,
            peripheralSegment[i - 1].eyePosition,
          );
          if (movement > 0.03) {
            saccades++;
          }
        }
        totalSaccades += saccades;
      }
    }

    final accuracy = trials.isNotEmpty ? successfulTrials / trials.length : 0.0;
    final meanLatency = successfulTrials > 0 ? totalLatency / successfulTrials : 0.0;
    final meanSaccades = successfulTrials > 0 ? totalSaccades / successfulTrials : 0.0;

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

    double totalGain = 0.0;
    int gainSamples = 0;
    int pursuingCount = 0;
    int catchUpSaccades = 0;
    int totalSamples = 0;

    AppLogger.logger.info('=== PURSUIT METRICS WITH DEBUG ===');
    
    for (final trial in trials) {
      if (trial.frames.length < MIN_FRAMES_FOR_ANALYSIS) continue;

      // DEBUG: Check target movement for first trial
      if (trial.trialNumber == 1) {
        AppLogger.logger.info('Trial 1 analysis:');
        final totalTime = trial.frames.last.timestamp - trial.frames.first.timestamp;
        double totalTargetMovement = 0;
        double totalEyeMovement = 0;
        
        for (int i = 1; i < trial.frames.length; i++) {
          totalTargetMovement += _calculateDistance(
            trial.frames[i].targetPosition,
            trial.frames[i - 1].targetPosition,
          );
          totalEyeMovement += _calculateDistance(
            trial.frames[i].eyePosition,
            trial.frames[i - 1].eyePosition,
          );
        }
        
        AppLogger.logger.info('  Total time: ${totalTime.toStringAsFixed(2)}s');
        AppLogger.logger.info('  Target moved: ${totalTargetMovement.toStringAsFixed(3)} units');
        AppLogger.logger.info('  Eye moved: ${totalEyeMovement.toStringAsFixed(3)} units');
        AppLogger.logger.info('  Avg target velocity: ${(totalTargetMovement / totalTime).toStringAsFixed(4)} units/s');
        AppLogger.logger.info('  Avg eye velocity: ${(totalEyeMovement / totalTime).toStringAsFixed(4)} units/s');
        AppLogger.logger.info('  Raw gain estimate: ${(totalEyeMovement / totalTargetMovement).toStringAsFixed(3)}');
        
        // Check frame timing
        List<double> timeDiffs = [];
        for (int i = 1; i < min(20, trial.frames.length); i++) {
          timeDiffs.add(trial.frames[i].timestamp - trial.frames[i - 1].timestamp);
        }
        final avgTime = timeDiffs.reduce((a, b) => a + b) / timeDiffs.length;
        final maxTime = timeDiffs.reduce(max);
        final minTime = timeDiffs.reduce(min);
        debugPrint('  Frame timing: avg=${(avgTime * 1000).toStringAsFixed(1)}ms, min=${(minTime * 1000).toStringAsFixed(1)}ms, max=${(maxTime * 1000).toStringAsFixed(1)}ms');
        
        // Sample some individual frames
        debugPrint('  First 5 frames:');
        for (int i = 0; i < min(5, trial.frames.length); i++) {
          final f = trial.frames[i];
          debugPrint('    [$i] t=${f.timestamp.toStringAsFixed(2)}s, target=(${f.targetPosition.dx.toStringAsFixed(3)}, ${f.targetPosition.dy.toStringAsFixed(3)}), eye=(${f.eyePosition.dx.toStringAsFixed(3)}, ${f.eyePosition.dy.toStringAsFixed(3)}), dist=${f.distance.toStringAsFixed(3)}');
        }
      }

      int trialGainSamples = 0;
      int trialPursuingSamples = 0;
      List<double> trialGains = [];
      
      for (int i = 2; i < trial.frames.length; i++) {
        final timeDiff = trial.frames[i].timestamp - trial.frames[i - 1].timestamp;
        if (timeDiff <= 0 || timeDiff > 0.1) continue;

        totalSamples++;

        // Calculate target velocity from frame-to-frame movement
        final targetMovement1 = _calculateDistance(
          trial.frames[i].targetPosition,
          trial.frames[i - 1].targetPosition,
        );
        final targetMovement2 = _calculateDistance(
          trial.frames[i - 1].targetPosition,
          trial.frames[i - 2].targetPosition,
        );
        final targetVelocity = (targetMovement1 + targetMovement2) / (2 * timeDiff);

        // Calculate eye velocity
        final eyeMovement1 = _calculateDistance(
          trial.frames[i].eyePosition,
          trial.frames[i - 1].eyePosition,
        );
        final eyeMovement2 = _calculateDistance(
          trial.frames[i - 1].eyePosition,
          trial.frames[i - 2].eyePosition,
        );
        final eyeVelocity = (eyeMovement1 + eyeMovement2) / (2 * timeDiff);

        // Debug first trial samples
        if (trial.trialNumber == 1 && i >= 10 && i < 15) {
          debugPrint('  Sample $i: eyeVel=${eyeVelocity.toStringAsFixed(4)}, targetVel=${targetVelocity.toStringAsFixed(4)}, gain=${(eyeVelocity / targetVelocity).toStringAsFixed(3)}, dist=${trial.frames[i].distance.toStringAsFixed(3)}');
        }

        if (targetVelocity > 0.01) {
          final gain = eyeVelocity / targetVelocity;

          if (gain > 0.05 && gain < 3.0) {
            totalGain += gain;
            gainSamples++;
            trialGainSamples++;
            trialGains.add(gain);
          }

          // More lenient: 10% of target velocity and distance < 0.3
          if (eyeVelocity > 0.1 * targetVelocity && trial.frames[i].distance < 0.3) {
            pursuingCount++;
            trialPursuingSamples++;
          }
        }

        // Detect catch-up saccades
        final eyeMovement = _calculateDistance(
          trial.frames[i].eyePosition,
          trial.frames[i - 1].eyePosition,
        );
        if (eyeMovement > 0.03 && trial.frames[i].distance > 0.1) {
          catchUpSaccades++;
        }
      }

      if (trial.trialNumber == 1 && trialGains.isNotEmpty) {
        final avgGain = trialGains.reduce((a, b) => a + b) / trialGains.length;
        final sortedGains = List<double>.from(trialGains)..sort();
        final medianGain = sortedGains[sortedGains.length ~/ 2];
        debugPrint('  Trial 1 gain stats: avg=${avgGain.toStringAsFixed(3)}, median=${medianGain.toStringAsFixed(3)}, samples=$trialGainSamples');
        debugPrint('  Trial 1 pursuing: $trialPursuingSamples/${trial.frames.length - 2} (${(trialPursuingSamples / (trial.frames.length - 2) * 100).toStringAsFixed(1)}%)');
      }
    }

    final pursuitGain = gainSamples > 0 ? totalGain / gainSamples : 0.0;
    final proportionPursuing = totalSamples > 0 ? pursuingCount / totalSamples : 0.0;

    debugPrint('FINAL: gain=$pursuitGain, pursuing=$proportionPursuing (${(proportionPursuing * 100).toStringAsFixed(1)}%)');
    debugPrint('Total samples: $totalSamples, gain samples: $gainSamples, pursuing samples: $pursuingCount');

    return {
      'pursuitGain': pursuitGain,
      'proportionPursuing': proportionPursuing,
      'catchUpSaccades': catchUpSaccades,
      'totalDataPoints': totalSamples,
    };
  }

  static double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return variance;
  }

  static double _calculateDistance(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return sqrt(dx * dx + dy * dy);
  }

  static double _calculateOverallAccuracy(double fixationDistance, double prosaccadeAccuracy, double pursuitGain) {
    final fixationScore = max(0.0, 1.0 - fixationDistance);
    return (fixationScore + prosaccadeAccuracy + pursuitGain) / 3.0;
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