import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../widgets/loon_loader.dart';
import '../../../database/database.dart';
import '../../player/presentation/queue_provider.dart';
import 'album_detail_page.dart';
import 'artist_detail_page.dart';

/// Search results grouped by type.
class SearchResults {
  const SearchResults({
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
  });

  final List<Track> tracks;
  final List<Album> albums;
  final List<Artist> artists;

  bool get isEmpty => tracks.isEmpty && albums.isEmpty && artists.isEmpty;
  int get totalCount => tracks.length + albums.length + artists.length;
}

/// Provider that runs a search query against the database.
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const SearchResults();

  final db = ref.watch(databaseProvider);
  final pattern = '%$query%';

  final tracks = await (db.select(db.tracks)
        ..where((t) =>
            t.title.like(pattern) |
            t.artist.like(pattern) |
            t.album.like(pattern))
        ..orderBy([(t) => OrderingTerm.asc(t.title)])
        ..limit(50))
      .get();

  final albums = await (db.select(db.albums)
        ..where((a) => a.name.like(pattern))
        ..orderBy([(a) => OrderingTerm.asc(a.name)])
        ..limit(20))
      .get();

  final artists = await (db.select(db.artists)
        ..where((a) => a.name.like(pattern))
        ..orderBy([(a) => OrderingTerm.asc(a.name)])
        ..limit(20))
      .get();

  return SearchResults(tracks: tracks, albums: albums, artists: artists);
});

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final results = ref.watch(searchResultsProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            ref.read(searchQueryProvider.notifier).state = value;
          },
        ),
      ),
      body: results.when(
        loading: () => const Center(child: LoonLoader()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (ref.watch(searchQueryProvider).isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    l10n.searchHint,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          if (data.isEmpty) {
            return Center(
              child: Text(
                'No results found',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          return ListView(
            children: [
              // Artists section
              if (data.artists.isNotEmpty) ...[
                _SectionHeader(
                  title: l10n.artistsTitle,
                  count: data.artists.length,
                ),
                ...data.artists.map((artist) => ListTile(
                      leading: CircleAvatar(
                        child: Text(artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ArtistDetailPage(artist: artist)),
                      ),
                    )),
              ],

              // Albums section
              if (data.albums.isNotEmpty) ...[
                _SectionHeader(
                  title: l10n.albumsTitle,
                  count: data.albums.length,
                ),
                ...data.albums.map((album) => ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.album, color: colorScheme.onSurfaceVariant),
                      ),
                      title: Text(
                        album.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: album.artist != null
                          ? Text(
                              album.artist!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AlbumDetailPage(album: album)),
                      ),
                    )),
              ],

              // Tracks section
              if (data.tracks.isNotEmpty) ...[
                _SectionHeader(
                  title: l10n.libraryTitle,
                  count: data.tracks.length,
                ),
                ...data.tracks.asMap().entries.map((entry) {
                  final track = entry.value;
                  return ListTile(
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
                      ref.read(queueProvider.notifier).setQueue(
                            data.tracks,
                            startIndex: entry.key,
                          );
                    },
                  );
                }),
              ],
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
