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
import '../services/service_locator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  Future<void> _navigateToTest(Widget screen, String testName) async {
    // Get audio service only when needed
    final audioService = getIt<AudioService>();
    
    if (!audioService.isInitialized) {
      await audioService.initialize();
    }
  
    await audioService.speak('Starting $testName');
    await Future.delayed(Duration(milliseconds: 500));
  
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
    }
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
              Text(
                'RealVision',
                style: TextStyle(
                  fontSize: AppConstants.titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              
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
                          onPressed: () => _navigateToTest(
                            const SpeechTestScreen(),
                            'speech test',
                          ),
                        ),
                        
                        TestButton(
                          icon: Icons.remove_red_eye,
                          title: 'Eye Tracking',
                          description: 'Follow visual targets',
                          completed: progress.eyeTrackingCompleted,
                          onPressed: () => _navigateToTest(
                            const EyeTrackingScreen(),
                            'eye tracking test',
                          ),
                        ),
                        
                        TestButton(
                          icon: Icons.sentiment_satisfied,
                          title: 'Smile Test',
                          description: 'Facial expression',
                          completed: progress.smileCompleted,
                          onPressed: () => _navigateToTest(
                            const FacialExpressionScreen(),
                            'smile test',
                          ),
                        ),
                        
                        TestButton(
                          icon: Icons.directions_walk,
                          title: 'Walking Test',
                          description: 'Step tracking',
                          completed: progress.gaitCompleted,
                          onPressed: () => _navigateToTest(
                            const GaitTestScreen(),
                            'walking test',
                          ),
                        ),
                        
                        SizedBox(height: 8),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: progress.allTestsCompleted
                                ? () {
                                    /* if (_initialized) {
                                      _audioService.speak('All tests completed');
                                    } */
                                    _showResultsDialog(context, progress);
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

  void _showResultsDialog(BuildContext context, TestProgress progress) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Assessment Complete',
          style: TextStyle(fontSize: 28),
        ),
        content: Text(
          'All tests completed successfully. Would you like to redo any tests or finish?',
          style: TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: Text('Keep Results', style: TextStyle(fontSize: 20)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              progress.resetProgress();
              /*if (_initialized) {
                _audioService.speak('All tests have been reset. You may now redo them.');
              } */
            },
            child: Text('Redo All Tests', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }
}