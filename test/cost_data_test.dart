import 'package:flutter_test/flutter_test.dart';
import 'package:claude_meter/models/cost_data.dart';
import 'package:claude_meter/utils/pricing.dart';

void main() {
  group('CostData', () {
    test('empty() returns zeroed data', () {
      final data = CostData.empty();
      expect(data.todayCost, 0);
      expect(data.totalCost, 0);
      expect(data.totalSessions, 0);
      expect(data.totalFiles, 0);
      expect(data.modelBreakdown, isEmpty);
      expect(data.dailyCosts, isEmpty);
      expect(data.oldestSession, isNull);
      expect(data.newestSession, isNull);
    });
  });

  group('ModelCost', () {
    test('stores model cost data', () {
      const modelCost = ModelCost(
        modelId: 'claude-opus-4-6',
        displayName: 'Opus 4.6',
        tokens: TokenUsage(inputTokens: 1000, outputTokens: 500),
        cost: 0.015,
      );
      expect(modelCost.modelId, 'claude-opus-4-6');
      expect(modelCost.displayName, 'Opus 4.6');
      expect(modelCost.cost, 0.015);
      expect(modelCost.tokens.inputTokens, 1000);
    });
  });

  group('DailyCost', () {
    test('stores daily cost data', () {
      final daily = DailyCost(
        date: DateTime(2026, 2, 9),
        cost: 1.50,
        messageCount: 42,
      );
      expect(daily.date.year, 2026);
      expect(daily.date.month, 2);
      expect(daily.date.day, 9);
      expect(daily.cost, 1.50);
      expect(daily.messageCount, 42);
      expect(daily.totalTokens, 0);
    });

    test('stores totalTokens', () {
      final daily = DailyCost(
        date: DateTime(2026, 2, 9),
        cost: 2.50,
        messageCount: 10,
        totalTokens: 150000,
      );
      expect(daily.totalTokens, 150000);
    });

    test('totalTokens defaults to 0', () {
      final daily = DailyCost(
        date: DateTime(2026, 2, 9),
        cost: 0,
        messageCount: 0,
      );
      expect(daily.totalTokens, 0);
    });
  });
}
