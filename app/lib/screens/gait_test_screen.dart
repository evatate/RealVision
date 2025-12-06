import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_progress.dart';
import '../services/health_service.dart';
import '../services/audio_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../widgets/breadcrumb.dart';
import 'dart:async';

class GaitTestScreen extends StatefulWidget {
  const GaitTestScreen({super.key});

  @override
  State<GaitTestScreen> createState() => _GaitTestScreenState();
}

class _GaitTestScreenState extends State<GaitTestScreen> {
  final HealthService _healthService = HealthService();
  final AudioService _audioService = AudioService();
  
  bool _isRecording = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _audioService.initialize();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _startTest() async {
    final hasPermission = await _healthService.requestPermissions();
    
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health permissions are required for this test'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _countdown = AppConstants.gaitTestDuration;
      _startTime = DateTime.now();
    });

    await _audioService.speak(
      'Please walk normally for the next 2 minutes. The app will track your steps.',
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
        
        if (_countdown <= 0) {
          timer.cancel();
          _completeTest();
        }
      });
    });
  }

  Future<void> _completeTest() async {
    if (_startTime == null) return;

    final endTime = DateTime.now();
    
    // Get gait data from health service
    final gaitData = await _healthService.getGaitData(
      start: _startTime!,
      end: endTime,
    );
    
    print('Gait data collected: $gaitData'); // For debugging

    setState(() => _isRecording = false);
    
    Provider.of<TestProgress>(context, listen: false).markGaitCompleted();
    await _audioService.speak('Walking test complete');
    
    // TODO: Send gait data to backend or save for model inference
    // For now, the data is just printed to console
    
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
            const Breadcrumb(current: 'Walking Test'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: _isRecording
                      ? _buildRecordingScreen()
                      : _buildStartScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Walking Test',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.directions_walk,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'This test uses your phone\'s step counter to analyze your walking pattern',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Please walk normally for 2 minutes',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMedium,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          onPressed: _startTest,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('Start Walking Test'),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.yellow[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.yellow[700]!, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Note: For Android, install Google Fit or Samsung Health',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.directions_walk,
          size: 120,
          color: AppColors.primary,
        ),
        const SizedBox(height: 32),
        Text(
          'Recording Walk',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 48),
        Text(
          '${_countdown}s',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: AppColors.primary,
                fontSize: 72,
              ),
        ),
        const SizedBox(height: 24),
        Text(
          'Keep walking normally',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textMedium,
              ),
        ),
      ],
    );
  }
}