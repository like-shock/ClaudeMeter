/// API Constants
class ApiConstants {
  static const String tokenUrl =
      'https://console.anthropic.com/v1/oauth/token';
  static const String authorizeUrl = 'https://claude.ai/oauth/authorize';
  static const String usageUrl = 'https://api.anthropic.com/api/oauth/usage';
  static const String profileUrl =
      'https://api.anthropic.com/api/oauth/profile';

  static const String clientId = '9d1c250a-e61b-44d9-88ed-5944d1962f5e';
  static const String oauthScopes = 'user:profile';
  static const String userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const Duration apiTimeout = Duration(seconds: 15);

  /// Maximum API response size (1 MB).
  static const int maxResponseBytes = 1024 * 1024;
}

/// Credentials file path
class CredentialsConstants {
  static const String credentialsFile = '.claude/.credentials.json';
  static const String credentialsKey = 'claudeAiOauth';
  static const String encryptionSalt = 'claude-monitor-v1';
}
