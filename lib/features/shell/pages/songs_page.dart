import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../widgets/loon_loader.dart';
import '../../../database/database.dart';
import '../../player/presentation/queue_provider.dart';
import '../widgets/track_context_menu.dart';
import 'auto_tag_page.dart';

/// Provider for the track list from the database.
final trackListProvider = FutureProvider<List<Track>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.tracks)
        ..orderBy([(t) => OrderingTerm.asc(t.title)]))
      .get();
});

enum _SortColumn { title, artist, album, duration }

class SongsPage extends ConsumerStatefulWidget {
  const SongsPage({super.key});

  @override
  ConsumerState<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends ConsumerState<SongsPage> {
  _SortColumn _sortColumn = _SortColumn.title;
  bool _sortAscending = true;

  List<Track> _sortTracks(List<Track> tracks) {
    final sorted = List<Track>.from(tracks);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case _SortColumn.title:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case _SortColumn.artist:
          cmp = (a.artist ?? '').toLowerCase().compareTo((b.artist ?? '').toLowerCase());
        case _SortColumn.album:
          cmp = (a.album ?? '').toLowerCase().compareTo((b.album ?? '').toLowerCase());
        case _SortColumn.duration:
          cmp = (a.durationMs ?? 0).compareTo(b.durationMs ?? 0);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  void _onSort(_SortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tracksAsync = ref.watch(trackListProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.songsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: l10n.mbAutoTagTitle,
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AutoTagPage(),
              ));
            },
          ),
          ...?tracksAsync.whenOrNull(
            data: (tracks) => [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    l10n.libraryTrackCount(tracks.length),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: tracksAsync.when(
        loading: () => const Center(child: LoonLoader()),
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

          final sorted = _sortTracks(tracks);

          return Column(
            children: [
              // Column headers
              _buildHeader(context, l10n, colorScheme),
              const Divider(height: 1),
              // Track rows
              Expanded(
                child: ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final track = sorted[index];
                    return GestureDetector(
                      onSecondaryTapUp: (details) {
                        showTrackContextMenu(context, ref, details.globalPosition, track);
                      },
                      child: _TrackRow(
                        track: track,
                        index: index,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        db: ref.read(databaseProvider),
                        onTap: () {
                          ref.read(queueProvider.notifier).setQueue(
                            sorted,
                            startIndex: index,
                          );
                        },
                      ),
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

  Widget _buildHeader(BuildContext context, AppLocalizations l10n, ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _SortableHeaderCell(
            label: l10n.trackTitle,
            flex: 3,
            column: _SortColumn.title,
            currentColumn: _sortColumn,
            ascending: _sortAscending,
            onTap: () => _onSort(_SortColumn.title),
          ),
          _SortableHeaderCell(
            label: l10n.trackArtist,
            flex: 2,
            column: _SortColumn.artist,
            currentColumn: _sortColumn,
            ascending: _sortAscending,
            onTap: () => _onSort(_SortColumn.artist),
          ),
          _SortableHeaderCell(
            label: l10n.trackAlbum,
            flex: 2,
            column: _SortColumn.album,
            currentColumn: _sortColumn,
            ascending: _sortAscending,
            onTap: () => _onSort(_SortColumn.album),
          ),
          _SortableHeaderCell(
            label: l10n.trackDuration,
            flex: 1,
            column: _SortColumn.duration,
            currentColumn: _sortColumn,
            ascending: _sortAscending,
            onTap: () => _onSort(_SortColumn.duration),
            alignRight: true,
          ),
        ],
      ),
    );
  }

}

class _SortableHeaderCell extends StatelessWidget {
  const _SortableHeaderCell({
    required this.label,
    required this.flex,
    required this.column,
    required this.currentColumn,
    required this.ascending,
    required this.onTap,
    this.alignRight = false,
  });

  final String label;
  final int flex;
  final _SortColumn column;
  final _SortColumn currentColumn;
  final bool ascending;
  final VoidCallback onTap;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final isActive = column == currentColumn;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisAlignment:
                alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 2),
                Icon(
                  ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.index,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
    required this.db,
  });

  final Track track;
  final int index;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;
  final LoonBoxDatabase db;

  @override
  Widget build(BuildContext context) {
    // Alternating row stripes — subtle tint on even rows
    final rowColor = index.isEven
        ? colorScheme.surfaceContainerLowest
        : colorScheme.surfaceContainerLow;

    return Material(
      color: rowColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: track.artist != null
                  ? MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => navigateToArtistByName(context, db, track.artist!),
                        child: Text(
                          track.artist!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              flex: 2,
              child: track.album != null
                  ? MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => navigateToAlbumByName(context, db, track.album!),
                        child: Text(
                          track.album!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              flex: 1,
              child: Text(
                _formatDuration(track.durationMs),
                textAlign: TextAlign.end,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
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
