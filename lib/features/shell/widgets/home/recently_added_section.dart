import 'package:flutter/material.dart';

import '../../../../database/database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/home_providers.dart';
import 'album_card.dart';
import 'home_section.dart';

/// Newest albums by dateAdded.
class RecentlyAddedSection extends StatelessWidget {
  const RecentlyAddedSection({super.key, required this.albums, required this.db});

  final List<AlbumWithArt> albums;
  final LoonBoxDatabase db;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HomeSection(
      title: l10n.homeRecentlyAdded,
      child: SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: albums.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = albums[index];
            return AlbumCard(
              album: item.album,
              db: db,
              trackPath: item.trackPath,
            );
          },
        ),
      ),
    );
  }
}
