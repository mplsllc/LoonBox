import 'package:flutter/material.dart';
import '../loonbox_theme.dart';

final blueMonday = LoonBoxFeather(
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
