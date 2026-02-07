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

  // Configure window - simpler options
  const windowOptions = WindowOptions(
    size: Size(320, 420),
    minimumSize: Size(280, 350),
    maximumSize: Size(400, 500),
    center: true,
    backgroundColor: Color(0xFF1E1E2E), // Catppuccin base color
    skipTaskbar: false, // Show in dock for now (debugging)
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Initialize services
  final oauthService = OAuthService();
  final usageService = UsageService(oauthService);
  final configService = ConfigService();
  final trayService = TrayService();

  // Initialize tray (with error handling)
  try {
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
  ));
}
