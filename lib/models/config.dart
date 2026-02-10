/// Application mode: plan (OAuth usage monitoring) or api (JSONL cost tracking).
enum AppMode { plan, api }

/// Application configuration.
class AppConfig {
  final int refreshIntervalSeconds;
  final bool showFiveHour;
  final bool showSevenDay;
  final bool showSonnet;
  final AppMode? appMode;

  const AppConfig({
    this.refreshIntervalSeconds = 600,
    this.showFiveHour = true,
    this.showSevenDay = true,
    this.showSonnet = true,
    this.appMode,
  });

  /// Parse from JSON with defensive type checking.
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final refreshRaw = json['refreshIntervalSeconds'];
    final fiveHourRaw = json['showFiveHour'];
    final sevenDayRaw = json['showSevenDay'];
    final sonnetRaw = json['showSonnet'];
    final modeRaw = json['appMode'];

    int refreshInterval = 600;
    if (refreshRaw is int) {
      // Clamp to reasonable bounds (10 seconds to 10 minutes)
      refreshInterval = refreshRaw.clamp(10, 600);
    }

    AppMode? appMode;
    if (modeRaw is String) {
      appMode = AppMode.values.where((e) => e.name == modeRaw).firstOrNull;
    }

    return AppConfig(
      refreshIntervalSeconds: refreshInterval,
      showFiveHour: fiveHourRaw is bool ? fiveHourRaw : true,
      showSevenDay: sevenDayRaw is bool ? sevenDayRaw : true,
      showSonnet: sonnetRaw is bool ? sonnetRaw : true,
      appMode: appMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'refreshIntervalSeconds': refreshIntervalSeconds,
      'showFiveHour': showFiveHour,
      'showSevenDay': showSevenDay,
      'showSonnet': showSonnet,
      'appMode': appMode?.name,
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
    AppMode? appMode,
    bool clearAppMode = false,
  }) {
    return AppConfig(
      refreshIntervalSeconds:
          refreshIntervalSeconds ?? this.refreshIntervalSeconds,
      showFiveHour: showFiveHour ?? this.showFiveHour,
      showSevenDay: showSevenDay ?? this.showSevenDay,
      showSonnet: showSonnet ?? this.showSonnet,
      appMode: clearAppMode ? null : (appMode ?? this.appMode),
    );
  }
}
