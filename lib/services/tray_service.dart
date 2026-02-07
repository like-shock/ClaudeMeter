import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';

/// Callbacks for tray menu actions.
typedef TrayCallback = void Function();

/// Service for managing the system tray icon.
class TrayService with TrayListener {
  TrayCallback? onToggle;
  TrayCallback? onRefresh;
  TrayCallback? onSettings;
  TrayCallback? onQuit;

  String? _iconPath;

  /// Initialize the system tray.
  Future<void> init() async {
    // Extract icon from assets to temp directory
    _iconPath = await _extractTrayIcon();

    if (_iconPath != null) {
      await trayManager.setIcon(_iconPath!);
    }

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

  /// Extract tray icon from Flutter assets to a file path.
  Future<String?> _extractTrayIcon() async {
    try {
      final tempDir = await getTemporaryDirectory();

      if (Platform.isMacOS) {
        // macOS: use monochrome template image (Template suffix for auto dark/light)
        final byteData = await rootBundle.load('assets/tray_iconTemplate.png');
        final bytes = byteData.buffer.asUint8List();
        final iconFile = File('${tempDir.path}/tray_iconTemplate.png');
        await iconFile.writeAsBytes(bytes);
        return iconFile.path;
      } else {
        final byteData = await rootBundle.load('assets/icon.png');
        final bytes = byteData.buffer.asUint8List();
        final iconFile = File('${tempDir.path}/tray.png');
        await iconFile.writeAsBytes(bytes);
        return iconFile.path;
      }
    } catch (e) {
      debugPrint('Failed to extract tray icon: $e');
      return null;
    }
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
