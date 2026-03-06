import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../widgets/loon_loader.dart';
import '../../../database/database.dart';
import '../../player/presentation/album_art_widget.dart';
import '../../player/presentation/queue_provider.dart';
import '../widgets/track_context_menu.dart';
import 'album_detail_page.dart';

// ─── Data Model ────────────────────────────────────────────────────────────

/// Album with a representative track path for art lookup.
class AlbumGridItem {
  final Album album;
  final String? trackPath;

  const AlbumGridItem({required this.album, this.trackPath});
}

// ─── Sort Mode ─────────────────────────────────────────────────────────────

enum _AlbumSortMode { nameAsc, nameDesc, artistAsc, yearDesc, yearAsc, recentlyAdded }

// ─── Provider ──────────────────────────────────────────────────────────────

final albumGridProvider = FutureProvider<List<AlbumGridItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  final albums = await (db.select(db.albums)
        ..orderBy([(a) => OrderingTerm.asc(a.name)]))
      .get();

  // Batch-fetch one representative track path per album (with album art)
  final items = <AlbumGridItem>[];
  for (final album in albums) {
    final tracks = await (db.select(db.tracks)
          ..where((t) => t.album.equals(album.name))
          ..where((t) => t.hasAlbumArt.equals(true))
          ..limit(1))
        .get();
    String? trackPath = tracks.isNotEmpty ? tracks.first.filePath : null;
    // Fallback: any track from the album (for playback, even without art)
    if (trackPath == null) {
      final fallback = await (db.select(db.tracks)
            ..where((t) => t.album.equals(album.name))
            ..limit(1))
          .get();
      trackPath = fallback.isNotEmpty ? fallback.first.filePath : null;
    }
    items.add(AlbumGridItem(album: album, trackPath: trackPath));
  }
  return items;
});

/// Provider that returns a representative track file path for an album name.
final albumTrackPathProvider =
    FutureProvider.family<String?, String>((ref, albumName) async {
  final db = ref.watch(databaseProvider);
  // Prefer a track with album art
  var tracks = await (db.select(db.tracks)
        ..where((t) => t.album.equals(albumName))
        ..where((t) => t.hasAlbumArt.equals(true))
        ..limit(1))
      .get();
  if (tracks.isNotEmpty) return tracks.first.filePath;
  // Fallback: any track from the album
  tracks = await (db.select(db.tracks)
        ..where((t) => t.album.equals(albumName))
        ..limit(1))
      .get();
  return tracks.isNotEmpty ? tracks.first.filePath : null;
});

// ─── Page ──────────────────────────────────────────────────────────────────

class AlbumsPage extends ConsumerStatefulWidget {
  const AlbumsPage({super.key});

