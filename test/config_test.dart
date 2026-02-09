import 'package:flutter_test/flutter_test.dart';
import 'package:claude_meter/models/config.dart';

void main() {
  group('AppMode', () {
    test('enum has plan and api values', () {
      expect(AppMode.values.length, equals(2));
      expect(AppMode.values, contains(AppMode.plan));
      expect(AppMode.values, contains(AppMode.api));
    });

    test('name returns correct string', () {
      expect(AppMode.plan.name, 'plan');
      expect(AppMode.api.name, 'api');
    });
  });

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
        expect(config.appMode, isNull);
      });

      test('uses defaults for missing fields', () {
        final config = AppConfig.fromJson({});
        expect(config.refreshIntervalSeconds, equals(60));
        expect(config.showFiveHour, isTrue);
        expect(config.showSevenDay, isTrue);
        expect(config.showSonnet, isTrue);
        expect(config.appMode, isNull);
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

      test('parses appMode plan', () {
        final config = AppConfig.fromJson({'appMode': 'plan'});
        expect(config.appMode, AppMode.plan);
      });

      test('parses appMode api', () {
        final config = AppConfig.fromJson({'appMode': 'api'});
        expect(config.appMode, AppMode.api);
      });

      test('handles invalid appMode string', () {
        final config = AppConfig.fromJson({'appMode': 'invalid'});
        expect(config.appMode, isNull);
      });

      test('handles non-string appMode', () {
        final config = AppConfig.fromJson({'appMode': 42});
        expect(config.appMode, isNull);
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

      test('round-trip preserves appMode plan', () {
        const original = AppConfig(appMode: AppMode.plan);
        final json = original.toJson();
        expect(json['appMode'], 'plan');
        final restored = AppConfig.fromJson(json);
        expect(restored.appMode, AppMode.plan);
      });

      test('round-trip preserves appMode api', () {
        const original = AppConfig(appMode: AppMode.api);
        final json = original.toJson();
        expect(json['appMode'], 'api');
        final restored = AppConfig.fromJson(json);
        expect(restored.appMode, AppMode.api);
      });

      test('round-trip preserves null appMode', () {
        const original = AppConfig();
        final json = original.toJson();
        expect(json['appMode'], isNull);
        final restored = AppConfig.fromJson(json);
        expect(restored.appMode, isNull);
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

      test('sets appMode', () {
        const config = AppConfig();
        final updated = config.copyWith(appMode: AppMode.api);
        expect(updated.appMode, AppMode.api);
      });

      test('preserves appMode when not specified', () {
        const config = AppConfig(appMode: AppMode.plan);
        final updated = config.copyWith(refreshIntervalSeconds: 30);
        expect(updated.appMode, AppMode.plan);
      });

      test('clearAppMode resets to null', () {
        const config = AppConfig(appMode: AppMode.api);
        final updated = config.copyWith(clearAppMode: true);
        expect(updated.appMode, isNull);
      });
    });
  });
}
