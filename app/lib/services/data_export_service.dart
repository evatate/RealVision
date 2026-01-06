import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/smile_data.dart';
import '../models/gait_data.dart';
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

      final jsonString = jsonEncode(session.toJson());
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
    } catch (e) {
      AppLogger.logger.severe('Error exporting smile session: $e');
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

      final jsonString = jsonEncode(session.toJson());
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
    } catch (e) {
      AppLogger.logger.severe('Error exporting gait session: $e');
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

  /// Load a smile session from JSON file
  Future<SmileSessionData?> loadSmileSession(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);
      return SmileSessionData.fromJson(jsonData);
    } catch (e) {
      AppLogger.logger.severe('Error loading smile session: $e');
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
      return GaitSessionData.fromJson(jsonData);
    } catch (e) {
      AppLogger.logger.severe('Error loading gait session: $e');
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