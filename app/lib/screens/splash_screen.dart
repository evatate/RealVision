import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../services/service_locator.dart';
import '../services/audio_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  String _statusMessage = 'Initializing services...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _statusMessage = 'Setting up audio...');
      await Future.delayed(Duration(milliseconds: 500));
      final audioService = getIt<AudioService>();
      await audioService.initialize();
      
      setState(() {
        _isLoading = false;
        _statusMessage = 'Ready!';
      });
    } catch (e) {
      print('Initialization error: $e');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Ready (some services unavailable)';
      });
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
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 40),
              
              // App Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.remove_red_eye,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              
              SizedBox(height: 24),
              
              Text(
                'RealVision',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              
              SizedBox(height: 8),
              
              Text(
                'Cognitive Assessment Tool',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.textMedium,
                ),
              ),
              
              SizedBox(height: 48),
              
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
              
              // Remove the "Ready" status section entirely
              SizedBox(height: 48),
              
              // Instructions
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[300]!, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Instructions',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildInstruction('1', 'Complete all 4 tests'),
                    SizedBox(height: 12),
                    _buildInstruction('2', 'Start with Walking Test for best results'),
                    SizedBox(height: 12),
                    _buildInstruction('3', 'Find a quiet, well-lit space'),
                    SizedBox(height: 12),
                    _buildInstruction('4', 'Follow audio instructions carefully'),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              if (!_isLoading)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _navigateToHome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.all(20),
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
              
              // Add extra space under the button
              SizedBox(height: 40),
            ],
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
          width: 28,
          height: 28,
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
                fontSize: 14,
              ),
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}