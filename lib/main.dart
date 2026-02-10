import 'dart:io';
import 'package:flutter/material.dart';
import 'app.dart';
import 'services/oauth_service.dart';
import 'services/usage_service.dart';
import 'services/config_service.dart';
import 'services/tray_service.dart';
import 'services/cost_tracking_service.dart';
import 'services/pricing_update_service.dart';
import 'utils/platform_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On Windows, configure the window via Dart (macOS uses native AppDelegate).
  if (Platform.isWindows) {
    await configureWindowsWindow();
  }

  // Initialize services
  final oauthService = OAuthService();
  final usageService = UsageService(oauthService);
  final configService = ConfigService();
  final trayService = TrayService();
  final costTrackingService = CostTrackingService();
  final pricingUpdateService = PricingUpdateService();

  // Initialize pricing update (fire-and-forget, non-blocking)
  pricingUpdateService.init();

  // Setup quit callback (used by tray menu)
  trayService.onQuit = () {
    pricingUpdateService.dispose();
    trayService.dispose();
    exit(0);
  };

  runApp(ClaudeMeterApp(
    oauthService: oauthService,
    usageService: usageService,
    configService: configService,
    trayService: trayService,
    costTrackingService: costTrackingService,
  ));
}
