import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../models/test_progress.dart';
import '../services/camera_service.dart';
import '../services/audio_service.dart';
import '../services/face_detection_service.dart';
import '../services/eye_tracking_service.dart';
import '../models/eye_tracking_data.dart';
import '../services/data_export_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../widgets/breadcrumb.dart';
import '../utils/logger.dart';
import 'dart:async';
import 'dart:math';
import '../services/service_locator.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'eye_tracking_results_screen.dart';

enum EyeTrackingTask { none, fixation, prosaccade, pursuit, driftCorrection }

class EyeTrackingScreen extends StatefulWidget {
  const EyeTrackingScreen({super.key});

  @override
  State<EyeTrackingScreen> createState() => _EyeTrackingScreenState();
}

class _EyeTrackingScreenState extends State<EyeTrackingScreen> {
    int _getCurrentTrialNumber() {
      switch (_currentTask) {
        case EyeTrackingTask.fixation:
          return _fixationTrialNumber;
        case EyeTrackingTask.prosaccade:
          return _isPractice ? _trialIndex : _completedTrials;
        case EyeTrackingTask.pursuit:
          return _pursuitTrialNumber;
        default:
          return 0;
      }
    }
  late CameraService _cameraService = CameraService();
  late AudioService _audioService = AudioService();
  final EyeTrackingService _eyeTrackingService = EyeTrackingService();
  final FaceDetectionService _faceDetector = FaceDetectionService();
  
  String? _participantId;

  EyeTrackingTask _currentTask = EyeTrackingTask.none;
  int _trialIndex = 0;
  int _completedTrials = 0;
  int _fixationTrialNumber = 0;
  int _pursuitTrialNumber = 0;
  bool _isPractice = false;
  Offset? _targetPosition;
  Timer? _taskTimer;
  bool _cameraInitialized = false;
  bool _showTarget = true;
  Timer? _eyeTrackingTimer;
  bool _isFaceDetected = false;
  bool _isDriftCorrecting = false;
  List<int> _prosaccadeSequence = [];
  int _prosaccadeIndex = 0;
  List<EyeTrackingTrialData> _trials = [];
  Size _screenSize = Size.zero;
  bool _isProcessingFrame = false;

