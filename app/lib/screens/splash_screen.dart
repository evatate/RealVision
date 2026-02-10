import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../services/service_locator.dart';
import '../services/audio_service.dart';
import '../services/aws_auth_service.dart';
import '../services/user_validation_service.dart';
import '../utils/logger.dart';
import '../models/test_progress.dart';
import 'package:provider/provider.dart';
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
  bool _isAuthenticated = false;
  bool _isValidating = false;
  
  final TextEditingController _usernameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Record start time to ensure minimum splash duration
    final startTime = DateTime.now();
    const minSplashDuration = Duration(seconds: 2);
    
    try {
      setState(() => _statusMessage = 'Checking authentication...');
      
      // Ensure user is signed in
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
      
      setState(() => _statusMessage = 'Setting up secure storage...');
      final validationService = getIt<UserValidationService>();
      await validationService.initialize();
      
      // Ensure minimum splash duration
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < minSplashDuration) {
        await Future.delayed(minSplashDuration - elapsed);
      }
      
      setState(() {
        _isLoading = false;
        _statusMessage = 'Enter your participant ID to continue';
      });
    } catch (e) {
      AppLogger.logger.severe('Initialization error: $e');
      
      // minimum duration
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < minSplashDuration) {
        await Future.delayed(minSplashDuration - elapsed);
      }
      
      setState(() {
        _isLoading = false;
        _statusMessage = 'Enter your participant ID to continue';
      });
    }
  }

  Future<bool> _checkUsername(String username) async {
    if (username.trim().isEmpty) return false;
    
    try {
      final validationService = getIt<UserValidationService>();
      return await validationService.validateUsername(username);
    } catch (e) {
      AppLogger.logger.warning('Username validation error: $e');
      return false;
    }
  }

  Future<void> _validateAndProceed() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isValidating = true;
      _statusMessage = 'Validating participant ID...';
    });
    
    final username = _usernameController.text;
    final isValid = await _checkUsername(username);
    
    if (!mounted) return;
    
    if (isValid) {
      // Store the validated participant ID in global state
      if (mounted) {
        Provider.of<TestProgress>(context, listen: false).setParticipantId(username);
      }
      
      setState(() {
        _isAuthenticated = true;
        _statusMessage = 'Validated! Preparing assessment...';
      });
      
      // Speak instructions after successful validation
      final audioService = getIt<AudioService>();
      if (!_instructionsSpoken) {
        _instructionsSpoken = true;
        await audioService.speak(
          'Welcome! Complete all four tests. '
          'Complete the eye tracking tests in order. '
          'Find a quiet, well lit space. '
          'Follow the audio instructions.'
        );
      }
      
      setState(() {
        _isValidating = false;
        _statusMessage = 'Ready to begin assessment!';
      });
    } else {
      setState(() {
        _isValidating = false;
        _statusMessage = 'Enter your participant ID to continue';
      });
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            'Invalid Participant ID',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Please contact the research team for assistance.',
            style: TextStyle(color: AppColors.textDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'OK',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
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
                  
                  if (_isLoading || _isValidating)
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
                    )
                  else if (!_isAuthenticated)
                    Column(
                      children: [
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textMedium,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 20),
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Participant ID',
                              hintText: 'Enter your participant ID',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your participant ID';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _validateAndProceed(),
                          ),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _validateAndProceed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: EdgeInsets.all(16),
                            ),
                            child: Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
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
                        _buildInstruction('2', 'Do eye tests in order'),
                        SizedBox(height: 12),
                        _buildInstruction('3', 'Find a quiet, well-lit space'),
                        SizedBox(height: 12),
                        _buildInstruction('4', 'Follow audio instructions'),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 48),
                  
                  if (_isAuthenticated && !_isLoading && !_isValidating)
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