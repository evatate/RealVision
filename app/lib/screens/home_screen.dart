import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_progress.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../widgets/test_button.dart';
import '../services/service_locator.dart';
import '../services/audio_service.dart';
import '../services/connectivity_service.dart';
import 'gait_test_screen.dart';
import 'speech_test_screen.dart';
import 'eye_tracking_screen.dart';
import 'facial_expression_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  Future<void> _navigateToTest(Widget screen, String testName) async {
    // Check internet connectivity before starting test
    final hasConnection = await ConnectivityService.checkConnectivityAndShowDialog(context);
    if (!hasConnection) {
      return; // Dialog shown, don't proceed
    }

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
          padding: EdgeInsets.symmetric(horizontal: AppConstants.buttonSpacing, vertical: 16), // Reduced vertical padding
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
              SizedBox(height: 24), // Reduced spacing
              
              Expanded(
                child: Consumer<TestProgress>(
                  builder: (context, progress, child) {
                    return SingleChildScrollView( // Added scroll view for smaller screens
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                            
                            SizedBox(height: 40),
                            
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
                            
                            SizedBox(height: 40),
                            
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
                            
                            SizedBox(height: 40),
                            
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
                            
                          ],
                        ),
                      ),
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
          "You've finished all the behavioral tasks. Please return to the earlier survey using your return code to continue where you left off and answer some brief feedback questions (5-10 minutes). If you cannot continue where you left off, please contact the research team.",
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
            },
            child: Text('Redo All Tests', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }
}