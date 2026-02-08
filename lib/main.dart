import 'dart:io';
import 'package:flutter/material.dart';
import 'app.dart';
import 'services/oauth_service.dart';
import 'services/usage_service.dart';
import 'services/config_service.dart';
import 'services/tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final oauthService = OAuthService();
  final usageService = UsageService(oauthService);
  final configService = ConfigService();
  final trayService = TrayService();

  // Setup quit callback (used by tray menu)
  trayService.onQuit = () {
    trayService.dispose();
    exit(0);
  };

  runApp(ClaudeMonitorApp(
    oauthService: oauthService,
    usageService: usageService,
    configService: configService,
    trayService: trayService,
  ));
}
