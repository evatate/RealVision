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

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _audioService.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _taskTimer?.cancel();
    _cameraService.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _startFixationTest() async {
    await _cameraService.initialize();
    setState(() {
      _currentTask = EyeTrackingTask.fixation;
      _trialNumber = 1;
      _cameraInitialized = true;
    });
    
    await _audioService.speak(
      'Look closely at the red cross without blinking for 10 seconds',
    );

    _runFixationTrial();
  }

  void _runFixationTrial() {
    if (_trialNumber > 3) {
      _completeFixationTest();
      return;
    }

    _taskTimer = Timer(const Duration(seconds: AppConstants.fixationDuration), () {
      setState(() => _trialNumber++);
      if (_trialNumber <= 3) {
        Future.delayed(const Duration(seconds: 2), _runFixationTrial);
      } else {
        _completeFixationTest();
      }
    });
  }

  void _completeFixationTest() {
    Provider.of<TestProgress>(context, listen: false).markFixationCompleted();
    _audioService.speak('Fixation test complete');
    setState(() {
      _currentTask = EyeTrackingTask.none;
      _trialNumber = 0;
    });
    _cameraService.dispose();
  }

  Future<void> _startProsaccadeTest() async {
    await _cameraService.initialize();
    setState(() {
      _currentTask = EyeTrackingTask.prosaccade;
      _trialNumber = 0;
      _cameraInitialized = true;
    });
    
    await _audioService.speak(
      'Look at the target circle as quickly as possible when it appears',
    );

    _runProsaccadeTrial();
  }

  void _runProsaccadeTrial() {
    if (_trialNumber >= AppConstants.prosaccadeTrials) {
      Provider.of<TestProgress>(context, listen: false).markProsaccadeCompleted();
      _audioService.speak('Pro-saccade test complete');
      setState(() {
        _currentTask = EyeTrackingTask.none;
        _trialNumber = 0;
      });
      _cameraService.dispose();
      return;
    }

    // Target positions (10 locations)
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

    // Center fixation (500ms)
    setState(() => _targetPosition = const Offset(0.5, 0.5));
    
    Future.delayed(const Duration(milliseconds: 500), () {
      // Blank (200ms)
      setState(() => _targetPosition = null);
      
      Future.delayed(const Duration(milliseconds: 200), () {
        // Show target
        final pos = positions[_trialNumber % positions.length];
        setState(() {
          _targetPosition = pos;
          _trialNumber++;
        });
        
        Future.delayed(const Duration(milliseconds: 1500), _runProsaccadeTrial);
      });
    });
  }

  Future<void> _startSmoothPursuitTest() async {
    await _cameraService.initialize();
    setState(() {
      _currentTask = EyeTrackingTask.pursuit;
      _trialNumber = 0;
      _cameraInitialized = true;
    });
    
    await _audioService.speak(
      'Follow the red circle with your eyes as closely as possible',
    );

    _runPursuitTrial();
  }

  void _runPursuitTrial() {
    if (_trialNumber >= AppConstants.smoothPursuitTrials) {
      Provider.of<TestProgress>(context, listen: false).markPursuitCompleted();
      _audioService.speak('Smooth pursuit test complete');
      setState(() {
        _currentTask = EyeTrackingTask.none;
        _trialNumber = 0;
      });
      _cameraService.dispose();
      return;
    }

    final isHorizontal = _trialNumber % 2 == 0;
    final speed = _trialNumber % 4 < 2 ? 10 : 20;
    final frequency = speed == 10 ? 0.25 : 0.5;
    final startTime = DateTime.now();

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_currentTask != EyeTrackingTask.pursuit) {
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
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Text(
            'Eye Tracking Tests',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 48),
          _buildTaskButton(
            'Fixation Stability Test',
            'Look at a cross for 10 seconds',
            _startFixationTest,
          ),
          const SizedBox(height: 24),
          _buildTaskButton(
            'Pro-saccade Test',
            'Look at targets as they appear',
            _startProsaccadeTest,
          ),
          const SizedBox(height: 24),
          _buildTaskButton(
            'Smooth Pursuit Test',
            'Follow a moving circle',
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
          padding: const EdgeInsets.all(24),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 18),
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
        Container(color: Colors.black),
        
        // Camera preview (small in corner)
        if (_cameraInitialized && _cameraService.controller != null)
          Positioned(
            top: 16,
            right: 16,
            child: SizedBox(
              width: 150,
              height: 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CameraPreview(_cameraService.controller!),
              ),
            ),
          ),
        
        // Target display
        if (_targetPosition != null)
          Positioned(
            left: MediaQuery.of(context).size.width * _targetPosition!.dx,
            top: MediaQuery.of(context).size.height * _targetPosition!.dy,
            child: Transform.translate(
              offset: const Offset(-20, -20),
              child: _buildTarget(),
            ),
          ),
        
        // Trial counter
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Trial $_trialNumber',
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

  Widget _buildTarget() {
    switch (_currentTask) {
      case EyeTrackingTask.fixation:
        return const Icon(
          Icons.add,
          size: 40,
          color: Colors.red,
        );
      case EyeTrackingTask.prosaccade:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        );
      case EyeTrackingTask.pursuit:
        return Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}