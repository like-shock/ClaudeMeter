/// Model pricing rates (USD per million tokens) as of 2026-02.
class ModelPricing {
  final String modelId;
  final String displayName;
  final double inputRate;
  final double cache5mWriteRate;
  final double cache1hWriteRate;
  final double cacheReadRate;
  final double outputRate;

  const ModelPricing({
    required this.modelId,
    required this.displayName,
    required this.inputRate,
    required this.cache5mWriteRate,
    required this.cache1hWriteRate,
    required this.cacheReadRate,
    required this.outputRate,
  });

  /// Deserialize from JSON (cached pricing).
  factory ModelPricing.fromJson(Map<String, dynamic> json) {
    return ModelPricing(
      modelId: json['modelId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      inputRate: (json['inputRate'] as num?)?.toDouble() ?? 0,
      cache5mWriteRate: (json['cache5mWriteRate'] as num?)?.toDouble() ?? 0,
      cache1hWriteRate: (json['cache1hWriteRate'] as num?)?.toDouble() ?? 0,
      cacheReadRate: (json['cacheReadRate'] as num?)?.toDouble() ?? 0,
      outputRate: (json['outputRate'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Serialize to JSON for caching.
  Map<String, dynamic> toJson() => {
        'modelId': modelId,
        'displayName': displayName,
        'inputRate': inputRate,
        'cache5mWriteRate': cache5mWriteRate,
        'cache1hWriteRate': cache1hWriteRate,
        'cacheReadRate': cacheReadRate,
        'outputRate': outputRate,
      };
}

/// Token counts extracted from a single JSONL usage entry.
class TokenUsage {
  final int inputTokens;
  final int cacheCreationInputTokens;
  final int cacheReadInputTokens;
  final int ephemeral5mInputTokens;
  final int ephemeral1hInputTokens;
  final int outputTokens;

  const TokenUsage({
    this.inputTokens = 0,
    this.cacheCreationInputTokens = 0,
    this.cacheReadInputTokens = 0,
    this.ephemeral5mInputTokens = 0,
    this.ephemeral1hInputTokens = 0,
    this.outputTokens = 0,
  });

  /// Parse from JSONL message.usage field.
  factory TokenUsage.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TokenUsage();

    int ephemeral5m = 0;
    int ephemeral1h = 0;
    final cacheCreation = json['cache_creation'];
    if (cacheCreation is Map<String, dynamic>) {
      final raw5m = cacheCreation['ephemeral_5m_input_tokens'];
      if (raw5m is num) ephemeral5m = raw5m.toInt();
      final raw1h = cacheCreation['ephemeral_1h_input_tokens'];
      if (raw1h is num) ephemeral1h = raw1h.toInt();
    }

    return TokenUsage(
      inputTokens: _parseInt(json['input_tokens']),
      cacheCreationInputTokens: _parseInt(json['cache_creation_input_tokens']),
      cacheReadInputTokens: _parseInt(json['cache_read_input_tokens']),
      ephemeral5mInputTokens: ephemeral5m,
      ephemeral1hInputTokens: ephemeral1h,
      outputTokens: _parseInt(json['output_tokens']),
    );
  }

  static int _parseInt(dynamic v) => v is num ? v.toInt() : 0;

  TokenUsage operator +(TokenUsage other) {
    return TokenUsage(
      inputTokens: inputTokens + other.inputTokens,
      cacheCreationInputTokens:
          cacheCreationInputTokens + other.cacheCreationInputTokens,
      cacheReadInputTokens:
          cacheReadInputTokens + other.cacheReadInputTokens,
      ephemeral5mInputTokens:
          ephemeral5mInputTokens + other.ephemeral5mInputTokens,
      ephemeral1hInputTokens:
          ephemeral1hInputTokens + other.ephemeral1hInputTokens,
      outputTokens: outputTokens + other.outputTokens,
    );
  }

  int get totalTokens =>
      inputTokens + cacheCreationInputTokens + cacheReadInputTokens + outputTokens;

  /// Serialize for cost cache file.
  Map<String, dynamic> toCacheJson() => {
        'i': inputTokens,
        'cc': cacheCreationInputTokens,
        'cr': cacheReadInputTokens,
        'e5': ephemeral5mInputTokens,
        'e1': ephemeral1hInputTokens,
        'o': outputTokens,
      };

  /// Deserialize from cost cache file.
  factory TokenUsage.fromCacheJson(Map<String, dynamic> json) => TokenUsage(
        inputTokens: json['i'] as int? ?? 0,
        cacheCreationInputTokens: json['cc'] as int? ?? 0,
        cacheReadInputTokens: json['cr'] as int? ?? 0,
        ephemeral5mInputTokens: json['e5'] as int? ?? 0,
        ephemeral1hInputTokens: json['e1'] as int? ?? 0,
        outputTokens: json['o'] as int? ?? 0,
      );
}

/// Pricing table and cost calculation utilities.
class PricingTable {
  PricingTable._();

  static const List<ModelPricing> _hardcodedModels = [
    // Opus 4.6 / 4.5
    ModelPricing(
      modelId: 'claude-opus-4-6',
      displayName: 'Opus 4.6',
      inputRate: 5,
      cache5mWriteRate: 6.25,
      cache1hWriteRate: 10,
      cacheReadRate: 0.50,
      outputRate: 25,
    ),
    ModelPricing(
      modelId: 'claude-opus-4-5',
      displayName: 'Opus 4.5',
      inputRate: 5,
      cache5mWriteRate: 6.25,
      cache1hWriteRate: 10,
      cacheReadRate: 0.50,
      outputRate: 25,
    ),
    // Opus 4.1 / 4
    ModelPricing(
      modelId: 'claude-opus-4-1',
      displayName: 'Opus 4.1',
      inputRate: 15,
      cache5mWriteRate: 18.75,
      cache1hWriteRate: 30,
      cacheReadRate: 1.50,
      outputRate: 75,
    ),
    ModelPricing(
      modelId: 'claude-opus-4',
      displayName: 'Opus 4',
      inputRate: 15,
      cache5mWriteRate: 18.75,
      cache1hWriteRate: 30,
      cacheReadRate: 1.50,
      outputRate: 75,
    ),
    // Sonnet 4.5 / 4
    ModelPricing(
      modelId: 'claude-sonnet-4-5',
      displayName: 'Sonnet 4.5',
      inputRate: 3,
      cache5mWriteRate: 3.75,
      cache1hWriteRate: 6,
      cacheReadRate: 0.30,
      outputRate: 15,
    ),
    ModelPricing(
      modelId: 'claude-sonnet-4',
      displayName: 'Sonnet 4',
      inputRate: 3,
      cache5mWriteRate: 3.75,
      cache1hWriteRate: 6,
      cacheReadRate: 0.30,
      outputRate: 15,
    ),
    // Haiku 4.5
    ModelPricing(
      modelId: 'claude-haiku-4-5',
      displayName: 'Haiku 4.5',
      inputRate: 1,
      cache5mWriteRate: 1.25,
      cache1hWriteRate: 2,
      cacheReadRate: 0.10,
      outputRate: 5,
    ),
    // Haiku 3.5
    ModelPricing(
      modelId: 'claude-3-5-haiku',
      displayName: 'Haiku 3.5',
      inputRate: 0.80,
      cache5mWriteRate: 1,
      cache1hWriteRate: 1.6,
      cacheReadRate: 0.08,
      outputRate: 4,
    ),
  ];

  static List<ModelPricing> _models = List.of(_hardcodedModels);

  /// Hardcoded fallback models (read-only access).
  static List<ModelPricing> get hardcodedModels =>
      List.unmodifiable(_hardcodedModels);

  /// Atomically replace the active model list.
  static void updateModels(List<ModelPricing> models) {
    _models = List.of(models);
  }

  /// Reset to hardcoded defaults (for tests and error recovery).
  static void resetToHardcoded() {
    _models = List.of(_hardcodedModels);
  }

  /// Look up pricing by model string from JSONL.
  /// Model strings in JSONL include date suffixes (e.g. "claude-sonnet-4-5-20250929"),
  /// so we strip the date part for matching.
  static ModelPricing? findPricing(String modelString) {
    // Try exact match first
    for (final m in _models) {
      if (modelString == m.modelId) return m;
    }
    // Try prefix match (strip date suffix like "-20250929")
    for (final m in _models) {
      if (modelString.startsWith(m.modelId)) return m;
    }
    return null;
  }

  /// Normalize model ID from JSONL to display name.
  static String normalizeModelId(String modelString) {
    final pricing = findPricing(modelString);
    return pricing?.displayName ?? modelString;
  }

  /// Calculate cost in USD for given token usage and model.
  static double calculateCost(String modelString, TokenUsage usage) {
    final pricing = findPricing(modelString);
    if (pricing == null) return 0.0;

    // Determine cache write tokens by type.
    // If ephemeral breakdown is available, use it. Otherwise, treat all
    // cache_creation_input_tokens as 5m (conservative default).
    final has5m = usage.ephemeral5mInputTokens > 0;
    final has1h = usage.ephemeral1hInputTokens > 0;

    double cache5mTokens;
    double cache1hTokens;

    if (has5m || has1h) {
      cache5mTokens = usage.ephemeral5mInputTokens.toDouble();
      cache1hTokens = usage.ephemeral1hInputTokens.toDouble();
    } else {
      // Fallback: all cache creation tokens as 5m
      cache5mTokens = usage.cacheCreationInputTokens.toDouble();
      cache1hTokens = 0;
    }

    return (usage.inputTokens * pricing.inputRate +
            cache5mTokens * pricing.cache5mWriteRate +
            cache1hTokens * pricing.cache1hWriteRate +
            usage.cacheReadInputTokens * pricing.cacheReadRate +
            usage.outputTokens * pricing.outputRate) /
        1000000;
  }
}
