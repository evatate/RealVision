import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../models/test_progress.dart';
import '../services/camera_service.dart';
import '../services/audio_service.dart';
import '../services/face_detection_service.dart';
import '../services/eye_tracking_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../widgets/breadcrumb.dart';
import '../utils/logger.dart';
import 'dart:async';
import 'dart:math';
import '../services/service_locator.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

enum EyeTrackingTask { none, fixation, prosaccade, pursuit, driftCorrection }

class EyeTrackingScreen extends StatefulWidget {
  const EyeTrackingScreen({super.key});

  @override
  State<EyeTrackingScreen> createState() => _EyeTrackingScreenState();
}

class _EyeTrackingScreenState extends State<EyeTrackingScreen> {
  late CameraService _cameraService = CameraService();
  late AudioService _audioService = AudioService();
  late EyeTrackingService _eyeTrackingService = EyeTrackingService();
  late FaceDetectionService _faceDetector = FaceDetectionService();
  
  EyeTrackingTask _currentTask = EyeTrackingTask.none;
  int _trialNumber = 0;
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
  List<double> _trialQualityScores = [];
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
      // Initialize camera once and reuse it
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
    // Disable high-frequency processing
    _eyeTrackingService.setAssessmentActive(false);
    
    _taskTimer?.cancel();
    _eyeTrackingTimer?.cancel();
    _stopEyeTracking(); // Stop eye tracking and disable assessment mode
    _cameraService.dispose();
    _audioService.dispose();
    _eyeTrackingService.dispose();
    _faceDetector.dispose();
    super.dispose();
  }

  // Generate randomized pro-saccade sequence
  void _generateProsaccadeSequence() {
    // 8 positions (excluding center): left, right, up, down + 4 diagonals
    final positions = [0, 1, 2, 3, 4, 5, 6, 7];
    final random = Random();
    _prosaccadeSequence = [];
    
    // Create 40 trials with proper randomization
    // Rule: same position cannot appear twice in a row
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
    // 8 positions at ~10° visual angle from center (approx 0.17 normalized units)
    const double distance = 0.17;
    const positions = [
      Offset(0.5 - distance, 0.5),      // 0: Left
      Offset(0.5 + distance, 0.5),      // 1: Right
      Offset(0.5, 0.5 - distance),      // 2: Up
      Offset(0.5, 0.5 + distance),      // 3: Down
      Offset(0.5 - distance * 0.707, 0.5 - distance * 0.707), // 4: Top-left
      Offset(0.5 + distance * 0.707, 0.5 - distance * 0.707), // 5: Top-right
      Offset(0.5 - distance * 0.707, 0.5 + distance * 0.707), // 6: Bottom-left
      Offset(0.5 + distance * 0.707, 0.5 + distance * 0.707), // 7: Bottom-right
    ];
    return positions[index];
  }

  // Drift correction before each trial
  Future<void> _performDriftCorrection() async {
    final originalTask = _currentTask; // Save current task
    
    setState(() {
      _isDriftCorrecting = true;
      _currentTask = EyeTrackingTask.driftCorrection;
      _targetPosition = const Offset(0.5, 0.5);
      _showTarget = true;
    });
    
    await _audioService.speak('Look at the center cross');
    
    // Collect calibration data for 2 seconds
    _eyeTrackingService.startDriftCorrection();
    await Future.delayed(const Duration(seconds: 2));
    _eyeTrackingService.finalizeDriftCorrection();
    
    setState(() {
      _isDriftCorrecting = false;
      _currentTask = originalTask; // Restore original task
    });
  }

  // Check trial quality
  bool _checkTrialQuality(List<GazePoint> trialData) {
    if (trialData.length < 5) return false;
    
    // Calculate percentage of valid gaze points (face detected)
    final validPoints = trialData.length;
    const requiredPoints = 5;
    
    if (validPoints < requiredPoints) return false;
    
    // Check if user was looking roughly near targets
    final meanDistance = trialData.map((p) => p.distance).reduce((a, b) => a + b) / trialData.length;
    
    // Store quality score
    _trialQualityScores.add(1.0 - meanDistance);
    
    // Different thresholds for different tasks
    double threshold;
    switch (_currentTask) {
      case EyeTrackingTask.prosaccade:
        threshold = 0.4;
        break;
      case EyeTrackingTask.pursuit:
        threshold = 0.4;
        break;
      default:
        threshold = 0.25;
    }
    
    // Trial passes if mean distance < threshold
    return meanDistance < threshold;
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
                Navigator.pop(context); // Close dialog
                // Start the next test in sequence
                if (testType == 'fixation') {
                  _startProsaccadeTest();
                } else if (testType == 'prosaccade') {
                  _startSmoothPursuitTest();
                } else if (testType == 'all') {
                  // Return to main home screen
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else {
                  // For any other case, return to test selection
                  setState(() {
                    _currentTask = EyeTrackingTask.none;
                    _trialNumber = 0;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.all(16),
              ),
              child: Text(
                testType == 'all' ? 'Return to Test Screen' : 'Continue with Next Test',
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
                // Return to test selection screen
                setState(() {
                  _currentTask = EyeTrackingTask.none;
                  _trialNumber = 0;
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

  void _showInstructions(String title, String instruction, VoidCallback onStart) {
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
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[300]!, width: 2),
              ),
              child: Text(
                'Starts with a practice round',
                style: TextStyle(
                  fontSize: 24,
                  fontStyle: FontStyle.italic,
                  color: const Color.fromARGB(255, 0, 0, 0),
                  fontWeight: FontWeight.w500,
                ),
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
    _showInstructions(
      'Fixation Stability Test',
      'Look closely at the red cross without blinking for 10 seconds',
      () async {
        try {
          if (!mounted) return;
          
          await Future.delayed(const Duration(milliseconds: 500));
          
          setState(() {
            _currentTask = EyeTrackingTask.fixation;
            _isPractice = true;
            _trialNumber = 0;
            _showTarget = true;
            _targetPosition = const Offset(0.5, 0.5);
            _trialQualityScores = [];
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
    // Disable high-frequency processing
    _eyeTrackingService.setAssessmentActive(false);
    
    _eyeTrackingTimer?.cancel();
    _cameraService.stopImageStream();
    _isProcessingFrame = false; // Reset processing flag
  }

  void _startEyeTracking() {
    // Enable high-frequency processing for assessment
    _eyeTrackingService.setAssessmentActive(true);
    
    _cameraService.startImageStream((CameraImage image, InputImageRotation rotation) async {
      if (!mounted || _targetPosition == null || _isProcessingFrame) return;
      
      // Set processing flag to prevent overlapping frame processing
      _isProcessingFrame = true;
      
      try {
        // First check if face is detected using the reliable face detection service
        final faceResult = await _faceDetector.detectFace(image, rotation);
        final faceDetected = faceResult.faceDetected;
        
        AppLogger.logger.fine('Face detection result: faceDetected=$faceDetected');
        
        setState(() => _isFaceDetected = faceDetected);
        
        if (faceDetected) {
          // Only attempt eye tracking if face is detected
          final result = await _eyeTrackingService.trackGaze(image, _targetPosition!, _screenSize, rotation);
          AppLogger.logger.fine('Eye tracking result: ${result != null ? 'success' : 'failed'}');
          if (result != null) {
            _eyeTrackingService.recordGazePoint(result);
          }
        }
      } finally {
        // Always reset the processing flag
        _isProcessingFrame = false;
      }
    });
  }

  void _runFixationTrial() {
    final maxTrials = _isPractice 
        ? AppConstants.fixationPracticeTrials 
        : AppConstants.fixationTestTrials;
    
    if (_trialNumber >= maxTrials) {
      if (_isPractice) {
        setState(() {
          _isPractice = false;
          _trialNumber = 0;
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

    _trialNumber++;
    _eyeTrackingService.clearData();
    setState(() => _targetPosition = const Offset(0.5, 0.5));
    
    _taskTimer = Timer(Duration(seconds: AppConstants.fixationDuration), () {
      // Check trial quality
      final trialData = _eyeTrackingService.getGazeData();
      final qualityOk = _checkTrialQuality(trialData);
      
      if (!qualityOk && !_isPractice) {
        _audioService.speak('Trial quality low. Repeating trial.');
        _trialNumber--; // Repeat this trial
        Future.delayed(const Duration(seconds: 2), () async {
          await _performDriftCorrection();
          _runFixationTrial();
        });
        return;
      }
      
      if (_trialNumber < maxTrials) {
        final label = _isPractice ? 'practice' : 'test';
        _audioService.speak('${label.capitalize()} trial ${_trialNumber + 1}');
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
    final metrics = _eyeTrackingService.getFixationMetrics();
    AppLogger.logger.info('Fixation metrics: $metrics');
    AppLogger.logger.info('Trial quality scores: $_trialQualityScores');
    
    _stopEyeTracking(); // Stop eye tracking and disable assessment mode
    _eyeTrackingService.clearData();
    
    Provider.of<TestProgress>(context, listen: false).markFixationCompleted();
    
    _showTestCompletionDialog('Fixation Stability Test Complete!', 'fixation');
  }

  Future<void> _startProsaccadeTest() async {
    _showInstructions(
      'Pro-saccade Test',
      'Look at the target circle as quickly as possible when it appears',
      () async {
        try {
          if (!mounted) return;
          
          // Generate randomized sequence for 40 trials
          _generateProsaccadeSequence();
          
          setState(() {
            _currentTask = EyeTrackingTask.prosaccade;
            _isPractice = true;
            _trialNumber = 0;
            _trialQualityScores = [];
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
    
    if (_trialNumber >= maxTrials) {
      if (_isPractice) {
        setState(() {
          _isPractice = false;
          _trialNumber = 0;
          _prosaccadeIndex = 0; // Reset for test trials
        });
        _audioService.speak('Practice complete. Starting 40 test trials.');
        Future.delayed(const Duration(seconds: 2), () async {
          await _performDriftCorrection();
          _runProsaccadeTrial();
        });
      } else {
        final metrics = _eyeTrackingService.getProsaccadeMetrics();
        AppLogger.logger.info('Pro-saccade metrics: $metrics');
        AppLogger.logger.info('Trial quality scores: $_trialQualityScores');
        
        _stopEyeTracking(); // Stop eye tracking and disable assessment mode
        _eyeTrackingService.clearData();
        
        Provider.of<TestProgress>(context, listen: false).markProsaccadeCompleted();
        
        _showTestCompletionDialog('Pro-saccade Test Complete!', 'prosaccade');
      }
      return;
    }

    // Show central fixation point
    setState(() {
      _targetPosition = const Offset(0.5, 0.5);
      _showTarget = true;
    });
    
    // Central fixation: 800-1200ms (randomized)
    final fixationDuration = 800 + Random().nextInt(400);
    
    Future.delayed(Duration(milliseconds: fixationDuration), () {
      if (!mounted || _currentTask != EyeTrackingTask.prosaccade) return;
      
      // GAP period: 200ms blank screen
      setState(() => _showTarget = false);
      
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || _currentTask != EyeTrackingTask.prosaccade) return;
        
        // Show peripheral target using randomized sequence
        final pos = _isPractice 
            ? _getProsaccadePosition(_trialNumber % 8) // Practice uses simple cycling
            : _getProsaccadePosition(_prosaccadeSequence[_prosaccadeIndex]);
        
        setState(() {
          _targetPosition = pos;
          _showTarget = true;
          _trialNumber++;
        });
        
        if (!_isPractice) _prosaccadeIndex++;
        
        // Target visible for 1000ms
        Future.delayed(const Duration(milliseconds: 1000), () {
          // Check trial quality
          final trialData = _eyeTrackingService.getGazeData();
          final qualityOk = _checkTrialQuality(trialData);
          
          if (!qualityOk && !_isPractice) {
            _audioService.speak('Trial quality low. Repeating trial.');
            _trialNumber--; // Repeat this trial
            if (!_isPractice) _prosaccadeIndex--;
            Future.delayed(const Duration(milliseconds: 500), () async {
              await _performDriftCorrection();
              _runProsaccadeTrial();
            });
          } else {
            // Inter-trial interval: 500ms
            Future.delayed(const Duration(milliseconds: 500), () async {
              // Drift correction every 5 trials
              if (_trialNumber % 5 == 0) {
                await _performDriftCorrection();
              }
              _runProsaccadeTrial();
            });
          }
        });
      });
    });
  }

  Future<void> _startSmoothPursuitTest() async {
    _showInstructions(
      'Smooth Pursuit Test',
      'Follow the red circle with your eyes as closely as possible',
      () async {
        try {
          if (!mounted) return;
          
          setState(() {
            _currentTask = EyeTrackingTask.pursuit;
            _isPractice = true;
            _trialNumber = 0;
            _trialQualityScores = [];
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
    
    if (_trialNumber >= maxTrials) {
      if (_isPractice) {
        setState(() {
          _isPractice = false;
          _trialNumber = 0;
        });
        _audioService.speak('Practice complete. Starting test trials.');
        Future.delayed(const Duration(seconds: 2), () async {
          await _performDriftCorrection();
          _runPursuitTrial();
        });
      } else {
        final metrics = _eyeTrackingService.getSmoothPursuitMetrics();
        AppLogger.logger.info('Smooth pursuit metrics: $metrics');
        AppLogger.logger.info('Trial quality scores: $_trialQualityScores');
        
        _stopEyeTracking(); // Stop eye tracking and disable assessment mode
        _eyeTrackingService.clearData();
        
        Provider.of<TestProgress>(context, listen: false).markPursuitCompleted();
        
        _showTestCompletionDialog('All Eye Tracking Tests Complete!', 'all');
      }
      return;
    }

    final isHorizontal = _trialNumber % 2 == 0;
    final speed = _trialNumber % 4 < 2 ? 10 : 20;
    final frequency = speed == 10 ? 0.25 : 0.5;
    
    // Clear trial data
    _eyeTrackingService.clearData();
    
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
          
          // Check trial quality
          final trialData = _eyeTrackingService.getGazeData();
          final qualityOk = _checkTrialQuality(trialData);
          
          if (!qualityOk && !_isPractice) {
            _audioService.speak('Trial quality low. Repeating trial.');
            Future.delayed(const Duration(seconds: 2), () async {
              await _performDriftCorrection();
              _runPursuitTrial();
            });
          } else {
            setState(() => _trialNumber++);
            Future.delayed(const Duration(seconds: 1), () async {
              await _performDriftCorrection();
              _runPursuitTrial();
            });
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
        
        // Home button during tests
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: () {
              _stopEyeTracking();
              setState(() {
                _currentTask = EyeTrackingTask.none;
                _trialNumber = 0;
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
                      ? 'Practice Trial $_trialNumber'
                      : 'Test Trial $_trialNumber',
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
        return 80.0; // Cross target
      case EyeTrackingTask.prosaccade:
        return 50.0; // ~1° visual angle circle
      case EyeTrackingTask.pursuit:
        return 40.0; // ~0.8° visual angle circle
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