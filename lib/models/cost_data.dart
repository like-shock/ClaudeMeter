import '../utils/pricing.dart';

/// Cost breakdown for a single model.
class ModelCost {
  final String modelId;
  final String displayName;
  final TokenUsage tokens;
  final double cost;

  const ModelCost({
    required this.modelId,
    required this.displayName,
    required this.tokens,
    required this.cost,
  });
}

/// Aggregated cost data for display.
class CostData {
  final int totalSessions;
  final int totalFiles;
  final DateTime? oldestSession;
  final DateTime? newestSession;
  final List<DailyCost> dailyCosts;
  final DateTime fetchedAt;

  const CostData({
    required this.totalSessions,
    required this.totalFiles,
    this.oldestSession,
    this.newestSession,
    required this.dailyCosts,
    required this.fetchedAt,
  });

  static CostData empty() {
    return CostData(
      totalSessions: 0,
      totalFiles: 0,
      dailyCosts: const [],
      fetchedAt: DateTime.now(),
    );
  }
}

/// Cost for a single day.
class DailyCost {
  final DateTime date;
  final double cost;
  final int messageCount;
  final int totalTokens;

  /// Per-model token usage for this day.
  final Map<String, TokenUsage> modelTokens;

  const DailyCost({
    required this.date,
    required this.cost,
    required this.messageCount,
    this.totalTokens = 0,
    this.modelTokens = const {},
  });
}
