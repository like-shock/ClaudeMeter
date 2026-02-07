import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// PKCE (Proof Key for Code Exchange) utilities.
class PKCE {
  /// Generate a random code verifier.
  static String generateVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Generate a code challenge from the verifier using S256.
  static String generateChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Generate a random state parameter for CSRF protection.
  static String generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
