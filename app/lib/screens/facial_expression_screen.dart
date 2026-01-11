import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/camera_service.dart';
import '../services/audio_service.dart';
import '../services/face_detection_service.dart';
import '../models/smile_data.dart';
import '../services/data_export_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../widgets/breadcrumb.dart';
import 'smile_results_screen.dart';
import '../services/service_locator.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

enum SmilePhase { none, neutral, smile, neutral2, complete }

class FacialExpressionScreen extends StatefulWidget {
  const FacialExpressionScreen({super.key});

  @override
  State<FacialExpressionScreen> createState() => _FacialExpressionScreenState();
}

class _FacialExpressionScreenState extends State<FacialExpressionScreen> {
  final CameraService _cameraService = CameraService();
  final AudioService _audioService = AudioService();
  final FaceDetectionService _faceDetector = FaceDetectionService();
  late DataExportService _dataExport;
  
  SmilePhase _currentPhase = SmilePhase.none;
  int _countdown = 0;
  Timer? _countdownTimer;
  bool _cameraInitialized = false;
  int _repetitionCount = 0;
  bool _isPractice = true;
  
  bool _isFaceDetected = false;
  double _smileProbability = 0.0;
  Timer? _faceDetectionTimer;

  // Data collection for feature extraction
  String? _participantId;
  List<SmileTrialData> _collectedTrials = [];
  List<SmileFrame> _currentTrialFrames = [];
  Stopwatch? _trialStopwatch;

  @override
  void initState() {
    super.initState();
    _dataExport = getIt<DataExportService>();
    _audioService.initialize();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _faceDetectionTimer?.cancel();
    _cameraService.stopImageStream();
    _cameraService.dispose();
    _audioService.dispose();
    _faceDetector.dispose();
    super.dispose();
  }

