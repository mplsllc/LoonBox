import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../database/database.dart';
import '../../player/presentation/queue_provider.dart';

/// All playlists from the database.
final playlistListProvider = FutureProvider<List<Playlist>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.playlists)
        ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]))
      .get();
});

/// Tracks in a specific playlist, ordered by position.
final playlistTracksProvider =
    FutureProvider.family<List<Track>, int>((ref, playlistId) async {
  final db = ref.watch(databaseProvider);
  final ptRows = await (db.select(db.playlistTracks)
        ..where((pt) => pt.playlistId.equals(playlistId))
        ..orderBy([(pt) => OrderingTerm.asc(pt.position)]))
      .get();

  if (ptRows.isEmpty) return [];

  final trackIds = ptRows.map((pt) => pt.trackId).toList();
  final tracks = await (db.select(db.tracks)
        ..where((t) => t.id.isIn(trackIds)))
      .get();

  // Preserve playlist order
  final trackMap = {for (final t in tracks) t.id: t};
  return trackIds.where((id) => trackMap.containsKey(id)).map((id) => trackMap[id]!).toList();
});

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playlistsAsync = ref.watch(playlistListProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.playlistsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.playlistCreate,
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: playlistsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (playlists) {
          if (playlists.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.queue_music, size: 64,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      l10n.playlistEmpty,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _showCreateDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.playlistCreate),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.queue_music, color: colorScheme.onPrimaryContainer),
                ),
                title: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  l10n.queueTrackCount(playlist.trackCount),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaylistDetailPage(playlist: playlist),
                  ),
                ),
                onLongPress: () => _showPlaylistOptions(context, ref, playlist),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.playlistCreate),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.playlistName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: l10n.playlistDescription,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final db = ref.read(databaseProvider);
              final now = DateTime.now().millisecondsSinceEpoch;
              await db.into(db.playlists).insert(PlaylistsCompanion.insert(
                    name: name,
                    description: Value(descController.text.trim().isNotEmpty
                        ? descController.text.trim()
                        : null),
                    createdAt: now,
                    updatedAt: now,
                  ));
              ref.invalidate(playlistListProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }

  void _showPlaylistOptions(BuildContext context, WidgetRef ref, Playlist playlist) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.playlistRename),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, ref, playlist);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text(l10n.playlistDelete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteDialog(context, ref, playlist);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, Playlist playlist) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: playlist.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.playlistRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.playlistName,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final db = ref.read(databaseProvider);
              await (db.update(db.playlists)
                    ..where((p) => p.id.equals(playlist.id)))
                  .write(PlaylistsCompanion(
                name: Value(name),
                updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
              ));
              ref.invalidate(playlistListProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Playlist playlist) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.playlistDelete),
        content: Text(l10n.playlistDeleteConfirm(playlist.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await (db.delete(db.playlistTracks)
                    ..where((pt) => pt.playlistId.equals(playlist.id)))
                  .go();
              await (db.delete(db.playlists)
                    ..where((p) => p.id.equals(playlist.id)))
                  .go();
              ref.invalidate(playlistListProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

/// Playlist detail view with track list.
class PlaylistDetailPage extends ConsumerWidget {
  const PlaylistDetailPage({super.key, required this.playlist});
  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tracksAsync = ref.watch(playlistTracksProvider(playlist.id));
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
      ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tracks) {
          if (tracks.isEmpty) {
            return Center(
              child: Text(
                l10n.queueEmpty,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          return Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.queue_music, size: 40,
                          color: colorScheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(playlist.name, style: textTheme.headlineSmall),
                          if (playlist.description != null)
                            Text(
                              playlist.description!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          Text(
                            l10n.queueTrackCount(tracks.length),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: tracks.isNotEmpty
                          ? () => ref.read(queueProvider.notifier).setQueue(tracks, startIndex: 0)
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.playAll),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Track list
              Expanded(
                child: ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return ListTile(
                      leading: Text(
                        '${index + 1}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
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
                    );
                  },
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
}
