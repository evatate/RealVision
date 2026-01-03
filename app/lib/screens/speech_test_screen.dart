import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/test_progress.dart';
import '../services/audio_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
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
  bool _hasSpoken = false;
  
  // New timing and validation variables
  DateTime? _testStartTime;
  bool _canFinish = false;
  Timer? _silenceTimer;
  Timer? _minimumTimeTimer;
  static const Duration _minimumTestDuration = Duration(minutes: 1);
  static const Duration _silenceThreshold = Duration(seconds: 5);
  static const int _minimumWordCount = 100;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      await _audioService.initialize();
      setState(() => _initialized = true);
      
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (mounted && !_hasSpoken) {
        await _audioService.speak(
          'Please describe everything and explain what is happening, what people are doing, and how the scene fits together. Continue speaking until I tell you to stop.',
        );
        _hasSpoken = true;
      }
    } catch (e) {
      AppLogger.logger.severe('Audio initialization error: $e');
      setState(() => _initialized = true);
    }
  }

  Future<void> _startTest() async {
    setState(() {
      _isListening = true;
      _transcript = '';
      _testStartTime = DateTime.now();
      _canFinish = false;
    });
    
    // Start minimum duration timer
    _minimumTimeTimer = Timer(_minimumTestDuration, () {
      if (mounted) {
        setState(() => _canFinish = true);
      }
    });
    
    try {
      await _audioService.startListening(
        onResult: (text) {
          if (mounted) {
            setState(() {
              _transcript = text;
            });
            
            // Cancel existing silence timer
            _silenceTimer?.cancel();
            
            // Start new silence timer
            _silenceTimer = Timer(_silenceThreshold, () async {
              if (mounted && _isListening) {
                await _audioService.speak('Please continue speaking. Describe more details about what you see.');
              }
            });
          }
        },
        onError: (error) {
          AppLogger.logger.severe('Speech recognition error: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Microphone error. Check permissions.'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      );
    } catch (e) {
      AppLogger.logger.severe('Error starting speech test: $e');
      if (mounted) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _stopTest() async {
    // Cancel timers
    _silenceTimer?.cancel();
    _minimumTimeTimer?.cancel();
    
    await _audioService.stopListening();
    
    if (mounted) {
      setState(() => _isListening = false);
    }
    
    final finalTranscript = _transcript.isNotEmpty 
        ? _transcript 
        : _audioService.getAccumulatedTranscript();
    
    // Check minimum duration
    final testDuration = _testStartTime != null 
        ? DateTime.now().difference(_testStartTime!) 
        : Duration.zero;
    
    if (testDuration < _minimumTestDuration) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test must run for at least ${_minimumTestDuration.inMinutes} minute(s). Current duration: ${testDuration.inSeconds} seconds.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    
    // Check word count
    final wordCount = finalTranscript.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
    
    if (wordCount < _minimumWordCount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please speak more. Minimum $_minimumWordCount words required. Current count: $wordCount words.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    
    if (finalTranscript.trim().isEmpty || finalTranscript.trim().length < 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No speech detected or recording too short. Please try again and speak clearly into the microphone.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    
    if (mounted) {
      Provider.of<TestProgress>(context, listen: false).markSpeechCompleted();
    }
    
    await _audioService.speak('Thank you. Speech test complete.');
    
    AppLogger.logger.info('Speech transcript: $finalTranscript');
    AppLogger.logger.info('Transcript length: $wordCount words');
    AppLogger.logger.info('Test duration: ${testDuration.inSeconds} seconds');
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _minimumTimeTimer?.cancel();
    _audioService.stopListening();
    super.dispose();
    // Dispose audio service after a delay to let final TTS complete
    Future.delayed(const Duration(seconds: 3), () {
      _audioService.dispose();
    });
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
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 2),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/images/cookie_theft.png',
                        height: 240,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 240,
                            color: Colors.grey[300],
                            child: Center(
                              child: Text(
                                'Cookie Theft Picture\n(Add to assets/images/)',
                                style: TextStyle(fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    Text(
                      'Describe everything you see',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    
                    if (!_isListening)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _initialized ? _startTest : null,
                          icon: const Icon(Icons.mic, size: 32),
                          label: Text(
                            'Start Recording',
                            style: TextStyle(fontSize: 24),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.all(20),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red, width: 3),
                            ),
                            child: const Icon(
                              Icons.mic,
                              size: 40,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Recording...',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          // Status information
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Time: ${_testStartTime != null ? DateTime.now().difference(_testStartTime!).inSeconds : 0}s / ${_minimumTestDuration.inSeconds}s min',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: _canFinish ? Colors.green : const Color.fromARGB(255, 207, 32, 5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border, width: 2),
                            ),
                            constraints: const BoxConstraints(
                              minHeight: 100,
                              maxHeight: 200,
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                _transcript.isEmpty 
                                    ? 'Your speech will appear here...' 
                                    : _transcript,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _transcript.isEmpty 
                                      ? AppColors.textMedium 
                                      : AppColors.textDark,
                                  fontStyle: _transcript.isEmpty 
                                      ? FontStyle.italic 
                                      : FontStyle.normal,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _canFinish ? _stopTest : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _canFinish ? Colors.red : Colors.grey,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.all(18),
                              ),
                              child: Text(
                                _canFinish ? 'Stop Recording' : 'Recording (Min 1 min & 100 words)',
                                style: TextStyle(fontSize: 22),
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