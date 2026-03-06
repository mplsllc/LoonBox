import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../database/database.dart';
import '../../player/presentation/album_art_widget.dart';
import '../../player/presentation/queue_provider.dart';
import '../widgets/loon_loader.dart';
import '../widgets/track_context_menu.dart';
import 'artist_detail_page.dart';

// ─── Data Model ────────────────────────────────────────────────────────────

/// Album thumbnail data for display in artist rows.
class ArtistAlbumThumb {
  final String albumName;
  final String trackPath;

  const ArtistAlbumThumb({required this.albumName, required this.trackPath});
}

/// Artist with enriched metadata for display in the list.
class ArtistListItem {
  final Artist artist;
  final int albumCount;
  final int trackCount;
  final String? firstAlbumArtPath;
  final List<ArtistAlbumThumb> albumThumbs;
  final String? genre;
  final String? singleTrackTitle;
  final int? yearMin;
  final int? yearMax;

  const ArtistListItem({
    required this.artist,
    required this.albumCount,
    required this.trackCount,
    this.firstAlbumArtPath,
    this.albumThumbs = const [],
    this.genre,
    this.singleTrackTitle,
    this.yearMin,
    this.yearMax,
  });
}

final artistListProvider = FutureProvider<List<ArtistListItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  final artists = await (db.select(db.artists)
        ..orderBy([(a) => OrderingTerm.asc(a.name)]))
      .get();

  final countCol = countAll();
  final items = <ArtistListItem>[];
  for (final artist in artists) {
    final albumCount = await (db.selectOnly(db.albums)
          ..addColumns([countCol])
          ..where(db.albums.artist.equals(artist.name)))
        .map((row) => row.read(countCol) ?? 0)
        .getSingle();

    final trackCount = await (db.selectOnly(db.tracks)
          ..addColumns([countCol])
          ..where(db.tracks.artist.equals(artist.name)))
        .map((row) => row.read(countCol) ?? 0)
        .getSingle();

    // Album art thumbnails (up to 3)
    String? artPath;
    final thumbs = <ArtistAlbumThumb>[];
    final artTracks = await (db.select(db.tracks)
          ..where((t) =>
              t.artist.equals(artist.name) & t.hasAlbumArt.equals(true)))
        .get();
    final seenAlbums = <String>{};
    for (final t in artTracks) {
      if (t.filePath == null) continue;
      if (t.album != null && seenAlbums.add(t.album!)) {
        artPath ??= t.filePath;
        thumbs.add(
            ArtistAlbumThumb(albumName: t.album!, trackPath: t.filePath!));
        if (thumbs.length >= 3) break;
      }
    }
    if (artPath == null && artTracks.isNotEmpty) {
      artPath = artTracks.first.filePath;
    }

    // Most common genre
    String? genre;
    final genreRows = await db.customSelect(
      'SELECT genre, COUNT(*) AS c FROM tracks '
      'WHERE artist = ? AND genre IS NOT NULL '
      'GROUP BY genre ORDER BY c DESC LIMIT 1',
      variables: [Variable.withString(artist.name)],
    ).get();
    if (genreRows.isNotEmpty) {
      genre = genreRows.first.read<String?>('genre');
    }

    // Single track title (when only 1 track)
    String? singleTrackTitle;
    if (trackCount == 1) {
      final singleTrack = await (db.select(db.tracks)
            ..where((t) => t.artist.equals(artist.name))
            ..limit(1))
          .getSingleOrNull();
      singleTrackTitle = singleTrack?.title;
    }

    // Year range from albums
    int? yearMin, yearMax;
    if (albumCount > 0) {
      final yearRows = await db.customSelect(
        'SELECT MIN(year) AS y_min, MAX(year) AS y_max FROM albums '
        'WHERE artist = ? AND year IS NOT NULL',
        variables: [Variable.withString(artist.name)],
      ).get();
      if (yearRows.isNotEmpty) {
        yearMin = yearRows.first.read<int?>('y_min');
        yearMax = yearRows.first.read<int?>('y_max');
      }
    }

    items.add(ArtistListItem(
      artist: artist,
      albumCount: albumCount,
      trackCount: trackCount,
      firstAlbumArtPath: artPath,
      albumThumbs: thumbs,
      genre: genre,
      singleTrackTitle: singleTrackTitle,
      yearMin: yearMin,
      yearMax: yearMax,
    ));
  }

  return items;
});

