import 'dart:convert';
import 'dart:developer' as developer;
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
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          _config = AppConfig.fromJson(decoded);
        } else {
          developer.log(
            'Config data is not a valid JSON object, using defaults',
            name: 'ConfigService',
            level: 900, // WARNING
          );
          _config = AppConfig.defaultConfig;
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to load config',
        name: 'ConfigService',
        error: e,
        stackTrace: stackTrace,
        level: 900, // WARNING
      );
      _config = AppConfig.defaultConfig;
    }
  }

  /// Save configuration to storage.
  Future<void> saveConfig(AppConfig config) async {
    _config = config;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(config.toJson()));
    } catch (e, stackTrace) {
      developer.log(
        'Failed to save config',
        name: 'ConfigService',
        error: e,
        stackTrace: stackTrace,
        level: 900, // WARNING
      );
    }
  }
}
