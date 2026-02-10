import 'package:flutter_test/flutter_test.dart';
import 'package:claude_meter/utils/pricing.dart';

void main() {
  group('TokenUsage', () {
    test('fromJson parses complete usage data', () {
      final json = {
        'input_tokens': 986,
        'cache_creation_input_tokens': 33752,
        'cache_read_input_tokens': 18209,
        'cache_creation': {
          'ephemeral_5m_input_tokens': 10000,
          'ephemeral_1h_input_tokens': 23752,
        },
        'output_tokens': 528,
        'service_tier': 'standard',
      };

      final usage = TokenUsage.fromJson(json);
      expect(usage.inputTokens, 986);
      expect(usage.cacheCreationInputTokens, 33752);
      expect(usage.cacheReadInputTokens, 18209);
      expect(usage.ephemeral5mInputTokens, 10000);
      expect(usage.ephemeral1hInputTokens, 23752);
      expect(usage.outputTokens, 528);
    });

    test('fromJson handles null', () {
      final usage = TokenUsage.fromJson(null);
      expect(usage.inputTokens, 0);
      expect(usage.outputTokens, 0);
    });

    test('fromJson handles missing cache_creation', () {
      final json = {
        'input_tokens': 100,
        'output_tokens': 50,
      };

      final usage = TokenUsage.fromJson(json);
      expect(usage.inputTokens, 100);
      expect(usage.outputTokens, 50);
      expect(usage.ephemeral5mInputTokens, 0);
      expect(usage.ephemeral1hInputTokens, 0);
    });

    test('fromJson handles wrong types gracefully', () {
      final json = {
        'input_tokens': 'not a number',
        'output_tokens': null,
        'cache_creation': 'invalid',
      };

      final usage = TokenUsage.fromJson(json);
      expect(usage.inputTokens, 0);
      expect(usage.outputTokens, 0);
    });

    test('operator + adds token counts', () {
      const a = TokenUsage(
        inputTokens: 100,
        outputTokens: 50,
        cacheReadInputTokens: 10,
      );
      const b = TokenUsage(
        inputTokens: 200,
        outputTokens: 100,
        cacheReadInputTokens: 20,
      );
      final sum = a + b;
      expect(sum.inputTokens, 300);
      expect(sum.outputTokens, 150);
      expect(sum.cacheReadInputTokens, 30);
    });

    test('totalTokens sums input, cache, and output', () {
      const usage = TokenUsage(
        inputTokens: 100,
        cacheCreationInputTokens: 200,
        cacheReadInputTokens: 50,
        outputTokens: 80,
      );
      expect(usage.totalTokens, 430);
    });
  });

  group('PricingTable', () {
    setUp(() {
      PricingTable.resetToHardcoded();
    });

    test('findPricing returns exact match', () {
      final pricing = PricingTable.findPricing('claude-opus-4-6');
      expect(pricing, isNotNull);
      expect(pricing!.displayName, 'Opus 4.6');
      expect(pricing.inputRate, 5);
      expect(pricing.outputRate, 25);
    });

    test('findPricing matches with date suffix', () {
      final pricing = PricingTable.findPricing('claude-sonnet-4-5-20250929');
      expect(pricing, isNotNull);
      expect(pricing!.displayName, 'Sonnet 4.5');
      expect(pricing.inputRate, 3);
    });

    test('findPricing returns null for unknown model', () {
      final pricing = PricingTable.findPricing('unknown-model-1234');
      expect(pricing, isNull);
    });

    test('findPricing matches haiku 4.5', () {
      final pricing = PricingTable.findPricing('claude-haiku-4-5-20251001');
      expect(pricing, isNotNull);
      expect(pricing!.displayName, 'Haiku 4.5');
      expect(pricing.inputRate, 1);
      expect(pricing.outputRate, 5);
    });

    test('findPricing matches haiku 3.5', () {
      final pricing = PricingTable.findPricing('claude-3-5-haiku-20241022');
      expect(pricing, isNotNull);
      expect(pricing!.displayName, 'Haiku 3.5');
    });

    test('normalizeModelId returns display name', () {
      expect(PricingTable.normalizeModelId('claude-opus-4-6'), 'Opus 4.6');
      expect(PricingTable.normalizeModelId('claude-sonnet-4-5-20250929'),
          'Sonnet 4.5');
    });

    test('normalizeModelId returns raw string for unknown model', () {
      expect(
          PricingTable.normalizeModelId('some-future-model'), 'some-future-model');
    });

    test('calculateCost computes correctly with ephemeral breakdown', () {
      const usage = TokenUsage(
        inputTokens: 1000000, // 1M input
        ephemeral5mInputTokens: 500000, // 0.5M 5m cache write
        ephemeral1hInputTokens: 500000, // 0.5M 1h cache write
        cacheCreationInputTokens: 1000000,
        cacheReadInputTokens: 2000000, // 2M cache read
        outputTokens: 100000, // 0.1M output
      );

      // Sonnet 4.5: input=$3, 5m=$3.75, 1h=$6, read=$0.30, output=$15
      final cost = PricingTable.calculateCost('claude-sonnet-4-5-20250929', usage);
      // = (1M*3 + 0.5M*3.75 + 0.5M*6 + 2M*0.30 + 0.1M*15) / 1M
      // = (3 + 1.875 + 3 + 0.6 + 1.5)
      // = 9.975
      expect(cost, closeTo(9.975, 0.001));
    });

    test('calculateCost uses 5m fallback when no ephemeral breakdown', () {
      const usage = TokenUsage(
        inputTokens: 1000000,
        cacheCreationInputTokens: 1000000,
        cacheReadInputTokens: 0,
        outputTokens: 100000,
      );

      // Opus 4.6: input=$5, 5m_write=$6.25, output=$25
      final cost = PricingTable.calculateCost('claude-opus-4-6', usage);
      // = (1M*5 + 1M*6.25 + 0 + 0.1M*25) / 1M
      // = (5 + 6.25 + 2.5)
      // = 13.75
      expect(cost, closeTo(13.75, 0.001));
    });

    test('calculateCost returns 0 for unknown model', () {
      const usage = TokenUsage(inputTokens: 1000, outputTokens: 500);
      final cost = PricingTable.calculateCost('unknown-model', usage);
      expect(cost, 0.0);
    });

    test('calculateCost handles zero tokens', () {
      const usage = TokenUsage();
      final cost = PricingTable.calculateCost('claude-opus-4-6', usage);
      expect(cost, 0.0);
    });

    test('updateModels replaces active model list', () {
      final custom = [
        const ModelPricing(
          modelId: 'claude-test-1',
          displayName: 'Test 1',
          inputRate: 99,
          cache5mWriteRate: 99,
          cache1hWriteRate: 99,
          cacheReadRate: 99,
          outputRate: 99,
        ),
      ];
      PricingTable.updateModels(custom);

      expect(PricingTable.findPricing('claude-test-1'), isNotNull);
      expect(PricingTable.findPricing('claude-test-1')!.inputRate, 99);
      // Original models should no longer be found
      expect(PricingTable.findPricing('claude-opus-4-6'), isNull);
    });

    test('resetToHardcoded restores original models', () {
      PricingTable.updateModels([]);
      expect(PricingTable.findPricing('claude-opus-4-6'), isNull);

      PricingTable.resetToHardcoded();
      expect(PricingTable.findPricing('claude-opus-4-6'), isNotNull);
      expect(PricingTable.findPricing('claude-opus-4-6')!.inputRate, 5);
    });

    test('hardcodedModels returns unmodifiable copy', () {
      final models = PricingTable.hardcodedModels;
      expect(models.length, 8);
      expect(models.first.modelId, 'claude-opus-4-6');
      expect(() => models.add(models.first), throwsUnsupportedError);
    });
  });

  group('ModelPricing serialization', () {
    test('toJson produces correct map', () {
      const model = ModelPricing(
        modelId: 'claude-opus-4-6',
        displayName: 'Opus 4.6',
        inputRate: 5,
        cache5mWriteRate: 6.25,
        cache1hWriteRate: 10,
        cacheReadRate: 0.50,
        outputRate: 25,
      );
      final json = model.toJson();
      expect(json['modelId'], 'claude-opus-4-6');
      expect(json['displayName'], 'Opus 4.6');
      expect(json['inputRate'], 5);
      expect(json['cache5mWriteRate'], 6.25);
      expect(json['cache1hWriteRate'], 10);
      expect(json['cacheReadRate'], 0.50);
      expect(json['outputRate'], 25);
    });

    test('fromJson roundtrips correctly', () {
      const original = ModelPricing(
        modelId: 'claude-sonnet-4-5',
        displayName: 'Sonnet 4.5',
        inputRate: 3,
        cache5mWriteRate: 3.75,
        cache1hWriteRate: 6,
        cacheReadRate: 0.30,
        outputRate: 15,
      );
      final restored = ModelPricing.fromJson(original.toJson());
      expect(restored.modelId, original.modelId);
      expect(restored.displayName, original.displayName);
      expect(restored.inputRate, original.inputRate);
      expect(restored.cache5mWriteRate, original.cache5mWriteRate);
      expect(restored.cache1hWriteRate, original.cache1hWriteRate);
      expect(restored.cacheReadRate, original.cacheReadRate);
      expect(restored.outputRate, original.outputRate);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = ModelPricing.fromJson({'modelId': 'test'});
      expect(model.modelId, 'test');
      expect(model.displayName, '');
      expect(model.inputRate, 0);
      expect(model.outputRate, 0);
    });

    test('fromJson handles empty map', () {
      final model = ModelPricing.fromJson({});
      expect(model.modelId, '');
      expect(model.inputRate, 0);
    });
  });
}
