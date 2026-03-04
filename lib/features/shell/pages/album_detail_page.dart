import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../../../l10n/app_localizations.dart';
import '../../player/presentation/queue_provider.dart';

/// Provider for tracks in a specific album.
final albumTracksProvider =
    FutureProvider.family<List<Track>, int>((ref, albumId) async {
  final db = ref.watch(databaseProvider);
  final album = await (db.select(db.albums)..where((a) => a.id.equals(albumId))).getSingle();
  return (db.select(db.tracks)
        ..where((t) => t.album.equals(album.name))
        ..orderBy([
          (t) => OrderingTerm.asc(t.discNumber),
          (t) => OrderingTerm.asc(t.trackNumber),
        ]))
      .get();
});

class AlbumDetailPage extends ConsumerWidget {
  const AlbumDetailPage({super.key, required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tracksAsync = ref.watch(albumTracksProvider(album.id));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(album.name),
      ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tracks) {
          return CustomScrollView(
            slivers: [
              // Album header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Album art placeholder
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.album, size: 80, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(album.name, style: textTheme.headlineMedium),
                            if (album.artist != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  album.artist!,
                                  style: textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              [
                                if (album.year != null) '${album.year}',
                                l10n.albumDetailTracks(tracks.length),
                                _formatTotalDuration(tracks),
                              ].join(' · '),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: tracks.isNotEmpty
                                  ? () => ref.read(queueProvider.notifier).setQueue(tracks)
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
              // Track list
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = tracks[index];
                    return ListTile(
                      leading: SizedBox(
                        width: 32,
                        child: Text(
                          track.trackNumber?.toString() ?? '–',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: track.artist != null
                          ? Text(
                              track.artist!,
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
                        ref.read(queueProvider.notifier).setQueue(tracks, startIndex: index);
                      },
                    );
                  },
                  childCount: tracks.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(int? ms) {
    if (ms == null) return '--:--';
    final total = Duration(milliseconds: ms);
    final m = total.inMinutes;
    final s = total.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatTotalDuration(List<Track> tracks) {
    final totalMs = tracks.fold<int>(0, (sum, t) => sum + (t.durationMs ?? 0));
    final d = Duration(milliseconds: totalMs);
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }
}
