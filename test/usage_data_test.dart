import 'package:flutter_test/flutter_test.dart';
import 'package:claude_monitor_flutter/models/usage_data.dart';

void main() {
  group('UsageTier', () {
    group('fromJson', () {
      test('parses valid JSON correctly', () {
        final tier = UsageTier.fromJson({
          'utilization': 0.75,
          'resets_at': '2026-02-08T00:00:00Z',
        });
        expect(tier.utilization, equals(0.75));
        expect(tier.resetsAt, isNotNull);
        expect(tier.percentage, equals(75));
      });

      test('handles null JSON', () {
        final tier = UsageTier.fromJson(null);
        expect(tier.utilization, equals(0.0));
        expect(tier.resetsAt, isNull);
        expect(tier.percentage, equals(0));
      });

      test('handles missing fields', () {
        final tier = UsageTier.fromJson({});
        expect(tier.utilization, equals(0.0));
        expect(tier.resetsAt, isNull);
      });

      test('handles invalid resets_at gracefully', () {
        final tier = UsageTier.fromJson({
          'utilization': 0.5,
          'resets_at': 'not-a-date',
        });
        expect(tier.utilization, equals(0.5));
        expect(tier.resetsAt, isNull);
      });

      test('handles int utilization', () {
        final tier = UsageTier.fromJson({
          'utilization': 1,
        });
        expect(tier.utilization, equals(1.0));
        expect(tier.percentage, equals(100));
      });
    });
  });

  group('UsageData', () {
    group('fromJson', () {
      test('parses complete response', () {
        final data = UsageData.fromJson({
          'five_hour': {'utilization': 0.3, 'resets_at': '2026-02-08T05:00:00Z'},
          'seven_day': {'utilization': 0.6},
          'seven_day_sonnet': {'utilization': 0.1},
        });
        expect(data.fiveHour.percentage, equals(30));
        expect(data.sevenDay.percentage, equals(60));
        expect(data.sevenDaySonnet.percentage, equals(10));
        expect(data.fetchedAt, isNotNull);
      });

      test('handles missing tiers', () {
        final data = UsageData.fromJson({});
        expect(data.fiveHour.percentage, equals(0));
        expect(data.sevenDay.percentage, equals(0));
        expect(data.sevenDaySonnet.percentage, equals(0));
      });
    });

    test('empty() returns zero utilization', () {
      final data = UsageData.empty();
      expect(data.fiveHour.percentage, equals(0));
      expect(data.sevenDay.percentage, equals(0));
      expect(data.sevenDaySonnet.percentage, equals(0));
    });
  });
}
