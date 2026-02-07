import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'services/oauth_service.dart';
import 'services/usage_service.dart';
import 'services/config_service.dart';
import 'services/tray_service.dart';

/// Position window directly below tray icon
Future<void> _positionWindowBelowTray() async {
  try {
    final trayBounds = await trayManager.getBounds();
    if (trayBounds != null) {
      final windowSize = await windowManager.getSize();
      
      // Center window horizontally below tray icon
      final x = trayBounds.center.dx - (windowSize.width / 2);
      final y = trayBounds.bottom + 4; // 4px gap
      
      await windowManager.setPosition(Offset(x, y));
    }
  } catch (e) {
    debugPrint('Position error: $e');
  }
}

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
    // Don't show initially - wait for tray click
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
          // Position window below tray icon
          await _positionWindowBelowTray();
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
    
    // Show window below tray after tray is ready
    await Future.delayed(const Duration(milliseconds: 100));
    await _positionWindowBelowTray();
    await windowManager.show();
    await windowManager.focus();
  } catch (e) {
    debugPrint('Tray init failed: $e');
    // Fallback: show window anyway
    await windowManager.show();
  }

  runApp(ClaudeMonitorApp(
    oauthService: oauthService,
    usageService: usageService,
    configService: configService,
    trayService: trayService,
  ));
}
