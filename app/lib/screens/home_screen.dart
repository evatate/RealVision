import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_progress.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../widgets/test_button.dart';
import '../services/audio_service.dart';
import 'speech_test_screen.dart';
import 'eye_tracking_screen.dart';
import 'facial_expression_screen.dart';
import 'gait_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioService _audioService = AudioService();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      await _audioService.initialize();
      setState(() => _initialized = true);
      await Future.delayed(const Duration(milliseconds: 500));
      await _audioService.speak('Welcome to Real Vision. Please choose a test.');
    } catch (e) {
      print('Audio initialization error: $e');
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header (not scrollable)
            Padding(
              padding: EdgeInsets.all(AppConstants.buttonSpacing),
              child: Column(
                children: [
                  Text(
                    'RealVision',
                    style: TextStyle(
                      fontSize: AppConstants.titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memory and Thinking Assessment',
                    style: TextStyle(
                      fontSize: AppConstants.bodyFontSize,
                      color: AppColors.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Scrollable test buttons
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: AppConstants.buttonSpacing),
                child: Consumer<TestProgress>(
                  builder: (context, progress, child) {
                    return Column(
                      children: [
                        TestButton(
                          icon: Icons.mic,
                          title: 'Speech Test',
                          description: 'Describe a picture',
                          completed: progress.speechCompleted,
                          onPressed: () async {
                            if (_initialized) {
                              await _audioService.speak('Starting speech test');
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SpeechTestScreen(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: AppConstants.buttonSpacing),
                        
                        TestButton(
                          icon: Icons.remove_red_eye,
                          title: 'Eye Tracking',
                          description: 'Follow visual targets',
                          completed: progress.eyeTrackingCompleted,
                          onPressed: () async {
                            if (_initialized) {
                              await _audioService.speak('Starting eye tracking test');
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EyeTrackingScreen(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: AppConstants.buttonSpacing),
                        
                        TestButton(
                          icon: Icons.sentiment_satisfied,
                          title: 'Facial Expression',
                          description: 'Smile test',
                          completed: progress.smileCompleted,
                          onPressed: () async {
                            if (_initialized) {
                              await _audioService.speak('Starting smile test');
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FacialExpressionScreen(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: AppConstants.buttonSpacing),
                        
                        TestButton(
                          icon: Icons.directions_walk,
                          title: 'Walking Test',
                          description: 'Step tracking',
                          completed: progress.gaitCompleted,
                          onPressed: () async {
                            if (_initialized) {
                              await _audioService.speak('Starting walking test');
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GaitTestScreen(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: AppConstants.buttonSpacing * 2),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: progress.allTestsCompleted
                                ? () async {
                                    if (_initialized) {
                                      await _audioService.speak('All tests completed');
                                    }
                                    _showResultsDialog(context);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              disabledBackgroundColor: AppColors.border,
                              padding: EdgeInsets.all(AppConstants.buttonPadding),
                            ),
                            child: Text(
                              'View Results',
                              style: TextStyle(fontSize: AppConstants.buttonFontSize),
                            ),
                          ),
                        ),
                        SizedBox(height: AppConstants.buttonSpacing),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Assessment Complete',
          style: TextStyle(fontSize: AppConstants.headingFontSize),
        ),
        content: Text(
          'All tests have been completed. Results will be analyzed by your healthcare provider.',
          style: TextStyle(fontSize: AppConstants.bodyFontSize),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(fontSize: AppConstants.bodyFontSize),
            ),
          ),
        ],
      ),
    );
  }
}