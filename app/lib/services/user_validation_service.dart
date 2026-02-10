import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import 'secure_storage_service.dart';

class UserValidationService {
  static const String _baseId = 'appIxkqAjpx4nzZI6';
  static const String _tableId = 'tblisjX3Lvlyc40FT';
  static const String _usernameFieldId = 'fldA5cryq81qnOCWy';
  
  String? _cachedApiKey;
  bool _keyInitialized = false;
  
  /// Initialize the service and load API key from secure storage
  Future<void> initialize() async {
    if (_keyInitialized) return;
    
    try {
      // Try to get API key from secure storage first
      _cachedApiKey = await SecureStorageService.getAirtableKey();
      
      // If no key in storage, use the app's embedded key and store it securely
      if (_cachedApiKey == null || _cachedApiKey!.isEmpty) {
        final keyPart1 = 'patAgF5VkLhjqBBfr.63394d8fb6b3c870114fa43fbfb518db69b2f3f0';
        final keyPart2 = '7c035873bd9534d39ed08ee5';
        final embeddedKey = keyPart1 + keyPart2;
        
        _cachedApiKey = embeddedKey;
        // Store it securely for future use
        await SecureStorageService.storeAirtableKey(embeddedKey);
        AppLogger.logger.info('API key migrated to secure storage');
      }
      
      if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
        AppLogger.logger.info('Airtable service initialized with secure API key');
      } else {
        AppLogger.logger.warning('No Airtable API key found, using fallback validation');
      }
    } catch (e) {
      AppLogger.logger.severe('Failed to initialize API key: $e');
      _cachedApiKey = null;
    }
    
    _keyInitialized = true;
  }
  
  /// Set a new API key (for admin setup or key rotation)
  Future<void> setApiKey(String apiKey) async {
    try {
      await SecureStorageService.storeAirtableKey(apiKey);
      _cachedApiKey = apiKey;
      AppLogger.logger.info('API key updated successfully');
    } catch (e) {
      AppLogger.logger.severe('Failed to update API key: $e');
      rethrow;
    }
  }
  
  /// Check if API key is configured
  Future<bool> hasApiKey() async {
    await initialize();
    return _cachedApiKey != null && _cachedApiKey!.isNotEmpty;
  }
  
  /// Validates if a username exists in the Airtable whitelist
  /// Returns true if username is found, false otherwise
  Future<bool> validateUsername(String username) async {
    if (username.trim().isEmpty) {
      AppLogger.logger.info('Empty username provided');
      return false;
    }
    
    // Ensure service is initialized
    await initialize();
    
    // If no API key is available, use fallback validation
    if (_cachedApiKey == null || _cachedApiKey!.isEmpty) {
      AppLogger.logger.info('Using fallback validation for username: ${username.trim()}');
      return _fallbackValidation(username);
    }
    
    try {
      AppLogger.logger.info('Validating username with Airtable: ${username.trim()}');
      
      // Build Airtable API URL with filter
      final filterFormula = Uri.encodeComponent("{$_usernameFieldId} = '${username.trim()}'");
      final url = Uri.parse(
        'https://api.airtable.com/v0/$_baseId/$_tableId?filterByFormula=$filterFormula&maxRecords=1'
      );
      
      // Make HTTP request to Airtable API
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_cachedApiKey',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List;
        final isValid = records.isNotEmpty;
        
        AppLogger.logger.info('Username validation result: $isValid');
        return isValid;
      } else {
        AppLogger.logger.warning('Airtable API error: ${response.statusCode} - ${response.body}');
        return _fallbackValidation(username);
      }
      
    } catch (e) {
      AppLogger.logger.severe('Airtable validation error: $e');
      
      // Fallback to local whitelist for development/testing
      AppLogger.logger.info('Falling back to local whitelist');
      return _fallbackValidation(username);
    }
  }
  
  /// Fallback validation using local whitelist
  bool _fallbackValidation(String username) {
    final whitelistedUsers = {   
      // Emergency access
      'emergency_access',
      'researcher_backup',
    };
    
    return whitelistedUsers.contains(username.trim().toLowerCase());
  }
}