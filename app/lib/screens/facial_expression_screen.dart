import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
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
  
  SmilePhase _currentPhase = SmilePhase.none;
  int _countdown = 0;
  Timer? _countdownTimer;
  bool _cameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _audioService.initialize();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraService.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _startTest() async {
    try {
      await _cameraService.initialize();
      
      if (!mounted) return;
      
      // Small delay to let camera stabilize
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _cameraInitialized = true;
        _currentPhase = SmilePhase.neutral;
        _countdown = AppConstants.smilePhaseDuration;
      });
      
      await _audioService.speak('Please keep a neutral face for 15 seconds');
      _startCountdown();
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

  void _nextPhase() {
    switch (_currentPhase) {
      case SmilePhase.neutral:
        setState(() {
          _currentPhase = SmilePhase.smile;
          _countdown = AppConstants.smilePhaseDuration;
        });
        _audioService.speak('Now smile for 15 seconds');
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
        setState(() => _currentPhase = SmilePhase.complete);
        Provider.of<TestProgress>(context, listen: false).markSmileCompleted();
        _audioService.speak('Smile test complete');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Breadcrumb(current: 'Facial Expression Test'),
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
    return SingleChildScrollView(
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
          SizedBox(height: AppConstants.buttonSpacing * 2),
          Text(
            'You will be asked to keep a neutral face, then smile, then return to neutral',
            style: TextStyle(
              fontSize: AppConstants.bodyFontSize,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppConstants.buttonSpacing * 2),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.all(AppConstants.buttonPadding),
              ),
              child: Text(
                'Start Test',
                style: TextStyle(fontSize: AppConstants.buttonFontSize),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestScreen() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppConstants.buttonSpacing),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_cameraInitialized && _cameraService.controller != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: _cameraService.controller!.value.aspectRatio,
                  child: CameraPreview(_cameraService.controller!),
                ),
              ),
            )
          else
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            ),
          SizedBox(height: AppConstants.buttonSpacing * 2),
          Text(
            _getPhaseEmoji(),
            style: const TextStyle(fontSize: 80),
          ),
          SizedBox(height: 24),
          Text(
            _getPhaseText(),
            style: TextStyle(
              fontSize: AppConstants.headingFontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          if (_currentPhase != SmilePhase.complete)
            Text(
              '${_countdown}s',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
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
    switch (_currentPhase) {
      case SmilePhase.neutral:
        return 'Keep Neutral Face';
      case SmilePhase.smile:
        return 'Smile!';
      case SmilePhase.neutral2:
        return 'Return to Neutral';
      case SmilePhase.complete:
        return 'Complete!';
      default:
        return '';
    }
  }
}