import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import '../models/config.dart';

/// Callbacks for tray menu actions.
typedef TrayCallback = void Function();

/// Service for managing the system tray icon.
class TrayService with TrayListener {
  TrayCallback? onToggle;
  TrayCallback? onRefresh;
  TrayCallback? onSettings;
  TrayCallback? onModeChange;
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
    trayManager.addListener(this);

    // Set default menu (will be replaced by updateMenuForMode)
    await _setMenu(null);
  }

  /// Update the tray context menu based on the active app mode.
  Future<void> updateMenuForMode(AppMode? mode) async {
    await _setMenu(mode);
  }

  Future<void> _setMenu(AppMode? mode) async {
    final List<MenuItem> items;

    switch (mode) {
      case AppMode.plan:
        items = [
          MenuItem(key: 'toggle', label: '사용량 보기'),
          MenuItem(key: 'refresh', label: '새로고침'),
          MenuItem.separator(),
          MenuItem(key: 'settings', label: '설정'),
          MenuItem(key: 'mode_change', label: '모드 변경'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '종료'),
        ];
      case AppMode.api:
        items = [
          MenuItem(key: 'toggle', label: '비용 보기'),
          MenuItem(key: 'refresh', label: '새로고침'),
          MenuItem.separator(),
          MenuItem(key: 'mode_change', label: '모드 변경'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '종료'),
        ];
      case null:
        items = [
          MenuItem(key: 'toggle', label: '열기'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '종료'),
        ];
    }

    await trayManager.setContextMenu(Menu(items: items));
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
      case 'mode_change':
        onModeChange?.call();
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
