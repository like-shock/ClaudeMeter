import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import '../models/credentials.dart';
import '../utils/constants.dart';
import '../utils/pkce.dart';

/// OAuth service for Claude authentication.
class OAuthService {
  Credentials? _credentials;
  final String _credentialsPath;

  OAuthService() : _credentialsPath = _getCredentialsPath();

  static String _getCredentialsPath() {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/${CredentialsConstants.credentialsFile}';
  }

  /// Whether the user has valid credentials.
  bool get hasCredentials => _credentials?.hasCredentials ?? false;

  /// Get current credentials.
  Credentials? get credentials => _credentials;

  /// Load credentials from file.
  Future<void> loadCredentials() async {
    try {
      final file = File(_credentialsPath);
      if (!await file.exists()) {
        _credentials = null;
        return;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final oauthData = json[CredentialsConstants.credentialsKey];

      if (oauthData != null) {
        _credentials = Credentials.fromJson(oauthData as Map<String, dynamic>);
      }
    } catch (e) {
      _credentials = null;
    }
  }

  /// Save credentials to file.
  Future<void> saveCredentials(Credentials creds) async {
    try {
      final file = File(_credentialsPath);

      // Read existing file to preserve other keys
      Map<String, dynamic> existing = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        existing = jsonDecode(content) as Map<String, dynamic>;
      }

      existing[CredentialsConstants.credentialsKey] = creds.toJson();

      // Ensure directory exists
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(existing));

      _credentials = creds;
    } catch (e) {
      rethrow;
    }
  }

  /// Start OAuth login flow.
  Future<bool> startLogin() async {
    final verifier = PKCE.generateVerifier();
    final challenge = PKCE.generateChallenge(verifier);
    final state = PKCE.generateState();

    // Start callback server
    final completer = Completer<String?>();
    HttpServer? server;

    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://localhost:$port/callback';

      // Handle callback
      server.listen((request) async {
        if (request.uri.path == '/callback') {
          final code = request.uri.queryParameters['code'];

          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write('''
              <html>
              <body style="font-family:sans-serif;text-align:center;padding:60px;background:#1e1e2e;color:#cdd6f4">
              <h2>✦ 인증 완료!</h2>
              <p>이 탭을 닫아도 됩니다.</p>
              </body>
              </html>
            ''');
          await request.response.close();

          if (!completer.isCompleted) {
            completer.complete(code);
          }
        } else {
          request.response.statusCode = 204;
          await request.response.close();
        }
      });

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

      final authUrl = Uri.parse(ApiConstants.authorizeUrl)
          .replace(queryParameters: params);

      // Open browser
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open browser');
      }

      // Wait for callback with timeout
      final code = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => null,
      );

      if (code == null) {
        return false;
      }

      // Exchange code for tokens
      await _exchangeCode(code, verifier, redirectUri);
      return true;
    } catch (e) {
      return false;
    } finally {
      await server?.close();
    }
  }

  Future<void> _exchangeCode(
      String code, String verifier, String redirectUri) async {
    final response = await http.post(
      Uri.parse(ApiConstants.tokenUrl),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': ApiConstants.userAgent,
      },
      body: jsonEncode({
        'code': code,
        'grant_type': 'authorization_code',
        'client_id': ApiConstants.clientId,
        'redirect_uri': redirectUri,
        'code_verifier': verifier,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Token exchange failed: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final expiresIn = json['expires_in'] as int? ?? 28800;

    final creds = Credentials(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? '',
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

  Future<void> _refreshToken() async {
    if (_credentials == null || _credentials!.refreshToken.isEmpty) {
      throw Exception('No refresh token');
    }

    final response = await http.post(
      Uri.parse(ApiConstants.tokenUrl),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': ApiConstants.userAgent,
      },
      body: jsonEncode({
        'grant_type': 'refresh_token',
        'client_id': ApiConstants.clientId,
        'refresh_token': _credentials!.refreshToken,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Token refresh failed: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final expiresIn = json['expires_in'] as int? ?? 28800;

    final creds = _credentials!.copyWith(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? _credentials!.refreshToken,
      expiresAt: DateTime.now()
          .add(Duration(seconds: expiresIn))
          .millisecondsSinceEpoch,
    );

    await saveCredentials(creds);
  }

  /// Logout and clear credentials.
  Future<void> logout() async {
    try {
      final file = File(_credentialsPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final existing = jsonDecode(content) as Map<String, dynamic>;
        existing.remove(CredentialsConstants.credentialsKey);
        await file.writeAsString(jsonEncode(existing));
      }
    } catch (_) {}

    _credentials = null;
  }
}
