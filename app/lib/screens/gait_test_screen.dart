import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_progress.dart';
import '../models/gait_data.dart';
import '../services/motion_sensor_service.dart';
import '../services/audio_service.dart';
import '../services/data_export_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../widgets/breadcrumb.dart';
import 'dart:async';
import '../services/service_locator.dart';
import 'gait_results_screen.dart';

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

    // Stop recording and get trial data
    final trialData = _motionService.stopRecording(_startTime!, _endTime!);

    // Extract features from the trial
    final features = GaitFeatureExtraction.extractTrialFeatures(trialData);

    // Create session data
    final sessionData = GaitSessionData(
      participantId: 'participant_001', 
      sessionId: 'gait_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: _startTime!,
      trials: [trialData],
      features: features,
    );

    Provider.of<TestProgress>(context, listen: false).markGaitCompleted();

    // Export the data
    final dataExportService = getIt<DataExportService>();
    try {
      await dataExportService.exportGaitSession(sessionData);
      AppLogger.logger.info('Gait session data exported successfully');
    } catch (e) {
      AppLogger.logger.warning('Failed to export gait session data: $e');
    }

    await _audioService.speak(
      'Walking test complete. You took ${trialData.stepCount} steps. '
      'Your gait quality score is ${features.gaitQualityScore.toStringAsFixed(2)}.'
    );

    AppLogger.logger.info('==== WALKING TEST RESULTS ====');
    AppLogger.logger.info('Steps: ${trialData.stepCount}');
    AppLogger.logger.info('Duration: ${trialData.duration.toStringAsFixed(1)} s');
    AppLogger.logger.info('Cadence: ${features.cadence.toStringAsFixed(1)} steps/min');
    AppLogger.logger.info('Step Time: ${features.stepTime.toStringAsFixed(2)} s');
    AppLogger.logger.info('Step Time Variability: ${features.stepTimeVariability.toStringAsFixed(3)}');
    AppLogger.logger.info('Gait Regularity: ${features.gaitRegularity.toStringAsFixed(3)}');
    AppLogger.logger.info('Gait Symmetry: ${features.gaitSymmetry.toStringAsFixed(3)}');
    AppLogger.logger.info('Gait Quality Score: ${features.gaitQualityScore.toStringAsFixed(3)}');
    AppLogger.logger.info('==============================');

    // Navigate to results screen
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => GaitResultsScreen(sessionData: sessionData),
          ),
        );
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