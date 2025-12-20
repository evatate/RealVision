import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../services/service_locator.dart';

enum EyeTrackingTask { none, fixation, prosaccade, pursuit }

class EyeTrackingScreen extends StatefulWidget {
  const EyeTrackingScreen({super.key});

  @override
  State<EyeTrackingScreen> createState() => _EyeTrackingScreenState();
}

class _EyeTrackingScreenState extends State<EyeTrackingScreen> {
  late CameraService _cameraService = CameraService();
  late AudioService _audioService = AudioService();
  
  EyeTrackingTask _currentTask = EyeTrackingTask.none;
  int _trialNumber = 0;
  bool _isPractice = false;
  Offset? _targetPosition;
  Timer? _taskTimer;
  bool _cameraInitialized = false;
  bool _showTarget = true;

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

  void _showInstructions(String title, String instruction, VoidCallback onStart) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          title,
          style: TextStyle(
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
              style: TextStyle(
                fontSize: 22,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[300]!, width: 2),
              ),
              child: Text(
                'Starting with practice round...',
                style: TextStyle(
                  fontSize: 20, 
                  fontStyle: FontStyle.italic,
                  color: Colors.blue[900],
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
                padding: EdgeInsets.all(16),
              ),
              child: Text(
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
          await _cameraService.initialize();
          if (!mounted) return;
          
          await Future.delayed(const Duration(milliseconds: 500));
          
          setState(() {
            _currentTask = EyeTrackingTask.fixation;
            _isPractice = true;
            _trialNumber = 0;
            _cameraInitialized = true;
            _showTarget = true;
            _targetPosition = const Offset(0.5, 0.5);
          });
          
          await _audioService.speak('Practice trial. Look at the red cross.');
          _runFixationTrial();
        } catch (e) {
          print('Camera error: $e');
        }
      },
    );
  }

  void _runFixationTrial() {
    final maxTrials = _isPractice 
        ? AppConstants.fixationPracticeTrials 
        : AppConstants.fixationTestTrials;
    
    if (_trialNumber >= maxTrials) {
      if (_isPractice) {
        // Practice done, start real trials
        setState(() {
          _isPractice = false;
          _trialNumber = 0;
        });
        _audioService.speak('Practice complete. Starting test trials. Trial 1 of ${AppConstants.fixationTestTrials}');
        Future.delayed(const Duration(seconds: 2), _runFixationTrial);
      } else {
        _completeFixationTest();
      }
      return;
    }

    _trialNumber++;
    setState(() => _targetPosition = const Offset(0.5, 0.5));
    
    _taskTimer = Timer(Duration(seconds: AppConstants.fixationDuration), () {
      if (_trialNumber < maxTrials) {
        final label = _isPractice ? 'practice' : 'test';
        _audioService.speak('${label.capitalize()} trial ${_trialNumber + 1}');
        Future.delayed(const Duration(seconds: 2), _runFixationTrial);
      } else {
        _runFixationTrial(); // Will trigger next phase or completion
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
    _showInstructions(
      'Pro-saccade Test',
      'Look at the target circle as quickly as possible when it appears',
      () async {
        try {
          await _cameraService.initialize();
          if (!mounted) return;
          
          setState(() {
            _currentTask = EyeTrackingTask.prosaccade;
            _isPractice = true;
            _trialNumber = 0;
            _cameraInitialized = true;
          });
          
          await _audioService.speak('Practice trials. Look at targets quickly.');
          _runProsaccadeTrial();
        } catch (e) {
          print('Camera error: $e');
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
        });
        _audioService.speak('Practice complete. Starting test trials.');
        Future.delayed(const Duration(seconds: 2), _runProsaccadeTrial);
      } else {
        Provider.of<TestProgress>(context, listen: false).markProsaccadeCompleted();
        _audioService.speak('Pro-saccade test complete');
        if (mounted) {
          setState(() {
            _currentTask = EyeTrackingTask.none;
            _trialNumber = 0;
          });
        }
        _cameraService.dispose();
      }
      return;
    }

    final positions = [
      const Offset(0.3, 0.5), const Offset(0.7, 0.5),
      const Offset(0.2, 0.5), const Offset(0.8, 0.5),
      const Offset(0.1, 0.5), const Offset(0.9, 0.5),
      const Offset(0.5, 0.3), const Offset(0.5, 0.7),
      const Offset(0.5, 0.2), const Offset(0.5, 0.8),
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
    _showInstructions(
      'Smooth Pursuit Test',
      'Follow the red circle with your eyes as closely as possible',
      () async {
        try {
          await _cameraService.initialize();
          if (!mounted) return;
          
          setState(() {
            _currentTask = EyeTrackingTask.pursuit;
            _isPractice = true;
            _trialNumber = 0;
            _cameraInitialized = true;
          });
          
          await _audioService.speak('Practice trials. Follow the red circle.');
          _runPursuitTrial();
        } catch (e) {
          print('Camera error: $e');
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
        Future.delayed(const Duration(seconds: 2), _runPursuitTrial);
      } else {
        Provider.of<TestProgress>(context, listen: false).markPursuitCompleted();
        _audioService.speak('Smooth pursuit test complete');
        if (mounted) {
          setState(() {
            _currentTask = EyeTrackingTask.none;
            _trialNumber = 0;
          });
        }
        _cameraService.dispose();
      }
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
          
          _buildTaskButton('Fixation Stability Test', _startFixationTest),
          SizedBox(height: AppConstants.buttonSpacing),
          
          _buildTaskButton('Pro-saccade Test', _startProsaccadeTest),
          SizedBox(height: AppConstants.buttonSpacing),
          
          _buildTaskButton('Smooth Pursuit Test', _startSmoothPursuitTest),
        ],
      ),
    );
  }

  Widget _buildTaskButton(String title, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.all(AppConstants.buttonPadding),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: AppConstants.testTitleFontSize,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildTaskScreen() {
    return Stack(
      children: [
        Container(color: Colors.black),
        
        Center(
          child: _showTarget && _targetPosition != null
              ? FractionallySizedBox(
                  widthFactor: 1.0,
                  heightFactor: 1.0,
                  child: Stack(
                    children: [
                      Positioned(
                        left: MediaQuery.of(context).size.width * _targetPosition!.dx - 40,
                        top: MediaQuery.of(context).size.height * _targetPosition!.dy - 40,
                        child: _buildTarget(),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        
        // Camera preview (only in debug mode)
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

  Widget _buildTarget() {
    switch (_currentTask) {
      case EyeTrackingTask.fixation:
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