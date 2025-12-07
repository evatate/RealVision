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
import 'dart:math';

enum EyeTrackingTask { none, fixation, prosaccade, pursuit }

class EyeTrackingScreen extends StatefulWidget {
  const EyeTrackingScreen({super.key});

  @override
  State<EyeTrackingScreen> createState() => _EyeTrackingScreenState();
}

class _EyeTrackingScreenState extends State<EyeTrackingScreen> {
  final CameraService _cameraService = CameraService();
  final AudioService _audioService = AudioService();
  
  EyeTrackingTask _currentTask = EyeTrackingTask.none;
  int _trialNumber = 0;
  Offset? _targetPosition;
  Timer? _taskTimer;
  bool _cameraInitialized = false;
  bool _showTarget = true;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _audioService.initialize();
    } catch (e) {
      print('Audio init error: $e');
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _taskTimer?.cancel();
    _cameraService.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _startFixationTest() async {
    try {
      await _cameraService.initialize();
      if (!mounted) return;
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _currentTask = EyeTrackingTask.fixation;
        _trialNumber = 0;
        _cameraInitialized = true;
        _showTarget = true;
        _targetPosition = const Offset(0.5, 0.5); // CENTER
      });
      
      await _audioService.speak(
        'Look closely at the red cross without blinking for 10 seconds. Trial 1 of ${AppConstants.fixationTrials}.',
      );

      _runFixationTrial();
    } catch (e) {
      print('Camera error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _runFixationTrial() {
    if (_trialNumber >= AppConstants.fixationTrials) {
      _completeFixationTest();
      return;
    }

    _trialNumber++;
    
    // keep cross in center for entire duration
    setState(() => _targetPosition = const Offset(0.5, 0.5));
    
    _taskTimer = Timer(Duration(seconds: AppConstants.fixationDuration), () {
      if (_trialNumber < AppConstants.fixationTrials) {
        _audioService.speak('Trial ${_trialNumber + 1} of ${AppConstants.fixationTrials}');
        Future.delayed(const Duration(seconds: 2), _runFixationTrial);
      } else {
        _completeFixationTest();
      }
    });
  }

  void _completeFixationTest() {
    Provider.of<TestProgress>(context, listen: false).markFixationCompleted();
    _audioService.speak('Fixation test complete');
    if (mounted) {
      setState(() {
        _currentTask = EyeTrackingTask.none;
        _trialNumber = 0;
      });
    }
    _cameraService.dispose();
  }

  Future<void> _startProsaccadeTest() async {
    try {
      await _cameraService.initialize();
      if (!mounted) return;
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _currentTask = EyeTrackingTask.prosaccade;
        _trialNumber = 0;
        _cameraInitialized = true;
      });
      
      await _audioService.speak(
        'Look at the target circle as quickly as possible when it appears',
      );

      _runProsaccadeTrial();
    } catch (e) {
      print('Camera error: $e');
    }
  }

  void _runProsaccadeTrial() {
    if (_trialNumber >= AppConstants.prosaccadeTestTrials) {
      Provider.of<TestProgress>(context, listen: false).markProsaccadeCompleted();
      _audioService.speak('Pro-saccade test complete');
      if (mounted) {
        setState(() {
          _currentTask = EyeTrackingTask.none;
          _trialNumber = 0;
        });
      }
      _cameraService.dispose();
      return;
    }

    final positions = [
      const Offset(0.3, 0.5),  // 5° left
      const Offset(0.7, 0.5),  // 5° right
      const Offset(0.2, 0.5),  // 10° left
      const Offset(0.8, 0.5),  // 10° right
      const Offset(0.1, 0.5),  // 15° left
      const Offset(0.9, 0.5),  // 15° right
      const Offset(0.5, 0.3),  // 5° up
      const Offset(0.5, 0.7),  // 5° down
      const Offset(0.5, 0.2),  // 10° up
      const Offset(0.5, 0.8),  // 10° down
    ];

    setState(() {
      _targetPosition = const Offset(0.5, 0.5);
      _showTarget = true;
    });
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _currentTask != EyeTrackingTask.prosaccade) return;
      
      setState(() => _showTarget = false);
      
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || _currentTask != EyeTrackingTask.prosaccade) return;
        
        final pos = positions[_trialNumber % positions.length];
        setState(() {
          _targetPosition = pos;
          _showTarget = true;
          _trialNumber++;
        });
        
        Future.delayed(const Duration(milliseconds: 1500), _runProsaccadeTrial);
      });
    });
  }

  Future<void> _startSmoothPursuitTest() async {
    try {
      await _cameraService.initialize();
      if (!mounted) return;
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _currentTask = EyeTrackingTask.pursuit;
        _trialNumber = 0;
        _cameraInitialized = true;
      });
      
      await _audioService.speak(
        'Follow the red circle with your eyes as closely as possible',
      );

      _runPursuitTrial();
    } catch (e) {
      print('Camera error: $e');
    }
  }

  void _runPursuitTrial() {
    if (_trialNumber >= AppConstants.smoothPursuitTestTrials) {
      Provider.of<TestProgress>(context, listen: false).markPursuitCompleted();
      _audioService.speak('Smooth pursuit test complete');
      if (mounted) {
        setState(() {
          _currentTask = EyeTrackingTask.none;
          _trialNumber = 0;
        });
      }
      _cameraService.dispose();
      return;
    }

    final isHorizontal = _trialNumber % 2 == 0;
    final speed = _trialNumber % 4 < 2 ? 10 : 20;
    final frequency = speed == 10 ? 0.25 : 0.5;
    final startTime = DateTime.now();

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _currentTask != EyeTrackingTask.pursuit) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000;
      
      if (elapsed > 10) {
        timer.cancel();
        setState(() => _trialNumber++);
        Future.delayed(const Duration(seconds: 1), _runPursuitTrial);
        return;
      }

      final position = 0.5 + 0.2 * sin(2 * pi * frequency * elapsed);
      
      setState(() {
        _targetPosition = isHorizontal
            ? Offset(position, 0.5)
            : Offset(0.5, position);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (_currentTask == EyeTrackingTask.none)
              const Breadcrumb(current: 'Eye Tracking'),
            Expanded(
              child: _currentTask == EyeTrackingTask.none
                  ? _buildTaskSelection()
                  : _buildTaskScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskSelection() {
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
          SizedBox(height: AppConstants.buttonSpacing * 2),
          _buildTaskButton(
            'Fixation Stability Test',
            'Look at a red cross for 10 seconds',
            _startFixationTest,
          ),
          SizedBox(height: AppConstants.buttonSpacing),
          _buildTaskButton(
            'Pro-saccade Test',
            'Look at targets as they appear',
            _startProsaccadeTest,
          ),
          SizedBox(height: AppConstants.buttonSpacing),
          _buildTaskButton(
            'Smooth Pursuit Test',
            'Follow a moving red circle',
            _startSmoothPursuitTest,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskButton(String title, String description, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.all(AppConstants.buttonPadding),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: AppConstants.bodyFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskScreen() {
    return Stack(
      children: [
        // Full screen black background
        Container(color: Colors.black),
        
        // Main test area with targets
        Center(
          child: _showTarget && _targetPosition != null
              ? FractionallySizedBox(
                  widthFactor: 1.0,
                  heightFactor: 1.0,
                  child: Stack(
                    children: [
                      // Target positioned as fraction of screen
                      Positioned(
                        left: MediaQuery.of(context).size.width * _targetPosition!.dx - 30,
                        top: MediaQuery.of(context).size.height * _targetPosition!.dy - 30,
                        child: _buildTarget(),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        
        // camera preview (small, in corner, ONLY for eye tracking)
        if (_cameraInitialized && _cameraService.controller != null)
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
        
        // Trial counter at bottom
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                'Trial $_trialNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTarget() {
    switch (_currentTask) {
      case EyeTrackingTask.fixation:
        // red cross, centered
        return Icon(
          Icons.add,
          size: 80,
          color: AppColors.fixationCross,
        );
        
      case EyeTrackingTask.prosaccade:
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.prosaccadeCenter,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.prosaccadeInner,
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