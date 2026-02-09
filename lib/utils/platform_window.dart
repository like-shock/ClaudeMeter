import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

const _windowSize = Size(280, 400);

/// Configure the window for Windows platform.
/// macOS uses native NSPanel via AppDelegate.swift; this is the Dart equivalent.
Future<void> configureWindowsWindow() async {
  await windowManager.ensureInitialized();

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: _windowSize,
      minimumSize: _windowSize,
      maximumSize: _windowSize,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: true,
    ),
    () async {
      await windowManager.setAsFrameless();
      await windowManager.hide(); // Show on tray click
    },
  );
}

/// Position the window at the bottom-right of the screen (near system tray).
Future<void> positionWindowNearTray() async {
  final primary = await screenRetriever.getPrimaryDisplay();
  final workArea = primary.visibleSize ?? primary.size;
  final x = workArea.width - _windowSize.width - 12;
  final y = workArea.height - _windowSize.height - 48;
  await windowManager.setPosition(Offset(x, y));
}
