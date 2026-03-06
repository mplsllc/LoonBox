import 'package:flutter/material.dart';

import '../../../../database/database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/home_providers.dart';
import 'album_card.dart';
import 'home_section.dart';

/// Intentional discovery with reason grouping.
class DiscoverSection extends StatelessWidget {
  const DiscoverSection({
    super.key,
    required this.albums,
    required this.db,
    this.onRefresh,
  });

  final List<DiscoverAlbum> albums;
  final LoonBoxDatabase db;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final forgotten = albums.where((a) => a.reason == DiscoverReason.forgotten).toList();
    final neverPlayed = albums.where((a) => a.reason == DiscoverReason.neverPlayed).toList();

    // Only one reason has results → show without grouping header
    final hasMultipleReasons = forgotten.isNotEmpty && neverPlayed.isNotEmpty;

    return HomeSection(
      title: l10n.homeRediscover,
      action: onRefresh != null
          ? TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.homeRefresh),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (forgotten.isNotEmpty) ...[
            if (hasMultipleReasons)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: Text(
                  l10n.homeForgotten,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            _albumRow(forgotten),
          ],
          if (neverPlayed.isNotEmpty) ...[
            if (hasMultipleReasons)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Text(
                  l10n.homeNeverPlayed,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            _albumRow(neverPlayed),
          ],
        ],
      ),
    );
  }

  Widget _albumRow(List<DiscoverAlbum> items) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return AlbumCard(
            album: item.album,
            db: db,
            trackPath: item.trackPath,
          );
        },
      ),
    );
  }
}
