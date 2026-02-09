import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'models/usage_data.dart';
import 'models/config.dart';
import 'models/cost_data.dart';
import 'services/oauth_service.dart';
import 'services/usage_service.dart';
import 'services/config_service.dart';
import 'services/tray_service.dart';
import 'services/cost_tracking_service.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/cost_screen.dart';
import 'utils/platform_window.dart';

/// Main application widget.
class ClaudeMeterApp extends StatefulWidget {
  final OAuthService oauthService;
  final UsageService usageService;
  final ConfigService configService;
  final TrayService trayService;
  final CostTrackingService costTrackingService;

  const ClaudeMeterApp({
    super.key,
    required this.oauthService,
    required this.usageService,
    required this.configService,
    required this.trayService,
    required this.costTrackingService,
  });

  @override
  State<ClaudeMeterApp> createState() => _ClaudeMeterAppState();
}

enum _AppScreen { home, settings, cost }

class _ClaudeMeterAppState extends State<ClaudeMeterApp> with WindowListener {
  _AppScreen _currentScreen = _AppScreen.home;
  bool _isLoading = false;
  String? _loginError;
  String? _usageError;
  String? _userEmail;
  String? _subscriptionType;
  UsageData? _usageData;
  Timer? _refreshTimer;
  bool _windowVisible = false;

  // Cost tracking state
  CostData? _costData;
  bool _isCostLoading = false;
  String? _costError;

  OAuthService get _oauth => widget.oauthService;
  UsageService get _usage => widget.usageService;
  ConfigService get _config => widget.configService;
  CostTrackingService get _costService => widget.costTrackingService;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      widget.trayService.onToggle = _toggleWindowWindows;
    }
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
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  /// Toggle window visibility (Windows only).
  Future<void> _toggleWindowWindows() async {
    if (_windowVisible) {
      await windowManager.hide();
      _windowVisible = false;
    } else {
      await positionWindowNearTray();
      await windowManager.show();
      await windowManager.focus();
      _windowVisible = true;
    }
  }

  /// Hide window when it loses focus (Windows only).
  @override
  void onWindowBlur() {
    if (Platform.isWindows && _windowVisible) {
      windowManager.hide();
      _windowVisible = false;
    }
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
      if (kDebugMode) debugPrint('Usage refresh error: $e');
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
      if (kDebugMode) debugPrint('Login error: $e');
      setState(() {
        _loginError = '로그인 중 오류가 발생했습니다. 다시 시도해주세요.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshCosts() async {
    if (!mounted) return;
    setState(() => _isCostLoading = true);

    try {
      final data = await _costService.calculateCosts();
      if (!mounted) return;
      setState(() {
        _costData = data;
        _costError = null;
        _isCostLoading = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Cost refresh error: $e');
      if (!mounted) return;
      setState(() {
        _costError = 'JSONL 파일을 읽을 수 없습니다.';
        _isCostLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await _oauth.logout();
    setState(() {
      _usageData = null;
      _userEmail = null;
      _subscriptionType = null;
      _currentScreen = _AppScreen.home;
    });
  }

  void _handleQuit() {
    _refreshTimer?.cancel();
    widget.trayService.dispose();
    exit(0);
  }

  Future<void> _handleConfigSave(AppConfig newConfig) async {
    await _config.saveConfig(newConfig);
    _startAutoRefresh();
    setState(() => _currentScreen = _AppScreen.home);
  }

  @override
  Widget build(BuildContext context) {
    late final Widget body;
    switch (_currentScreen) {
      case _AppScreen.settings:
        body = SettingsScreen(
          config: _config.config,
          isLoggedIn: _oauth.hasCredentials,
          onSave: _handleConfigSave,
          onLogout: _handleLogout,
          onClose: () => setState(() => _currentScreen = _AppScreen.home),
        );
        break;
      case _AppScreen.cost:
        body = CostScreen(
          costData: _costData,
          isLoading: _isCostLoading,
          error: _costError,
          onRefresh: _refreshCosts,
          onClose: () => setState(() => _currentScreen = _AppScreen.home),
        );
        break;
      case _AppScreen.home:
        body = HomeScreen(
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
          onSettings: () => setState(() => _currentScreen = _AppScreen.settings),
          onCost: () {
            setState(() => _currentScreen = _AppScreen.cost);
            if (_costData == null) _refreshCosts();
          },
          onQuit: _handleQuit,
        );
        break;
    }

    return MaterialApp(
      title: 'Claude Meter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        // On Windows, add a translucent solid background (replacing macOS NSVisualEffectView).
        // On macOS, the native layer handles the frosted glass effect.
        body: Platform.isWindows
            ? Container(
                decoration: BoxDecoration(
                  color: const Color(0xF0F2F2F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: body,
              )
            : body,
      ),
    );
  }
}
