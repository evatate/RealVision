import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../amplifyconfiguration.dart';
import '../utils/logger.dart';

/// Secure AWS Authentication Service
/// 
/// Uses synthetic user accounts for privacy:
/// - Email: study-participant-{uuid}@realvision.local
/// - Password: Auto-generated secure random
/// - No PII collected or stored
class AWSAuthService {
  static bool _configured = false;
  String? _currentUserId;
  final _secureStorage = const FlutterSecureStorage();
  final _uuid = const Uuid();
  
  static const String _USER_ID_KEY = 'realvision_user_id';
  static const String _USER_EMAIL_KEY = 'realvision_user_email';
  static const String _USER_PASSWORD_KEY = 'realvision_user_password';
  
  Future<void> initialize() async {
    if (_configured) return;
    
    try {
      await Amplify.addPlugins([
        AmplifyAuthCognito(),
        AmplifyStorageS3(),
      ]);
      
      await Amplify.configure(amplifyconfig);

      _configured = true;
      
      safePrint('AWS Amplify configured successfully');
    } on AmplifyAlreadyConfiguredException {
      safePrint('Amplify already configured');
      _configured = true;
    } catch (e) {
      safePrint('Error configuring Amplify: $e');
      rethrow;
    }
  }
  
  /// Check if user is already signed in, if not create synthetic account
  Future<String?> ensureSignedIn() async {
    try {
      // First check if already signed in with Amplify
      final session = await Amplify.Auth.fetchAuthSession();
      
      if (session.isSignedIn) {
        safePrint('User already signed in');
        final user = await Amplify.Auth.getCurrentUser();
        _currentUserId = user.userId;
        await _secureStorage.write(key: _USER_ID_KEY, value: _currentUserId);
        await ensureAwsCredentials();
        return _currentUserId;
      }
      
      safePrint('No active session, checking stored credentials...');
      
      // Check if we have stored credentials
      final existingEmail = await _secureStorage.read(key: _USER_EMAIL_KEY);
      final existingPassword = await _secureStorage.read(key: _USER_PASSWORD_KEY);
      
      if (existingEmail != null && existingPassword != null) {
        // Try signing in with existing credentials
        safePrint('Found stored credentials, attempting sign-in...');
        try {
          final result = await Amplify.Auth.signIn(
            username: existingEmail,
            password: existingPassword,
          );
          
          if (result.isSignedIn) {
            final user = await Amplify.Auth.getCurrentUser();
            _currentUserId = user.userId;
            await _secureStorage.write(key: _USER_ID_KEY, value: _currentUserId);
            
            safePrint('Signed in with existing credentials: $_currentUserId');
            await ensureAwsCredentials();
            return _currentUserId;
          }
        } catch (e) {
          safePrint('Stored credentials invalid: $e');
          // Clear invalid credentials
          await _secureStorage.deleteAll();
        }
      }
      
      // if no valid session or credentials, create new synthetic user
      safePrint('Creating new synthetic user account...');
      final newUserId = await _createSyntheticUser();
      // Fetch Identity Pool credentials for the new user
      await ensureAwsCredentials();
      return newUserId;
    } catch (e) {
      safePrint('Error in ensureSignedIn: $e');
      return null;
    }
  }
  
  /// Create new synthetic user (private method)
  Future<String?> _createSyntheticUser() async {
    try {
      final syntheticEmail = 'study-participant-${_uuid.v4()}@realvision.local';
      final securePassword = _generateSecurePassword();
      
      safePrint('Email: $syntheticEmail');
      
      // Sign up new user
      final signUpResult = await Amplify.Auth.signUp(
        username: syntheticEmail,
        password: securePassword,
        options: SignUpOptions(
          userAttributes: {
            AuthUserAttributeKey.email: syntheticEmail,
          },
        ),
      );
      
      if (!signUpResult.isSignUpComplete) {
        safePrint('Auto-confirm not working. Check Lambda trigger.');
        return null;
      }
      
      // Sign in immediately
      final signInResult = await Amplify.Auth.signIn(
        username: syntheticEmail,
        password: securePassword,
      );
      
      if (signInResult.isSignedIn) {
        final user = await Amplify.Auth.getCurrentUser();
        _currentUserId = user.userId;
        
        // Store credentials securely
        await _secureStorage.write(key: _USER_ID_KEY, value: _currentUserId);
        await _secureStorage.write(key: _USER_EMAIL_KEY, value: syntheticEmail);
        await _secureStorage.write(key: _USER_PASSWORD_KEY, value: securePassword);
        
        safePrint('New synthetic user created: $_currentUserId');
        return _currentUserId;
      }
      
      return null;
      
    } catch (e) {
      safePrint('Error creating synthetic user: $e');
      return null;
    }
  }
  