  @override
  ConsumerState<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends ConsumerState<AlbumsPage> {
  final _filterController = TextEditingController();
  String _filterText = '';
  _AlbumSortMode _sortMode = _AlbumSortMode.nameAsc;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  List<AlbumGridItem> _sortAndFilter(List<AlbumGridItem> items) {
    var filtered = items;
    if (_filterText.isNotEmpty) {
      final q = _filterText.toLowerCase();
      filtered = items.where((i) =>
          i.album.name.toLowerCase().contains(q) ||
          (i.album.artist?.toLowerCase().contains(q) ?? false)).toList();
    }

    switch (_sortMode) {
      case _AlbumSortMode.nameAsc:
        filtered.sort((a, b) =>
            a.album.name.toLowerCase().compareTo(b.album.name.toLowerCase()));
      case _AlbumSortMode.nameDesc:
        filtered.sort((a, b) =>
            b.album.name.toLowerCase().compareTo(a.album.name.toLowerCase()));
      case _AlbumSortMode.artistAsc:
        filtered.sort((a, b) {
          final aa = a.album.artist?.toLowerCase() ?? '';
          final ba = b.album.artist?.toLowerCase() ?? '';
          final cmp = aa.compareTo(ba);
          if (cmp != 0) return cmp;
          return a.album.name.toLowerCase().compareTo(b.album.name.toLowerCase());
        });
      case _AlbumSortMode.yearDesc:
        filtered.sort((a, b) {
          final ay = a.album.year ?? 0;
          final by = b.album.year ?? 0;
          final cmp = by.compareTo(ay);
          if (cmp != 0) return cmp;
          return a.album.name.toLowerCase().compareTo(b.album.name.toLowerCase());
        });
      case _AlbumSortMode.yearAsc:
        filtered.sort((a, b) {
          final ay = a.album.year ?? 9999;
          final by = b.album.year ?? 9999;
          final cmp = ay.compareTo(by);
          if (cmp != 0) return cmp;
          return a.album.name.toLowerCase().compareTo(b.album.name.toLowerCase());
        });
      case _AlbumSortMode.recentlyAdded:
        filtered.sort((a, b) {
          final ad = a.album.dateAdded ?? 0;
          final bd = b.album.dateAdded ?? 0;
          return bd.compareTo(ad);
        });
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final albumsAsync = ref.watch(albumGridProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: albumsAsync.when(
        loading: () => const Center(child: LoonLoader()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (albums) {
          if (albums.isEmpty) {
            return const Center(child: Text('No albums yet.'));
          }

          final sorted = _sortAndFilter(albums);

          return Column(
            children: [
              // ── Header Bar ──
              _HeaderBar(
                totalCount: albums.length,
                filteredCount: sorted.length,
                filterController: _filterController,
                sortMode: _sortMode,
                onFilterChanged: (text) => setState(() => _filterText = text),
                onSortChanged: (mode) => setState(() => _sortMode = mode),
                l10n: l10n,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              // ── Grid ──
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 5 columns at ≥1000px, 4 at ≥700px, 3 otherwise
                    final crossAxisCount = constraints.maxWidth >= 1000
                        ? 5
                        : constraints.maxWidth >= 700
                            ? 4
                            : 3;
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        return _AlbumCard(item: sorted[index]);
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
}

// ─── Header Bar ────────────────────────────────────────────────────────────

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.totalCount,
    required this.filteredCount,
    required this.filterController,
    required this.sortMode,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.l10n,
    required this.colorScheme,
    required this.textTheme,
  });

  final int totalCount;
  final int filteredCount;
  final TextEditingController filterController;
  final _AlbumSortMode sortMode;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<_AlbumSortMode> onSortChanged;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(60),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(l10n.albumsTitle, style: textTheme.titleLarge),
          const SizedBox(width: 8),
          Text(
            '$filteredCount',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          // Filter field
          SizedBox(
            width: 200,
            height: 36,
            child: TextField(
              controller: filterController,
              onChanged: onFilterChanged,
              style: textTheme.bodySmall,
              decoration: InputDecoration(
                hintText: 'Filter albums...',
                hintStyle: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Icon(Icons.filter_list,
                    size: 18, color: colorScheme.onSurfaceVariant),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                suffixIcon: filterController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            size: 16, color: colorScheme.onSurfaceVariant),
                        onPressed: () {
                          filterController.clear();
                          onFilterChanged('');
                        },
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Sort dropdown
          PopupMenuButton<_AlbumSortMode>(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: 'Sort',
            onSelected: onSortChanged,
            itemBuilder: (_) => [
              _sortItem(_AlbumSortMode.nameAsc, 'A \u2013 Z'),
              _sortItem(_AlbumSortMode.nameDesc, 'Z \u2013 A'),
              _sortItem(_AlbumSortMode.artistAsc, 'Artist'),
              _sortItem(_AlbumSortMode.yearDesc, 'Year (Newest)'),
              _sortItem(_AlbumSortMode.yearAsc, 'Year (Oldest)'),
              _sortItem(_AlbumSortMode.recentlyAdded, 'Recently Added'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<_AlbumSortMode> _sortItem(
      _AlbumSortMode mode, String label) {
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          if (sortMode == mode)
            const Icon(Icons.check, size: 16)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

// ─── Album Card ────────────────────────────────────────────────────────────

class _AlbumCard extends ConsumerStatefulWidget {
  const _AlbumCard({required this.item});

  final AlbumGridItem item;

  @override
  ConsumerState<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends ConsumerState<_AlbumCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final album = widget.item.album;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onSecondaryTapUp: (details) {
          showAlbumContextMenu(context, ref, details.globalPosition, album);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _hovering
                ? colorScheme.surfaceContainerHigh
                : colorScheme.surfaceContainerLow,
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AlbumDetailPage(album: album),
              ));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Album Art with hover play button ──
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _AlbumGridArt(
                        albumName: album.name,
                        trackPath: widget.item.trackPath,
                      ),
                      // Play button overlay on hover
                      if (_hovering)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: _PlayButton(
                            albumName: album.name,
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Title + Artist ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Text(
                    album.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      height: 1.2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Row(
                    children: [
                      if (album.artist != null)
                        Expanded(
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => navigateToArtistByName(
                                context,
                                ref.read(databaseProvider),
                                album.artist!,
                              ),
                              child: Text(
                                album.artist!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (album.year != null)
                        Text(
                          '${album.year}',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withAlpha(150),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Play Button (on hover) ────────────────────────────────────────────────

class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.albumName});

  final String albumName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.primary,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          final db = ref.read(databaseProvider);
          final tracks = await (db.select(db.tracks)
                ..where((t) => t.album.equals(albumName))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.discNumber),
                  (t) => OrderingTerm.asc(t.trackNumber),
                ]))
              .get();
          if (tracks.isNotEmpty) {
            ref.read(queueProvider.notifier).setQueue(tracks);
          }
        },
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            Icons.play_arrow,
            color: colorScheme.onPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ─── Album Grid Art ────────────────────────────────────────────────────────

class _AlbumGridArt extends ConsumerWidget {
  const _AlbumGridArt({required this.albumName, this.trackPath});

  final String albumName;
  final String? trackPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (trackPath != null) {
      final artAsync = ref.watch(albumArtPathProvider(trackPath!));
      return artAsync.when(
        loading: () => _GenerativePlaceholder(albumName: albumName),
        error: (_, __) => _GenerativePlaceholder(albumName: albumName),
        data: (artPath) {
          if (artPath == null) {
            return _GenerativePlaceholder(albumName: albumName);
          }
          return AlbumArtWidget(
            trackPath: trackPath,
            size: double.infinity,
            borderRadius: 0,
            iconSize: 64,
          );
        },
      );
    }
    return _GenerativePlaceholder(albumName: albumName);
  }
}

// ─── Generative Placeholder ────────────────────────────────────────────────

class _GenerativePlaceholder extends StatelessWidget {
  const _GenerativePlaceholder({required this.albumName});

  final String albumName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Generate a deterministic color from the album name
    final hash = albumName.hashCode;
    final hue = (hash % 360).abs().toDouble();
    final baseColor = HSLColor.fromAHSL(1.0, hue, 0.15, 0.25).toColor();

    return Container(
      color: baseColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(
        albumName,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: textTheme.titleSmall?.copyWith(
          color: Colors.white.withAlpha(140),
          height: 1.3,
        ),
      ),
    );
  }
}
