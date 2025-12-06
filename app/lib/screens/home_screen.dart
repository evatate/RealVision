import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_progress.dart';
import '../utils/colors.dart';
import '../widgets/test_button.dart';
import 'speech_test_screen.dart';
import 'eye_tracking_screen.dart';
import 'facial_expression_screen.dart';
import 'gait_test_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'RealVision',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Memory and Thinking Assessment',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textMedium,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 64),
                Consumer<TestProgress>(
                  builder: (context, progress, child) {
                    return Column(
                      children: [
                        TestButton(
                          icon: Icons.mic,
                          title: 'Speech Test',
                          description: 'Describe a picture',
                          completed: progress.speechCompleted,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SpeechTestScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        TestButton(
                          icon: Icons.remove_red_eye,
                          title: 'Eye Tracking',
                          description: 'Follow visual targets',
                          completed: progress.eyeTrackingCompleted,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EyeTrackingScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        TestButton(
                          icon: Icons.sentiment_satisfied,
                          title: 'Facial Expression',
                          description: 'Smile test',
                          completed: progress.smileCompleted,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FacialExpressionScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        TestButton(
                          icon: Icons.directions_walk,
                          title: 'Walking Test',
                          description: 'Step tracking',
                          completed: progress.gaitCompleted,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GaitTestScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 48),
                        ElevatedButton(
                          onPressed: progress.allTestsCompleted
                              ? () {
                                  _showResultsDialog(context);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            disabledBackgroundColor: AppColors.border,
                          ),
                          child: const Text('View Results'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResultsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assessment Complete'),
        content: const Text(
          'All tests have been completed. Results will be analyzed by your healthcare provider.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}