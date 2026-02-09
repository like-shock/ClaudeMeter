import 'package:flutter_test/flutter_test.dart';
import 'package:claude_meter/utils/pkce.dart';

/// Tests for OAuth state (CSRF) verification logic.
///
/// Note: The actual state verification happens inside OAuthService.startLogin()
/// callback handler. These tests verify the underlying state generation and
/// comparison logic that the verification depends on.
void main() {
  group('OAuth State Verification', () {
    test('generated states are unique per login attempt', () {
      // Each login should have a unique state to prevent replay attacks
      final states = List.generate(50, (_) => PKCE.generateState());
      final unique = states.toSet();
      expect(unique.length, equals(50));
    });

    test('state comparison is exact match', () {
      final state1 = PKCE.generateState();
      final state2 = PKCE.generateState();

      // Same state should match
      expect(state1 == state1, isTrue);

      // Different states should not match
      expect(state1 == state2, isFalse);
    });

    test('state is not empty', () {
      final state = PKCE.generateState();
      expect(state, isNotEmpty);
    });

    test('state has sufficient length for security', () {
      final state = PKCE.generateState();
      // At least 32 bytes of entropy (base64url ≈ 43 chars)
      expect(state.length, greaterThanOrEqualTo(40));
    });

    test('state does not contain URL-unsafe characters', () {
      for (int i = 0; i < 50; i++) {
        final state = PKCE.generateState();
        // Should only contain base64url characters (no =, +, /)
        expect(state, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
        expect(state, isNot(contains('=')));
        expect(state, isNot(contains('+')));
        expect(state, isNot(contains('/')));
      }
    });

    test('null state should fail verification', () {
      final validState = PKCE.generateState();

      // Simulates callback handler logic where state could be null from query params.
      // Using a helper to avoid static analysis "always null" warning.
      bool verifyState(String? returned, String expected) {
        return returned != null && returned == expected;
      }

      expect(verifyState(null, validState), isFalse);
    });

    test('empty string state should fail comparison', () {
      final validState = PKCE.generateState();
      const emptyState = '';

      expect(emptyState != validState, isTrue);
    });

    test('tampered state should fail comparison', () {
      final originalState = PKCE.generateState();
      // Tamper with the state
      final tamperedState = '${originalState}x';

      expect(tamperedState != originalState, isTrue);
    });

    test('truncated state should fail comparison', () {
      final originalState = PKCE.generateState();
      final truncatedState = originalState.substring(0, 10);

      expect(truncatedState != originalState, isTrue);
    });

    group('state preview (logging safety)', () {
      test('handles state shorter than 8 chars without RangeError', () {
        const shortState = 'abc';
        // Simulate the safe preview logic from OAuthService
        final preview = shortState.length >= 8
            ? '${shortState.substring(0, 8)}...'
            : shortState;
        expect(preview, equals('abc'));
      });

      test('handles exactly 8 char state', () {
        const state8 = 'abcdefgh';
        final preview = state8.length >= 8
            ? '${state8.substring(0, 8)}...'
            : state8;
        expect(preview, equals('abcdefgh...'));
      });

      test('handles empty state without RangeError', () {
        const emptyState = '';
        final preview = emptyState.length >= 8
            ? '${emptyState.substring(0, 8)}...'
            : emptyState;
        expect(preview, equals(''));
      });

      test('handles null state preview', () {
        const String? nullState = null;
        final preview = (nullState != null && nullState.length >= 8)
            ? '${nullState.substring(0, 8)}...'
            : nullState ?? 'null';
        expect(preview, equals('null'));
      });

      test('normal length state shows first 8 chars', () {
        final normalState = PKCE.generateState();
        final preview = normalState.length >= 8
            ? '${normalState.substring(0, 8)}...'
            : normalState;
        expect(preview, endsWith('...'));
        expect(preview.length, equals(11)); // 8 chars + '...'
      });
    });
  });
}
