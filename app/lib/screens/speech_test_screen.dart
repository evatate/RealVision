import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_progress.dart';
import '../services/audio_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../widgets/breadcrumb.dart';

class SpeechTestScreen extends StatefulWidget {
  const SpeechTestScreen({super.key});

  @override
  State<SpeechTestScreen> createState() => _SpeechTestScreenState();
}

class _SpeechTestScreenState extends State<SpeechTestScreen> {
  final AudioService _audioService = AudioService();
  bool _isListening = false;
  String _transcript = '';
  String _interimTranscript = '';
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
      
      // Wait a bit before speaking
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _audioService.speak(
        'Please describe everything you see happening in this picture. Take your time.',
      );
    } catch (e) {
      print('Audio initialization error: $e');
      setState(() => _initialized = true);
    }
  }

  Future<void> _startTest() async {
    setState(() {
      _isListening = true;
      _transcript = '';
      _interimTranscript = '';
    });
    
    try {
      await _audioService.startListening(
        onResult: (text) {
          setState(() {
            _transcript = text;
            _interimTranscript = text;
          });
        },
        onError: (error) {
          print('Speech recognition error: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Microphone error: $error'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      );

      // Auto-stop after 2 minutes
      Future.delayed(Duration(seconds: AppConstants.speechTestDuration), () {
        if (_isListening) {
          _stopTest();
        }
      });
    } catch (e) {
      print('Error starting speech test: $e');
      setState(() => _isListening = false);
    }
  }

  Future<void> _stopTest() async {
    await _audioService.stopListening();
    setState(() => _isListening = false);
    
    if (_transcript.isNotEmpty) {
      Provider.of<TestProgress>(context, listen: false).markSpeechCompleted();
      await _audioService.speak('Thank you. Speech test complete.');
      
      print('Speech transcript: $_transcript');
      // TODO: Save transcript for ML inference
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      // No transcript recorded
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No speech detected. Please try again with microphone enabled.'),
          ),
        );
      }
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
            const Breadcrumb(current: 'Speech Test'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppConstants.buttonSpacing),
                child: Column(
                  children: [
                    Text(
                      'Cookie Theft Picture',
                      style: TextStyle(
                        fontSize: AppConstants.headingFontSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: AppConstants.buttonSpacing),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 2),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(
                        'assets/images/cookie_theft.png',
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 300,
                            color: Colors.grey[300],
                            child: Center(
                              child: Text(
                                'Cookie Theft Picture\n(Add image to assets/images/)',
                                style: TextStyle(fontSize: 18),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: AppConstants.buttonSpacing),
                    Text(
                      'Please describe everything you see happening in this picture',
                      style: TextStyle(
                        fontSize: AppConstants.bodyFontSize,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppConstants.buttonSpacing * 2),
                    if (!_isListening)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _initialized ? _startTest : null,
                          icon: const Icon(Icons.mic, size: 32),
                          label: Text(
                            'Start Recording',
                            style: TextStyle(fontSize: AppConstants.buttonFontSize),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: EdgeInsets.all(AppConstants.buttonPadding),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red, width: 3),
                            ),
                            child: const Icon(
                              Icons.mic,
                              size: 64,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Recording...',
                            style: TextStyle(
                              fontSize: AppConstants.headingFontSize,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: AppConstants.buttonSpacing),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border, width: 2),
                            ),
                            constraints: const BoxConstraints(minHeight: 150),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'What you said:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _transcript.isEmpty 
                                      ? 'Speak now...' 
                                      : _transcript,
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: AppConstants.buttonSpacing),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _stopTest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: EdgeInsets.all(AppConstants.buttonPadding),
                              ),
                              child: Text(
                                'Stop Recording',
                                style: TextStyle(fontSize: AppConstants.buttonFontSize),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}