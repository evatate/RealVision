import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/test_progress.dart';
import '../services/camera_service.dart';
import '../services/audio_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../widgets/breadcrumb.dart';
import 'dart:async';

enum SmilePhase { none, neutral, smile, neutral2, complete }

class FacialExpressionScreen extends StatefulWidget {
  const FacialExpressionScreen({super.key});

  @override
  State<FacialExpressionScreen> createState() => _FacialExpressionScreenState();
}

class _FacialExpressionScreenState extends State<FacialExpressionScreen> {
  final CameraService _cameraService = CameraService();
  final AudioService _audioService = AudioService();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      minFaceSize: 0.15,
    ),
  );
  
  SmilePhase _currentPhase = SmilePhase.none;
  int _countdown = 0;
  Timer? _countdownTimer;
  bool _cameraInitialized = false;
  int _repetitionCount = 0;
  bool _isPractice = true;
  
  // Face detection
  bool _isFaceDetected = true;
  int _faceOutOfFrameCount = 0;
  Timer? _faceCheckTimer;

  @override
  void initState() {
    super.initState();
    _audioService.initialize();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _faceCheckTimer?.cancel();
    _faceDetector.close();
    _cameraService.dispose();
    _audioService.dispose();
    super.dispose();
  }

  void _showInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Smile Test',
          style: TextStyle(fontSize: 28),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You will be asked to:\n\n'
              '1. Keep a neutral face (15 seconds)\n'
              '2. Smile (15 seconds)\n'
              '3. Return to neutral (15 seconds)\n\n'
              'This will be done twice after a practice round.',
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Keep your face in the camera frame',
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Colors.orange[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startTest();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.all(16),
            ),
            child: Text('Start', style: TextStyle(fontSize: 22)),
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
      
      setState(() {
        _cameraInitialized = true;
        _currentPhase = SmilePhase.neutral;
        _countdown = AppConstants.smilePhaseDuration;
        _isPractice = true;
        _repetitionCount = 0;
      });
      
      await _audioService.speak('Practice round. Keep a neutral face for 15 seconds');
      _startCountdown();
      _startFaceDetection();
    } catch (e) {
      print('Camera error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
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

  void _startFaceDetection() {
    // Check face every 500ms
    _faceCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!mounted || _cameraService.controller == null) {
        timer.cancel();
        return;
      }
      
      try {
        // In production, implement actual face detection here
        // For now, assume face is always detected
        setState(() => _isFaceDetected = true);
      } catch (e) {
        print('Face detection error: $e');
      }
    });
  }

  void _nextPhase() {
    switch (_currentPhase) {
      case SmilePhase.neutral:
        setState(() {
          _currentPhase = SmilePhase.smile;
          _countdown = AppConstants.smilePhaseDuration;
        });
        final label = _isPractice ? 'Practice. Now' : 'Now';
        _audioService.speak('$label smile for 15 seconds');
        _startCountdown();
        break;
        
      case SmilePhase.smile:
        setState(() {
          _currentPhase = SmilePhase.neutral2;
          _countdown = AppConstants.smilePhaseDuration;
        });
        _audioService.speak('Return to neutral face for 15 seconds');
        _startCountdown();
        break;
        
      case SmilePhase.neutral2:
        if (_isPractice) {
          // Practice done
          _checkQualityAndContinue(isPractice: true);
        } else {
          _repetitionCount++;
          
          if (_repetitionCount < AppConstants.smileTestRepetitions) {
            // Start next repetition
            setState(() {
              _currentPhase = SmilePhase.neutral;
              _countdown = AppConstants.smilePhaseDuration;
            });
            _audioService.speak('Repetition ${_repetitionCount + 1}. Keep neutral face');
            _startCountdown();
          } else {
            // All repetitions done
            _checkQualityAndContinue(isPractice: false);
          }
        }
        break;
        
      default:
        break;
    }
  }

  void _checkQualityAndContinue({required bool isPractice}) {
    // Check if face was out of frame too much
    if (_faceOutOfFrameCount > 20) { // More than 10 seconds total
      _showQualityDialog();
    } else {
      if (isPractice) {
        // Practice done, start real trials
        setState(() {
          _isPractice = false;
          _currentPhase = SmilePhase.neutral;
          _countdown = AppConstants.smilePhaseDuration;
          _faceOutOfFrameCount = 0; // Reset counter
        });
        _audioService.speak('Practice complete. Starting test. Keep neutral face.');
        _startCountdown();
      } else {
        // All done!
        _completeTest();
      }
    }
  }

  void _showQualityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Test Quality Issue', style: TextStyle(fontSize: 28)),
        content: Text(
          'Your face was out of frame too often. Would you like to retake this test?',
          style: TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _completeTest(); // Save anyway
            },
            child: Text('Continue Anyway', style: TextStyle(fontSize: 20)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _retakeTest();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text('Retake Test', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }

  void _retakeTest() {
    setState(() {
      _currentPhase = SmilePhase.neutral;
      _countdown = AppConstants.smilePhaseDuration;
      _isPractice = false; // Skip practice
      _repetitionCount = 0;
      _faceOutOfFrameCount = 0;
    });
    _audioService.speak('Retaking test. Keep neutral face');
    _startCountdown();
  }

  void _completeTest() {
    setState(() => _currentPhase = SmilePhase.complete);
    Provider.of<TestProgress>(context, listen: false).markSmileCompleted();
    _audioService.speak('Smile test complete');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Breadcrumb(current: 'Smile Test'),
            Expanded(
              child: _currentPhase == SmilePhase.none
                  ? _buildStartScreen()
                  : _buildTestScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.buttonSpacing),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Smile Test',
              style: TextStyle(
                fontSize: AppConstants.headingFontSize,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
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
                  padding: EdgeInsets.all(24),
                ),
                child: Text(
                  'Start Test',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestScreen() {
    return Padding(
      padding: EdgeInsets.all(AppConstants.buttonSpacing),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Camera preview
          if (_cameraInitialized && _cameraService.controller != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isFaceDetected ? AppColors.success : Colors.red,
                  width: 4,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: CameraPreview(_cameraService.controller!),
                ),
              ),
            )
          else
            Container(
              height: 400,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          
          SizedBox(height: 32),
          
          // Phase indicator
          Text(
            _getPhaseEmoji(),
            style: const TextStyle(fontSize: 60),
          ),
          
          SizedBox(height: 16),
          
          // Phase text
          Text(
            _getPhaseText(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 16),
          
          // Countdown
          if (_currentPhase != SmilePhase.complete)
            Text(
              '${_countdown}s',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          
          // Warning if face out of frame
          if (!_isFaceDetected)
            Container(
              margin: EdgeInsets.only(top: 16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Text(
                '⚠️ Keep your face in frame',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red[900],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
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