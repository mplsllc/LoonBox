import 'package:flutter/material.dart';
import '../loonbox_theme.dart';

final purpleRain = LoonBoxFeather(
  id: 'purplerain',
  name: 'Purple Rain',
  lightTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7B1FA2),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7B1FA2),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  ),
);
