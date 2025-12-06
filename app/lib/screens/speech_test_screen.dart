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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    await _audioService.initialize();
    setState(() => _initialized = true);
    await _audioService.speak(
      'Please describe everything you see happening in this picture. Take your time.',
    );
  }

  Future<void> _startTest() async {
    setState(() => _isListening = true);
    
    await _audioService.startListening(
      onResult: (text) {
        setState(() => _transcript = text);
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      },
    );

    // Auto-stop after 2 minutes
    Future.delayed(const Duration(seconds: AppConstants.speechTestDuration), () {
      if (_isListening) {
        _stopTest();
      }
    });
  }

  Future<void> _stopTest() async {
    await _audioService.stopListening();
    setState(() => _isListening = false);
    
    if (_transcript.isNotEmpty) {
      Provider.of<TestProgress>(context, listen: false).markSpeechCompleted();
      await _audioService.speak('Thank you. Speech test complete.');
      
      // Save transcript for later processing
      // TODO: Send to backend or save locally for model inference
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
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
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Text(
                      'Cookie Theft Picture',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 32),
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
                            child: const Center(
                              child: Text(
                                'Cookie Theft Picture\n(Add image to assets/images/)',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Please describe everything you see happening in this picture',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    if (!_isListening)
                      ElevatedButton.icon(
                        onPressed: _initialized ? _startTest : null,
                        icon: const Icon(Icons.mic, size: 32),
                        label: const Text('Start Recording'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                      )
                    else
                      Column(
                        children: [
                          const Icon(
                            Icons.mic,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Recording...',
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border, width: 2),
                            ),
                            constraints: const BoxConstraints(minHeight: 150),
                            child: Text(
                              _transcript.isEmpty ? 'Listening...' : _transcript,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: _stopTest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Stop Recording'),
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