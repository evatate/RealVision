import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_progress.dart';
import '../services/motion_sensor_service.dart';
import '../services/audio_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../widgets/breadcrumb.dart';
import 'dart:async';
import '../services/service_locator.dart';

class GaitTestScreen extends StatefulWidget {
  const GaitTestScreen({super.key});

  @override
  State<GaitTestScreen> createState() => _GaitTestScreenState();
}

class _GaitTestScreenState extends State<GaitTestScreen> {
  final MotionSensorService _motionService = MotionSensorService();
  late AudioService _audioService;
  
  bool _isRecording = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  Timer? _stepUpdateTimer;
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    _audioService = getIt<AudioService>();
    _audioService.initialize();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stepUpdateTimer?.cancel();
    _motionService.dispose();
    super.dispose();
  }

  Future<void> _startTest() async {
    setState(() {
      _isRecording = true;
      _countdown = AppConstants.gaitTestDuration;
      _startTime = DateTime.now();
    });

    await _audioService.speak('Please walk normally for the next 2 minutes. Your steps are being counted.');

    // Start motion sensor recording
    _motionService.startRecording();
    
    // Update step count display every second
    _stepUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });

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
  }

  Future<void> _completeTest() async {
    if (_startTime == null) return;

    _endTime = DateTime.now();
    
    setState(() => _isRecording = false);
    _stepUpdateTimer?.cancel();
    
    // Stop recording and get results
    final gaitData = _motionService.stopRecording(_startTime!, _endTime!);
    
    Provider.of<TestProgress>(context, listen: false).markGaitCompleted();
    
    await _audioService.speak(
      'Walking test complete. You took ${gaitData['steps']} steps.'
    );
    
    print('==== WALKING TEST RESULTS ====');
    print('Steps: ${gaitData['steps']}');
    print('Duration: ${gaitData['durationMinutes']} min');
    print('Cadence: ${gaitData['cadence']} steps/min');
    print('Avg Acceleration: ${gaitData['avgAcceleration']} m/s²');
    print('Acceleration Variability: ${gaitData['accelerationVariability']}');
    print('Rotation Rate: ${gaitData['rotationRate']} rad/s');
    print('Data Source: ${gaitData['dataSource']}');
    print('==============================');
    
    Future.delayed(const Duration(seconds: 3), () {
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
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 20),
          
          Icon(
            Icons.directions_walk,
            size: 70,
            color: AppColors.primary,
          ),
          SizedBox(height: 20),
          
          Text(
            'Please walk normally for 2 minutes',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 28),
          
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[300]!, width: 2),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[900], size: 26),
                SizedBox(height: 8),
                Text(
                  'Using Motion Sensors',
                  style: TextStyle(
                    fontSize: 20,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Keep your phone in your pocket or hand while walking. The app will count your steps using the accelerometer.',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          SizedBox(height: 28),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.all(18),
              ),
              child: Text(
                'Start Walking Test',
                style: TextStyle(fontSize: 22, color: Colors.white),
              ),
            ),
          ),
          
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRecordingScreen() {
    final currentSteps = _motionService.currentStepCount;
    
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
        
        // Step counter
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green[300]!, width: 3),
          ),
          child: Column(
            children: [
              Text(
                '$currentSteps',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'steps',
                style: TextStyle(
                  fontSize: 24,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 32),
        
        Text(
          '${_countdown}s',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
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