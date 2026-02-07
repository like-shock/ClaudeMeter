import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claude_monitor_flutter/utils/pkce.dart';

void main() {
  group('PKCE', () {
    group('generateVerifier', () {
      test('generates non-empty verifier', () {
        final verifier = PKCE.generateVerifier();
        expect(verifier, isNotEmpty);
      });

      test('generates verifier of sufficient length', () {
        final verifier = PKCE.generateVerifier();
        // 32 bytes base64url encoded ≈ 43 chars
        expect(verifier.length, greaterThanOrEqualTo(40));
      });

      test('generates unique verifiers', () {
        final verifiers = List.generate(100, (_) => PKCE.generateVerifier());
        final unique = verifiers.toSet();
        expect(unique.length, equals(100));
      });

      test('generates URL-safe characters only', () {
        final verifier = PKCE.generateVerifier();
        // base64url without padding: [A-Za-z0-9_-]
        expect(verifier, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      });

      test('does not contain padding characters', () {
        for (int i = 0; i < 50; i++) {
          final verifier = PKCE.generateVerifier();
          expect(verifier, isNot(contains('=')));
        }
      });
    });

    group('generateChallenge', () {
      test('generates non-empty challenge', () {
        final verifier = PKCE.generateVerifier();
        final challenge = PKCE.generateChallenge(verifier);
        expect(challenge, isNotEmpty);
      });

      test('is deterministic for same verifier', () {
        final verifier = PKCE.generateVerifier();
        final challenge1 = PKCE.generateChallenge(verifier);
        final challenge2 = PKCE.generateChallenge(verifier);
        expect(challenge1, equals(challenge2));
      });

      test('produces different challenges for different verifiers', () {
        final verifier1 = PKCE.generateVerifier();
        final verifier2 = PKCE.generateVerifier();
        final challenge1 = PKCE.generateChallenge(verifier1);
        final challenge2 = PKCE.generateChallenge(verifier2);
        expect(challenge1, isNot(equals(challenge2)));
      });

      test('is valid S256 transform', () {
        final verifier = 'test_verifier_string';
        final challenge = PKCE.generateChallenge(verifier);

        // Manually compute expected challenge
        final bytes = utf8.encode(verifier);
        final digest = sha256.convert(bytes);
        final expected = base64UrlEncode(digest.bytes).replaceAll('=', '');

        expect(challenge, equals(expected));
      });

      test('generates URL-safe characters only', () {
        final verifier = PKCE.generateVerifier();
        final challenge = PKCE.generateChallenge(verifier);
        expect(challenge, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      });
    });

    group('generateState', () {
      test('generates non-empty state', () {
        final state = PKCE.generateState();
        expect(state, isNotEmpty);
      });

      test('generates unique states', () {
        final states = List.generate(100, (_) => PKCE.generateState());
        final unique = states.toSet();
        expect(unique.length, equals(100));
      });

      test('generates URL-safe characters only', () {
        final state = PKCE.generateState();
        expect(state, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      });

      test('has sufficient entropy (at least 32 bytes source)', () {
        final state = PKCE.generateState();
        // 32 bytes base64url encoded ≈ 43 chars
        expect(state.length, greaterThanOrEqualTo(40));
      });
    });
  });
}
