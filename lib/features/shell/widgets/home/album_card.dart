import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../database/database.dart';
import '../../../player/presentation/album_art_widget.dart';
import '../track_context_menu.dart';

/// Compact album card for horizontal scroll sections.
class AlbumCard extends ConsumerWidget {
  const AlbumCard({
    super.key,
    required this.album,
    required this.db,
    this.trackPath,
    this.subtitle,
  });

  final Album album;
  final LoonBoxDatabase db;
  final String? trackPath;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final artistName = subtitle ?? album.artist;

    return GestureDetector(
      onTap: () => navigateToAlbumByName(context, db, album.name),
      onSecondaryTapUp: (details) {
        showAlbumContextMenu(context, ref, details.globalPosition, album);
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AlbumArtWidget(
                trackPath: trackPath,
                size: 140,
                borderRadius: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (artistName != null && artistName.isNotEmpty)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => navigateToArtistByName(context, db, artistName),
                  child: Text(
                    artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Text(
                '',
                style: textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}
