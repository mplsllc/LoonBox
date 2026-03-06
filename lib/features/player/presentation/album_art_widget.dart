import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/album_art_service.dart';

/// Cached album art path provider, keyed by track file path.
final albumArtPathProvider =
    FutureProvider.family<String?, String>((ref, trackPath) async {
  final artService = ref.watch(albumArtServiceProvider);
  return artService.getArtPath(trackPath);
});

/// Displays album art for a track, with fallback icon.
class AlbumArtWidget extends ConsumerWidget {
  const AlbumArtWidget({
    super.key,
    required this.trackPath,
    this.size = 48,
    this.borderRadius = 4,
    this.iconSize,
  });

  final String? trackPath;
  final double size;
  final double borderRadius;
  final double? iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconSize = iconSize ?? (size * 0.5).clamp(24, 120).toDouble();

    if (trackPath == null) {
      return _placeholder(colorScheme, effectiveIconSize);
    }

    final artAsync = ref.watch(albumArtPathProvider(trackPath!));

    return artAsync.when(
      loading: () => _placeholder(colorScheme, effectiveIconSize),
      error: (_, __) => _placeholder(colorScheme, effectiveIconSize),
      data: (artPath) {
        if (artPath == null) {
          return _placeholder(colorScheme, effectiveIconSize);
        }
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(artPath),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholderInner(colorScheme, effectiveIconSize),
          ),
        );
      },
    );
  }

  Widget _placeholder(ColorScheme colorScheme, double iconSz) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(Icons.music_note, size: iconSz, color: colorScheme.onSurfaceVariant),
    );
  }

  Widget _placeholderInner(ColorScheme colorScheme, double iconSz) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, size: iconSz, color: colorScheme.onSurfaceVariant),
    );
  }
}
