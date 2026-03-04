import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/audio_service.dart';
import 'services/rust_audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('LoonBox');
    await windowManager.setMinimumSize(const Size(800, 600));
    // Intercept close → hide to tray instead
    await windowManager.setPreventClose(true);
  }

  // Initialize Windows media transport controls
  if (Platform.isWindows) {
    await SMTCWindows.initialize();
  }

  // Initialize the Rust audio engine
  final audioService = await RustAudioService.create();

  runApp(
    ProviderScope(
      overrides: [
        audioServiceProvider.overrideWithValue(audioService),
      ],
      child: const LoonBoxApp(),
    ),
  );
}
