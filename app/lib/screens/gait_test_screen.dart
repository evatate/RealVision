import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_progress.dart';
import '../services/health_service.dart';
import '../services/audio_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../widgets/breadcrumb.dart';
import 'dart:async';
import 'dart:io' show Platform;

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
    try {
      final hasPermission = await _healthService.requestPermissions();
      
      if (!hasPermission && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please install Google Fit and grant permissions',
              style: TextStyle(fontSize: 18),
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      setState(() {
        _isRecording = true;
        _countdown = AppConstants.gaitTestDuration;
        _startTime = DateTime.now();
      });

      await _audioService.speak('Please walk normally for the next 2 minutes');

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        setState(() {
          _countdown--;
          
          if (_countdown <= 0) {
            timer.cancel();
            _completeTest();
          }
        });
      });
    } catch (e) {
      print('Error starting gait test: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _completeTest() async {
    if (_startTime == null) return;

    final endTime = DateTime.now();
    
    try {
      final gaitData = await _healthService.getGaitData(
        start: _startTime!,
        end: endTime,
      );
      
      print('Gait data collected: $gaitData');
    } catch (e) {
      print('Error getting gait data: $e');
    }

    if (!mounted) return;
    
    setState(() => _isRecording = false);
    
    Provider.of<TestProgress>(context, listen: false).markGaitCompleted();
    await _audioService.speak('Walking test complete');
    
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
              child: Padding(
                padding: EdgeInsets.all(AppConstants.buttonSpacing),
                child: _isRecording
                    ? _buildRecordingScreen()
                    : _buildStartScreen(),
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
        Icon(
          Icons.directions_walk,
          size: 80,
          color: AppColors.primary,
        ),
        SizedBox(height: 32),
        
        // Main instruction as header
        Text(
          'Please walk normally for 2 minutes',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: 48),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.all(24),
            ),
            child: Text(
              'Start Walking Test',
              style: TextStyle(fontSize: 24),
            ),
          ),
        ),
        
        SizedBox(height: 32),
        
        // Larger install instructions
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[300]!, width: 2),
          ),
          child: Text(
            Platform.isIOS
                ? 'iOS uses the built-in Health app for step tracking. Permissions will be requested when you start.'
                : 'Install Google Fit or Samsung Health for step tracking. Permissions will be requested when you start.',
            style: TextStyle(
              fontSize: 20,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.directions_walk,
          size: 100,
          color: AppColors.primary,
        ),
        SizedBox(height: 32),
        
        Text(
          'Recording Walk',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        
        SizedBox(height: 48),
        
        Text(
          '${_countdown}s',
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        
        SizedBox(height: 24),
        
        Text(
          'Keep walking normally',
          style: TextStyle(
            fontSize: 24,
            color: AppColors.textMedium,
          ),
        ),
      ],
    );
  }
}