import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/test_progress.dart';
import '../services/camera_service.dart';
import '../services/audio_service.dart';
import '../services/face_detection_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../widgets/breadcrumb.dart';
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
  
  SmilePhase _currentPhase = SmilePhase.none;
  int _countdown = 0;
  Timer? _countdownTimer;
  bool _cameraInitialized = false;
  int _repetitionCount = 0;
  bool _isPractice = true;
  
  bool _isFaceDetected = false;
  double _smileProbability = 0.0;
  Timer? _faceDetectionTimer;

  @override
  void initState() {
    super.initState();
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
              'You will:\n\n'
              '1. Keep neutral face (15s)\n'
              '2. Smile (15s)\n'
              '3. Return to neutral (15s)\n\n'
              'Done twice after practice.',
              style: TextStyle(fontSize: 20, color: AppColors.textDark),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!, width: 2),
              ),
              child: Text(
                '⚠️ Keep your face in frame',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
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
      
      setState(() {
        _cameraInitialized = true;
        _currentPhase = SmilePhase.neutral;
        _countdown = AppConstants.smilePhaseDuration;
        _isPractice = true;
        _repetitionCount = 0;
      });
      
      // Start face detection
      _startFaceDetection();
      
      await _audioService.speak('Practice round. Keep neutral face');
      _startCountdown();
    } catch (e) {
      print('Camera error: $e');
    }
  }

  void _startFaceDetection() async {
    try {
      await _cameraService.startImageStream((CameraImage image) async {
        // Process every 500ms to avoid overload
        if (_faceDetectionTimer?.isActive ?? false) return;
        
        _faceDetectionTimer = Timer(Duration(milliseconds: 500), () async {
          final result = await _faceDetector.detectFace(
            image,
            InputImageRotation.rotation0deg, // Adjust based on camera orientation
          );
          
          if (mounted) {
            setState(() {
              _isFaceDetected = result.faceDetected;
              _smileProbability = result.smilingProbability;
            });
          }
        });
      });
    } catch (e) {
      print('Error starting face detection: $e');
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

  void _nextPhase() {
    switch (_currentPhase) {
      case SmilePhase.neutral:
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

  void _completeTest() {
    setState(() => _currentPhase = SmilePhase.complete);
    _cameraService.stopImageStream();
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
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Camera takes most of the space
          Expanded(
            flex: 70, // percentage based
            child: _cameraInitialized && _cameraService.controller != null
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _cameraService.controller!.value.aspectRatio,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isFaceDetected ? AppColors.success : Colors.red,
                            width: 4,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CameraPreview(_cameraService.controller!),
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
          ),
          
          SizedBox(height: 12), // Spacing between camera and instructions
          
          // Instructions
          Expanded(
            flex: 30,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Emoji
                Text(
                  _getPhaseEmoji(),
                  style: const TextStyle(fontSize: 36),
                ),
                
                // Phase text
                Flexible(
                  child: Text(
                    _getPhaseText(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Countdown
                if (_currentPhase != SmilePhase.complete)
                  Text(
                    '${_countdown}s',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                
                // Warning or debug info
                if (!_isFaceDetected && _currentPhase != SmilePhase.complete)
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: Text(
                        '⚠️ Face in frame',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else if (kDebugMode && _isFaceDetected && _currentPhase != SmilePhase.complete)
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Smile: ${(_smileProbability * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                      ),
                    ),
                  )
                else
                  SizedBox(height: 30), // Placeholder when no warning
              ],
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