  /// Generate cryptographically secure random password
  /// Meets Cognito requirements: uppercase, lowercase, numbers, symbols, min 8 chars
  String _generateSecurePassword() {
    final uuid1 = _uuid.v4().replaceAll('-', '');
    final uuid2 = _uuid.v4().replaceAll('-', '');
    
    // Ensure we have all required character types
    final uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final lowercase = 'abcdefghijklmnopqrstuvwxyz';
    final numbers = '0123456789';
    final symbols = '!@#\$%^&*';
    
    // Build password with guaranteed character types
    final password = StringBuffer();
    password.write(uppercase[uuid1.codeUnitAt(0) % uppercase.length]); // 1 uppercase
    password.write(lowercase[uuid1.codeUnitAt(1) % lowercase.length]); // 1 lowercase
    password.write(numbers[uuid1.codeUnitAt(2) % numbers.length]);     // 1 number
    password.write(symbols[uuid1.codeUnitAt(3) % symbols.length]);     // 1 symbol
    password.write(uuid1.substring(4, 20)); // Add more randomness
    password.write(uuid2.substring(0, 12)); // Total 32 chars
    
    return password.toString();
  }
  
  /// Get current user ID from Cognito
  Future<String?> getCurrentUserId() async {
    if (_currentUserId != null) return _currentUserId;
    
    try {
      final user = await Amplify.Auth.getCurrentUser();
      _currentUserId = user.userId;
      await _secureStorage.write(key: _USER_ID_KEY, value: _currentUserId);
      return _currentUserId;
    } catch (e) {
      // Fallback to stored ID
      _currentUserId = await _secureStorage.read(key: _USER_ID_KEY);
      return _currentUserId;
    }
  }
  
  /// Check if user is signed in
  Future<bool> isSignedIn() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } catch (e) {
      return false;
    }
  }
  
  /// Force credential resolution immediately after sign in
  Future<void> ensureAwsCredentials() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      if (!session.isSignedIn) {
        throw Exception('User not signed in');
      }

      // Check if identity pool credentials are available
      if (session.identityIdResult.value != null) {
        AppLogger.logger.info('Identity ID: ${session.identityIdResult.value}');

        // Check if AWS credentials are available
        if (session.credentialsResult.value != null) {
          AppLogger.logger.info('AWS credentials available for service calls');
        } else {
          AppLogger.logger.warning('AWS credentials not yet available');
        }
      } else {
        AppLogger.logger.warning('No identity ID available');
      }
    } catch (e) {
      if (e.toString().contains('No identity pool registered') ||
          e.toString().contains('InvalidAccountTypeException')) {
        AppLogger.logger.warning('Identity pool not configured - proceeding with user pool auth only');
        AppLogger.logger.warning('Note: AWS services requiring credentials will need identity pool setup');
      } else {
        AppLogger.logger.severe('Error ensuring AWS credentials: $e');
        rethrow;
      }
    }
  }

  Future<String?> getIdentityId() async {
    final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

    if (!session.isSignedIn) {
      throw Exception('User is not signed in');
    }

    final identityId = session.identityIdResult.value;
    if (identityId == null) {
      throw Exception('No identity ID available. Is your Identity Pool configured?');
    }

    return identityId;
  }
  
  /// Get AWS credentials for direct API calls (access key, secret key, session token)
  Future<Map<String, String>?> getAWSCredentials() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      if (session.credentialsResult.value != null) {
        final credentials = session.credentialsResult.value!;
        return {
          'accessKeyId': credentials.accessKeyId,
          'secretAccessKey': credentials.secretAccessKey,
          'sessionToken': credentials.sessionToken ?? '',
        };
      } else {
        safePrint('No AWS credentials available');
        return null;
      }
    } catch (e) {
      safePrint('Error getting AWS credentials: $e');
      return null;
    }
  }
  
  /// Get auth session tokens for AWS API calls
  Future<Map<String, String>> getAuthHeaders() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      
      final accessToken = session.userPoolTokensResult.value.accessToken.raw;
      final idToken = session.userPoolTokensResult.value.idToken.raw;
      
      return {
        'Authorization': 'Bearer $accessToken',
        'X-ID-Token': idToken,
      };
      
    } catch (e) {
      safePrint('Error getting auth headers: $e');
      return {};
    }
  }
  
  /// Sign out and clear data
  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
      _currentUserId = null;
      
      // Clear ALL stored credentials
      await _secureStorage.delete(key: _USER_ID_KEY);
      await _secureStorage.delete(key: _USER_EMAIL_KEY);
      await _secureStorage.delete(key: _USER_PASSWORD_KEY);
      
      safePrint('User signed out and data cleared');
    } catch (e) {
      safePrint('Sign out error: $e');
    }
  }
  
  /// Get synthetic email (for debugging only, never show to user)
  Future<String?> getSyntheticEmail() async {
    return await _secureStorage.read(key: _USER_EMAIL_KEY);
  }
}