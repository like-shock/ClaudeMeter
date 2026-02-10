import 'package:flutter_test/flutter_test.dart';
import 'package:claude_meter/services/pricing_update_service.dart';
import 'package:claude_meter/utils/pricing.dart';

void main() {
  setUp(() {
    PricingTable.resetToHardcoded();
  });

  group('extractClaudeModels', () {
    test('extracts Claude models with correct rates', () {
      final data = {
        'claude-opus-4-6': {
          'input_cost_per_token': 0.000005, // $5/MTok
          'output_cost_per_token': 0.000025, // $25/MTok
        },
        'claude-sonnet-4-5': {
          'input_cost_per_token': 0.000003,
          'output_cost_per_token': 0.000015,
        },
      };

      final models = PricingUpdateService.extractClaudeModels(data);
      expect(models.length, 2);

      final opus = models.firstWhere((m) => m.modelId == 'claude-opus-4-6');
      expect(opus.inputRate, closeTo(5.0, 0.001));
      expect(opus.outputRate, closeTo(25.0, 0.001));
      expect(opus.cache5mWriteRate, closeTo(6.25, 0.001)); // 5 * 1.25
      expect(opus.cache1hWriteRate, closeTo(10.0, 0.001)); // 5 * 2.0
      expect(opus.cacheReadRate, closeTo(0.5, 0.001)); // 5 * 0.1
    });

    test('strips date suffix and deduplicates', () {
      final data = {
        'claude-opus-4-6': {
          'input_cost_per_token': 0.000005,
          'output_cost_per_token': 0.000025,
        },
        'claude-opus-4-6-20260101': {
          'input_cost_per_token': 0.000006, // different rate
          'output_cost_per_token': 0.000030,
        },
      };

      final models = PricingUpdateService.extractClaudeModels(data);
      // Should only have one entry; first match wins
      final opusModels =
          models.where((m) => m.modelId == 'claude-opus-4-6').toList();
      expect(opusModels.length, 1);
      expect(opusModels.first.inputRate, closeTo(5.0, 0.001));
    });

    test('skips non-Claude models', () {
      final data = {
        'gpt-4o': {
          'input_cost_per_token': 0.000005,
          'output_cost_per_token': 0.000015,
        },
        'anthropic.claude-opus-4-6-bedrock': {
          'input_cost_per_token': 0.000005,
          'output_cost_per_token': 0.000025,
        },
        'claude-sonnet-4': {
          'input_cost_per_token': 0.000003,
          'output_cost_per_token': 0.000015,
        },
      };

      final models = PricingUpdateService.extractClaudeModels(data);
      expect(models.length, 1);
      expect(models.first.modelId, 'claude-sonnet-4');
    });

    test('skips entries with missing cost fields', () {
      final data = {
        'claude-opus-4-6': {
          'input_cost_per_token': 0.000005,
          // missing output_cost_per_token
        },
        'claude-sonnet-4': {
          'input_cost_per_token': 0.000003,
          'output_cost_per_token': 0.000015,
        },
      };

      final models = PricingUpdateService.extractClaudeModels(data);
      expect(models.length, 1);
      expect(models.first.modelId, 'claude-sonnet-4');
    });

    test('skips entries with zero or negative costs', () {
      final data = {
        'claude-opus-4-6': {
          'input_cost_per_token': 0,
          'output_cost_per_token': 0.000025,
        },
        'claude-sonnet-4': {
          'input_cost_per_token': -0.001,
          'output_cost_per_token': 0.000015,
        },
      };

      final models = PricingUpdateService.extractClaudeModels(data);
      expect(models.isEmpty, true);
    });

    test('skips entries where value is not a Map', () {
      final data = {
        'claude-opus-4-6': 'not a map',
        'claude-sonnet-4': {
          'input_cost_per_token': 0.000003,
          'output_cost_per_token': 0.000015,
        },
      };

      final models = PricingUpdateService.extractClaudeModels(data);
      expect(models.length, 1);
    });

    test('returns empty list for empty data', () {
      final models = PricingUpdateService.extractClaudeModels({});
      expect(models.isEmpty, true);
    });
  });

  group('generateDisplayName', () {
    test('modern pattern: claude-opus-4-6', () {
      expect(
          PricingUpdateService.generateDisplayName('claude-opus-4-6'), 'Opus 4.6');
    });

    test('modern pattern: claude-sonnet-4-5', () {
      expect(PricingUpdateService.generateDisplayName('claude-sonnet-4-5'),
          'Sonnet 4.5');
    });

    test('modern pattern: claude-haiku-4-5', () {
      expect(PricingUpdateService.generateDisplayName('claude-haiku-4-5'),
          'Haiku 4.5');
    });

    test('modern pattern without minor: claude-opus-5', () {
      expect(
          PricingUpdateService.generateDisplayName('claude-opus-5'), 'Opus 5');
    });

    test('legacy pattern: claude-3-5-haiku', () {
      expect(PricingUpdateService.generateDisplayName('claude-3-5-haiku'),
          'Haiku 3.5');
    });

    test('legacy pattern: claude-3-5-sonnet', () {
      expect(PricingUpdateService.generateDisplayName('claude-3-5-sonnet'),
          'Sonnet 3.5');
    });

    test('fallback strips claude- prefix', () {
      expect(PricingUpdateService.generateDisplayName('claude-custom'),
          'custom');
    });
  });

  group('mergeWithHardcoded', () {
    test('fetched models override hardcoded ones', () {
      final fetched = [
        const ModelPricing(
          modelId: 'claude-opus-4-6',
          displayName: 'Opus 4.6',
          inputRate: 99, // different from hardcoded
          cache5mWriteRate: 99,
          cache1hWriteRate: 99,
          cacheReadRate: 99,
          outputRate: 99,
        ),
      ];

      final merged = PricingUpdateService.mergeWithHardcoded(fetched);
      final opus = merged.firstWhere((m) => m.modelId == 'claude-opus-4-6');
      expect(opus.inputRate, 99);
    });

    test('hardcoded models preserved when not in fetched', () {
      final fetched = [
        const ModelPricing(
          modelId: 'claude-new-model',
          displayName: 'New Model',
          inputRate: 10,
          cache5mWriteRate: 12.5,
          cache1hWriteRate: 20,
          cacheReadRate: 1,
          outputRate: 50,
        ),
      ];

      final merged = PricingUpdateService.mergeWithHardcoded(fetched);
      // All 8 hardcoded + 1 new = 9
      expect(merged.length, 9);
      expect(merged.any((m) => m.modelId == 'claude-opus-4-6'), true);
      expect(merged.any((m) => m.modelId == 'claude-new-model'), true);
    });

    test('empty fetched list returns hardcoded models', () {
      final merged = PricingUpdateService.mergeWithHardcoded([]);
      expect(merged.length, 8);
    });

    test('new models from fetch are added', () {
      final fetched = [
        const ModelPricing(
          modelId: 'claude-opus-5',
          displayName: 'Opus 5',
          inputRate: 7,
          cache5mWriteRate: 8.75,
          cache1hWriteRate: 14,
          cacheReadRate: 0.7,
          outputRate: 35,
        ),
      ];

      final merged = PricingUpdateService.mergeWithHardcoded(fetched);
      expect(merged.any((m) => m.modelId == 'claude-opus-5'), true);
      final opus5 = merged.firstWhere((m) => m.modelId == 'claude-opus-5');
      expect(opus5.inputRate, 7);
    });
  });

  group('stripDateSuffix', () {
    test('strips 8-digit date suffix', () {
      expect(PricingUpdateService.stripDateSuffix('claude-opus-4-6-20260101'),
          'claude-opus-4-6');
    });

    test('strips date from sonnet', () {
      expect(
          PricingUpdateService.stripDateSuffix('claude-sonnet-4-5-20250929'),
          'claude-sonnet-4-5');
    });

    test('returns unchanged when no date suffix', () {
      expect(PricingUpdateService.stripDateSuffix('claude-opus-4-6'),
          'claude-opus-4-6');
    });

    test('returns unchanged for short suffix', () {
      expect(PricingUpdateService.stripDateSuffix('claude-opus-4-6-123'),
          'claude-opus-4-6-123');
    });

    test('handles legacy model IDs', () {
      expect(
          PricingUpdateService.stripDateSuffix('claude-3-5-haiku-20241022'),
          'claude-3-5-haiku');
    });
  });

  group('shouldFetch', () {
    test('returns true when never fetched', () {
      final service = PricingUpdateService();
      expect(service.shouldFetch(), true);
    });
  });
}
