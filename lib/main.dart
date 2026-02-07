import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'services/oauth_service.dart';
import 'services/usage_service.dart';
import 'services/config_service.dart';
import 'services/tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  await windowManager.ensureInitialized();

  // Configure window - popover style
  const windowOptions = WindowOptions(
    size: Size(320, 380),
    minimumSize: Size(280, 300),
    maximumSize: Size(400, 500),
    backgroundColor: Colors.transparent,
    skipTaskbar: true, // Tray app: hide from dock/taskbar
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Prevent macOS from terminating app when window is closed/hidden
    await windowManager.setPreventClose(true);
    
    // Position window at top-right (near menu bar)
    final screen = await windowManager.getSize();
    final screenSize = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    final devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final logicalWidth = screenSize.width / devicePixelRatio;
    
    await windowManager.setPosition(Offset(
      logicalWidth - screen.width - 10,
      30, // Below menu bar
    ));
    
    await windowManager.show();
    await windowManager.focus();
  });

  // Initialize services
  final oauthService = OAuthService();
  final usageService = UsageService(oauthService);
  final configService = ConfigService();
  final trayService = TrayService();

  // Initialize tray
  try {
    await trayService.init();

    // Setup tray callbacks with safe window toggle
    trayService.onToggle = () async {
      try {
        final isVisible = await windowManager.isVisible();
        if (isVisible) {
          await windowManager.hide();
        } else {
          await windowManager.show();
          await windowManager.focus();
        }
      } catch (e) {
        debugPrint('Window toggle error: $e');
      }
    };

    trayService.onRefresh = () {
      debugPrint('Refresh clicked');
    };

    trayService.onSettings = () {
      debugPrint('Settings clicked');
    };

    trayService.onQuit = () {
      exit(0);
    };
  } catch (e) {
    debugPrint('Tray init failed: $e');
  }

  runApp(ClaudeMonitorApp(
    oauthService: oauthService,
    usageService: usageService,
    configService: configService,
    trayService: trayService,
  ));
}
