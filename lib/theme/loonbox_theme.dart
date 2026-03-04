import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A LoonBox "feather" — a complete theme definition.
class LoonBoxFeather {
  const LoonBoxFeather({
    required this.id,
    required this.name,
    required this.lightTheme,
    required this.darkTheme,
  });

  final String id;
  final String name;
  final ThemeData lightTheme;
  final ThemeData darkTheme;
}

/// Default feather: Blue Monday (homage to Nightingale's bluemonday).
final _blueMonday = LoonBoxFeather(
  id: 'bluemonday',
  name: 'Blue Monday',
  lightTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1565C0),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1565C0),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  ),
);

final loonBoxThemeProvider = StateNotifierProvider<LoonBoxThemeNotifier, LoonBoxFeather>(
  (ref) => LoonBoxThemeNotifier(),
);

class LoonBoxThemeNotifier extends StateNotifier<LoonBoxFeather> {
  LoonBoxThemeNotifier() : super(_blueMonday);

  void setFeather(LoonBoxFeather feather) {
    state = feather;
  }
}
