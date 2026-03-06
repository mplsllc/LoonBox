import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'features/browser/browser_service.dart';
import 'services/audio_service.dart';
import 'services/rust_audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        titleBarStyle: TitleBarStyle.hidden,
        size: Size(1200, 800),
        minimumSize: Size(800, 600),
        title: 'LoonBox',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
    // Intercept close → hide to tray instead
    await windowManager.setPreventClose(true);
  }

  // Initialize Windows media transport controls
  if (Platform.isWindows) {
    await SMTCWindows.initialize();
  }

  // Initialize the Rust audio engine
  final audioService = await RustAudioService.create();

  // Initialize the browser filtering proxy
  final browserService = await BrowserService.create();

  runApp(
    ProviderScope(
      overrides: [
        audioServiceProvider.overrideWithValue(audioService),
        browserServiceProvider.overrideWithValue(browserService),
      ],
      child: const LoonBoxApp(),
    ),
  );
}