  @override
  void initState() {
    super.initState();
    _cameraService = getIt<CameraService>();
    _audioService = getIt<AudioService>();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _audioService.initialize();
      await _cameraService.initialize();
      if (mounted) {
        setState(() => _cameraInitialized = true);
      }
    } catch (e) {
      AppLogger.logger.severe('Service init error: $e');
    }
  }

  @override
  void dispose() {
    _eyeTrackingService.setAssessmentActive(false);
    _faceDetector.setAssessmentActive(false);
    _taskTimer?.cancel();
    _eyeTrackingTimer?.cancel();
    _stopEyeTracking();
    _cameraService.dispose();
    _audioService.dispose();
    _eyeTrackingService.dispose();
    _faceDetector.dispose();
    super.dispose();
  }

  void _generateProsaccadeSequence() {
    final positions = [0, 1, 2, 3, 4, 5, 6, 7];
    final random = Random();
    _prosaccadeSequence = [];
    
    int lastPosition = -1;
    for (int i = 0; i < 40; i++) {
      List<int> available = positions.where((p) => p != lastPosition).toList();
      final selected = available[random.nextInt(available.length)];
      _prosaccadeSequence.add(selected);
      lastPosition = selected;
    }
    _prosaccadeIndex = 0;
  }

  Offset _getProsaccadePosition(int index) {
    const double distance = 0.17;
    const positions = [
      Offset(0.5 - distance, 0.5),
      Offset(0.5 + distance, 0.5),
      Offset(0.5, 0.5 - distance),
      Offset(0.5, 0.5 + distance),
      Offset(0.5 - distance * 0.707, 0.5 - distance * 0.707),
      Offset(0.5 + distance * 0.707, 0.5 - distance * 0.707),
      Offset(0.5 - distance * 0.707, 0.5 + distance * 0.707),
      Offset(0.5 + distance * 0.707, 0.5 + distance * 0.707),
    ];
    return positions[index];
  }

  Future<void> _performDriftCorrection() async {
    final originalTask = _currentTask;
    
    if (!mounted) return;
    setState(() {
      _isDriftCorrecting = true;
      _currentTask = EyeTrackingTask.driftCorrection;
      _targetPosition = const Offset(0.5, 0.5);
      _showTarget = true;
    });
    
    await _audioService.speak('Look at the center cross');
    
    _eyeTrackingService.startDriftCorrection();
    await Future.delayed(const Duration(seconds: 3));
    _eyeTrackingService.finalizeDriftCorrection();
    
    if (!mounted) return;
    setState(() {
      _isDriftCorrecting = false;
      _currentTask = originalTask;
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
  }

bool _checkTrialQuality(List<EyeTrackingFrame> trialData) {
    if (_currentTask == EyeTrackingTask.fixation && trialData.length < 30) {
      AppLogger.logger.warning('Fixation trial rejected: only ${trialData.length} frames (need 30+)');
      return false;
    }

    if (_currentTask == EyeTrackingTask.prosaccade && trialData.length < 15) {
      AppLogger.logger.warning('Prosaccade trial rejected: only ${trialData.length} frames (need 15+)');
      return false;
    }

    if (_currentTask == EyeTrackingTask.pursuit && trialData.length < 20) {
      AppLogger.logger.warning('Pursuit trial rejected: only ${trialData.length} frames (need 20+)');
      return false;
    }

    int largeGaps = 0;
    for (int i = 1; i < trialData.length; i++) {
      final gap = trialData[i].timestamp - trialData[i - 1].timestamp;
      if (gap > 0.4) largeGaps++;
    }
    final gapRate = trialData.length > 1 ? largeGaps / (trialData.length - 1) : 0.0;
    final maxGapRate = _currentTask == EyeTrackingTask.pursuit ? 0.6 : 0.4;
    
    if (gapRate > maxGapRate) {
      AppLogger.logger.warning('Trial rejected: too many gaps (${(gapRate * 100).toStringAsFixed(1)}%)');
      return false;
    }

    if (_currentTask == EyeTrackingTask.pursuit) {
      return true;
    }

    final meanDistance = trialData.map((p) => p.distance).reduce((a, b) => a + b) / trialData.length;

    double threshold;
    switch (_currentTask) {
      case EyeTrackingTask.fixation:
        threshold = 0.30;
        break;
      case EyeTrackingTask.prosaccade:
        threshold = 0.50;
        break;
      default:
        threshold = 0.35;
    }

    if (meanDistance > threshold) {
      AppLogger.logger.warning('Trial rejected: mean distance ${meanDistance.toStringAsFixed(3)} > $threshold');
      return false;
    }

    return true;
  }

  void _showTestCompletionDialog(String title, String testType) {
    _audioService.speak(testType == 'all' ? 'All eye tracking tests finished!' : '$testType test complete');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 24,
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Great! Remember: Complete all 3 tests.',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (testType == 'fixation') {
                  _startProsaccadeTest();
                } else if (testType == 'prosaccade') {
                  _startSmoothPursuitTest();
                } else if (testType == 'all') {
                  final features = EyeTrackingFeatureExtraction.extractSessionFeatures(
                    EyeTrackingSessionData(
                      participantId: _participantId!,
                      sessionId: 'temp',
                      timestamp: DateTime.now(),
                      trials: _trials,
                      features: EyeTrackingFeatureExtraction.getEmptyFeatures(),
                    ),
                  );
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const EyeTrackingResultsScreen(),
                      settings: RouteSettings(arguments: EyeTrackingSessionData(
                        participantId: _participantId!,
                        sessionId: 'eye_tracking_${DateTime.now().millisecondsSinceEpoch}',
                        timestamp: DateTime.now(),
                        trials: _trials,
                        features: features,
                      )),
                    ),
                  );
                } else {
                  setState(() {
                    _currentTask = EyeTrackingTask.none;
                    _fixationTrialNumber = 0;
                    _pursuitTrialNumber = 0;
                    _trialIndex = 0;
                    _completedTrials = 0;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.all(16),
              ),
              child: Text(
                testType == 'all' ? 'View Results' : 'Continue with Next Test',
                style: TextStyle(fontSize: 18, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _currentTask = EyeTrackingTask.none;
                  _fixationTrialNumber = 0;
                  _pursuitTrialNumber = 0;
                  _trialIndex = 0;
                  _completedTrials = 0;
                });
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary, width: 2),
                padding: EdgeInsets.all(16),
              ),
              child: Text(
                'Return to Eye Tracking Tests',
                style: TextStyle(fontSize: 18, color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInstructions(String title, String instruction, String trialInfo, VoidCallback onStart) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              instruction,
              style: const TextStyle(
                fontSize: 22,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[300]!, width: 2),
              ),
              child: Text(
                trialInfo,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.blue[900],
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[300]!, width: 2),
              ),
              child: Text(
                'Keep your head still and move only your eyes',
                style: TextStyle(
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  color: const Color.fromARGB(255, 0, 0, 0),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onStart();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text(
                'Start',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
Future<void> _startFixationTest() async {
    _participantId ??= 'participant_${DateTime.now().millisecondsSinceEpoch}';
    _trials = [];

    _showInstructions(
      'Fixation Stability Test',
      'Look closely at the red cross without blinking for 10 seconds per trial',
      'Practice + 3 test trials',
      () async {
        try {
          if (!mounted) return;

          // Audio instruction for all tests
          await _audioService.speak('Keep your head still and move only your eyes');
          await Future.delayed(const Duration(milliseconds: 500));

          setState(() {
            _currentTask = EyeTrackingTask.fixation;
            _isPractice = true;
            _fixationTrialNumber = 0;
            _showTarget = true;
            _targetPosition = const Offset(0.5, 0.5);
          });

          _startEyeTracking();

          await _audioService.speak('Practice trial. Look at the red cross.');
          await _performDriftCorrection();
          _runFixationTrial();
        } catch (e) {
          AppLogger.logger.severe('Camera error: $e');
        }
      },
    );
  }

  void _stopEyeTracking() {
    _eyeTrackingService.setAssessmentActive(false);
    _faceDetector.setAssessmentActive(false);
    _eyeTrackingTimer?.cancel();
    try {
      final controller = _cameraService.controller;
      if (controller != null && controller.value.isInitialized && !controller.value.isRecordingVideo && controller.value.isStreamingImages && mounted) {
        _cameraService.stopImageStream();
      }
    } catch (e) {
      AppLogger.logger.warning('Error stopping camera stream: $e');
    }
    _isProcessingFrame = false;
  }

  void _startEyeTracking() {
    _eyeTrackingService.setAssessmentActive(true);
    _faceDetector.setAssessmentActive(true);

    try {
      final controller = _cameraService.controller;
      if (controller != null && controller.value.isInitialized && !controller.value.isRecordingVideo && !controller.value.isStreamingImages && mounted) {
        _cameraService.startImageStream((CameraImage image, InputImageRotation rotation) async {
          if (!mounted || _targetPosition == null || _isProcessingFrame) return;

          _isProcessingFrame = true;

          try {
            final faceResult = await _faceDetector.detectFace(image, rotation);
            final faceDetected = faceResult.faceDetected;

            if (mounted) {
              setState(() => _isFaceDetected = faceDetected);
            }

            if (faceDetected) {
              await _eyeTrackingService.trackGaze(image, _targetPosition!, _screenSize, rotation);
            }
          } finally {
            _isProcessingFrame = false;
          }
        });
      }
    } catch (e) {
      AppLogger.logger.warning('Error starting camera stream: $e');
    }
  }

  void _runFixationTrial() {
    final maxTrials = _isPractice 
        ? AppConstants.fixationPracticeTrials 
        : AppConstants.fixationTestTrials;
    
    if (_fixationTrialNumber >= maxTrials) {
      if (_isPractice) {
        setState(() {
          _isPractice = false;
          _fixationTrialNumber = 0;
        });
        _audioService.speak('Practice complete. Starting test trials. Trial 1 of ${AppConstants.fixationTestTrials}');
        Future.delayed(const Duration(seconds: 2), () async {
          await _performDriftCorrection();
          _runFixationTrial();
        });
      } else {
        _completeFixationTest();
      }
      return;
    }

    _fixationTrialNumber++;
    _eyeTrackingService.clearData();
    _eyeTrackingService.setTaskType('fixation');
    _eyeTrackingService.startTrial();
    setState(() => _targetPosition = const Offset(0.5, 0.5));
    
    _taskTimer = Timer(Duration(seconds: AppConstants.fixationDuration), () {
      final trialResult = _eyeTrackingService.completeTrial();
      final qualityOk = _checkTrialQuality(trialResult.frames);

      if (!qualityOk && !_isPractice) {
        _audioService.speak('Trial quality low. Repeating trial.');
        _fixationTrialNumber--;
        _eyeTrackingService.clearData();
        Future.delayed(const Duration(seconds: 2), () async {
          await _performDriftCorrection();
          _runFixationTrial();
        });
        return;
      }

      if (qualityOk && !_isPractice) {
        final updatedTrial = EyeTrackingTrialData(
          trialNumber: _trials.length + 1,
          taskType: 'fixation',
          frames: trialResult.frames,
          qualityScore: trialResult.qualityScore,
        );
        _trials.add(updatedTrial);
        AppLogger.logger.info('Added fixation trial ${_trials.length} with ${trialResult.frames.length} frames');
      }
      
      if (_fixationTrialNumber < maxTrials) {
        final label = _isPractice ? 'practice' : 'test';
        _audioService.speak('Next $label trial');
        Future.delayed(const Duration(seconds: 2), () async {
          await _performDriftCorrection();
          _runFixationTrial();
        });
      } else {
        _runFixationTrial();
      }
    });
  }

  void _completeFixationTest() {
    _stopEyeTracking();
    _eyeTrackingService.clearData();

    Provider.of<TestProgress>(context, listen: false).markFixationCompleted();

    AppLogger.logger.info('Fixation test complete. Total trials collected: ${_trials.length}');

    _showTestCompletionDialog('Fixation Stability Test Complete!', 'fixation');
  }

  Future<void> _startProsaccadeTest() async {
    _showInstructions(
      'Pro-saccade Test',
      'Look at the target circle as quickly as possible when it appears',
      'Practice + 30 test trials',
      () async {
        try {
          if (!mounted) return;

          // Audio instruction for all tests
          await _audioService.speak('Keep your head still and move only your eyes');

          _generateProsaccadeSequence();

          setState(() {
            _currentTask = EyeTrackingTask.prosaccade;
            _isPractice = true;
            _trialIndex = 0;
            _completedTrials = 0;
          });

          _startEyeTracking();

          await _audioService.speak('Practice trials. Look at targets quickly.');
          await _performDriftCorrection();
          _runProsaccadeTrial();
        } catch (e) {
          AppLogger.logger.severe('Camera error: $e');
        }
      },
    );
  }

  void _runProsaccadeTrial() {
    final maxTrials = _isPractice
        ? AppConstants.prosaccadePracticeTrials
        : AppConstants.prosaccadeTestTrials;

    final int trialToken = _trialIndex;

    if (_isPractice && _trialIndex >= maxTrials) {
      AppLogger.logger.info('Prosaccade practice block complete. Transitioning to test trials.');
      setState(() {
        _isPractice = false;
        _trialIndex = 0;
        _completedTrials = 0;
        _prosaccadeIndex = 0;
      });
      _audioService.speak('Practice complete. Starting 30 test trials.');
      Future.delayed(const Duration(seconds: 2), () async {
        if (!mounted) {
          AppLogger.logger.warning('Not mounted after practice block.');
          return;
        }
        setState(() {
          _trialIndex = 0;
          _completedTrials = 0;
          _prosaccadeIndex = 0;
          _isPractice = false;
          _currentTask = EyeTrackingTask.prosaccade;
        });
        AppLogger.logger.info('Starting first test trial after practice.');
        await _performDriftCorrection();
        _runProsaccadeTrial();
      });
      return;
    }
    if (!_isPractice && _completedTrials >= maxTrials) {
      AppLogger.logger.info('Prosaccade test block complete. completedTrials=$_completedTrials maxTrials=$maxTrials');
      _stopEyeTracking();
      _eyeTrackingService.clearData();

      final sessionData = EyeTrackingSessionData(
        participantId: _participantId!,
        sessionId: 'eye_tracking_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        trials: _trials,
        features: EyeTrackingFeatureExtraction.extractSessionFeatures(
          EyeTrackingSessionData(
            participantId: _participantId!,
            sessionId: 'temp',
            timestamp: DateTime.now(),
            trials: _trials,
            features: EyeTrackingFeatureExtraction.getEmptyFeatures(),
          ),
        ),
      );

      Provider.of<TestProgress>(context, listen: false).markProsaccadeCompleted();

      final dataExportService = getIt<DataExportService>();
      try {
        dataExportService.exportEyeTrackingSession(sessionData);
        AppLogger.logger.info('Eye tracking session data exported successfully');
      } catch (e) {
        AppLogger.logger.warning('Failed to export eye tracking session data: $e');
      }
      _showTestCompletionDialog('Pro-saccade Test Complete!', 'prosaccade');
      return;
    }

    if (!mounted) return;

    _eyeTrackingService.setTaskType('prosaccade');
    _eyeTrackingService.startTrial();

    setState(() {
      _targetPosition = const Offset(0.5, 0.5);
      _showTarget = true;
    });

    final fixationDuration = 800 + Random().nextInt(400);

    Future.delayed(Duration(milliseconds: fixationDuration), () {
      if (!mounted || _currentTask != EyeTrackingTask.prosaccade) return;
      if (trialToken != _trialIndex) return;
      if (_completedTrials >= maxTrials) return;

      setState(() => _showTarget = false);

      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || _currentTask != EyeTrackingTask.prosaccade) return;
        if (trialToken != _trialIndex) return;
        if (_completedTrials >= maxTrials) return;

        Offset? pos;
        if (_isPractice) {
          pos = _getProsaccadePosition(_trialIndex % 8);
        } else {
          if (_prosaccadeIndex >= _prosaccadeSequence.length) {
            AppLogger.logger.info('All prosaccade trials completed');
            _stopEyeTracking();
            _eyeTrackingService.clearData();
            Provider.of<TestProgress>(context, listen: false).markProsaccadeCompleted();
            _showTestCompletionDialog('Pro-saccade Test Complete!', 'prosaccade');
            return;
          }
          pos = _getProsaccadePosition(_prosaccadeSequence[_prosaccadeIndex]);
        }

        if (!mounted) return;
        setState(() {
          _targetPosition = pos;
          _showTarget = true;
        });

        final trialDurationMs = 1800 + Random().nextInt(400);
        final trialStart = DateTime.now();

        Future.delayed(Duration(milliseconds: trialDurationMs), () {
          if (!mounted) return;
          if (trialToken != _trialIndex) return;
          if (_completedTrials >= maxTrials) return;
          final trialEnd = DateTime.now();
          final actualDurationMs = trialEnd.difference(trialStart).inMilliseconds;
          final trialResult = _eyeTrackingService.completeTrial();

          final qualityOk = actualDurationMs >= 800 && _checkTrialQuality(trialResult.frames);

          if (!mounted) return;
          if (trialToken != _trialIndex) return;
          if (_isPractice) {
            if (!qualityOk) {
              _audioService.speak('Practice trial quality low. Repeating trial.');
            }
            _trialIndex++;
            Future.delayed(const Duration(milliseconds: 500), () async {
              if (!mounted) return;
              if (trialToken + 1 != _trialIndex) return;
              await _performDriftCorrection();
              _runProsaccadeTrial();
            });
          } else {
            if (!qualityOk) {
              _audioService.speak('Trial too short or quality low. Repeating trial.');
              Future.delayed(const Duration(milliseconds: 500), () async {
                if (!mounted) return;
                if (trialToken != _trialIndex) return;
                await _performDriftCorrection();
                _runProsaccadeTrial();
              });
            } else {
              final updatedTrial = EyeTrackingTrialData(
                trialNumber: _trials.length + 1,
                taskType: 'prosaccade',
                frames: trialResult.frames,
                qualityScore: trialResult.qualityScore,
              );
              _trials.add(updatedTrial);
              AppLogger.logger.info('Added prosaccade trial ${_trials.length} with ${trialResult.frames.length} frames, duration: $actualDurationMs ms');
              _completedTrials++;
              _trialIndex++;
              _prosaccadeIndex++;
              if (_completedTrials >= maxTrials || _prosaccadeIndex >= _prosaccadeSequence.length) {
                AppLogger.logger.info('Prosaccade test block complete (hard stop after increment).');
                _stopEyeTracking();
                _eyeTrackingService.clearData();
                Provider.of<TestProgress>(context, listen: false).markProsaccadeCompleted();
                _showTestCompletionDialog('Pro-saccade Test Complete!', 'prosaccade');
                return;
              }
              Future.delayed(const Duration(milliseconds: 500), () async {
                if (!mounted) return;
                if (trialToken + 1 != _trialIndex) return;
                if (_completedTrials >= maxTrials || _prosaccadeIndex >= _prosaccadeSequence.length) return;
                if (_completedTrials % 5 == 0) {
                  await _performDriftCorrection();
                }
                _runProsaccadeTrial();
              });
            }
          }
        });
      });
    });
  }

  Future<void> _startSmoothPursuitTest() async {
    _participantId ??= 'participant_${DateTime.now().millisecondsSinceEpoch}';

    _showInstructions(
      'Smooth Pursuit Test',
      'Follow the red circle with your eyes as closely as possible',
      'Practice + 12 test trials',
      () async {
        try {
          if (!mounted) return;

          // Audio instruction for all tests
          await _audioService.speak('Keep your head still and move only your eyes');

          setState(() {
            _currentTask = EyeTrackingTask.pursuit;
            _isPractice = true;
            _pursuitTrialNumber = 0;
          });

          _startEyeTracking();

          await _audioService.speak('Practice trials. Follow the red circle.');
          await _performDriftCorrection();
          _runPursuitTrial();
        } catch (e) {
          AppLogger.logger.severe('Camera error: $e');
        }
      },
    );
  }

  void _runPursuitTrial() {
    final maxTrials = _isPractice
        ? AppConstants.smoothPursuitPracticeTrials
        : AppConstants.smoothPursuitTestTrials;
    
    if (_pursuitTrialNumber >= maxTrials) {
      if (_isPractice) {
        setState(() {
          _isPractice = false;
          _pursuitTrialNumber = 0;
        });
        _audioService.speak('Practice complete. Starting test trials.');
        Future.delayed(const Duration(seconds: 2), () async {
          await _performDriftCorrection();
          _runPursuitTrial();
        });
      } else {
        _stopEyeTracking();
        _eyeTrackingService.clearData();

        final sessionData = EyeTrackingSessionData(
          participantId: _participantId!,
          sessionId: 'eye_tracking_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          trials: _trials,
          features: EyeTrackingFeatureExtraction.extractSessionFeatures(
            EyeTrackingSessionData(
              participantId: _participantId!,
              sessionId: 'temp',
              timestamp: DateTime.now(),
              trials: _trials,
              features: EyeTrackingFeatureExtraction.getEmptyFeatures(),
            ),
          ),
        );

        Provider.of<TestProgress>(context, listen: false).markPursuitCompleted();

        final dataExportService = getIt<DataExportService>();
        try {
          dataExportService.exportEyeTrackingSession(sessionData);
          AppLogger.logger.info('Eye tracking session data exported successfully');
        } catch (e) {
          AppLogger.logger.warning('Failed to export eye tracking session data: $e');
        }

        _showTestCompletionDialog('All Eye Tracking Tests Complete!', 'all');
      }
      return;
    }

    _pursuitTrialNumber++;

    final isHorizontal = (_pursuitTrialNumber - 1) % 2 == 0;
    final speed = (_pursuitTrialNumber - 1) % 4 < 2 ? 10 : 20;
    final frequency = speed == 10 ? 0.25 : 0.5;
    
    _eyeTrackingService.clearData();
    _eyeTrackingService.setTaskType('pursuit');
    _eyeTrackingService.startTrial();
    
    setState(() {
      _targetPosition = const Offset(0.5, 0.5);
      _showTarget = true;
    });
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _currentTask != EyeTrackingTask.pursuit) return;
      
      final startTime = DateTime.now();
      
      Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (!mounted || _currentTask != EyeTrackingTask.pursuit) {
          timer.cancel();
          return;
        }

        final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000;
        
        if (elapsed > 10) {
          timer.cancel();
          
          final trialResult = _eyeTrackingService.completeTrial();
          final qualityOk = _checkTrialQuality(trialResult.frames);
          
          if (!qualityOk && !_isPractice) {
            _audioService.speak('Trial quality low. Repeating trial.');
            _pursuitTrialNumber--;
            Future.delayed(const Duration(seconds: 2), () async {
              await _performDriftCorrection();
              _runPursuitTrial();
            });
          } else {
            if (qualityOk && !_isPractice) {
              final updatedTrial = EyeTrackingTrialData(
                trialNumber: _trials.length + 1,
                taskType: 'pursuit',
                frames: trialResult.frames,
                qualityScore: trialResult.qualityScore,
              );
              _trials.add(updatedTrial);
              AppLogger.logger.info('Added pursuit trial ${_trials.length} with ${trialResult.frames.length} frames');
            }

            if (_pursuitTrialNumber < maxTrials) {
              Future.delayed(const Duration(seconds: 1), () async {
                await _performDriftCorrection();
                _runPursuitTrial();
              });
            } else {
              _runPursuitTrial();
            }
          }
          return;
        }

        final position = 0.5 + 0.2 * sin(2 * pi * frequency * elapsed);
        setState(() {
          _targetPosition = isHorizontal
              ? Offset(position, 0.5)
              : Offset(0.5, position);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentTask == EyeTrackingTask.none ? AppColors.background : Colors.black,
      body: _currentTask == EyeTrackingTask.none
          ? SafeArea(
              child: Column(
                children: [
                  const Breadcrumb(current: 'Eye Tracking'),
                  Expanded(child: _buildTaskSelection()),
                ],
              ),
            )
          : _buildTaskScreen(),
    );
  }

  Widget _buildTaskSelection() {
    final progress = Provider.of<TestProgress>(context);
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppConstants.buttonSpacing),
      child: Column(
        children: [
          Text(
            'Eye Tracking Tests',
            style: TextStyle(
              fontSize: AppConstants.headingFontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 16),
          
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple[300]!, width: 2),
            ),
            child: Text(
              'Complete all 3 tests for full assessment',
              style: TextStyle(
                fontSize: 18,
                color: Colors.purple[900],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          SizedBox(height: AppConstants.buttonSpacing),
          
          _buildTaskButtonWithStatus(
            'Fixation Stability Test', 
            _startFixationTest,
            progress.fixationCompleted,
          ),
          SizedBox(height: AppConstants.buttonSpacing),
          
          _buildTaskButtonWithStatus(
            'Pro-saccade Test', 
            _startProsaccadeTest,
            progress.prosaccadeCompleted,
          ),
          SizedBox(height: AppConstants.buttonSpacing),
          
          _buildTaskButtonWithStatus(
            'Smooth Pursuit Test', 
            _startSmoothPursuitTest,
            progress.pursuitCompleted,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskButtonWithStatus(String title, VoidCallback onPressed, bool completed) {
    return Container(
      decoration: BoxDecoration(
        color: completed ? Colors.green[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completed ? Colors.green[400]! : AppColors.border,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.all(AppConstants.buttonPadding),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                if (completed)
                  Icon(
                    Icons.check_circle,
                    color: Colors.green[700],
                    size: 32,
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.textMedium,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskScreen() {
    _screenSize = MediaQuery.of(context).size;
    
    return Stack(
      children: [
        Container(color: Colors.black),
        
        if (_showTarget && _targetPosition != null)
          Positioned(
            left: _screenSize.width * _targetPosition!.dx - _getTargetSize() / 2,
            top: _screenSize.height * _targetPosition!.dy - _getTargetSize() / 2,
            child: _buildTarget(),
          ),
        
        if (kDebugMode && _cameraInitialized && _cameraService.controller != null)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 100,
              height: 75,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CameraPreview(_cameraService.controller!),
              ),
            ),
          ),
        
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: () {
              _stopEyeTracking();
              setState(() {
                _currentTask = EyeTrackingTask.none;
                _fixationTrialNumber = 0;
                _pursuitTrialNumber = 0;
                _trialIndex = 0;
                _completedTrials = 0;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.home,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        
        if (!_isFaceDetected && !_isDriftCorrecting)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '⚠️ Face NOT detected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        
        if (_isDriftCorrecting)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  'Look at the Center',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        
        if (!_isDriftCorrecting)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  _isPractice
                      ? 'Practice Trial ${_getCurrentTrialNumber()}'
                      : 'Test Trial ${_getCurrentTrialNumber()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  double _getTargetSize() {
    switch (_currentTask) {
      case EyeTrackingTask.fixation:
      case EyeTrackingTask.driftCorrection:
        return 80.0;
      case EyeTrackingTask.prosaccade:
        return 50.0;
      case EyeTrackingTask.pursuit:
        return 40.0;
      default:
        return 40.0;
    }
  }

  Widget _buildTarget() {
    switch (_currentTask) {
      case EyeTrackingTask.fixation:
      case EyeTrackingTask.driftCorrection:
        return Icon(Icons.add, size: 80, color: AppColors.fixationCross);
      case EyeTrackingTask.prosaccade:
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        );
      case EyeTrackingTask.pursuit:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.pursuitTarget,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}