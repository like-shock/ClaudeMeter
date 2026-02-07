/// Usage tier data from Claude API.
class UsageTier {
  final double utilization;
  final DateTime? resetsAt;

  const UsageTier({
    this.utilization = 0.0,
    this.resetsAt,
  });

  /// Parse from JSON with defensive type checking.
  factory UsageTier.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UsageTier();
    }

    DateTime? resetsAt;
    final resetsAtRaw = json['resets_at'];
    if (resetsAtRaw is String) {
      resetsAt = DateTime.tryParse(resetsAtRaw);
    }

    double utilization = 0.0;
    final utilizationRaw = json['utilization'];
    if (utilizationRaw is num) {
      // API returns percentage directly (0-100)
      utilization = utilizationRaw.toDouble().clamp(0.0, 100.0);
    }

    return UsageTier(
      utilization: utilization,
      resetsAt: resetsAt,
    );
  }

  /// Returns utilization as percentage (0-100).
  int get percentage => utilization.round();
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

  /// Parse from JSON with defensive type checking.
  factory UsageData.fromJson(Map<String, dynamic> json) {
    final fiveHourRaw = json['five_hour'];
    final sevenDayRaw = json['seven_day'];
    final sevenDaySonnetRaw = json['seven_day_sonnet'];

    return UsageData(
      fiveHour: UsageTier.fromJson(
          fiveHourRaw is Map<String, dynamic> ? fiveHourRaw : null),
      sevenDay: UsageTier.fromJson(
          sevenDayRaw is Map<String, dynamic> ? sevenDayRaw : null),
      sevenDaySonnet: UsageTier.fromJson(
          sevenDaySonnetRaw is Map<String, dynamic> ? sevenDaySonnetRaw : null),
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
