import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_test/flutter_test.dart';
import 'package:claude_monitor_flutter/models/credentials.dart';
import 'package:claude_monitor_flutter/utils/constants.dart';

/// Replicate OAuthService._deriveKey() logic for testing.
encrypt.Key _deriveKey() {
  final hostname = Platform.localHostname;
  final username = Platform.environment['USER'] ??
      Platform.environment['USERNAME'] ??
      'default';
  final salt = CredentialsConstants.encryptionSalt;
  final keyBytes =
      sha256.convert(utf8.encode('$hostname:$username:$salt')).bytes;
  return encrypt.Key(Uint8List.fromList(keyBytes));
}

void main() {
  group('AES-256 암호화', () {
    group('키 생성', () {
      test('동일 환경에서 동일 키 생성 (결정적)', () {
        final key1 = _deriveKey();
        final key2 = _deriveKey();
        expect(key1.bytes, equals(key2.bytes));
      });

      test('키 길이 32바이트 (AES-256)', () {
        final key = _deriveKey();
        expect(key.bytes.length, equals(32));
      });
    });

    group('암호화/복호화 라운드트립', () {
      test('Credentials 암호화 후 복호화 시 원본 복원', () {
        const original = Credentials(
          accessToken: 'test_access_token_abc123',
          refreshToken: 'test_refresh_token_xyz789',
          expiresAt: 1700000000000,
        );

        // Encrypt
        final key = _deriveKey();
        final iv = encrypt.IV.fromSecureRandom(16);
        final encrypter =
            encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
        final plaintext = jsonEncode(original.toJson());
        final encrypted = encrypter.encrypt(plaintext, iv: iv);

        // Decrypt
        final decrypted = encrypter.decrypt64(encrypted.base64, iv: iv);
        final restored =
            Credentials.fromJson(jsonDecode(decrypted) as Map<String, dynamic>);

        expect(restored.accessToken, equals(original.accessToken));
        expect(restored.refreshToken, equals(original.refreshToken));
        expect(restored.expiresAt, equals(original.expiresAt));
      });

      test('다른 IV로 암호화 시 다른 암호문 생성', () {
        const creds = Credentials(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: 12345,
        );

        final key = _deriveKey();
        final plaintext = jsonEncode(creds.toJson());

        final iv1 = encrypt.IV.fromSecureRandom(16);
        final iv2 = encrypt.IV.fromSecureRandom(16);
        final encrypter =
            encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

        final encrypted1 = encrypter.encrypt(plaintext, iv: iv1);
        final encrypted2 = encrypter.encrypt(plaintext, iv: iv2);

        expect(encrypted1.base64, isNot(equals(encrypted2.base64)));
      });

      test('빈 Credentials도 정상 암호화/복호화', () {
        const original = Credentials.empty;

        final key = _deriveKey();
        final iv = encrypt.IV.fromSecureRandom(16);
        final encrypter =
            encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
        final plaintext = jsonEncode(original.toJson());
        final encrypted = encrypter.encrypt(plaintext, iv: iv);

        final decrypted = encrypter.decrypt64(encrypted.base64, iv: iv);
        final restored =
            Credentials.fromJson(jsonDecode(decrypted) as Map<String, dynamic>);

        expect(restored.accessToken, equals(''));
        expect(restored.refreshToken, equals(''));
        expect(restored.expiresAt, equals(0));
      });
    });

    group('저장 포맷', () {
      test('암호화된 포맷은 iv와 data 필드 포함', () {
        const creds = Credentials(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: 99999,
        );

        final key = _deriveKey();
        final iv = encrypt.IV.fromSecureRandom(16);
        final encrypter =
            encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
        final plaintext = jsonEncode(creds.toJson());
        final encrypted = encrypter.encrypt(plaintext, iv: iv);

        final stored = {
          CredentialsConstants.credentialsKey: {
            'iv': iv.base64,
            'data': encrypted.base64,
          },
        };

        final storedJson = jsonEncode(stored);
        final parsed = jsonDecode(storedJson) as Map<String, dynamic>;
        final oauthData = parsed[CredentialsConstants.credentialsKey]
            as Map<String, dynamic>;

        expect(oauthData.containsKey('iv'), isTrue);
        expect(oauthData.containsKey('data'), isTrue);
        expect(oauthData.containsKey('accessToken'), isFalse);
        expect(oauthData.containsKey('refreshToken'), isFalse);
      });

      test('저장된 암호화 데이터에서 평문 토큰 노출 안 됨', () {
        const creds = Credentials(
          accessToken: 'super_secret_access_token',
          refreshToken: 'super_secret_refresh_token',
          expiresAt: 12345,
        );

        final key = _deriveKey();
        final iv = encrypt.IV.fromSecureRandom(16);
        final encrypter =
            encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
        final plaintext = jsonEncode(creds.toJson());
        final encrypted = encrypter.encrypt(plaintext, iv: iv);

        final stored = jsonEncode({
          CredentialsConstants.credentialsKey: {
            'iv': iv.base64,
            'data': encrypted.base64,
          },
        });

        expect(stored, isNot(contains('super_secret_access_token')));
        expect(stored, isNot(contains('super_secret_refresh_token')));
      });
    });

    group('레거시 평문 감지', () {
      test('평문 포맷은 iv/data 필드 없음', () {
        final legacyData = {
          'accessToken': 'plain_token',
          'refreshToken': 'plain_refresh',
          'expiresAt': 12345,
        };

        final isEncrypted =
            legacyData.containsKey('iv') && legacyData.containsKey('data');
        expect(isEncrypted, isFalse);
      });

      test('암호화 포맷은 iv/data 필드 있음', () {
        final encryptedData = {
          'iv': 'base64encodediv==',
          'data': 'base64encodeddata==',
        };

        final isEncrypted =
            encryptedData.containsKey('iv') && encryptedData.containsKey('data');
        expect(isEncrypted, isTrue);
      });

      test('레거시 평문 데이터를 Credentials로 파싱 가능', () {
        final legacyData = {
          'accessToken': 'old_token',
          'refreshToken': 'old_refresh',
          'expiresAt': 1700000000000,
        };

        final creds = Credentials.fromJson(legacyData);
        expect(creds.accessToken, equals('old_token'));
        expect(creds.refreshToken, equals('old_refresh'));
      });
    });

    group('파일 기반 라운드트립', () {
      test('임시 파일에 암호화 저장 후 복호화 읽기', () async {
        final tempDir = await Directory.systemTemp.createTemp('cred_test_');
        final tempFile = File('${tempDir.path}/.credentials.json');

        try {
          const original = Credentials(
            accessToken: 'file_test_access',
            refreshToken: 'file_test_refresh',
            expiresAt: 1800000000000,
          );

          // Encrypt and save
          final key = _deriveKey();
          final iv = encrypt.IV.fromSecureRandom(16);
          final encrypter =
              encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
          final plaintext = jsonEncode(original.toJson());
          final encrypted = encrypter.encrypt(plaintext, iv: iv);

          final fileContent = jsonEncode({
            CredentialsConstants.credentialsKey: {
              'iv': iv.base64,
              'data': encrypted.base64,
            },
          });
          await tempFile.writeAsString(fileContent);

          // Read and decrypt
          final readContent = await tempFile.readAsString();
          final parsed = jsonDecode(readContent) as Map<String, dynamic>;
          final oauthData = parsed[CredentialsConstants.credentialsKey]
              as Map<String, dynamic>;

          final readIv = encrypt.IV.fromBase64(oauthData['iv'] as String);
          final decrypted =
              encrypter.decrypt64(oauthData['data'] as String, iv: readIv);
          final restored = Credentials.fromJson(
              jsonDecode(decrypted) as Map<String, dynamic>);

          expect(restored.accessToken, equals(original.accessToken));
          expect(restored.refreshToken, equals(original.refreshToken));
          expect(restored.expiresAt, equals(original.expiresAt));

          // Verify file content doesn't contain plaintext tokens
          expect(readContent, isNot(contains('file_test_access')));
          expect(readContent, isNot(contains('file_test_refresh')));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('보안 검증', () {
      test('잘못된 키로 복호화 실패', () {
        const creds = Credentials(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: 12345,
        );

        final correctKey = _deriveKey();
        final wrongKey = encrypt.Key.fromSecureRandom(32);
        final iv = encrypt.IV.fromSecureRandom(16);

        final encrypter = encrypt.Encrypter(
            encrypt.AES(correctKey, mode: encrypt.AESMode.cbc));
        final plaintext = jsonEncode(creds.toJson());
        final encrypted = encrypter.encrypt(plaintext, iv: iv);

        final wrongEncrypter = encrypt.Encrypter(
            encrypt.AES(wrongKey, mode: encrypt.AESMode.cbc));

        expect(
          () => wrongEncrypter.decrypt64(encrypted.base64, iv: iv),
          throwsA(anything),
        );
      });

      test('잘못된 IV로 복호화 시 원본과 다른 결과', () {
        const creds = Credentials(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: 12345,
        );

        final key = _deriveKey();
        final correctIv = encrypt.IV.fromSecureRandom(16);
        final wrongIv = encrypt.IV.fromSecureRandom(16);

        final encrypter =
            encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
        final plaintext = jsonEncode(creds.toJson());
        final encrypted = encrypter.encrypt(plaintext, iv: correctIv);

        // Wrong IV should either throw or produce garbage
        try {
          final decrypted =
              encrypter.decrypt64(encrypted.base64, iv: wrongIv);
          // If it doesn't throw, the result should differ
          expect(decrypted, isNot(equals(plaintext)));
        } catch (_) {
          // Expected — wrong IV causes decryption failure
        }
      });

      test('IV는 매번 랜덤 생성 (16바이트)', () {
        final iv1 = encrypt.IV.fromSecureRandom(16);
        final iv2 = encrypt.IV.fromSecureRandom(16);

        expect(iv1.bytes.length, equals(16));
        expect(iv2.bytes.length, equals(16));
        expect(iv1.bytes, isNot(equals(iv2.bytes)));
      });
    });
  });
}
