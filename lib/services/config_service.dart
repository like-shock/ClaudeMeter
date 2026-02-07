import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/config.dart';

/// Service for managing application configuration.
class ConfigService {
  static const String _configKey = 'app_config';

  AppConfig _config = AppConfig.defaultConfig;

  /// Current configuration.
  AppConfig get config => _config;

  /// Load configuration from storage.
  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_configKey);

      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        _config = AppConfig.fromJson(json);
      }
    } catch (_) {
      _config = AppConfig.defaultConfig;
    }
  }

  /// Save configuration to storage.
  Future<void> saveConfig(AppConfig config) async {
    _config = config;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(config.toJson()));
    } catch (_) {
      // Ignore save errors
    }
  }
}
