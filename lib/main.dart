import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/audio_service.dart';
import 'services/rust_audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
