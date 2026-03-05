import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/test_progress.dart';
import '../services/audio_service.dart';
import '../services/aws_storage_service.dart';
import '../services/service_locator.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../widgets/breadcrumb.dart';
import 'dart:io';

class SpeechTestScreen extends StatefulWidget {
  const SpeechTestScreen({super.key});

  @override
  State<SpeechTestScreen> createState() => _SpeechTestScreenState();
}

class _SpeechTestScreenState extends State<SpeechTestScreen> {
  late final AudioService _audioService;
  final AWSStorageService _awsStorage = getIt<AWSStorageService>();
  bool _isListening = false;
  bool _initialized = false;
  bool _hasSpoken = false;

  // Timing and validation variables
  DateTime? _testStartTime;
  bool _canFinish = false;
  Timer? _minimumTimeTimer;
  Timer? _elapsedTimeTimer;
  int _elapsedSeconds = 0;
  static const Duration _minimumTestDuration = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    _audioService = getIt<AudioService>();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      await _audioService.initialize();
      setState(() => _initialized = true);

      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted && !_hasSpoken) {
        await _audioService.speak(
          'Please describe everything you see happening in this picture. Take your time.',
        );
        _hasSpoken = true;
      }
    } catch (e) {
      AppLogger.logger.info('Audio initialization error: $e');
      setState(() => _initialized = true);
    }
  }

  Future<void> _startTest() async {
    // Check microphone permission before starting
    final hasPermission = await _audioService.checkMicrophonePermission();
    if (!hasPermission) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Microphone Permission Required'),
            content: const Text(
              'Microphone access is required to record your speech.\n\nPlease enable microphone permissions in your device settings and try again.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Get participant ID from global state
    if (mounted) {
      final participantId = Provider.of<TestProgress>(context, listen: false).participantId;
      AppLogger.logger.info('Starting speech test for participant: $participantId');
    }

    setState(() {
      _isListening = true;
      _testStartTime = DateTime.now();
      _canFinish = false;
      _elapsedSeconds = 0;
    });

    // Start minimum duration timer
    _minimumTimeTimer = Timer(_minimumTestDuration, () {
      if (mounted) {
        setState(() => _canFinish = true);
      }
    });

    // Start elapsed time counter
    _elapsedTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isListening) {
        setState(() {
          _elapsedSeconds = timer.tick;
        });
      }
    });

    // WAV recording start
    String? wavPath;
    try {
      wavPath = await _audioService.startRecording();
      AppLogger.logger.info('WAV recording started. File path: $wavPath');
    } catch (e) {
      AppLogger.logger.severe('Error starting WAV recording: $e');
      if (mounted) {
        setState(() => _isListening = false);
        _elapsedTimeTimer?.cancel();
        _minimumTimeTimer?.cancel();
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
    // Check minimum duration before proceeding
    final testDuration = _testStartTime != null
        ? DateTime.now().difference(_testStartTime!)
        : Duration.zero;

    if (testDuration < _minimumTestDuration) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Please continue speaking. Test must run for at least ${_minimumTestDuration.inMinutes} minute(s). Current duration: ${testDuration.inSeconds} seconds.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Cancel timers
    _elapsedTimeTimer?.cancel();
    _minimumTimeTimer?.cancel();

    // WAV recording stop
    String? wavPath;
    try {
      wavPath = await _audioService.stopRecording();
      AppLogger.logger.info('WAV recording stopped. File path: $wavPath');
    } catch (e) {
      AppLogger.logger.severe('Error stopping WAV recording: $e');
    }

    if (mounted) {
      setState(() => _isListening = false);
    }

    // Validate that we have a recording file
    if (wavPath == null || !File(wavPath).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // WAV upload (both iOS and Android)
    if (File(wavPath).existsSync()) {
      try {
        AppLogger.logger.info('Uploading WAV file to S3: $wavPath');
        final s3Key = await _awsStorage.uploadAudioFile(wavPath);
        if (s3Key != null) {
          AppLogger.logger.info('WAV uploaded to S3: $s3Key');
          
          // Get participant ID and create metadata
          if (mounted) {
            final participantId = Provider.of<TestProgress>(context, listen: false).participantId ?? 'unknown_participant';
            await _exportSpeechMetadata(s3Key, testDuration, participantId);
          }
        } else {
          AppLogger.logger.severe('S3 upload failed for $wavPath');
        }
      } catch (e) {
        AppLogger.logger.severe('WAV upload to S3 failed: $e');
      }
    } else {
      AppLogger.logger.warning('WAV recording not available or file not found');
    }

    if (mounted) {
      Provider.of<TestProgress>(context, listen: false).markSpeechCompleted();
    }

    AppLogger.logger.info('Speech recording complete. Duration: ${testDuration.inSeconds} seconds');

    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    _audioService.speak('The speech test is now complete. You can close this screen, unless a researcher asks you to do it again.');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700], size: 40),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Test Complete!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'You have finished the speech test. Please only do this test again if the research team asks you to.',
            style: TextStyle(fontSize: 22, color: AppColors.textDark),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Dismiss dialog
                  Navigator.of(context).pop(); // Go back to previous screen
                },
                child: const Text('OK', style: TextStyle(fontSize: 24, color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }
  Future<void> _exportSpeechMetadata(String s3Key, Duration testDuration, String participantId) async {
    try {
      final metadata = {
        'participantId': participantId,
        'testType': 'speech',
        'exportedAt': DateTime.now().toIso8601String(),
        'sessionData': {
          'participantId': participantId,
          'sessionId': 'speech_${DateTime.now().millisecondsSinceEpoch}',
          'timestamp': _testStartTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
          'duration': testDuration.inSeconds,
          's3Key': s3Key,
          'testType': 'speech_description',
        },
      };
      
      final directory = await getApplicationDocumentsDirectory();
      final filename = 'speech_${participantId}_${DateTime.now().toIso8601String().split('T')[0]}.json';
      final file = File('${directory.path}/$filename');
      
      final jsonString = jsonEncode(metadata);
      await file.writeAsString(jsonString);
      
      AppLogger.logger.info('Speech metadata exported to: ${file.path}');
      
      // Also upload metadata to S3
      try {
        final metadataS3Key = await _awsStorage.uploadFile(file.path, 'speech');
        if (metadataS3Key != null) {
          AppLogger.logger.info('Speech metadata uploaded to S3: $metadataS3Key');
        } else {
          AppLogger.logger.warning('Failed to upload speech metadata to S3');
        }
      } catch (e) {
        AppLogger.logger.warning('Failed to upload speech metadata to S3, but local export succeeded: $e');
      }
    } catch (e) {
      AppLogger.logger.severe('Error exporting speech metadata: $e');
    }
  }

  @override
  void dispose() {
    _elapsedTimeTimer?.cancel();
    _minimumTimeTimer?.cancel();
    _audioService.stopRecording();
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
                            child: Text(
                              'Time: ${_elapsedSeconds}s / ${_minimumTestDuration.inSeconds}s min',
                              style: TextStyle(
                                fontSize: 20,
                                color:
                                    _canFinish ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _canFinish ? _stopTest : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _canFinish ? Colors.red : Colors.grey,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.all(18),
                              ),
                              child: Text(
                                _canFinish
                                    ? 'Stop Recording'
                                    : 'Recording (Min 1 min required)',
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
