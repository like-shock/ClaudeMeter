/// Application configuration.
class AppConfig {
  final int refreshIntervalSeconds;
  final bool showFiveHour;
  final bool showSevenDay;
  final bool showSonnet;

  const AppConfig({
    this.refreshIntervalSeconds = 30,
    this.showFiveHour = true,
    this.showSevenDay = true,
    this.showSonnet = true,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      refreshIntervalSeconds: json['refreshIntervalSeconds'] as int? ?? 30,
      showFiveHour: json['showFiveHour'] as bool? ?? true,
      showSevenDay: json['showSevenDay'] as bool? ?? true,
      showSonnet: json['showSonnet'] as bool? ?? true,
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
