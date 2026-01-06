import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../services/service_locator.dart';
import '../services/audio_service.dart';
import '../services/aws_auth_service.dart';
import '../utils/logger.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  String _statusMessage = 'Initializing...';

  bool _instructionsSpoken = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Record start time to ensure minimum splash duration (prevents flicker)
    final startTime = DateTime.now();
    const minSplashDuration = Duration(seconds: 2);
    
    try {
      setState(() => _statusMessage = 'Checking authentication...');
      
      // Ensure user is signed in (checks existing session first, only creates new user if needed)
      final awsAuth = getIt<AWSAuthService>();
      final userId = await awsAuth.ensureSignedIn();
      
      if (userId != null) {
        AppLogger.logger.info('User authenticated: $userId');
      } else {
        AppLogger.logger.warning('Authentication failed');
      }

      setState(() => _statusMessage = 'Setting up audio...');
      final audioService = getIt<AudioService>();
      await audioService.initialize();
      
      // Ensure minimum splash duration
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < minSplashDuration) {
        await Future.delayed(minSplashDuration - elapsed);
      }
      
      setState(() {
        _isLoading = false;
        _statusMessage = 'Ready!';
      });
    } catch (e) {
      AppLogger.logger.severe('Initialization error: $e');
      
      // Still respect minimum duration
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < minSplashDuration) {
        await Future.delayed(minSplashDuration - elapsed);
      }
      
      setState(() {
        _isLoading = false;
        _statusMessage = 'Ready (some services unavailable)';
      });
    }

    final audioService = getIt<AudioService>();
    if (mounted && !_instructionsSpoken) {
      _instructionsSpoken = true;
      await audioService.speak(
        'Complete all four tests. '
        'Start with the walking test. '
        'Find a quiet, well lit space. '
        'Follow the audio instructions. '
        'Press Start Assessment to begin.'
      );
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 40,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Container(
                    width: 80, 
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.remove_red_eye,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  
                  SizedBox(height: 16), 
                  
                  Text(
                    'RealVision',
                    style: TextStyle(
                      fontSize: 40, 
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  
                  SizedBox(height: 6),
                  
                  Text(
                    'Cognitive Assessment Tool',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textMedium,
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  if (_isLoading)
                    Column(
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  
                  SizedBox(height: 12),
                  
                  // Instructions
                  Container(
                    padding: EdgeInsets.all(16), 
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[300]!, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Test Instructions',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildInstruction('1', 'Complete all 4 tests'),
                        SizedBox(height: 12),
                        _buildInstruction('2', 'Start with Walking Test'),
                        SizedBox(height: 12),
                        _buildInstruction('3', 'Find a quiet, well-lit space'),
                        SizedBox(height: 12),
                        _buildInstruction('4', 'Follow audio instructions'),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 48),
                  
                  if (!_isLoading)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _navigateToHome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.all(16), 
                        ),
                        child: Text(
                          'Start Assessment',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  
                  SizedBox(height: 12), 
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24, 
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 24,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}