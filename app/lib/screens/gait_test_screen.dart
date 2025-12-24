import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
    
    Provider.of<TestProgress>(context, listen: false).markGaitCompleted();
    await _audioService.speak('Walking test complete. Step data will sync in background.');
    
    if (mounted) {
      Navigator.pop(context);
    }
    
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
          
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[400]!, width: 2),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, color: Colors.green[900], size: 26),
                SizedBox(height: 8),
                Text(
                  'Install Google Fit',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  Platform.isIOS
                      ? 'After installing:\n1. Open Google Fit\n2. Grant Motion & Fitness permissions\n3. Return to this app'
                      : 'After installing:\n1. Open Google Fit\n2. Complete setup\n3. Grant permissions\n4. Return here',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Use itms-apps:// scheme for iOS to open App Store directly
                    final url = Platform.isIOS
                        ? 'itms-apps://apps.apple.com/app/id1423857595'
                        : 'https://play.google.com/store/apps/details?id=com.google.android.apps.fitness';
                    
                    final uri = Uri.parse(url);
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      // Fallback to web URL for iOS
                      if (Platform.isIOS) {
                        final webUrl = Uri.parse('https://apps.apple.com/us/app/google-fit/id1423857595');
                        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open app store')),
                          );
                        }
                      }
                    }
                  },
                  icon: Icon(Icons.download, color: Colors.white, size: 18),
                  label: Text(
                    'Get Google Fit',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 20),
        ],
      ),
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