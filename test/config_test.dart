import 'package:flutter_test/flutter_test.dart';
import 'package:claude_meter/models/config.dart';

void main() {
  group('AppConfig', () {
    group('fromJson', () {
      test('parses valid JSON', () {
        final config = AppConfig.fromJson({
          'refreshIntervalSeconds': 60,
          'showFiveHour': false,
          'showSevenDay': true,
          'showSonnet': false,
        });
        expect(config.refreshIntervalSeconds, equals(60));
        expect(config.showFiveHour, isFalse);
        expect(config.showSevenDay, isTrue);
        expect(config.showSonnet, isFalse);
      });

      test('uses defaults for missing fields', () {
        final config = AppConfig.fromJson({});
        expect(config.refreshIntervalSeconds, equals(60));
        expect(config.showFiveHour, isTrue);
        expect(config.showSevenDay, isTrue);
        expect(config.showSonnet, isTrue);
      });

      test('handles null values with defaults', () {
        final config = AppConfig.fromJson({
          'refreshIntervalSeconds': null,
          'showFiveHour': null,
        });
        expect(config.refreshIntervalSeconds, equals(60));
        expect(config.showFiveHour, isTrue);
      });

      test('handles invalid types with defaults', () {
        final config = AppConfig.fromJson({
          'refreshIntervalSeconds': 'sixty',
          'showFiveHour': 'yes',
        });
        expect(config.refreshIntervalSeconds, equals(60));
        expect(config.showFiveHour, isTrue);
      });
    });

    group('toJson', () {
      test('round-trip preserves data', () {
        const original = AppConfig(
          refreshIntervalSeconds: 120,
          showFiveHour: false,
          showSevenDay: true,
          showSonnet: false,
        );
        final restored = AppConfig.fromJson(original.toJson());
        expect(restored.refreshIntervalSeconds, equals(120));
        expect(restored.showFiveHour, isFalse);
        expect(restored.showSevenDay, isTrue);
        expect(restored.showSonnet, isFalse);
      });
    });

    group('copyWith', () {
      test('updates specified field only', () {
        const config = AppConfig.defaultConfig;
        final updated = config.copyWith(refreshIntervalSeconds: 90);
        expect(updated.refreshIntervalSeconds, equals(90));
        expect(updated.showFiveHour, isTrue);
      });

      test('preserves all when no args', () {
        const config = AppConfig(
          refreshIntervalSeconds: 45,
          showFiveHour: false,
          showSevenDay: false,
          showSonnet: false,
        );
        final copy = config.copyWith();
        expect(copy.refreshIntervalSeconds, equals(45));
        expect(copy.showFiveHour, isFalse);
      });
    });
  });
}
