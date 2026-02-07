import 'dart:async';
import 'package:flutter/material.dart';
import 'models/usage_data.dart';
import 'models/config.dart';
import 'services/oauth_service.dart';
import 'services/usage_service.dart';
import 'services/config_service.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

/// Main application widget.
class ClaudeMonitorApp extends StatefulWidget {
  final OAuthService oauthService;
  final UsageService usageService;
  final ConfigService configService;

  const ClaudeMonitorApp({
    super.key,
    required this.oauthService,
    required this.usageService,
    required this.configService,
  });

  @override
  State<ClaudeMonitorApp> createState() => _ClaudeMonitorAppState();
}

class _ClaudeMonitorAppState extends State<ClaudeMonitorApp> {
  bool _showSettings = false;
  bool _isLoading = false;
  String? _loginError;
  UsageData? _usageData;
  Timer? _refreshTimer;

  OAuthService get _oauth => widget.oauthService;
  UsageService get _usage => widget.usageService;
  ConfigService get _config => widget.configService;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _oauth.loadCredentials();
    await _config.loadConfig();

    if (_oauth.hasCredentials) {
      await _refreshUsage();
    }

    _startAutoRefresh();
    setState(() {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    final interval = Duration(seconds: _config.config.refreshIntervalSeconds);
    _refreshTimer = Timer.periodic(interval, (_) {
      if (_oauth.hasCredentials && !_isLoading) {
        _refreshUsage();
      }
    });
  }

  Future<void> _refreshUsage() async {
    if (!_oauth.hasCredentials) return;

    setState(() => _isLoading = true);

    try {
      final data = await _usage.fetchUsage();
      setState(() {
        _usageData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _loginError = null;
    });

    try {
      final success = await _oauth.startLogin();
      if (success) {
        await _refreshUsage();
        _startAutoRefresh();
      } else {
        setState(() => _loginError = '로그인이 취소되었습니다');
      }
    } catch (e) {
      setState(() => _loginError = '로그인 중 오류 발생');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _handleLogout() async {
    await _oauth.logout();
    setState(() {
      _usageData = null;
      _showSettings = false;
    });
  }

  Future<void> _handleConfigSave(AppConfig newConfig) async {
    await _config.saveConfig(newConfig);
    _startAutoRefresh();
    setState(() => _showSettings = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Claude Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF1E1E2E).withOpacity(0.95),
        body: _showSettings
            ? SettingsScreen(
                config: _config.config,
                isLoggedIn: _oauth.hasCredentials,
                onSave: _handleConfigSave,
                onLogout: _handleLogout,
                onClose: () => setState(() => _showSettings = false),
              )
            : HomeScreen(
                isLoggedIn: _oauth.hasCredentials,
                isLoading: _isLoading,
                loginError: _loginError,
                usageData: _usageData,
                config: _config.config,
                onLogin: _handleLogin,
                onRefresh: _refreshUsage,
                onSettings: () => setState(() => _showSettings = true),
              ),
      ),
    );
  }
}
