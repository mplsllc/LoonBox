import 'dart:convert';
import 'dart:ui';

/// Complete feather manifest — the JSON contract for `.loonfeather` packages.
///
/// Designed to be forward-compatible with The Nest (marketplace) fields
/// from day one; unused fields are simply ignored until The Nest ships.
class FeatherManifest {
  const FeatherManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.minLoonboxVersion,
    this.authorName,
    this.authorUrl,
    this.authorEmail,
    this.license,
    this.screenshots = const [],
    this.tags = const [],
    this.homepageUrl,
    this.repositoryUrl,
    required this.colors,
    this.fontFamily,
    this.fontSizes,
    this.density = FeatherDensity.normal,
    this.backgroundImage,
    this.backgroundBlendMode,
    this.backgroundOpacity = 1.0,
    this.playerBarStyle = PlayerBarStyle.standard,
    this.sidebarStyle = SidebarStyle.rail,
    this.brightness,
  });

  // ── Core identity ──
  final String id;
  final String name;
  final String version;
  final String? description;
  final String? minLoonboxVersion;

  // ── Author ──
  final String? authorName;
  final String? authorUrl;
  final String? authorEmail;

  // ── Nest-ready (unused until The Nest launches) ──
  final String? license;
  final List<String> screenshots;
  final List<String> tags;
  final String? homepageUrl;
  final String? repositoryUrl;

  // ── Visual ──
  final FeatherColors colors;
  final String? fontFamily;
  final FeatherFontSizes? fontSizes;
  final FeatherDensity density;
  final String? backgroundImage;
  final String? backgroundBlendMode;
  final double backgroundOpacity;
  final PlayerBarStyle playerBarStyle;
  final SidebarStyle sidebarStyle;

  /// Optional brightness override. When set, the app forces this brightness
  /// instead of following system preference. Dark feathers like Nightingale
  /// should set this to [FeatherBrightness.dark].
  final FeatherBrightness? brightness;

  factory FeatherManifest.fromJson(Map<String, dynamic> json) {
    return FeatherManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String? ?? '1.0.0',
      description: json['description'] as String?,
      minLoonboxVersion: json['min_loonbox_version'] as String?,
      authorName: json['author_name'] as String?,
      authorUrl: json['author_url'] as String?,
      authorEmail: json['author_email'] as String?,
      license: json['license'] as String?,
      screenshots: (json['screenshots'] as List?)?.cast<String>() ?? const [],
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      homepageUrl: json['homepage_url'] as String?,
      repositoryUrl: json['repository_url'] as String?,
      colors: FeatherColors.fromJson(json['colors'] as Map<String, dynamic>),
      fontFamily: json['font_family'] as String?,
      fontSizes: json['font_sizes'] != null
          ? FeatherFontSizes.fromJson(json['font_sizes'] as Map<String, dynamic>)
          : null,
      density: FeatherDensity.values.byName(
        json['density'] as String? ?? 'normal',
      ),
      backgroundImage: json['background_image'] as String?,
      backgroundBlendMode: json['background_blend_mode'] as String?,
      backgroundOpacity: (json['background_opacity'] as num?)?.toDouble() ?? 1.0,
      playerBarStyle: _parseEnum(
        PlayerBarStyle.values, json['player_bar_style'] as String?, PlayerBarStyle.standard,
      ),
      sidebarStyle: _parseEnum(
        SidebarStyle.values, json['sidebar_style'] as String?, SidebarStyle.rail,
      ),
      brightness: json['brightness'] != null
          ? _parseEnum(FeatherBrightness.values, json['brightness'] as String?, FeatherBrightness.dark)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        if (description != null) 'description': description,
        if (minLoonboxVersion != null) 'min_loonbox_version': minLoonboxVersion,
        if (authorName != null) 'author_name': authorName,
        if (authorUrl != null) 'author_url': authorUrl,
        if (authorEmail != null) 'author_email': authorEmail,
        if (license != null) 'license': license,
        if (screenshots.isNotEmpty) 'screenshots': screenshots,
        if (tags.isNotEmpty) 'tags': tags,
        if (homepageUrl != null) 'homepage_url': homepageUrl,
        if (repositoryUrl != null) 'repository_url': repositoryUrl,
        'colors': colors.toJson(),
        if (fontFamily != null) 'font_family': fontFamily,
        if (fontSizes != null) 'font_sizes': fontSizes!.toJson(),
        'density': density.name,
        if (backgroundImage != null) 'background_image': backgroundImage,
        if (backgroundBlendMode != null) 'background_blend_mode': backgroundBlendMode,
        'background_opacity': backgroundOpacity,
        'player_bar_style': playerBarStyle.name,
        'sidebar_style': sidebarStyle.name,
        if (brightness != null) 'brightness': brightness!.name,
      };

  static FeatherManifest? tryParse(String jsonString) {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return FeatherManifest.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

/// Color palette for a feather. All colors are hex strings (#RRGGBB or #AARRGGBB).
class FeatherColors {
  const FeatherColors({
    required this.primary,
    this.secondary,
    this.tertiary,
    this.surface,
    this.background,
    this.error,
    this.onPrimary,
    this.onSecondary,
    this.onSurface,
    this.onBackground,
    this.accent,
  });

  final String primary;
  final String? secondary;
  final String? tertiary;
  final String? surface;
  final String? background;
  final String? error;
  final String? onPrimary;
  final String? onSecondary;
  final String? onSurface;
  final String? onBackground;
  final String? accent;

  factory FeatherColors.fromJson(Map<String, dynamic> json) {
    return FeatherColors(
      primary: json['primary'] as String,
      secondary: json['secondary'] as String?,
      tertiary: json['tertiary'] as String?,
      surface: json['surface'] as String?,
      background: json['background'] as String?,
      error: json['error'] as String?,
      onPrimary: json['on_primary'] as String?,
      onSecondary: json['on_secondary'] as String?,
      onSurface: json['on_surface'] as String?,
      onBackground: json['on_background'] as String?,
      accent: json['accent'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'primary': primary,
        if (secondary != null) 'secondary': secondary,
        if (tertiary != null) 'tertiary': tertiary,
        if (surface != null) 'surface': surface,
        if (background != null) 'background': background,
        if (error != null) 'error': error,
        if (onPrimary != null) 'on_primary': onPrimary,
        if (onSecondary != null) 'on_secondary': onSecondary,
        if (onSurface != null) 'on_surface': onSurface,
        if (onBackground != null) 'on_background': onBackground,
        if (accent != null) 'accent': accent,
      };

  /// Parse hex color string to Flutter Color.
  static Color parseHex(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }
}

class FeatherFontSizes {
  const FeatherFontSizes({
    this.displayLarge,
    this.displayMedium,
    this.displaySmall,
    this.headlineLarge,
    this.headlineMedium,
    this.headlineSmall,
    this.titleLarge,
    this.titleMedium,
    this.titleSmall,
    this.bodyLarge,
    this.bodyMedium,
    this.bodySmall,
    this.labelLarge,
    this.labelMedium,
    this.labelSmall,
  });

  final double? displayLarge;
  final double? displayMedium;
  final double? displaySmall;
  final double? headlineLarge;
  final double? headlineMedium;
  final double? headlineSmall;
  final double? titleLarge;
  final double? titleMedium;
  final double? titleSmall;
  final double? bodyLarge;
  final double? bodyMedium;
  final double? bodySmall;
  final double? labelLarge;
  final double? labelMedium;
  final double? labelSmall;

  factory FeatherFontSizes.fromJson(Map<String, dynamic> json) {
    return FeatherFontSizes(
      displayLarge: (json['display_large'] as num?)?.toDouble(),
      displayMedium: (json['display_medium'] as num?)?.toDouble(),
      displaySmall: (json['display_small'] as num?)?.toDouble(),
      headlineLarge: (json['headline_large'] as num?)?.toDouble(),
      headlineMedium: (json['headline_medium'] as num?)?.toDouble(),
      headlineSmall: (json['headline_small'] as num?)?.toDouble(),
      titleLarge: (json['title_large'] as num?)?.toDouble(),
      titleMedium: (json['title_medium'] as num?)?.toDouble(),
      titleSmall: (json['title_small'] as num?)?.toDouble(),
      bodyLarge: (json['body_large'] as num?)?.toDouble(),
      bodyMedium: (json['body_medium'] as num?)?.toDouble(),
      bodySmall: (json['body_small'] as num?)?.toDouble(),
      labelLarge: (json['label_large'] as num?)?.toDouble(),
      labelMedium: (json['label_medium'] as num?)?.toDouble(),
      labelSmall: (json['label_small'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (displayLarge != null) 'display_large': displayLarge,
        if (displayMedium != null) 'display_medium': displayMedium,
        if (displaySmall != null) 'display_small': displaySmall,
        if (headlineLarge != null) 'headline_large': headlineLarge,
        if (headlineMedium != null) 'headline_medium': headlineMedium,
        if (headlineSmall != null) 'headline_small': headlineSmall,
        if (titleLarge != null) 'title_large': titleLarge,
        if (titleMedium != null) 'title_medium': titleMedium,
        if (titleSmall != null) 'title_small': titleSmall,
        if (bodyLarge != null) 'body_large': bodyLarge,
        if (bodyMedium != null) 'body_medium': bodyMedium,
        if (bodySmall != null) 'body_small': bodySmall,
        if (labelLarge != null) 'label_large': labelLarge,
        if (labelMedium != null) 'label_medium': labelMedium,
        if (labelSmall != null) 'label_small': labelSmall,
      };
}

enum FeatherDensity { compact, normal, comfortable }

enum FeatherBrightness { light, dark }

enum PlayerBarStyle { standard, minimal, expanded, topTransport }

enum SidebarStyle { rail, drawer, hidden, tree }

/// Safely parse an enum value, falling back to a default for unknown strings.
T _parseEnum<T extends Enum>(List<T> values, String? name, T defaultValue) {
  if (name == null) return defaultValue;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return defaultValue;
}
