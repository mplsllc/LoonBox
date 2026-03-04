import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../database/database.dart';
import '../pages/playlists_page.dart';

/// Shows a dialog to pick a playlist and add a track to it.
Future<void> showAddToPlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final l10n = AppLocalizations.of(context)!;
  final db = ref.read(databaseProvider);
  final playlists = await (db.select(db.playlists)
        ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]))
      .get();

  if (!context.mounted) return;

  if (playlists.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.playlistEmpty)),
    );
    return;
  }

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.contextAddToPlaylist),
      content: SizedBox(
        width: 300,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: playlists.length,
          itemBuilder: (_, index) {
            final playlist = playlists[index];
            return ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(playlist.name),
              subtitle: Text(l10n.queueTrackCount(playlist.trackCount)),
              onTap: () async {
                // Get the next position
                final maxPos = await (db.selectOnly(db.playlistTracks)
                      ..addColumns([db.playlistTracks.position.max()])
                      ..where(db.playlistTracks.playlistId.equals(playlist.id)))
                    .map((row) => row.read(db.playlistTracks.position.max()))
                    .getSingleOrNull();

                final nextPos = (maxPos ?? -1) + 1;
                final now = DateTime.now().millisecondsSinceEpoch;

                await db.into(db.playlistTracks).insert(
                      PlaylistTracksCompanion.insert(
                        playlistId: playlist.id,
                        trackId: track.id,
                        position: nextPos,
                        addedAt: now,
                      ),
                    );

                // Update track count
                await (db.update(db.playlists)
                      ..where((p) => p.id.equals(playlist.id)))
                    .write(PlaylistsCompanion(
                  trackCount: Value(playlist.trackCount + 1),
                  updatedAt: Value(now),
                ));

                ref.invalidate(playlistListProvider);
                ref.invalidate(playlistTracksProvider(playlist.id));

                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );
}