/// Provider that returns a representative track path for an artist (for avatar art).
final artistArtPathProvider =
    FutureProvider.family<String?, String>((ref, artistName) async {
  final db = ref.watch(databaseProvider);
  final tracks = await (db.select(db.tracks)
        ..where((t) => t.artist.equals(artistName) & t.hasAlbumArt.equals(true))
        ..limit(1))
      .get();
  return tracks.isNotEmpty ? tracks.first.filePath : null;
});

// ─── Sort Mode ─────────────────────────────────────────────────────────────

enum _ArtistSortMode { nameAsc, nameDesc, mostTracks, mostAlbums }

// ─── Sectioned List Entry ──────────────────────────────────────────────────

sealed class _ListEntry {}

class _SectionHeader extends _ListEntry {
  final String letter;
  final int count;
  _SectionHeader(this.letter, this.count);
}

class _ArtistEntry extends _ListEntry {
  final ArtistListItem item;
  _ArtistEntry(this.item);
}

// ─── Constants ─────────────────────────────────────────────────────────────

const _rowHeight = 60.0;
const _sectionHeaderHeight = 32.0;

// ─── Page ──────────────────────────────────────────────────────────────────

class ArtistsPage extends ConsumerStatefulWidget {
  const ArtistsPage({super.key});

  @override
  ConsumerState<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends ConsumerState<ArtistsPage> {
  final _scrollController = ScrollController();
  final _filterController = TextEditingController();
  String _filterText = '';
  _ArtistSortMode _sortMode = _ArtistSortMode.nameAsc;
  String _currentLetter = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  /// Build sectioned + filtered + sorted entries from raw artist list.
  List<_ListEntry> _buildEntries(List<ArtistListItem> artists) {
    // Filter
    var filtered = artists;
    if (_filterText.isNotEmpty) {
      final query = _filterText.toLowerCase();
      filtered = artists
          .where((a) => a.artist.name.toLowerCase().contains(query))
          .toList();
    }

    // Sort
    switch (_sortMode) {
      case _ArtistSortMode.nameAsc:
        filtered.sort(
            (a, b) => a.artist.name.toLowerCase().compareTo(b.artist.name.toLowerCase()));
      case _ArtistSortMode.nameDesc:
        filtered.sort(
            (a, b) => b.artist.name.toLowerCase().compareTo(a.artist.name.toLowerCase()));
      case _ArtistSortMode.mostTracks:
        filtered.sort((a, b) => b.trackCount.compareTo(a.trackCount));
      case _ArtistSortMode.mostAlbums:
        filtered.sort((a, b) => b.albumCount.compareTo(a.albumCount));
    }

    // Section by first letter (only for alphabetical sorts)
    final entries = <_ListEntry>[];
    if (_sortMode == _ArtistSortMode.nameAsc ||
        _sortMode == _ArtistSortMode.nameDesc) {
      String? lastLetter;
      final letterCounts = <String, int>{};
      for (final a in filtered) {
        final letter = _firstLetter(a.artist.name);
        letterCounts[letter] = (letterCounts[letter] ?? 0) + 1;
      }
      for (final a in filtered) {
        final letter = _firstLetter(a.artist.name);
        if (letter != lastLetter) {
          entries.add(_SectionHeader(letter, letterCounts[letter] ?? 0));
          lastLetter = letter;
        }
        entries.add(_ArtistEntry(a));
      }
    } else {
      for (final a in filtered) {
        entries.add(_ArtistEntry(a));
      }
    }

    return entries;
  }

  /// Get available letters and their scroll offsets for the alphabet rail.
  Map<String, double> _buildLetterOffsets(List<_ListEntry> entries) {
    final offsets = <String, double>{};
    double offset = 0;
    for (final entry in entries) {
      if (entry is _SectionHeader) {
        offsets[entry.letter] = offset;
        offset += _sectionHeaderHeight;
      } else {
        offset += _rowHeight;
      }
    }
    return offsets;
  }

  /// Determine which letter we're currently scrolled to.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final entries = _cachedEntries;
    if (entries == null) return;

    final scrollOffset = _scrollController.offset;
    double offset = 0;
    String letter = '';
    for (final entry in entries) {
      if (entry is _SectionHeader) {
        letter = entry.letter;
        offset += _sectionHeaderHeight;
      } else {
        offset += _rowHeight;
      }
      if (offset > scrollOffset + 100) break;
    }
    if (letter != _currentLetter) {
      setState(() => _currentLetter = letter);
    }
  }

