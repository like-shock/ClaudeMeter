import 'dart:io';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Default window size (Plan mode).
const planWindowSize = Size(280, 400);

/// Window size for API cost tracking mode.
const apiWindowSize = Size(400, 600);

/// Configure the window for Windows platform.
/// macOS uses native NSPanel via AppDelegate.swift; this is the Dart equivalent.
Future<void> configureWindowsWindow() async {
  await windowManager.ensureInitialized();

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: planWindowSize,
      minimumSize: planWindowSize,
      maximumSize: planWindowSize,
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
Future<void> positionWindowNearTray({Size? windowSize}) async {
  final size = windowSize ?? planWindowSize;
  final primary = await screenRetriever.getPrimaryDisplay();
  final workArea = primary.visibleSize ?? primary.size;
  final x = workArea.width - size.width - 12;
  final y = workArea.height - size.height - 48;
  await windowManager.setPosition(Offset(x, y));
}

const _windowChannel = MethodChannel('com.claudemeter/window');

/// Resize the application window (cross-platform).
Future<void> resizeWindow(Size size) async {
  if (Platform.isMacOS) {
    await _windowChannel.invokeMethod('setWindowSize', {
      'width': size.width,
      'height': size.height,
    });
  } else if (Platform.isWindows) {
    await windowManager.setSize(size);
    await windowManager.setMinimumSize(size);
    await windowManager.setMaximumSize(size);
    await positionWindowNearTray(windowSize: size);
  }
}
