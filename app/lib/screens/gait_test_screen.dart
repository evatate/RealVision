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
    try {
      final hasPermission = await _healthService.requestPermissions();
      
      if (!hasPermission && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please install Google Fit or Samsung Health and grant permissions',
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

      await _audioService.speak(
        'Please walk normally for the next 2 minutes',
      );

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
              child: SingleChildScrollView( // MAKES IT SCROLLABLE - FIXES OVERFLOW
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
        Text(
          'Walking Test',
          style: TextStyle(
            fontSize: AppConstants.headingFontSize,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: AppConstants.buttonSpacing * 2),
        Container(
          padding: EdgeInsets.all(AppConstants.buttonPadding),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Column(
            children: [
              Icon(
                Icons.directions_walk,
                size: 80,
                color: AppColors.primary,
              ),
              SizedBox(height: 24),
              Text(
                'This test uses your phone\'s step counter to analyze your walking pattern',
                style: TextStyle(
                  fontSize: AppConstants.bodyFontSize,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Please walk normally for 2 minutes',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
              'Start Walking Test',
              style: TextStyle(fontSize: AppConstants.buttonFontSize),
            ),
          ),
        ),
        SizedBox(height: AppConstants.buttonSpacing),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[300]!, width: 2),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange[700], size: 28),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Install Google Fit or Samsung Health for step tracking',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textDark,
                  ),
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
        Icon(
          Icons.directions_walk,
          size: 120,
          color: AppColors.primary,
        ),
        SizedBox(height: AppConstants.buttonSpacing),
        Text(
          'Recording Walk',
          style: TextStyle(
            fontSize: AppConstants.headingFontSize,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: AppConstants.buttonSpacing * 2),
        Text(
          '${_countdown}s',
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: AppConstants.buttonSpacing),
        Text(
          'Keep walking normally',
          style: TextStyle(
            fontSize: AppConstants.bodyFontSize,
            color: AppColors.textMedium,
          ),
        ),
      ],
    );
  }
}