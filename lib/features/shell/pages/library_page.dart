import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../database/database.dart';
import '../../player/presentation/queue_provider.dart';
import 'album_detail_page.dart';
import 'artist_detail_page.dart';

/// Provider for the track list from the database.
final trackListProvider = FutureProvider<List<Track>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.tracks)
        ..orderBy([(t) => OrderingTerm.asc(t.title)]))
      .get();
});

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tracksAsync = ref.watch(trackListProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libraryTitle),
      ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tracks) {
          if (tracks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.libraryEmpty,
                  style: textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return GestureDetector(
                onSecondaryTapUp: (details) {
                  _showContextMenu(context, ref, details.globalPosition, track);
                },
                child: ListTile(
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [track.artist, track.album]
                        .where((s) => s != null)
                        .join(' — '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _formatDuration(track.durationMs),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    ref.read(queueProvider.notifier).setQueue(tracks, startIndex: index);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref, Offset position, Track track) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(value: 'play_next', child: Text(l10n.contextPlayNext)),
        PopupMenuItem(value: 'play_later', child: Text(l10n.contextPlayLater)),
        if (track.album != null)
          PopupMenuItem(value: 'go_album', child: Text(l10n.contextGoToAlbum)),
        if (track.artist != null)
          PopupMenuItem(value: 'go_artist', child: Text(l10n.contextGoToArtist)),
      ],
    ).then((value) async {
      if (value == null) return;
      switch (value) {
        case 'play_next':
          ref.read(queueProvider.notifier).playNext(track);
        case 'play_later':
          ref.read(queueProvider.notifier).playLater(track);
        case 'go_album':
          final albums = await (db.select(db.albums)
                ..where((a) => a.name.equals(track.album!)))
              .get();
          if (albums.isNotEmpty && context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AlbumDetailPage(album: albums.first),
            ));
          }
        case 'go_artist':
          final artists = await (db.select(db.artists)
                ..where((a) => a.name.equals(track.artist!)))
              .get();
          if (artists.isNotEmpty && context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ArtistDetailPage(artist: artists.first),
            ));
          }
      }
    });
  }

  String _formatDuration(int? ms) {
    if (ms == null) return '--:--';
    final total = Duration(milliseconds: ms);
    final m = total.inMinutes;
    final s = total.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
