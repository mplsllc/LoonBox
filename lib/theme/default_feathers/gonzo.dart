import 'package:flutter/material.dart';
import '../loonbox_theme.dart';

final gonzo = LoonBoxFeather(
  id: 'gonzo',
  name: 'Gonzo',
  lightTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  ),
);
