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
    await _cameraService.initialize();
    setState(() {
      _cameraInitialized = true;
      _currentPhase = SmilePhase.neutral;
      _countdown = AppConstants.smilePhaseDuration;
    });
    
    await _audioService.speak('Please keep a neutral face for 15 seconds');
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Smile Test',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 32),
            Text(
              'You will be asked to keep a neutral face, then smile, then return to neutral',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _startTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Start Test'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
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
                    aspectRatio: 4 / 3,
                    child: CameraPreview(_cameraService.controller!),
                  ),
                ),
              ),
            const SizedBox(height: 48),
            Text(
              _getPhaseEmoji(),
              style: const TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 24),
            Text(
              _getPhaseText(),
              style: Theme.of(context).textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_currentPhase != SmilePhase.complete)
              Text(
                '${_countdown}s',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
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