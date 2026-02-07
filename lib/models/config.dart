/// Application configuration.
class AppConfig {
  final int refreshIntervalSeconds;
  final bool showFiveHour;
  final bool showSevenDay;
  final bool showSonnet;

  const AppConfig({
    this.refreshIntervalSeconds = 60,
    this.showFiveHour = true,
    this.showSevenDay = true,
    this.showSonnet = true,
  });

  /// Parse from JSON with defensive type checking.
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final refreshRaw = json['refreshIntervalSeconds'];
    final fiveHourRaw = json['showFiveHour'];
    final sevenDayRaw = json['showSevenDay'];
    final sonnetRaw = json['showSonnet'];

    int refreshInterval = 60;
    if (refreshRaw is int) {
      // Clamp to reasonable bounds (10 seconds to 5 minutes)
      refreshInterval = refreshRaw.clamp(10, 300);
    }

    return AppConfig(
      refreshIntervalSeconds: refreshInterval,
      showFiveHour: fiveHourRaw is bool ? fiveHourRaw : true,
      showSevenDay: sevenDayRaw is bool ? sevenDayRaw : true,
      showSonnet: sonnetRaw is bool ? sonnetRaw : true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'refreshIntervalSeconds': refreshIntervalSeconds,
      'showFiveHour': showFiveHour,
      'showSevenDay': showSevenDay,
      'showSonnet': showSonnet,
    };
  }

  /// Default configuration.
  static const AppConfig defaultConfig = AppConfig();

  /// Create a copy with updated values.
  AppConfig copyWith({
    int? refreshIntervalSeconds,
    bool? showFiveHour,
    bool? showSevenDay,
    bool? showSonnet,
  }) {
    return AppConfig(
      refreshIntervalSeconds:
          refreshIntervalSeconds ?? this.refreshIntervalSeconds,
      showFiveHour: showFiveHour ?? this.showFiveHour,
      showSevenDay: showSevenDay ?? this.showSevenDay,
      showSonnet: showSonnet ?? this.showSonnet,
    );
  }
}
