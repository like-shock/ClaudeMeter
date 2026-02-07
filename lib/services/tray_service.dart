import 'dart:io';
import 'package:flutter/services.dart';
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
    await trayManager.setIcon(_getIconPath());
    await trayManager.setToolTip('Claude Monitor');

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

  String _getIconPath() {
    if (Platform.isMacOS) {
      // For macOS, use the icon in the app bundle Resources
      final executable = Platform.resolvedExecutable;
      final appBundle = executable.substring(0, executable.lastIndexOf('/MacOS/'));
      return '$appBundle/Resources/icon.png';
    }
    return 'assets/icon.ico';
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
