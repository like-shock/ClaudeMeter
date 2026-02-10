import 'package:flutter_test/flutter_test.dart';
import 'package:claude_meter/models/cost_data.dart';
import 'package:claude_meter/utils/pricing.dart';

void main() {
  group('CostData', () {
    test('empty() returns zeroed data', () {
      final data = CostData.empty();
      expect(data.totalSessions, 0);
      expect(data.totalFiles, 0);
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

    test('toJson/fromJson roundtrip preserves all fields', () {
      final original = DailyCost(
        date: DateTime(2026, 2, 9),
        cost: 3.14,
        messageCount: 42,
        totalTokens: 150000,
        modelTokens: {
          'claude-opus-4-6': const TokenUsage(
            inputTokens: 1000,
            cacheCreationInputTokens: 500,
            cacheReadInputTokens: 200,
            ephemeral5mInputTokens: 100,
            ephemeral1hInputTokens: 400,
            outputTokens: 300,
          ),
          'claude-sonnet-4-5': const TokenUsage(
            inputTokens: 2000,
            outputTokens: 600,
          ),
        },
      );
      final json = original.toJson();
      final restored = DailyCost.fromJson(json);
      expect(restored.date, original.date);
      expect(restored.cost, original.cost);
      expect(restored.messageCount, original.messageCount);
      expect(restored.totalTokens, original.totalTokens);
      expect(restored.modelTokens.length, 2);
      expect(restored.modelTokens['claude-opus-4-6']!.inputTokens, 1000);
      expect(restored.modelTokens['claude-opus-4-6']!.ephemeral1hInputTokens, 400);
      expect(restored.modelTokens['claude-sonnet-4-5']!.outputTokens, 600);
    });

    test('fromJson handles missing modelTokens', () {
      final json = {
        'date': '2026-02-09T00:00:00.000',
        'cost': 1.0,
        'messageCount': 5,
      };
      final restored = DailyCost.fromJson(json);
      expect(restored.modelTokens, isEmpty);
      expect(restored.totalTokens, 0);
    });
  });

  group('CostData serialization', () {
    test('toJson/fromJson roundtrip preserves all fields', () {
      final original = CostData(
        totalSessions: 5,
        totalFiles: 10,
        oldestSession: DateTime.utc(2026, 1, 1),
        newestSession: DateTime.utc(2026, 2, 9),
        fetchedAt: DateTime.utc(2026, 2, 9, 12, 0),
        dailyCosts: [
          DailyCost(
            date: DateTime(2026, 2, 8),
            cost: 1.5,
            messageCount: 20,
            totalTokens: 50000,
            modelTokens: {
              'claude-opus-4-6': const TokenUsage(inputTokens: 500, outputTokens: 200),
            },
          ),
          DailyCost(
            date: DateTime(2026, 2, 9),
            cost: 2.0,
            messageCount: 30,
            totalTokens: 80000,
          ),
        ],
      );
      final json = original.toJson();
      final restored = CostData.fromJson(json);
      expect(restored.totalSessions, 5);
      expect(restored.totalFiles, 10);
      expect(restored.oldestSession, DateTime.utc(2026, 1, 1));
      expect(restored.newestSession, DateTime.utc(2026, 2, 9));
      expect(restored.dailyCosts.length, 2);
      expect(restored.dailyCosts[0].cost, 1.5);
      expect(restored.dailyCosts[0].modelTokens['claude-opus-4-6']!.inputTokens, 500);
      expect(restored.dailyCosts[1].messageCount, 30);
    });

    test('fromJson handles null sessions', () {
      final json = {
        'totalSessions': 0,
        'totalFiles': 0,
        'fetchedAt': '2026-02-09T12:00:00.000Z',
        'dailyCosts': [],
      };
      final restored = CostData.fromJson(json);
      expect(restored.oldestSession, isNull);
      expect(restored.newestSession, isNull);
      expect(restored.dailyCosts, isEmpty);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'fetchedAt': '2026-02-09T12:00:00.000Z',
        'dailyCosts': [],
      };
      final restored = CostData.fromJson(json);
      expect(restored.totalSessions, 0);
      expect(restored.totalFiles, 0);
    });
  });
}
