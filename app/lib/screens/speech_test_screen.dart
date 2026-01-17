import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import '../models/test_progress.dart';
import '../services/audio_service.dart';
import '../services/aws_storage_service.dart';
import '../services/service_locator.dart';
import '../services/cha_transcript_builder.dart';
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
  final AudioService _audioService = AudioService();
  final AWSStorageService _awsStorage = getIt<AWSStorageService>();
  bool _isListening = false;
  String _transcript = '';
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

    setState(() {
      _isListening = true;
      _transcript = '';
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
    _audioService.resetSegments();
    String? wavPath;
    try {
      wavPath = await _audioService.startRecording();
      AppLogger.logger.info('WAV recording started. File path: $wavPath');
    } catch (e) {
      AppLogger.logger.severe('Error starting WAV recording: $e');
    }

    try {
      await _audioService.startListening(
        onResult: (text) {
          if (mounted) {
            setState(() => _transcript = text);
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

    await _audioService.stopListening();

    if (mounted) {
      setState(() => _isListening = false);
    }

    final finalTranscript = _transcript.isNotEmpty
        ? _transcript
        : _audioService.getAccumulatedTranscript();

    if (finalTranscript.trim().isEmpty || finalTranscript.trim().length < 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No speech detected or recording too short. Please try again and speak clearly into the microphone.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Generate and upload CHA transcript
    try {
      final segments = _audioService.getSegments();
      AppLogger.logger.info('Segments length: ${segments.length}');

      // If no segments from audio service, create one from the final transcript
      final List<SpeechSegment> chaSegments = segments.isEmpty
          ? [
              SpeechSegment(
                text: finalTranscript,
                start: Duration.zero,
                end: testDuration,
              )
            ]
          : segments;

      final cha = ChaTranscriptBuilder.build(
        segments: chaSegments,
        totalDuration: testDuration,
      );

      if (segments.isEmpty) {
        AppLogger.logger
            .warning('No segments from audio service, using final transcript.');
      }

      // Create temporary CHA file
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final chaFilePath = '${dir.path}/speech_$timestamp.cha';
      final chaFile = File(chaFilePath);
      await chaFile.writeAsString(cha);
      AppLogger.logger.info('CHA file created: $chaFilePath');

      // Upload using the same method as audio files, just pass the file path
      final chaS3Key = await _awsStorage.uploadFile(chaFilePath, 'transcript');

      if (chaS3Key != null) {
        AppLogger.logger.info('CHA uploaded to S3: $chaS3Key');
      } else {
        AppLogger.logger.severe('CHA upload to S3 failed');
      }
    } catch (e) {
      AppLogger.logger.severe('CHA generation/upload failed: $e');
    }

    // WAV upload (iOS only)
    if (wavPath != null && File(wavPath).existsSync()) {
      try {
        AppLogger.logger.info('Uploading WAV file to S3: $wavPath');
        final s3Key = await _awsStorage.uploadAudioFile(wavPath);
        if (s3Key != null) {
          AppLogger.logger.info('WAV uploaded to S3: $s3Key');
        } else {
          AppLogger.logger.severe('S3 upload failed for $wavPath');
        }
      } catch (e) {
        AppLogger.logger.severe('WAV upload to S3 failed: $e');
      }
    } else {
      AppLogger.logger.info(
          'WAV recording not available (Android uses speech-to-text only)');
    }

    if (mounted) {
      Provider.of<TestProgress>(context, listen: false).markSpeechCompleted();
    }

    await _audioService.speak('Thank you. Speech test complete.');

    AppLogger.logger.info('Speech transcript: $finalTranscript');
    AppLogger.logger
        .info('Transcript length: ${finalTranscript.split(' ').length} words');

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _elapsedTimeTimer?.cancel();
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

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AppColors.border, width: 2),
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
