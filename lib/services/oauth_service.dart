import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/credentials.dart';
import '../utils/constants.dart';
import '../utils/pkce.dart';

/// OAuth service for Claude authentication.
///
/// Uses Anthropic's official OAuth flow with code display page.
/// User must copy the authorization code from the browser.
class OAuthService {
  Credentials? _credentials;

  /// Secure storage key for credentials.
  static const String _secureStorageKey = 'claude_oauth_credentials';

  /// Legacy file path for migration.
  static String get _legacyCredentialsPath {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/${CredentialsConstants.credentialsFile}';
  }

  final FlutterSecureStorage _secureStorage;

  /// Pending PKCE verifier for token exchange.
  String? _pendingVerifier;

  /// Pending OAuth state for CSRF verification.
  String? _pendingState;

  OAuthService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  /// Whether the user has valid credentials.
  bool get hasCredentials => _credentials?.hasCredentials ?? false;

  /// Get current credentials.
  Credentials? get credentials => _credentials;

  /// Load credentials from secure storage.
  Future<void> loadCredentials() async {
    try {
      final jsonStr = await _secureStorage.read(key: _secureStorageKey);
      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        _credentials = Credentials.fromJson(json);
        return;
      }

      // Migration: check legacy plaintext file
      await _migrateFromLegacyFile();
    } catch (e, stackTrace) {
      developer.log(
        'Failed to load credentials',
        name: 'OAuthService',
        error: e,
        stackTrace: stackTrace,
        level: 900,
      );
      _credentials = null;
    }
  }

  /// Migrate credentials from legacy plaintext file to secure storage.
  Future<void> _migrateFromLegacyFile() async {
    try {
      final file = File(_legacyCredentialsPath);
      if (!await file.exists()) {
        _credentials = null;
        return;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content);
      if (json is! Map<String, dynamic>) {
        _credentials = null;
        return;
      }

      final oauthData = json[CredentialsConstants.credentialsKey];
      if (oauthData is! Map<String, dynamic>) {
        _credentials = null;
        return;
      }

      _credentials = Credentials.fromJson(oauthData);

      // Save to secure storage
      await _secureStorage.write(
        key: _secureStorageKey,
        value: jsonEncode(_credentials!.toJson()),
      );

      // Remove legacy credentials from plaintext file
      json.remove(CredentialsConstants.credentialsKey);
      if (json.isEmpty) {
        await file.delete();
      } else {
        await file.writeAsString(jsonEncode(json));
      }

      developer.log(
        'Migrated credentials from plaintext file to secure storage',
        name: 'OAuthService',
        level: 800,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Failed to migrate legacy credentials',
        name: 'OAuthService',
        error: e,
        stackTrace: stackTrace,
        level: 900,
      );
      _credentials = null;
    }
  }

  /// Save credentials to secure storage.
  Future<void> saveCredentials(Credentials creds) async {
    try {
      await _secureStorage.write(
        key: _secureStorageKey,
        value: jsonEncode(creds.toJson()),
      );
      _credentials = creds;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to save credentials to secure storage',
        name: 'OAuthService',
        error: e,
        stackTrace: stackTrace,
        level: 1000,
      );
      rethrow;
    }
  }

  /// Create a secure HttpClient with TLS verification.
  HttpClient _createSecureHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) {
      developer.log(
        'Rejected bad certificate for $host:$port',
        name: 'OAuthService.TLS',
        level: 1000,
      );
      return false;
    };
    return client;
  }

  /// Make a secure POST request to Anthropic API.
  Future<({int statusCode, String body})> _securePost(
    String url,
    Map<String, String> headers,
    String body,
  ) async {
    final client = _createSecureHttpClient();
    try {
      final uri = Uri.parse(url);
      final request = await client.postUrl(uri);

      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }

      final bodyBytes = utf8.encode(body);
      request.headers.contentLength = bodyBytes.length;
      request.add(bodyBytes);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      return (statusCode: response.statusCode, body: responseBody);
    } finally {
      client.close();
    }
  }

  /// Start OAuth login flow - opens browser with authorization URL.
  /// Returns the URL that was opened.
  /// User must copy the code from the browser and call [exchangeCodeForTokens].
  Future<String> startLogin() async {
    final verifier = PKCE.generateVerifier();
    final challenge = PKCE.generateChallenge(verifier);
    final state = PKCE.generateState();

    // Store for later token exchange
    _pendingVerifier = verifier;
    _pendingState = state;

    // Build authorization URL with code=true for code display page
    final params = {
      'code': 'true',
      'client_id': ApiConstants.clientId,
      'response_type': 'code',
      'redirect_uri': ApiConstants.redirectUri,
      'scope': ApiConstants.oauthScopes,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
    };

    final authUrl = Uri.parse(ApiConstants.authorizeUrl)
        .replace(queryParameters: params);

    debugPrint('OAuth: Opening authorization URL');

    // Open browser
    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open browser');
    }

    return authUrl.toString();
  }

  /// Exchange authorization code for tokens.
  /// Call this after user copies code from browser.
  Future<bool> exchangeCodeForTokens(String code) async {
    if (_pendingVerifier == null || _pendingState == null) {
      debugPrint('OAuth: No pending login session');
      return false;
    }

    try {
      // Clean up the code in case it has URL fragments
      final cleanedCode = code.trim().split('#')[0].split('&')[0];

      debugPrint('OAuth: Exchanging code for tokens...');
      await _exchangeCode(cleanedCode, _pendingVerifier!, _pendingState!);
      debugPrint('OAuth: Token exchange successful!');
      return true;
    } catch (e, stackTrace) {
      debugPrint('OAuth: Token exchange failed: $e');
      developer.log(
        'Token exchange failed',
        name: 'OAuthService',
        error: e,
        stackTrace: stackTrace,
        level: 1000,
      );
      return false;
    } finally {
      _pendingVerifier = null;
      _pendingState = null;
    }
  }

  /// Exchange authorization code for tokens.
  Future<void> _exchangeCode(
      String code, String verifier, String state) async {
    final requestBody = jsonEncode({
      'grant_type': 'authorization_code',
      'client_id': ApiConstants.clientId,
      'code': code,
      'redirect_uri': ApiConstants.redirectUri,
      'code_verifier': verifier,
      'state': state,
    });

    debugPrint('OAuth: Token URL: ${ApiConstants.tokenUrl}');

    final (:statusCode, body: responseBody) = await _securePost(
      ApiConstants.tokenUrl,
      {
        'Content-Type': 'application/json',
        'User-Agent': ApiConstants.userAgent,
      },
      requestBody,
    );

    debugPrint('OAuth: Token response status: $statusCode');
    if (statusCode != 200) {
      debugPrint('OAuth: Token exchange failed: $responseBody');
      developer.log(
        'Token exchange failed: $statusCode - $responseBody',
        name: 'OAuthService',
        level: 1000,
      );
      throw Exception('Token exchange failed: $statusCode - $responseBody');
    }

    final json = jsonDecode(responseBody);

    if (json is! Map<String, dynamic>) {
      throw const FormatException('Token response is not a JSON object');
    }

    final accessToken = json['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const FormatException('Missing or invalid access_token in response');
    }

    final refreshToken = json['refresh_token'];
    final expiresInRaw = json['expires_in'];
    final expiresIn = expiresInRaw is int ? expiresInRaw : 28800;

    final creds = Credentials(
      accessToken: accessToken,
      refreshToken: refreshToken is String ? refreshToken : '',
      expiresAt: DateTime.now()
          .add(Duration(seconds: expiresIn))
          .millisecondsSinceEpoch,
    );

    await saveCredentials(creds);
  }

  /// Get a valid access token, refreshing if necessary.
  Future<String?> getAccessToken() async {
    if (_credentials == null || !_credentials!.hasCredentials) {
      return null;
    }

    if (_credentials!.isExpired) {
      await _refreshToken();
    }

    return _credentials?.accessToken;
  }

  /// Refresh the access token.
  Future<void> _refreshToken() async {
    if (_credentials == null || _credentials!.refreshToken.isEmpty) {
      throw Exception('No refresh token');
    }

    final requestBody = jsonEncode({
      'grant_type': 'refresh_token',
      'client_id': ApiConstants.clientId,
      'refresh_token': _credentials!.refreshToken,
    });

    try {
      final (:statusCode, body: responseBody) = await _securePost(
        ApiConstants.tokenUrl,
        {
          'Content-Type': 'application/json',
          'User-Agent': ApiConstants.userAgent,
        },
        requestBody,
      );

      if (statusCode != 200) {
        developer.log(
          'Token refresh failed: $statusCode - $responseBody',
          name: 'OAuthService',
          level: 1000,
        );
        throw Exception('Token refresh failed: $statusCode');
      }

      final json = jsonDecode(responseBody);

      if (json is! Map<String, dynamic>) {
        throw const FormatException('Refresh response is not a JSON object');
      }

      final accessToken = json['access_token'];
      if (accessToken is! String || accessToken.isEmpty) {
        throw const FormatException(
            'Missing or invalid access_token in refresh response');
      }

      final refreshToken = json['refresh_token'];
      final expiresInRaw = json['expires_in'];
      final expiresIn = expiresInRaw is int ? expiresInRaw : 28800;

      final creds = _credentials!.copyWith(
        accessToken: accessToken,
        refreshToken:
            refreshToken is String ? refreshToken : _credentials!.refreshToken,
        expiresAt: DateTime.now()
            .add(Duration(seconds: expiresIn))
            .millisecondsSinceEpoch,
      );

      await saveCredentials(creds);
    } catch (e, stackTrace) {
      developer.log(
        'Token refresh error',
        name: 'OAuthService',
        error: e,
        stackTrace: stackTrace,
        level: 1000,
      );
      rethrow;
    }
  }

  /// Logout and clear credentials.
  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: _secureStorageKey);
    } catch (e, stackTrace) {
      developer.log(
        'Failed to delete credentials from secure storage',
        name: 'OAuthService',
        error: e,
        stackTrace: stackTrace,
        level: 900,
      );
    }

    _credentials = Credentials.empty;
    _credentials = null;
    _pendingVerifier = null;
    _pendingState = null;
  }
}
