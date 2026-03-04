import 'package:flutter/material.dart';
import '../loonbox_theme.dart';

final pinkMartini = LoonBoxFeather(
  id: 'pinkmartini',
  name: 'Pink Martini',
  lightTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFE91E63),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFE91E63),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  ),
);
