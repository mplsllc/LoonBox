import 'package:flutter/material.dart';

import '../../../../database/database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/home_providers.dart';
import 'album_card.dart';
import 'home_section.dart';

/// Recently played albums from play_history.
class RecentlyPlayedSection extends StatelessWidget {
  const RecentlyPlayedSection({super.key, required this.albums, required this.db});

  final List<RecentAlbum> albums;
  final LoonBoxDatabase db;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HomeSection(
      title: l10n.homeRecentlyPlayed,
      child: SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: albums.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
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
