import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feather_manifest.dart';
import 'feather_theme_builder.dart';

/// A LoonBox "feather" — a complete theme definition.
class LoonBoxFeather {
  const LoonBoxFeather({
    required this.id,
    required this.name,
    required this.lightTheme,
    required this.darkTheme,
    this.manifest,
    this.directoryPath,
    this.isBuiltIn = true,
  });

  final String id;
  final String name;
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final FeatherManifest? manifest;
  final String? directoryPath;
  final bool isBuiltIn;

  /// Create a feather from a manifest.
  factory LoonBoxFeather.fromManifest(FeatherManifest manifest, {String? directoryPath}) {
    final themes = FeatherThemeBuilder.build(manifest);
    return LoonBoxFeather(
      id: manifest.id,
      name: manifest.name,
      lightTheme: themes.light,
      darkTheme: themes.dark,
      manifest: manifest,
      directoryPath: directoryPath,
      isBuiltIn: false,
    );
  }
}

final loonBoxThemeProvider = StateNotifierProvider<LoonBoxThemeNotifier, LoonBoxFeather>(
  (ref) => LoonBoxThemeNotifier(),
);

class LoonBoxThemeNotifier extends StateNotifier<LoonBoxFeather> {
  LoonBoxThemeNotifier() : super(_defaultFeather);

  void setFeather(LoonBoxFeather feather) {
    state = feather;
  }
}

/// Default built-in feather used until the engine loads.
final _defaultFeather = LoonBoxFeather.fromManifest(
  const FeatherManifest(
    id: 'bluemonday',
    name: 'Blue Monday',
    version: '1.0.0',
    description: 'Default feather — the original Nightingale look, reimagined.',
    colors: FeatherColors(primary: '#1565C0'),
  ),
);