  List<_ListEntry>? _cachedEntries;

  String _firstLetter(String name) {
    if (name.isEmpty) return '#';
    final c = name[0].toUpperCase();
    if (RegExp(r'[A-Z]').hasMatch(c)) return c;
    if (RegExp(r'[0-9]').hasMatch(c)) return '#';
    return '#';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final artistsAsync = ref.watch(artistListProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final db = ref.read(databaseProvider);

    return Scaffold(
      body: artistsAsync.when(
        loading: () => const Center(child: LoonLoader()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (artists) {
          if (artists.isEmpty) {
            return const Center(child: Text('No artists yet.'));
          }

          final entries = _buildEntries(artists);
          _cachedEntries = entries;
          final letterOffsets = _buildLetterOffsets(entries);
          final showAlphabetRail =
              _sortMode == _ArtistSortMode.nameAsc ||
              _sortMode == _ArtistSortMode.nameDesc;

          return Column(
            children: [
              // ── Header Bar ──
              _HeaderBar(
                artistCount: artists.length,
                filteredCount: entries
                    .whereType<_ArtistEntry>()
                    .length,
                filterController: _filterController,
                sortMode: _sortMode,
                onFilterChanged: (text) =>
                    setState(() => _filterText = text),
                onSortChanged: (mode) =>
                    setState(() => _sortMode = mode),
                l10n: l10n,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),

              // ── List + Alphabet Rail ──
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        top: 4,
                        bottom: 24,
                        right: showAlphabetRail ? 24 : 0,
                      ),
                      itemCount: entries.length,
                      itemExtent: null,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return switch (entry) {
                          _SectionHeader() => _SectionHeaderWidget(
                              letter: entry.letter,
                              count: entry.count,
                            ),
                          _ArtistEntry() => _ArtistRow(
                              item: entry.item,
                              db: db,
                            ),
                        };
                      },
                    ),
                    if (showAlphabetRail)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: _AlphabetRail(
                          activeLetters: letterOffsets.keys.toSet(),
                          currentLetter: _currentLetter,
                          onJump: (letter) {
                            final offset = letterOffsets[letter];
                            if (offset != null) {
                              _scrollController.animateTo(
                                offset,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        ),
                      ),
                  ],
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
    required this.artistCount,
    required this.filteredCount,
    required this.filterController,
    required this.sortMode,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.l10n,
    required this.colorScheme,
    required this.textTheme,
  });

  final int artistCount;
  final int filteredCount;
  final TextEditingController filterController;
  final _ArtistSortMode sortMode;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<_ArtistSortMode> onSortChanged;
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
          // Title + count
          Text(l10n.artistsTitle, style: textTheme.titleLarge),
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
                hintText: 'Filter artists...',
                hintStyle: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                prefixIcon:
                    Icon(Icons.filter_list, size: 18, color: colorScheme.onSurfaceVariant),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                suffixIcon: filterController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, size: 16, color: colorScheme.onSurfaceVariant),
                        onPressed: () {
                          filterController.clear();
                          onFilterChanged('');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
          PopupMenuButton<_ArtistSortMode>(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: 'Sort',
            onSelected: onSortChanged,
            itemBuilder: (_) => [
              _sortItem(_ArtistSortMode.nameAsc, 'A \u2013 Z'),
              _sortItem(_ArtistSortMode.nameDesc, 'Z \u2013 A'),
              _sortItem(_ArtistSortMode.mostTracks, 'Most Tracks'),
              _sortItem(_ArtistSortMode.mostAlbums, 'Most Albums'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<_ArtistSortMode> _sortItem(
      _ArtistSortMode mode, String label) {
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

// ─── Section Header ────────────────────────────────────────────────────────

class _SectionHeaderWidget extends StatelessWidget {
  const _SectionHeaderWidget({
    required this.letter,
    required this.count,
  });

  final String letter;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: _sectionHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      color: colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Text(
            letter,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\u00b7  $count',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Artist Row ────────────────────────────────────────────────────────────

class _ArtistRow extends ConsumerStatefulWidget {
  const _ArtistRow({required this.item, required this.db});

  final ArtistListItem item;
  final LoonBoxDatabase db;

  @override
  ConsumerState<_ArtistRow> createState() => _ArtistRowState();
}

class _ArtistRowState extends ConsumerState<_ArtistRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final item = widget.item;
    final isWeak =
        item.trackCount == 1 && item.firstAlbumArtPath == null;

    return SizedBox(
      height: _rowHeight,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ArtistDetailPage(artist: item.artist),
        )),
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Avatar with hover play overlay
                _AvatarWithPlay(
                  artPath: item.firstAlbumArtPath,
                  name: item.artist.name,
                  hovering: _hovering,
                  onPlay: () => _playAll(),
                ),
                const SizedBox(width: 12),
                // Name + stats (expanded)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isWeak
                              ? colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _smartSubtitle(item) +
                            (item.genre != null
                                ? ' \u00b7 ${item.genre}'
                                : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Thumbnails zone (fixed width for up to 3 × 44px + gaps)
                SizedBox(
                  width: 144,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final thumb in item.albumThumbs)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => navigateToAlbumByName(
                                  context, widget.db, thumb.albumName),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: AlbumArtWidget(
                                  trackPath: thumb.trackPath,
                                  size: 44,
                                  borderRadius: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Chevron
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withAlpha(120),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _playAll() async {
    final tracks =
        await ref.read(artistTracksProvider(widget.item.artist.id).future);
    if (tracks.isNotEmpty && mounted) {
      ref.read(queueProvider.notifier).setQueue(tracks);
    }
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        const PopupMenuItem(
            value: 'go_artist', child: Text('Go to Artist')),
      ],
    ).then((value) {
      if (value == 'go_artist' && context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ArtistDetailPage(artist: widget.item.artist),
        ));
      }
    });
  }

  String _smartSubtitle(ArtistListItem item) {
    // Single track: show the track title
    if (item.trackCount == 1 && item.singleTrackTitle != null) {
      return item.singleTrackTitle!;
    }

    final parts = <String>[];

    // Year range for multi-album artists
    if (item.yearMin != null && item.albumCount > 1) {
      if (item.yearMax != null && item.yearMax != item.yearMin) {
        parts.add('${item.yearMin}\u2013${item.yearMax}');
      } else {
        parts.add('${item.yearMin}');
      }
    }

    if (item.albumCount > 0) {
      parts.add(
          '${item.albumCount} ${item.albumCount == 1 ? "album" : "albums"}');
    }
    if (item.trackCount > 0) {
      parts.add(
          '${item.trackCount} ${item.trackCount == 1 ? "track" : "tracks"}');
    }
    return parts.join(' \u00b7 ');
  }
}

// ─── Avatar with Hover Play Overlay ────────────────────────────────────────

class _AvatarWithPlay extends StatelessWidget {
  const _AvatarWithPlay({
    required this.artPath,
    required this.name,
    required this.hovering,
    required this.onPlay,
  });

  final String? artPath;
  final String name;
  final bool hovering;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const size = 44.0;

    Widget avatar;
    if (artPath != null) {
      avatar = ClipOval(
        child: AlbumArtWidget(
          trackPath: artPath,
          size: size,
          borderRadius: 0,
        ),
      );
    } else {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          avatar,
          if (hovering)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPlay,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Alphabet Rail ─────────────────────────────────────────────────────────

const _allRailLetters = ['#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
    'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W',
    'X', 'Y', 'Z'];

class _AlphabetRail extends StatefulWidget {
  const _AlphabetRail({
    required this.activeLetters,
    required this.currentLetter,
    required this.onJump,
  });

  /// Letters that have at least one artist.
  final Set<String> activeLetters;
  final String currentLetter;
  final ValueChanged<String> onJump;

  @override
  State<_AlphabetRail> createState() => _AlphabetRailState();
}

class _AlphabetRailState extends State<_AlphabetRail> {
  String? _hoveredLetter;
  bool _dragging = false;

  /// Resolve letter from a vertical position within the column.
  String? _letterFromPosition(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPosition);
    // Account for vertical centering padding — letters start at _topPadding
    final letterHeight = _letterItemHeight;
    // The column is centered; compute start from the box height.
    final totalLettersHeight = _allRailLetters.length * letterHeight +
        _hashSeparatorHeight; // extra gap after #
    final startY = (box.size.height - totalLettersHeight) / 2;
    var y = local.dy - startY;
    if (y < 0) return _allRailLetters.first;
    // First item is '#', then a small gap, then A-Z
    if (y < letterHeight) return '#';
    y -= letterHeight + _hashSeparatorHeight;
    if (y < 0) return '#';
    final index = y ~/ letterHeight;
    if (index < 0) return 'A';
    if (index >= 26) return 'Z';
    return _allRailLetters[index + 1]; // +1 to skip '#'
  }

  void _handleDragUpdate(Offset globalPosition) {
    final letter = _letterFromPosition(globalPosition);
    if (letter != null && letter != _hoveredLetter) {
      setState(() => _hoveredLetter = letter);
      if (widget.activeLetters.contains(letter)) {
        widget.onJump(letter);
      }
    }
  }

  static const _letterItemHeight = 17.0;
  static const _hashSeparatorHeight = 4.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedColor = colorScheme.onSurfaceVariant.withAlpha(100);
    final emptyColor = colorScheme.onSurfaceVariant.withAlpha(40);

    return Center(
      child: GestureDetector(
        onVerticalDragStart: (details) {
          setState(() => _dragging = true);
          _handleDragUpdate(details.globalPosition);
        },
        onVerticalDragUpdate: (details) {
          _handleDragUpdate(details.globalPosition);
        },
        onVerticalDragEnd: (_) {
          setState(() {
            _dragging = false;
            _hoveredLetter = null;
          });
        },
        onVerticalDragCancel: () {
          setState(() {
            _dragging = false;
            _hoveredLetter = null;
          });
        },
        child: MouseRegion(
          onExit: (_) => setState(() => _hoveredLetter = null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // '#' entry
                    _buildLetterItem('#', colorScheme, mutedColor, emptyColor),
                    // Small gap between # and A
                    const SizedBox(height: _hashSeparatorHeight),
                    // A-Z entries
                    for (final letter in _allRailLetters.skip(1))
                      _buildLetterItem(letter, colorScheme, mutedColor, emptyColor),
                  ],
                ),
                // Floating preview label
                if ((_hoveredLetter != null || _dragging) && _hoveredLetter != null)
                  _buildFloatingLabel(colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLetterItem(
    String letter,
    ColorScheme colorScheme,
    Color mutedColor,
    Color emptyColor,
  ) {
    final isActive = letter == widget.currentLetter;
    final hasArtists = widget.activeLetters.contains(letter);
    final isHovered = letter == _hoveredLetter && hasArtists;

    Color color;
    if (isActive) {
      color = colorScheme.primary;
    } else if (!hasArtists) {
      color = emptyColor;
    } else if (isHovered) {
      color = colorScheme.onSurface;
    } else {
      color = mutedColor;
    }

    return MouseRegion(
      onEnter: hasArtists ? (_) => setState(() => _hoveredLetter = letter) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: hasArtists ? () => widget.onJump(letter) : null,
        child: SizedBox(
          width: 20,
          height: _letterItemHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Hover highlight circle
              if (isHovered)
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                letter,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: color,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingLabel(ColorScheme colorScheme) {
    // Position the floating label to the left of the rail, vertically aligned
    // with the hovered letter.
    final letter = _hoveredLetter!;
    final letterIndex = _allRailLetters.indexOf(letter);
    if (letterIndex < 0) return const SizedBox.shrink();

    double topOffset;
    if (letterIndex == 0) {
      // '#'
      topOffset = 0;
    } else {
      topOffset = _letterItemHeight + _hashSeparatorHeight +
          (letterIndex - 1) * _letterItemHeight;
    }
    // Center the label on the letter
    topOffset += (_letterItemHeight - 36) / 2;

    return Positioned(
      right: 28,
      top: topOffset,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 6,
              offset: const Offset(-2, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
