import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'aws_auth_service.dart';

/// Secure AWS Storage Service
class AWSStorageService {
  final AWSAuthService _authService;
  
  AWSStorageService(this._authService);
  
  // Upload audio file to S3 securely
  Future<String?> uploadAudioFile(String localPath) async {
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Audio file not found');
      }
      
      // Generate unique S3 key with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'speech_$timestamp.wav';
      final s3Key = 'private/$userId/audio/$fileName';
      
      safePrint('Uploading to S3: $s3Key');
      
      // Upload to S3 with Amplify Storage
      final result = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(localPath),
        path: StoragePath.fromString(s3Key),
        options: const StorageUploadFileOptions(
          pluginOptions: S3UploadFilePluginOptions(
            getProperties: true,
          ),
        ),
      ).result;
      
      safePrint('Upload complete: ${result.uploadedItem.path}');
      
      // Return the S3 key for later reference
      return s3Key;
      
    } catch (e) {
      safePrint('Upload error: $e');
      return null;
    }
  }
  
  /// Trigger AWS Transcribe Medical for audio transcription
  Future<Map<String, dynamic>?> transcribeAudio(String s3Key) async {
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Get auth headers with Cognito tokens
      final headers = await _authService.getAuthHeaders();
      
      // Your API Gateway endpoint URL
      const apiEndpoint = 'https://3nn8vej5pf.execute-api.us-east-2.amazonaws.com/prod/transcribe';
      
      safePrint('📞 Calling Transcribe API: $apiEndpoint');
      
      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userId': userId,
          's3Key': s3Key,
          'bucket': 'realvision-dev-audio',
          'specialty': 'PRIMARYCARE',
          'type': 'DICTATION',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        safePrint('Transcription initiated: ${data['jobName']}');
        return data;
      } else {
        safePrint('Transcription error: ${response.statusCode} - ${response.body}');
        return null;
      }
      
    } catch (e) {
      safePrint('Transcription error: $e');
      return null;
    }
  }
  
  /// Get transcription results (poll until complete)
  Future<SpeechAnalysis?> getTranscriptionResults(String jobName) async {
    try {
      final headers = await _authService.getAuthHeaders();
      
      // API endpoint to get results
      const apiEndpoint = 'https://3nn8vej5pf.execute-api.us-east-2.amazonaws.com/prod/transcribe/results';
      
      final response = await http.get(
        Uri.parse('$apiEndpoint?jobName=$jobName'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'COMPLETED') {
          safePrint('Transcription complete!');
          return _parseTranscribeResults(data['transcript']);
        } else if (data['status'] == 'IN_PROGRESS') {
          safePrint('Transcription in progress...');
          return null;
        } else {
          safePrint('Transcription failed: ${data['status']}');
          return null;
        }
      }
      
      return null;
      
    } catch (e) {
      safePrint('Error getting results: $e');
      return null;
    }
  }
  
  /// Parse Transcribe Medical results
  SpeechAnalysis _parseTranscribeResults(Map<String, dynamic> transcript) {
    final text = transcript['results']['transcripts'][0]['transcript'] as String;
    final items = transcript['results']['items'] as List;
    
    int wordCount = 0;
    int fillerWordCount = 0;
    int pauseCount = 0;
    double totalPauseDuration = 0.0;
    
    final fillers = {'uh', 'um', 'uhm', 'ah', 'er'};
    
    double? lastEndTime;
    
    for (var item in items) {
      if (item['type'] == 'pronunciation') {
        wordCount++;
        
        final word = (item['alternatives'][0]['content'] as String).toLowerCase();
        if (fillers.contains(word)) {
          fillerWordCount++;
        }
        
        // Detect pauses
        final startTime = double.parse(item['start_time']);
        if (lastEndTime != null) {
          final pause = startTime - lastEndTime;
          if (pause > 0.5) {
            pauseCount++;
            totalPauseDuration += pause;
          }
        }
        
        lastEndTime = double.parse(item['end_time']);
      }
    }
    
    final duration = lastEndTime ?? 0.0;
    final speakingRate = duration > 0 ? (wordCount / (duration / 60.0)) : 0.0;
    final fillerRate = wordCount > 0 ? (fillerWordCount / wordCount) * 100 : 0.0;
    final avgPauseDuration = pauseCount > 0 ? totalPauseDuration / pauseCount : 0.0;
    
    return SpeechAnalysis(
      wordCount: wordCount,
      fillerWordCount: fillerWordCount,
      fillerRate: fillerRate,
      pauseCount: pauseCount,
      totalPauseDuration: totalPauseDuration,
      avgPauseDuration: avgPauseDuration,
      speakingRate: speakingRate,
      duration: duration,
      transcript: text,
    );
  }
  
  /// Download file from S3
  Future<String?> downloadFile(String s3Key, String localPath) async {
    try {
      final result = await Amplify.Storage.downloadFile(
        path: StoragePath.fromString(s3Key),
        localFile: AWSFile.fromPath(localPath),
      ).result;
      
      safePrint('Download complete: ${result.localFile.path}');
      return result.localFile.path;
      
    } catch (e) {
      safePrint('Download error: $e');
      return null;
    }
  }
  
  /// List all audio files for current user
  Future<List<String>> listUserAudioFiles() async {
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null) return [];
      
      final result = await Amplify.Storage.list(
        path: StoragePath.fromString('private/$userId/audio/'),
      ).result;
      
      return result.items.map((item) => item.path).toList();
      
    } catch (e) {
      safePrint('List error: $e');
      return [];
    }
  }
}

class SpeechAnalysis {
  final int wordCount;
  final int fillerWordCount;
  final double fillerRate;
  final int pauseCount;
  final double totalPauseDuration;
  final double avgPauseDuration;
  final double speakingRate;
  final double duration;
  final String transcript;
  
  SpeechAnalysis({
    required this.wordCount,
    required this.fillerWordCount,
    required this.fillerRate,
    required this.pauseCount,
    required this.totalPauseDuration,
    required this.avgPauseDuration,
    required this.speakingRate,
    required this.duration,
    required this.transcript,
  });
  
  @override
  String toString() {
    return '''
Speech Analysis Results:
- Total words: $wordCount
- Filler words: $fillerWordCount (${fillerRate.toStringAsFixed(1)}%)
- Speaking rate: ${speakingRate.toStringAsFixed(1)} words/min
- Pauses: $pauseCount (avg: ${avgPauseDuration.toStringAsFixed(2)}s)
- Duration: ${duration.toStringAsFixed(1)}s
''';
  }
}