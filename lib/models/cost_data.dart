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

  /// Serialize for cost cache file.
  Map<String, dynamic> toJson() => {
        'totalSessions': totalSessions,
        'totalFiles': totalFiles,
        'oldestSession': oldestSession?.toIso8601String(),
        'newestSession': newestSession?.toIso8601String(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'dailyCosts': dailyCosts.map((d) => d.toJson()).toList(),
      };

  /// Deserialize from cost cache file.
  factory CostData.fromJson(Map<String, dynamic> json) {
    final dailyCostsJson = json['dailyCosts'] as List<dynamic>? ?? [];
    return CostData(
      totalSessions: json['totalSessions'] as int? ?? 0,
      totalFiles: json['totalFiles'] as int? ?? 0,
      oldestSession: json['oldestSession'] != null
          ? DateTime.parse(json['oldestSession'] as String)
          : null,
      newestSession: json['newestSession'] != null
          ? DateTime.parse(json['newestSession'] as String)
          : null,
      fetchedAt: json['fetchedAt'] != null
          ? DateTime.parse(json['fetchedAt'] as String)
          : DateTime.now(),
      dailyCosts: dailyCostsJson
          .map((e) => DailyCost.fromJson(e as Map<String, dynamic>))
          .toList(),
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

  /// Serialize for cost cache file.
  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'cost': cost,
        'messageCount': messageCount,
        'totalTokens': totalTokens,
        'modelTokens':
            modelTokens.map((k, v) => MapEntry(k, v.toCacheJson())),
      };

  /// Deserialize from cost cache file.
  factory DailyCost.fromJson(Map<String, dynamic> json) {
    final modelTokensJson = json['modelTokens'] as Map<String, dynamic>? ?? {};
    return DailyCost(
      date: DateTime.parse(json['date'] as String),
      cost: (json['cost'] as num).toDouble(),
      messageCount: json['messageCount'] as int? ?? 0,
      totalTokens: json['totalTokens'] as int? ?? 0,
      modelTokens: modelTokensJson.map(
          (k, v) => MapEntry(k, TokenUsage.fromCacheJson(v as Map<String, dynamic>))),
    );
  }
}
