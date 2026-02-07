/// API Constants
class ApiConstants {
  static const String tokenUrl =
      'https://console.anthropic.com/v1/oauth/token';
  static const String authorizeUrl = 'https://claude.ai/oauth/authorize';
  static const String usageUrl = 'https://api.anthropic.com/api/oauth/usage';
  static const String profileUrl =
      'https://api.anthropic.com/api/oauth/profile';

  static const String clientId = '9d1c250a-e61b-44d9-88ed-5944d1962f5e';
  static const String oauthScopes = 'org:create_api_key user:profile user:inference';
  static const String userAgent = 'claude-code/2.0.32';

  static const Duration apiTimeout = Duration(seconds: 15);
}

/// Credentials file path
class CredentialsConstants {
  static const String credentialsFile = '.claude/.credentials.json';
  static const String credentialsKey = 'claudeAiOauth';
}
