import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../../../l10n/app_localizations.dart';
import '../../player/presentation/queue_provider.dart';
import 'album_detail_page.dart';

/// Provider for albums by a specific artist.
final artistAlbumsProvider =
    FutureProvider.family<List<Album>, int>((ref, artistId) async {
  final db = ref.watch(databaseProvider);
  final artist = await (db.select(db.artists)..where((a) => a.id.equals(artistId))).getSingle();
  return (db.select(db.albums)
        ..where((a) => a.artist.equals(artist.name))
        ..orderBy([(a) => OrderingTerm.desc(a.year)]))
      .get();
});

/// Provider for all tracks by a specific artist.
final artistTracksProvider =
    FutureProvider.family<List<Track>, int>((ref, artistId) async {
  final db = ref.watch(databaseProvider);
  final artist = await (db.select(db.artists)..where((a) => a.id.equals(artistId))).getSingle();
  return (db.select(db.tracks)
        ..where((t) => t.artist.equals(artist.name))
        ..orderBy([(t) => OrderingTerm.asc(t.title)]))
      .get();
});

class ArtistDetailPage extends ConsumerWidget {
  const ArtistDetailPage({super.key, required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final albumsAsync = ref.watch(artistAlbumsProvider(artist.id));
    final tracksAsync = ref.watch(artistTracksProvider(artist.id));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(artist.name),
      ),
      body: albumsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (albums) {
          final allTracks = tracksAsync.valueOrNull ?? [];
          return CustomScrollView(
            slivers: [
              // Artist header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        child: Text(
                          artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
                          style: textTheme.headlineLarge,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(artist.name, style: textTheme.headlineMedium),
                            const SizedBox(height: 4),
                            Text(
                              [
                                l10n.artistAlbumCount(albums.length),
                                l10n.albumDetailTracks(allTracks.length),
                              ].join(' · '),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: allTracks.isNotEmpty
                                  ? () => ref.read(queueProvider.notifier).setQueue(allTracks)
                                  : null,
                              icon: const Icon(Icons.play_arrow),
                              label: Text(l10n.playerPlay),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Albums section
              if (albums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: Text(l10n.navAlbums, style: textTheme.titleMedium),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final album = albums[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => AlbumDetailPage(album: album),
                              ));
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Container(
                                    color: colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.album, size: 48),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        album.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.titleSmall,
                                      ),
                                      if (album.year != null)
                                        Text(
                                          '${album.year}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: albums.length,
                    ),
                  ),
                ),
              ],
              // All tracks section
              if (allTracks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Text(l10n.navLibrary, style: textTheme.titleMedium),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = allTracks[index];
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
                          subtitle: track.album != null
                              ? Text(
                                  track.album!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall,
                                )
                              : null,
                          trailing: Text(
                            _formatDuration(track.durationMs),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            ref.read(queueProvider.notifier).setQueue(allTracks, startIndex: index);
                          },
                        ),
                      );
                    },
                    childCount: allTracks.length,
                  ),
                ),
              ],
            ],
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
