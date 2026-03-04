import 'package:flutter/material.dart';

import 'feather_manifest.dart';

/// Builds Flutter ThemeData from a FeatherManifest.
class FeatherThemeBuilder {
  const FeatherThemeBuilder._();

  /// Build a complete ThemeData pair (light + dark) from a manifest.
  static ({ThemeData light, ThemeData dark}) build(FeatherManifest manifest) {
    return (
      light: _buildTheme(manifest, Brightness.light),
      dark: _buildTheme(manifest, Brightness.dark),
    );
  }

  static ThemeData _buildTheme(FeatherManifest manifest, Brightness brightness) {
    final colors = manifest.colors;
    final seedColor = FeatherColors.parseHex(colors.primary);

    // Start with seed-generated scheme, then override with explicit colors
    var colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    // Override individual colors if specified in the manifest
    colorScheme = colorScheme.copyWith(
      primary: FeatherColors.parseHex(colors.primary),
      secondary: colors.secondary != null ? FeatherColors.parseHex(colors.secondary!) : null,
      tertiary: colors.tertiary != null ? FeatherColors.parseHex(colors.tertiary!) : null,
      surface: colors.surface != null ? FeatherColors.parseHex(colors.surface!) : null,
      error: colors.error != null ? FeatherColors.parseHex(colors.error!) : null,
      onPrimary: colors.onPrimary != null ? FeatherColors.parseHex(colors.onPrimary!) : null,
      onSecondary: colors.onSecondary != null ? FeatherColors.parseHex(colors.onSecondary!) : null,
      onSurface: colors.onSurface != null ? FeatherColors.parseHex(colors.onSurface!) : null,
    );

    // Build text theme with optional font overrides
    TextTheme? textTheme;
    if (manifest.fontFamily != null || manifest.fontSizes != null) {
      textTheme = _buildTextTheme(manifest.fontFamily, manifest.fontSizes);
    }

    // Density
    final visualDensity = switch (manifest.density) {
      FeatherDensity.compact => VisualDensity.compact,
      FeatherDensity.normal => VisualDensity.standard,
      FeatherDensity.comfortable => VisualDensity.comfortable,
    };

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      visualDensity: visualDensity,
      fontFamily: manifest.fontFamily,
      textTheme: textTheme,
    );
  }

  static TextTheme _buildTextTheme(String? fontFamily, FeatherFontSizes? sizes) {
    final base = const TextTheme();
    if (sizes == null) return base;

    return base.copyWith(
      displayLarge: sizes.displayLarge != null
          ? base.displayLarge?.copyWith(fontSize: sizes.displayLarge)
          : null,
      displayMedium: sizes.displayMedium != null
          ? base.displayMedium?.copyWith(fontSize: sizes.displayMedium)
          : null,
      displaySmall: sizes.displaySmall != null
          ? base.displaySmall?.copyWith(fontSize: sizes.displaySmall)
          : null,
      headlineLarge: sizes.headlineLarge != null
          ? base.headlineLarge?.copyWith(fontSize: sizes.headlineLarge)
          : null,
      headlineMedium: sizes.headlineMedium != null
          ? base.headlineMedium?.copyWith(fontSize: sizes.headlineMedium)
          : null,
      headlineSmall: sizes.headlineSmall != null
          ? base.headlineSmall?.copyWith(fontSize: sizes.headlineSmall)
          : null,
      titleLarge: sizes.titleLarge != null
          ? base.titleLarge?.copyWith(fontSize: sizes.titleLarge)
          : null,
      titleMedium: sizes.titleMedium != null
          ? base.titleMedium?.copyWith(fontSize: sizes.titleMedium)
          : null,
      titleSmall: sizes.titleSmall != null
          ? base.titleSmall?.copyWith(fontSize: sizes.titleSmall)
          : null,
      bodyLarge: sizes.bodyLarge != null
          ? base.bodyLarge?.copyWith(fontSize: sizes.bodyLarge)
          : null,
      bodyMedium: sizes.bodyMedium != null
          ? base.bodyMedium?.copyWith(fontSize: sizes.bodyMedium)
          : null,
      bodySmall: sizes.bodySmall != null
          ? base.bodySmall?.copyWith(fontSize: sizes.bodySmall)
          : null,
      labelLarge: sizes.labelLarge != null
          ? base.labelLarge?.copyWith(fontSize: sizes.labelLarge)
          : null,
      labelMedium: sizes.labelMedium != null
          ? base.labelMedium?.copyWith(fontSize: sizes.labelMedium)
          : null,
      labelSmall: sizes.labelSmall != null
          ? base.labelSmall?.copyWith(fontSize: sizes.labelSmall)
          : null,
    );
  }
}
