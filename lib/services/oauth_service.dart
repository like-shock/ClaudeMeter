import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/credentials.dart';
import '../utils/constants.dart';
import '../utils/pkce.dart';

/// OAuth service for Claude authentication.
/// Uses AES-256 encrypted file storage (~/.claude/.credentials.json).
class OAuthService {
  Credentials? _credentials;
  Future<void>? _refreshLock;

  static String get _credentialsPath {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/${CredentialsConstants.credentialsFile}';
  }

  OAuthService();

  bool get hasCredentials => _credentials?.hasCredentials ?? false;
  Credentials? get credentials => _credentials;

  /// Derive AES-256 key from machine-unique values.
  encrypt.Key _deriveKey() {
    final hostname = Platform.localHostname;
    final username = Platform.environment['USER'] ?? Platform.environment['USERNAME'] ?? 'default';
    final salt = CredentialsConstants.encryptionSalt;
    final keyBytes = sha256.convert(utf8.encode('$hostname:$username:$salt')).bytes;
    return encrypt.Key(Uint8List.fromList(keyBytes));
  }

  /// POSIX chmod via dart:ffi — no external process dependency.
  static void _chmod(String path, int mode) {
    final lib = ffi.DynamicLibrary.process();
    final chmodFn = lib.lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Uint16),
        int Function(ffi.Pointer<ffi.Void>, int)>('chmod');
    final mallocFn = lib.lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.IntPtr),
        ffi.Pointer<ffi.Void> Function(int)>('malloc');
    final freeFn = lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<ffi.Void>),
        void Function(ffi.Pointer<ffi.Void>)>('free');

    final pathBytes = utf8.encode(path);
    final ptr = mallocFn(pathBytes.length + 1);
    final bytePtr = ptr.cast<ffi.Uint8>();
    for (var i = 0; i < pathBytes.length; i++) {
      bytePtr[i] = pathBytes[i];
    }
    bytePtr[pathBytes.length] = 0;
    try {
      chmodFn(ptr, mode);
    } finally {
      freeFn(ptr);
    }
  }

  /// Load credentials from encrypted file.
  Future<void> loadCredentials() async {
    try {
      final file = File(_credentialsPath);
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

      // Check if data is encrypted (has 'iv' and 'data' fields)
      if (oauthData.containsKey('iv') && oauthData.containsKey('data')) {
        // Decrypt
        final key = _deriveKey();
        final iv = encrypt.IV.fromBase64(oauthData['iv'] as String);
        final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
        final decrypted = encrypter.decrypt64(oauthData['data'] as String, iv: iv);
        final credJson = jsonDecode(decrypted) as Map<String, dynamic>;
        _credentials = Credentials.fromJson(credJson);
        if (kDebugMode) debugPrint('OAuth: Encrypted credentials loaded');
      } else {
        // Legacy plaintext format — migrate to encrypted
        _credentials = Credentials.fromJson(oauthData);
        if (kDebugMode) debugPrint('OAuth: Legacy plaintext detected, migrating...');
        await saveCredentials(_credentials!);
        if (kDebugMode) debugPrint('OAuth: Migration to encrypted format complete');
      }
    } catch (e, stackTrace) {
      developer.log('Failed to load credentials',
          name: 'OAuthService', error: e, stackTrace: stackTrace, level: 900);
      _credentials = null;
    }
  }

  /// Save credentials to encrypted file with restricted permissions.
  Future<void> saveCredentials(Credentials creds) async {
    try {
      final file = File(_credentialsPath);

      // Read existing file to preserve other keys
      Map<String, dynamic> existing = {};
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          existing = jsonDecode(content) as Map<String, dynamic>;
        } catch (_) {}
      }

      // Encrypt credentials
      final key = _deriveKey();
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final plaintext = jsonEncode(creds.toJson());
      final encrypted = encrypter.encrypt(plaintext, iv: iv);

      existing[CredentialsConstants.credentialsKey] = {
        'iv': iv.base64,
        'data': encrypted.base64,
      };

      // Ensure directory exists
      await file.parent.create(recursive: true);

      // Atomic write: temp file → chmod 600 → rename to target.
      // Eliminates TOCTOU race (target never exists with wrong permissions).
      final tempFile = File('${file.path}.$pid.tmp');
      await tempFile.writeAsString(jsonEncode(existing));
      _chmod(tempFile.path, 384); // 0600 octal
      await tempFile.rename(file.path);

      _credentials = creds;
      if (kDebugMode) debugPrint('OAuth: Encrypted credentials saved');
    } catch (e, stackTrace) {
      developer.log('Failed to save credentials',
          name: 'OAuthService', error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Create secure HTTP client.
  HttpClient _createSecureHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) {
      developer.log('Rejected bad certificate for $host:$port',
          name: 'OAuthService.TLS', level: 1000);
      return false;
    };
    return client;
  }

  /// Read HTTP response body with size limit to prevent OOM.
  static Future<String> _readLimited(HttpClientResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > ApiConstants.maxResponseBytes) {
        throw Exception('Response too large');
      }
    }
    return utf8.decode(bytes);
  }

  /// Make secure POST request.
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

      final response = await request.close().timeout(ApiConstants.apiTimeout);
      final responseBody = await _readLimited(response);
      return (statusCode: response.statusCode, body: responseBody);
    } finally {
      client.close();
    }
  }

  /// Full OAuth login flow with local callback server.
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

      if (kDebugMode) debugPrint('OAuth: Callback server started on port $port');

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
      var requestCount = 0;
      const maxRequests = 10;
      final completer = Completer<void>();
      final timeout = Timer(const Duration(seconds: 120), () {
        if (!completer.isCompleted) {
          if (kDebugMode) debugPrint('OAuth: Callback timeout');
          completer.complete();
        }
      });

      server.listen((request) {
        // Rate limit: reject after max requests
        requestCount++;
        if (requestCount > maxRequests) {
          request.response
            ..statusCode = HttpStatus.tooManyRequests
            ..close();
          if (!completer.isCompleted) completer.complete();
          return;
        }

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
      if (kDebugMode) debugPrint('OAuth: Exchanging code for tokens...');
      await _exchangeCode(authCode!, verifier, state, redirectUri);
      if (kDebugMode) debugPrint('OAuth: Login successful');
      return true;
    } catch (e, stackTrace) {
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
    final safeError = _escapeHtml(error);
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
<p>$safeError</p>
</div>
</body>
</html>
''')
      ..close();
  }

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
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

    if (statusCode != 200) {
      developer.log('Token exchange failed: $statusCode',
          name: 'OAuthService', level: 1000);
      throw Exception('Token exchange failed: $statusCode');
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
  /// Uses _refreshLock to prevent concurrent refresh requests.
  Future<String?> getAccessToken() async {
    if (_credentials == null || !_credentials!.hasCredentials) {
      return null;
    }

    if (_credentials!.isExpired) {
      if (_refreshLock != null) {
        await _refreshLock;
      } else {
        _refreshLock = _refreshToken();
        try {
          await _refreshLock;
        } finally {
          _refreshLock = null;
        }
      }
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

    final (:statusCode, body: responseBody) = await _securePost(
      ApiConstants.tokenUrl,
      {
        'Content-Type': 'application/json',
        'User-Agent': ApiConstants.userAgent,
      },
      requestBody,
    );

    if (statusCode != 200) {
      developer.log('Token refresh failed: $statusCode',
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
      refreshToken: refreshToken is String ? refreshToken : _credentials!.refreshToken,
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
        final json = jsonDecode(content) as Map<String, dynamic>;
        json.remove(CredentialsConstants.credentialsKey);
        if (json.isEmpty) {
          await file.delete();
        } else {
          await file.writeAsString(jsonEncode(json));
        }
      }
    } catch (e, stackTrace) {
      developer.log('Failed to delete credentials',
          name: 'OAuthService', error: e, stackTrace: stackTrace, level: 900);
    }
    _credentials = null;
  }
}
