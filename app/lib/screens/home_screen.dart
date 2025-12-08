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
      await Future.delayed(Duration(milliseconds: AppConstants.audioInstructionDelay));
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
        child: Padding(
          padding: EdgeInsets.all(AppConstants.buttonSpacing),
          child: Column(
            children: [
              // Compact header
              Text(
                'RealVision',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              
              // Test buttons (no scrolling needed)
              Expanded(
                child: Consumer<TestProgress>(
                  builder: (context, progress, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TestButton(
                          icon: Icons.mic,
                          title: 'Speech Test',
                          description: 'Describe a picture',
                          completed: progress.speechCompleted,
                          onPressed: () async {
                            if (_initialized) {
                              await _audioService.speak('Starting speech test');
                              await Future.delayed(Duration(milliseconds: AppConstants.audioInstructionDelay));
                            }
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SpeechTestScreen(),
                                ),
                              );
                            }
                          },
                        ),
                        
                        TestButton(
                          icon: Icons.remove_red_eye,
                          title: 'Eye Tracking',
                          description: 'Follow visual targets',
                          completed: progress.eyeTrackingCompleted,
                          onPressed: () async {
                            if (_initialized) {
                              await _audioService.speak('Starting eye tracking test');
                              await Future.delayed(Duration(milliseconds: AppConstants.audioInstructionDelay));
                            }
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const EyeTrackingScreen(),
                                ),
                              );
                            }
                          },
                        ),
                        
                        TestButton(
                          icon: Icons.sentiment_satisfied,
                          title: 'Smile Test',
                          description: 'Facial expression',
                          completed: progress.smileCompleted,
                          onPressed: () async {
                            if (_initialized) {
                              await _audioService.speak('Starting smile test');
                              await Future.delayed(Duration(milliseconds: AppConstants.audioInstructionDelay));
                            }
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FacialExpressionScreen(),
                                ),
                              );
                            }
                          },
                        ),
                        
                        TestButton(
                          icon: Icons.directions_walk,
                          title: 'Walking Test',
                          description: 'Step tracking',
                          completed: progress.gaitCompleted,
                          onPressed: () async {
                            if (_initialized) {
                              await _audioService.speak('Starting walking test');
                              await Future.delayed(Duration(milliseconds: AppConstants.audioInstructionDelay));
                            }
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const GaitTestScreen(),
                                ),
                              );
                            }
                          },
                        ),
                        
                        SizedBox(height: 8),
                        
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
                              padding: EdgeInsets.all(20),
                            ),
                            child: Text(
                              'View Results',
                              style: TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
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
          style: TextStyle(fontSize: 32),
        ),
        content: Text(
          'All tests completed. Results will be analyzed.',
          style: TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Option to redo tests
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Redo Tests?', style: TextStyle(fontSize: 28)),
                  content: Text(
                    'Would you like to redo any tests?',
                    style: TextStyle(fontSize: 20),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        // Reset progress
                        Provider.of<TestProgress>(context, listen: false).resetProgress();
                        Navigator.pop(ctx);
                      },
                      child: Text('Yes, Redo All', style: TextStyle(fontSize: 20)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('No, Keep Results', style: TextStyle(fontSize: 20)),
                    ),
                  ],
                ),
              );
            },
            child: Text('OK', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}