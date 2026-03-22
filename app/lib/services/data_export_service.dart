import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/smile_data.dart';
import '../models/gait_data.dart';
import '../models/eye_tracking_data.dart';
import '../utils/logger.dart';
import 'aws_storage_service.dart';

/// Service for exporting participant session data to JSON files

class DataExportService {
  final AWSStorageService? _awsStorage;

  DataExportService({AWSStorageService? awsStorage}) : _awsStorage = awsStorage;
  /// Export a single smile session to JSON file
  Future<File> exportSmileSession(SmileSessionData session) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filename = 'smile_${session.participantId}_${session.timestamp.toIso8601String().split('T')[0]}.json';
      final file = File('${directory.path}/$filename');

      // Create JSON with participantId at the top
      final jsonData = {
        'participantId': session.participantId,
        'testType': 'smile',
        'exportedAt': DateTime.now().toIso8601String(),
        'sessionData': session.toJson(),
      };
      final jsonString = jsonEncode(jsonData);
      await file.writeAsString(jsonString);

      AppLogger.logger.info('Exported smile session to: ${file.path}');

      // Also upload to S3 if available
      if (_awsStorage != null) {
        try {
          final s3Key = await _awsStorage!.uploadFile(file.path, 'smile');
          if (s3Key != null) {
            AppLogger.logger.info('Smile session uploaded to S3: $s3Key');
          }
        } catch (e) {
          AppLogger.logger.warning('Failed to upload to S3, but local export succeeded: $e');
        }
      }

      return file;
    } catch (e, stackTrace) {
      AppLogger.logger.severe('Error exporting smile session', e, stackTrace);
      rethrow;
    }
  }

  /// Export multiple smile sessions
  Future<List<File>> exportSmileSessions(List<SmileSessionData> sessions) async {
    final files = <File>[];
    for (var session in sessions) {
      files.add(await exportSmileSession(session));
    }
    return files;
  }

  /// Export a single gait session to JSON file
  Future<File> exportGaitSession(GaitSessionData session) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filename = 'gait_${session.participantId}_${session.timestamp.toIso8601String().split('T')[0]}.json';
      final file = File('${directory.path}/$filename');

      // Create JSON with participantId at the top
      final jsonData = {
        'participantId': session.participantId,
        'testType': 'gait',
        'exportedAt': DateTime.now().toIso8601String(),
        'sessionData': session.toJson(),
      };
      final jsonString = jsonEncode(jsonData);
      await file.writeAsString(jsonString);

      AppLogger.logger.info('Exported gait session to: ${file.path}');

      // Also upload to S3 if available
      if (_awsStorage != null) {
        try {
          final s3Key = await _awsStorage!.uploadFile(file.path, 'gait');
          if (s3Key != null) {
            AppLogger.logger.info('Gait session uploaded to S3: $s3Key');
          }
        } catch (e) {
          AppLogger.logger.warning('Failed to upload to S3, but local export succeeded: $e');
        }
      }

      return file;
    } catch (e, stackTrace) {
      AppLogger.logger.severe('Error exporting gait session', e, stackTrace);
      rethrow;
    }
  }

  /// Export multiple gait sessions
  Future<List<File>> exportGaitSessions(List<GaitSessionData> sessions) async {
    final files = <File>[];
    for (var session in sessions) {
      files.add(await exportGaitSession(session));
    }
    return files;
  }

  /// Export a single eye tracking session to JSON file
  Future<File> exportEyeTrackingSession(EyeTrackingSessionData session) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filename = 'eye_tracking_${session.participantId}_${session.timestamp.toIso8601String().split('T')[0]}.json';
      final file = File('${directory.path}/$filename');

      // Create JSON with participantId at the top
      final jsonData = {
        'participantId': session.participantId,
        'testType': 'eye_tracking',
        'exportedAt': DateTime.now().toIso8601String(),
        'sessionData': session.toJson(),
      };
      final jsonString = jsonEncode(jsonData);
      await file.writeAsString(jsonString);

      AppLogger.logger.info('Exported eye tracking session to: ${file.path}');

      // Also upload to S3 if available
      if (_awsStorage != null) {
        try {
          final s3Key = await _awsStorage!.uploadFile(file.path, 'eye_tracking');
          if (s3Key != null) {
            AppLogger.logger.info('Eye tracking session uploaded to S3: $s3Key');
          }
        } catch (e) {
          AppLogger.logger.warning('Failed to upload to S3, but local export succeeded: $e');
        }
      }

      return file;
    } catch (e, stackTrace) {
      AppLogger.logger.severe('Error exporting eye tracking session', e, stackTrace);
      rethrow;
    }
  }

  /// Export multiple eye tracking sessions
  Future<List<File>> exportEyeTrackingSessions(List<EyeTrackingSessionData> sessions) async {
    final files = <File>[];
    for (var session in sessions) {
      files.add(await exportEyeTrackingSession(session));
    }
    return files;
  }

  /// Load a smile session from JSON file
  Future<SmileSessionData?> loadSmileSession(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);
      
      // Handle both old and new JSON structures
      if (jsonData.containsKey('sessionData')) {
        // New structure with participant ID at top
        return SmileSessionData.fromJson(jsonData['sessionData']);
      } else {
        // Old structure with direct session data
        return SmileSessionData.fromJson(jsonData);
      }
    } catch (e, stackTrace) {
      AppLogger.logger.severe('Error loading smile session', e, stackTrace);
      return null;
    }
  }

  /// Load a gait session from JSON file
  Future<GaitSessionData?> loadGaitSession(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);
      
      // Handle both old and new JSON structures
      if (jsonData.containsKey('sessionData')) {
        // New structure with participant ID at top
        return GaitSessionData.fromJson(jsonData['sessionData']);
      } else {
        // Old structure with direct session data
        return GaitSessionData.fromJson(jsonData);
      }
    } catch (e, stackTrace) {
      AppLogger.logger.severe('Error loading gait session', e, stackTrace);
      return null;
    }
  }

  /// Load an eye tracking session from JSON file
  Future<EyeTrackingSessionData?> loadEyeTrackingSession(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);
      
      // Handle both old and new JSON structures
      if (jsonData.containsKey('sessionData')) {
        // New structure with participant ID at top
        return EyeTrackingSessionData.fromJson(jsonData['sessionData']);
      } else {
        // Old structure with direct session data
        return EyeTrackingSessionData.fromJson(jsonData);
      }
    } catch (e, stackTrace) {
      AppLogger.logger.severe('Error loading eye tracking session', e, stackTrace);
      return null;
    }
  }

  /// List all exported session files
  Future<List<File>> listExportedSessions() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync().whereType<File>();
    return files.where((file) =>
      file.path.endsWith('.json') &&
      (file.path.contains('smile_') || file.path.contains('eye_') || file.path.contains('gait_'))
    ).toList();
  }

  /// Get app documents directory path
  Future<String> getExportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
}