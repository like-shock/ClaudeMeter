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
/// Uses local HTTP callback server for automatic code exchange,
/// matching the original ClaudeMonitor Python implementation.
class OAuthService {
  Credentials? _credentials;

  static const String _secureStorageKey = 'claude_oauth_credentials';

  static String get _legacyCredentialsPath {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/${CredentialsConstants.credentialsFile}';
  }

  final FlutterSecureStorage _secureStorage;

  OAuthService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  bool get hasCredentials => _credentials?.hasCredentials ?? false;
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
      await _migrateFromLegacyFile();
    } catch (e, stackTrace) {
      developer.log('Failed to load credentials',
          name: 'OAuthService', error: e, stackTrace: stackTrace, level: 900);
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

      await _secureStorage.write(
        key: _secureStorageKey,
        value: jsonEncode(_credentials!.toJson()),
      );

      json.remove(CredentialsConstants.credentialsKey);
      if (json.isEmpty) {
        await file.delete();
      } else {
        await file.writeAsString(jsonEncode(json));
      }

      developer.log('Migrated credentials from plaintext file to secure storage',
          name: 'OAuthService', level: 800);
    } catch (e, stackTrace) {
      developer.log('Failed to migrate legacy credentials',
          name: 'OAuthService', error: e, stackTrace: stackTrace, level: 900);
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
      developer.log('Failed to save credentials to secure storage',
          name: 'OAuthService', error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  HttpClient _createSecureHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) {
      developer.log('Rejected bad certificate for $host:$port',
          name: 'OAuthService.TLS', level: 1000);
      return false;
    };
    return client;
  }

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

  /// Full OAuth login flow with local callback server.
  /// Opens browser, waits for callback, exchanges code for tokens.
  Future<bool> login() async {
    HttpServer? server;

    try {
      // Generate PKCE parameters
      final verifier = PKCE.generateVerifier();
      final challenge = PKCE.generateChallenge(verifier);
      final state = PKCE.generateState();

      // Start local callback server on random port
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://localhost:$port/callback';

      debugPrint('OAuth: Callback server started on port $port');

      // Build authorization URL
      final params = {
        'client_id': ApiConstants.clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': ApiConstants.oauthScopes,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': state,
      };

      final authUrl =
          Uri.parse(ApiConstants.authorizeUrl).replace(queryParameters: params);

      // Open browser
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open browser');
      }

      // Wait for callback (120 second timeout)
      String? authCode;
      final completer = Completer<void>();
      final timeout = Timer(const Duration(seconds: 120), () {
        if (!completer.isCompleted) {
          debugPrint('OAuth: Callback timeout');
          completer.complete();
        }
      });

      server.listen((request) {
        final uri = request.uri;

        // Ignore non-callback requests (favicon, etc.)
        if (uri.path != '/callback') {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
          return;
        }

        final code = uri.queryParameters['code'];
        final returnedState = uri.queryParameters['state'];
        final error = uri.queryParameters['error'];

        if (error != null) {
          _sendErrorPage(request.response, error);
        } else if (code == null || returnedState == null) {
          _sendErrorPage(request.response, '인증 코드가 없습니다.');
        } else if (returnedState != state) {
          _sendErrorPage(request.response, 'CSRF 검증 실패');
        } else {
          authCode = code;
          _sendSuccessPage(request.response);
        }

        if (!completer.isCompleted) completer.complete();
      });

      await completer.future;
      timeout.cancel();
      await server.close();
      server = null;

      if (authCode == null) {
        return false;
      }

      // Exchange code for tokens
      debugPrint('OAuth: Exchanging code for tokens...');
      await _exchangeCode(authCode!, verifier, state, redirectUri);
      debugPrint('OAuth: Token exchange successful!');
      return true;
    } catch (e, stackTrace) {
      debugPrint('OAuth: Login failed: $e');
      developer.log('Login failed',
          name: 'OAuthService', error: e, stackTrace: stackTrace, level: 1000);
      return false;
    } finally {
      try {
        await server?.close();
      } catch (_) {}
    }
  }

  void _sendSuccessPage(HttpResponse response) {
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write('''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>인증 완료</title></head>
<body style="background:#1e1e2e;color:#cdd6f4;font-family:system-ui;display:flex;justify-content:center;align-items:center;height:100vh;margin:0">
<div style="text-align:center">
<h1 style="color:#a6e3a1">✓ 인증 완료!</h1>
<p>이 창을 닫고 앱으로 돌아가세요.</p>
</div>
</body>
</html>
''')
      ..close();
  }

  void _sendErrorPage(HttpResponse response, String error) {
    response
      ..statusCode = HttpStatus.badRequest
      ..headers.contentType = ContentType.html
      ..write('''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>인증 실패</title></head>
<body style="background:#1e1e2e;color:#cdd6f4;font-family:system-ui;display:flex;justify-content:center;align-items:center;height:100vh;margin:0">
<div style="text-align:center">
<h1 style="color:#f38ba8">✗ 인증 실패</h1>
<p>$error</p>
</div>
</body>
</html>
''')
      ..close();
  }

  /// Exchange authorization code for tokens.
  Future<void> _exchangeCode(
      String code, String verifier, String state, String redirectUri) async {
    final requestBody = jsonEncode({
      'grant_type': 'authorization_code',
      'client_id': ApiConstants.clientId,
      'code': code,
      'redirect_uri': redirectUri,
      'code_verifier': verifier,
      'state': state,
    });

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
      throw Exception('Token exchange failed: $statusCode - $responseBody');
    }

    final json = jsonDecode(responseBody);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Token response is not a JSON object');
    }

    final accessToken = json['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const FormatException('Missing or invalid access_token');
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
        developer.log('Token refresh failed: $statusCode - $responseBody',
            name: 'OAuthService', level: 1000);
        throw Exception('Token refresh failed: $statusCode');
      }

      final json = jsonDecode(responseBody);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Refresh response is not a JSON object');
      }

      final accessToken = json['access_token'];
      if (accessToken is! String || accessToken.isEmpty) {
        throw const FormatException('Missing or invalid access_token');
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
      developer.log('Token refresh error',
          name: 'OAuthService', error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Logout and clear credentials.
  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: _secureStorageKey);
    } catch (e, stackTrace) {
      developer.log('Failed to delete credentials from secure storage',
          name: 'OAuthService', error: e, stackTrace: stackTrace, level: 900);
    }

    _credentials = Credentials.empty;
    _credentials = null;
  }
}
