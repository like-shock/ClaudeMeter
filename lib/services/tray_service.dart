import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

/// Callbacks for tray menu actions.
typedef TrayCallback = void Function();

/// Service for managing the system tray icon.
class TrayService with TrayListener {
  TrayCallback? onToggle;
  TrayCallback? onRefresh;
  TrayCallback? onSettings;
  TrayCallback? onQuit;

  /// Initialize the system tray.
  Future<void> init() async {
    try {
      if (Platform.isWindows) {
        await trayManager.setIcon('assets/tray_icon_win.png');
      } else {
        // tray_manager on macOS uses rootBundle.load(iconPath) internally,
        // so pass the Flutter asset path directly (not a file system path).
        await trayManager.setIcon(
          'assets/tray_iconTemplate.png',
          isTemplate: true,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Tray setIcon failed: $e');
    }

    await trayManager.setToolTip('Claude Meter');

    final menu = Menu(
      items: [
        MenuItem(
          key: 'toggle',
          label: '사용량 보기',
        ),
        MenuItem(
          key: 'refresh',
          label: '새로고침',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'settings',
          label: '설정',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: '종료',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
    trayManager.addListener(this);
  }

  /// Dispose the tray service.
  void dispose() {
    trayManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    onToggle?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'toggle':
        onToggle?.call();
        break;
      case 'refresh':
        onRefresh?.call();
        break;
      case 'settings':
        onSettings?.call();
        break;
      case 'quit':
        onQuit?.call();
        break;
    }
  }

  /// Update the tooltip text.
  Future<void> setTooltip(String text) async {
    await trayManager.setToolTip(text);
  }
}
