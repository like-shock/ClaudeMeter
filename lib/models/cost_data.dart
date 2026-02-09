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
  final double todayCost;
  final double totalCost;
  final int totalSessions;
  final int totalFiles;
  final DateTime? oldestSession;
  final DateTime? newestSession;
  final List<ModelCost> modelBreakdown;
  final List<DailyCost> dailyCosts;
  final DateTime fetchedAt;

  const CostData({
    required this.todayCost,
    required this.totalCost,
    required this.totalSessions,
    required this.totalFiles,
    this.oldestSession,
    this.newestSession,
    required this.modelBreakdown,
    required this.dailyCosts,
    required this.fetchedAt,
  });

  static CostData empty() {
    return CostData(
      todayCost: 0,
      totalCost: 0,
      totalSessions: 0,
      totalFiles: 0,
      modelBreakdown: const [],
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

  const DailyCost({
    required this.date,
    required this.cost,
    required this.messageCount,
  });
}
