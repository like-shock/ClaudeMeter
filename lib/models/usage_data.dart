/// Usage tier data from Claude API.
class UsageTier {
  final double utilization;
  final DateTime? resetsAt;

  const UsageTier({
    this.utilization = 0.0,
    this.resetsAt,
  });

  factory UsageTier.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UsageTier();
    }

    DateTime? resetsAt;
    final resetsAtStr = json['resets_at'] as String?;
    if (resetsAtStr != null) {
      resetsAt = DateTime.tryParse(resetsAtStr);
    }

    return UsageTier(
      utilization: (json['utilization'] as num?)?.toDouble() ?? 0.0,
      resetsAt: resetsAt,
    );
  }

  /// Returns utilization as percentage (0-100).
  int get percentage => (utilization * 100).round();
}

/// Complete usage data from Claude API.
class UsageData {
  final UsageTier fiveHour;
  final UsageTier sevenDay;
  final UsageTier sevenDaySonnet;
  final DateTime fetchedAt;

  const UsageData({
    required this.fiveHour,
    required this.sevenDay,
    required this.sevenDaySonnet,
    required this.fetchedAt,
  });

  factory UsageData.fromJson(Map<String, dynamic> json) {
    return UsageData(
      fiveHour: UsageTier.fromJson(json['five_hour'] as Map<String, dynamic>?),
      sevenDay: UsageTier.fromJson(json['seven_day'] as Map<String, dynamic>?),
      sevenDaySonnet:
          UsageTier.fromJson(json['seven_day_sonnet'] as Map<String, dynamic>?),
      fetchedAt: DateTime.now(),
    );
  }

  /// Empty usage data (for initial state).
  static UsageData empty() {
    return UsageData(
      fiveHour: const UsageTier(),
      sevenDay: const UsageTier(),
      sevenDaySonnet: const UsageTier(),
      fetchedAt: DateTime.now(),
    );
  }
}
