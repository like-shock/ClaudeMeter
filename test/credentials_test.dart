import 'package:flutter_test/flutter_test.dart';
import 'package:claude_meter/models/credentials.dart';

void main() {
  group('Credentials', () {
    group('fromJson', () {
      test('parses valid JSON correctly', () {
        final creds = Credentials.fromJson({
          'accessToken': 'test_access_token',
          'refreshToken': 'test_refresh_token',
          'expiresAt': 1700000000000,
        });

        expect(creds.accessToken, equals('test_access_token'));
        expect(creds.refreshToken, equals('test_refresh_token'));
        expect(creds.expiresAt, equals(1700000000000));
      });

      test('handles missing fields with defaults', () {
        final creds = Credentials.fromJson({});

        expect(creds.accessToken, equals(''));
        expect(creds.refreshToken, equals(''));
        expect(creds.expiresAt, equals(0));
      });

      test('handles null values with defaults', () {
        final creds = Credentials.fromJson({
          'accessToken': null,
          'refreshToken': null,
          'expiresAt': null,
        });

        expect(creds.accessToken, equals(''));
        expect(creds.refreshToken, equals(''));
        expect(creds.expiresAt, equals(0));
      });

      test('throws FormatException for invalid accessToken type', () {
        expect(
          () => Credentials.fromJson({'accessToken': 123}),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for invalid refreshToken type', () {
        expect(
          () => Credentials.fromJson({'refreshToken': true}),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for invalid expiresAt type', () {
        expect(
          () => Credentials.fromJson({'expiresAt': '1700000000000'}),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('toJson', () {
      test('serializes correctly', () {
        const creds = Credentials(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: 12345,
        );

        final json = creds.toJson();
        expect(json['accessToken'], equals('token'));
        expect(json['refreshToken'], equals('refresh'));
        expect(json['expiresAt'], equals(12345));
      });

      test('round-trip: fromJson(toJson()) preserves data', () {
        const original = Credentials(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: 9999999999999,
        );

        final restored = Credentials.fromJson(original.toJson());
        expect(restored.accessToken, equals(original.accessToken));
        expect(restored.refreshToken, equals(original.refreshToken));
        expect(restored.expiresAt, equals(original.expiresAt));
      });
    });

    group('hasCredentials', () {
      test('returns true when refreshToken is present', () {
        const creds = Credentials(
          accessToken: '',
          refreshToken: 'some_token',
          expiresAt: 0,
        );
        expect(creds.hasCredentials, isTrue);
      });

      test('returns false when refreshToken is empty', () {
        const creds = Credentials(
          accessToken: 'some_access',
          refreshToken: '',
          expiresAt: 0,
        );
        expect(creds.hasCredentials, isFalse);
      });
    });

    group('isExpired', () {
      test('returns true when expiresAt is 0', () {
        const creds = Credentials(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: 0,
        );
        expect(creds.isExpired, isTrue);
      });

      test('returns true when expired', () {
        final pastTime = DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch;
        final creds = Credentials(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: pastTime,
        );
        expect(creds.isExpired, isTrue);
      });

      test('returns false when not expired (far future)', () {
        final futureTime = DateTime.now()
            .add(const Duration(hours: 8))
            .millisecondsSinceEpoch;
        final creds = Credentials(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: futureTime,
        );
        expect(creds.isExpired, isFalse);
      });

      test('returns true within 1 minute buffer', () {
        // Expires in 30 seconds, but 1 minute buffer makes it "expired"
        final soonTime = DateTime.now()
            .add(const Duration(seconds: 30))
            .millisecondsSinceEpoch;
        final creds = Credentials(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: soonTime,
        );
        expect(creds.isExpired, isTrue);
      });
    });

    group('copyWith', () {
      test('copies with updated accessToken', () {
        const original = Credentials(
          accessToken: 'old',
          refreshToken: 'refresh',
          expiresAt: 100,
        );
        final updated = original.copyWith(accessToken: 'new');
        expect(updated.accessToken, equals('new'));
        expect(updated.refreshToken, equals('refresh'));
        expect(updated.expiresAt, equals(100));
      });

      test('preserves all fields when no arguments given', () {
        const original = Credentials(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: 42,
        );
        final copy = original.copyWith();
        expect(copy.accessToken, equals(original.accessToken));
        expect(copy.refreshToken, equals(original.refreshToken));
        expect(copy.expiresAt, equals(original.expiresAt));
      });
    });

    group('empty', () {
      test('has empty tokens and zero expiry', () {
        expect(Credentials.empty.accessToken, equals(''));
        expect(Credentials.empty.refreshToken, equals(''));
        expect(Credentials.empty.expiresAt, equals(0));
      });

      test('has no credentials', () {
        expect(Credentials.empty.hasCredentials, isFalse);
      });

      test('is expired', () {
        expect(Credentials.empty.isExpired, isTrue);
      });
    });
  });
}
