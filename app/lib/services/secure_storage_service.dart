import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'realvision_secure_prefs',
      preferencesKeyPrefix: 'realvision_',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  static const String _airtableKeyName = 'airtable_api_key';
  
  /// Store the Airtable API key securely
  static Future<void> storeAirtableKey(String apiKey) async {
    try {
      await _storage.write(key: _airtableKeyName, value: apiKey);
      AppLogger.logger.info('API key stored securely');
    } catch (e) {
      AppLogger.logger.severe('Failed to store API key: $e');
      rethrow;
    }
  }
  
  /// Retrieve the Airtable API key from secure storage
  static Future<String?> getAirtableKey() async {
    try {
      final key = await _storage.read(key: _airtableKeyName);
      if (key != null) {
        AppLogger.logger.info('API key retrieved from secure storage');
      } else {
        AppLogger.logger.info('No API key found in secure storage');
      }
      return key;
    } catch (e) {
      AppLogger.logger.severe('Failed to retrieve API key: $e');
      return null;
    }
  }
  
  /// Check if API key exists in secure storage
  static Future<bool> hasAirtableKey() async {
    try {
      final key = await _storage.read(key: _airtableKeyName);
      return key != null && key.isNotEmpty;
    } catch (e) {
      AppLogger.logger.severe('Failed to check for API key: $e');
      return false;
    }
  }
  
  /// Remove the API key (for testing or key rotation)
  static Future<void> removeAirtableKey() async {
    try {
      await _storage.delete(key: _airtableKeyName);
      AppLogger.logger.info('API key removed from secure storage');
    } catch (e) {
      AppLogger.logger.severe('Failed to remove API key: $e');
      rethrow;
    }
  }
}