  void _showInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Smile Test',
          style: TextStyle(fontSize: 28, color: AppColors.textDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You will:\n'
              '1. Keep a neutral face\n'
              '2. Smile\n'
              '3. Return to neutral\n'
              'Done twice after a practice round.',
              style: TextStyle(fontSize: 22, color: AppColors.textDark),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 248, 111, 101),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[700]!, width: 2),
              ),
              child: Text(
                '⚠️ Keep your face in frame',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
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
                _startTest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.all(16),
              ),
              child: Text('Start', style: TextStyle(fontSize: 24, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startTest() async {
    try {
      await _cameraService.initialize();
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 500));

      // Initialize data collection
      _participantId = 'participant_${DateTime.now().millisecondsSinceEpoch}';
      _collectedTrials = [];
      _currentTrialFrames = [];
      _trialStopwatch = Stopwatch();

      setState(() {
        _cameraInitialized = true;
        _currentPhase = SmilePhase.neutral;
        _countdown = AppConstants.smilePhaseDuration;
        _isPractice = true;
        _repetitionCount = 0;
      });

      _startFaceDetection();

      await _audioService.speak('Practice round. Keep neutral face');
      _startCountdown();
    } catch (e) {
      AppLogger.logger.severe('Camera error: $e');
    }
  }

  void _startFaceDetection() async {
    try {
      await _cameraService.startImageStream((CameraImage image, InputImageRotation rotation) async {
        if (_faceDetectionTimer?.isActive ?? false) return;

        _faceDetectionTimer = Timer(Duration(milliseconds: 33), () async { // ~30 fps
          final result = await _faceDetector.detectFace(
            image,
            rotation,
          );

          final timestamp = _trialStopwatch?.elapsedMilliseconds.toDouble() ?? 0.0;
          final smileIndex = (result.smilingProbability * 100).clamp(0.0, 100.0);

          // Collect frame data for feature extraction
          if (_currentPhase != SmilePhase.none && _currentPhase != SmilePhase.complete) {
            final phaseString = _getPhaseString(_currentPhase);
            final frame = SmileFrame(
              timestamp: timestamp / 1000.0, // convert to seconds
              smileIndex: smileIndex,
              phase: phaseString,
            );
            _currentTrialFrames.add(frame);
          }

          if (mounted) {
            setState(() {
              _isFaceDetected = result.faceDetected;
              _smileProbability = result.smilingProbability;
            });
          }
        });
      });
    } catch (e) {
      AppLogger.logger.severe('Error starting face detection: $e');
    }
  }

  String _getPhaseString(SmilePhase phase) {
    switch (phase) {
      case SmilePhase.neutral:
      case SmilePhase.neutral2:
        return 'neutral';
      case SmilePhase.smile:
        return 'smile';
      default:
        return 'neutral';
    }
  }

  void _stopFaceDetection() {
    _faceDetectionTimer?.cancel();
    _faceDetectionTimer = null;
    _cameraService.stopImageStream();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          timer.cancel();
          _nextPhase();
        }
      });
    });
  }

  void _nextPhase() {
    switch (_currentPhase) {
      case SmilePhase.neutral:
        // Start trial stopwatch when moving to first phase
        if (_trialStopwatch != null && !_trialStopwatch!.isRunning) {
          _trialStopwatch!.start();
        }
        setState(() {
          _currentPhase = SmilePhase.smile;
          _countdown = AppConstants.smilePhaseDuration;
        });
        _audioService.speak(_isPractice ? 'Practice. Smile now' : 'Smile now');
        _startCountdown();
        break;

      case SmilePhase.smile:
        setState(() {
          _currentPhase = SmilePhase.neutral2;
          _countdown = AppConstants.smilePhaseDuration;
        });
        _audioService.speak('Return to neutral face');
        _startCountdown();
        break;

      case SmilePhase.neutral2:
        // Complete trial and save data
        _completeTrial();

        if (_isPractice) {
          setState(() {
            _isPractice = false;
            _currentPhase = SmilePhase.neutral;
            _countdown = AppConstants.smilePhaseDuration;
          });
          _audioService.speak('Practice complete. Starting test. Keep neutral face');
          _startCountdown();
        } else {
          _repetitionCount++;
          if (_repetitionCount < AppConstants.smileTestRepetitions) {
            setState(() {
              _currentPhase = SmilePhase.neutral;
              _countdown = AppConstants.smilePhaseDuration;
            });
            _audioService.speak('Repetition ${_repetitionCount + 1}. Keep neutral face');
            _startCountdown();
          } else {
            _completeTest();
          }
        }
        break;

      default:
        break;
    }
  }

  void _completeTrial() {
    if (_trialStopwatch != null) {
      _trialStopwatch!.stop();
    }

    // Save trial data
    final trialData = SmileTrialData(
      trialNumber: _isPractice ? 0 : _repetitionCount + 1,
      frames: List.from(_currentTrialFrames),
    );

    if (!_isPractice) {
      _collectedTrials.add(trialData);
    }

    // Reset for next trial
    _currentTrialFrames = [];
    if (_trialStopwatch != null) {
      _trialStopwatch!.reset();
    }

    AppLogger.logger.info('Completed trial ${_isPractice ? "practice" : _repetitionCount + 1} with ${trialData.frames.length} frames');
  }

  void _completeTest() {
    // Stop face detection
    _stopFaceDetection();

    // Extract features from collected trials
    final sessionFeatures = SmileFeatureExtraction.extractSessionFeatures(
      SmileSessionData(
        participantId: _participantId!,
        sessionId: '',
        timestamp: DateTime.now(),
        trials: _collectedTrials,
        features: SmileFeatures(
          smilingDuration: 0.0,
          proportionSmiling: 0.0,
          timeToSmile: 0.0,
          meanSmileIndex: 0.0,
          maxSmileIndex: 0.0,
          minSmileIndex: 0.0,
          stdSmileIndex: 0.0,
          smileNeutralDifference: 0.0,
        ),
      ),
    );

    // Create session data
    final sessionData = SmileSessionData(
      participantId: _participantId!,
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      trials: _collectedTrials,
      features: sessionFeatures,
    );

    // Export to JSON
    _dataExport.exportSmileSession(sessionData).then((filePath) {
      AppLogger.logger.info('Smile session data exported to: $filePath');
    }).catchError((error) {
      AppLogger.logger.severe('Failed to export smile session data: $error');
    });

    // Navigate to results screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SmileResultsScreen(
          sessionData: sessionData,
          exportPath: null, // Will be set by export service
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Breadcrumb(current: 'Smile Test'),
              if (_currentPhase == SmilePhase.none)
                _buildStartScreen()
              else
                _buildTestScreen(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.buttonSpacing),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 32),
            Text(
              'Smile Test',
              style: TextStyle(
                fontSize: AppConstants.headingFontSize,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            Icon(
              Icons.sentiment_satisfied,
              size: 80,
              color: AppColors.primary,
            ),
            SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showInstructions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.all(24),
                ),
                child: Text(
                  'Start Test',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTestScreen() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenWidth > screenHeight;
    final cameraHeight = isLandscape
        ? screenHeight * 0.6
        : screenWidth * 0.9 / (_cameraService.controller?.value.aspectRatio ?? 1.0);
    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Camera preview with fixed height
            Container(
              height: cameraHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isFaceDetected ? AppColors.success : Colors.red,
                  width: 4,
                ),
              ),
              child: _cameraInitialized && _cameraService.controller != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CameraPreview(_cameraService.controller!),
                    )
                  : Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
            ),
            const SizedBox(height: 16),
            // Emoji
            Center(
              child: Text(
                _getPhaseEmoji(),
                style: const TextStyle(fontSize: 56),
              ),
            ),
            const SizedBox(height: 16),
            // Phase text
            Text(
              _getPhaseText(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Countdown
            if (_currentPhase != SmilePhase.complete)
              Center(
                child: Text(
                  '${_countdown}s',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Warning or debug info
            if (!_isFaceDetected && _currentPhase != SmilePhase.complete)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Text(
                  '⚠️ Face NOT in frame',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (kDebugMode && _isFaceDetected && _currentPhase != SmilePhase.complete)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Smile: ${(_smileProbability * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 14, color: Colors.blue[900]),
                ),
              )
            else
              SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getPhaseEmoji() {
    switch (_currentPhase) {
      case SmilePhase.neutral:
      case SmilePhase.neutral2:
        return '😐';
      case SmilePhase.smile:
        return '😊';
      case SmilePhase.complete:
        return '✅';
      default:
        return '';
    }
  }

  String _getPhaseText() {
    final prefix = _isPractice ? 'Practice: ' : '';
    
    switch (_currentPhase) {
      case SmilePhase.neutral:
        return '${prefix}Keep Neutral Face';
      case SmilePhase.smile:
        return '${prefix}Smile!';
      case SmilePhase.neutral2:
        return '${prefix}Return to Neutral';
      case SmilePhase.complete:
        return 'Complete!';
      default:
        return '';
    }
  }
}