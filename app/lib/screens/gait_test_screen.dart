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
  DateTime? _endTime;
  bool _waitingForSync = false;

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
              Platform.isIOS 
                ? 'Please enable Motion & Fitness in Settings > Privacy & Security'
                : 'Please install Google Fit and grant permissions',
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

    _endTime = DateTime.now();
    
    setState(() {
      _isRecording = false;
      _waitingForSync = true;
    });
    
    // Mark as completed immediately so user can continue
    Provider.of<TestProgress>(context, listen: false).markGaitCompleted();
    await _audioService.speak('Walking test complete. Step data will sync in background.');
    
    // Return to home screen
    if (mounted) {
      Navigator.pop(context);
    }
    
    // Query data after 2 minutes in background
    Future.delayed(const Duration(minutes: 2), () async {
      if (_startTime == null || _endTime == null) return;
      
      try {
        final gaitData = await _healthService.getGaitData(
          start: _startTime!,
          end: _endTime!,
        );
        
        print('==== WALKING TEST RESULTS (queried 2 min later) ====');
        print('Steps: ${gaitData['steps']}');
        print('Duration: ${gaitData['durationMinutes']} min');
        print('Distance: ${gaitData['distance']} m');
        print('Avg Speed: ${gaitData['avgSpeed']} m/s');
        print('Message: ${gaitData['message']}');
        print('===================================================');
      } catch (e) {
        print('Error getting delayed gait data: $e');
      }
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
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
          ),
        ),
        
        SizedBox(height: 32),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[300]!, width: 2),
          ),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[900], size: 32),
              SizedBox(height: 12),
              Text(
                Platform.isIOS
                    ? 'Make sure Motion & Fitness is enabled:\nSettings > Privacy & Security > Motion & Fitness'
                    : 'Install Google Fit or Samsung Health\nfor step tracking',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
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