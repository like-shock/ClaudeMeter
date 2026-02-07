import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'models/usage_data.dart';
import 'models/config.dart';
import 'services/oauth_service.dart';
import 'services/usage_service.dart';
import 'services/config_service.dart';
import 'services/tray_service.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

/// Main application widget.
class ClaudeMonitorApp extends StatefulWidget {
  final OAuthService oauthService;
  final UsageService usageService;
  final ConfigService configService;
  final TrayService trayService;

  const ClaudeMonitorApp({
    super.key,
    required this.oauthService,
    required this.usageService,
    required this.configService,
    required this.trayService,
  });

  @override
  State<ClaudeMonitorApp> createState() => _ClaudeMonitorAppState();
}

class _ClaudeMonitorAppState extends State<ClaudeMonitorApp> {
  bool _showSettings = false;
  bool _isLoading = false;
  String? _loginError;
  String? _usageError;
  String? _userEmail;
  String? _subscriptionType;
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
      await _fetchProfile();
      await _refreshUsage();
    }

    _startAutoRefresh();
    setState(() {});
  }

  Future<void> _fetchProfile() async {
    final profile = await _usage.fetchUserProfile();
    if (mounted && profile != null) {
      setState(() {
        _userEmail = profile.email;
        _subscriptionType = profile.subscriptionType;
      });
    }
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

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await _usage.fetchUsage();
      if (!mounted) return;
      setState(() {
        _usageData = data;
        _usageError = null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Usage refresh error: $e');
      if (!mounted) return;
      
      final errorMsg = e.toString();
      String? displayError;
      
      if (errorMsg.contains('auth_expired') || errorMsg.contains('401')) {
        displayError = '인증이 만료되었습니다. 다시 로그인해주세요.';
      } else if (errorMsg.contains('403')) {
        displayError = '접근 권한이 없습니다. 다시 로그인해주세요.';
      } else if (errorMsg.contains('API error')) {
        displayError = 'API 오류가 발생했습니다.';
      }
      
      setState(() {
        _usageError = displayError;
        _isLoading = false;
      });
    }
  }

  /// Start OAuth login with automatic callback.
  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _loginError = null;
    });

    try {
      final success = await _oauth.login();
      if (success) {
        await _fetchProfile();
        await _refreshUsage();
        _startAutoRefresh();
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _loginError = '인증에 실패했습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loginError = '로그인 중 오류 발생: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await _oauth.logout();
    setState(() {
      _usageData = null;
      _userEmail = null;
      _subscriptionType = null;
      _showSettings = false;
    });
  }

  void _handleQuit() {
    exit(0);
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
        backgroundColor: const Color(0xFF1E1E2E),
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
                usageError: _usageError,
                userEmail: _userEmail,
                subscriptionType: _subscriptionType,
                usageData: _usageData,
                config: _config.config,
                onLogin: _handleLogin,
                onRefresh: _refreshUsage,
                onSettings: () => setState(() => _showSettings = true),
                onQuit: _handleQuit,
              ),
      ),
    );
  }
}
