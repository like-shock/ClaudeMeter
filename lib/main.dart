import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'app.dart';
import 'services/oauth_service.dart';
import 'services/usage_service.dart';
import 'services/config_service.dart';
import 'services/tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  await windowManager.ensureInitialized();

  // Configure window
  const windowOptions = WindowOptions(
    size: Size(320, 420),
    minimumSize: Size(280, 350),
    maximumSize: Size(400, 500),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true, // Hide from dock
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
  });

  // Initialize services
  final oauthService = OAuthService();
  final usageService = UsageService(oauthService);
  final configService = ConfigService();
  final trayService = TrayService();

  // Initialize tray
  await trayService.init();

  // Setup tray callbacks
  trayService.onToggle = () async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  };

  trayService.onRefresh = () {
    // Will be handled by app state
  };

  trayService.onQuit = () {
    exit(0);
  };

  runApp(ClaudeMonitorApp(
    oauthService: oauthService,
    usageService: usageService,
    configService: configService,
  ));
}
