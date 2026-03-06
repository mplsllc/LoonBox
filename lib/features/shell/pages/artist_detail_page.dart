import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../browser/browser_provider.dart';
import '../../../database/database.dart';
import '../widgets/loon_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/musicbrainz_service.dart';
import '../../player/presentation/album_art_widget.dart';
import '../../player/presentation/queue_provider.dart';
import '../widgets/track_context_menu.dart';
import 'album_detail_page.dart';
import 'albums_page.dart';
import 'artists_page.dart';

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

/// Fetches artist bio from MusicBrainz + Wikipedia.
/// Uses the MBID from tagged tracks, or searches by artist name.
final artistBioProvider =
    FutureProvider.family<ArtistBioData?, String>((ref, artistName) async {
  final db = ref.watch(databaseProvider);
  final mb = ref.watch(musicBrainzServiceProvider);

  // Try to find an MBID from tagged tracks
  final tracks = await (db.select(db.tracks)
        ..where((t) => t.artist.equals(artistName) &
            t.musicbrainzArtistId.isNotNull())
        ..limit(1))
      .get();

  MusicBrainzArtist? mbArtist;

  if (tracks.isNotEmpty && tracks.first.musicbrainzArtistId != null) {
    try {
      mbArtist = await mb.getArtist(tracks.first.musicbrainzArtistId!);
    } catch (_) {}
  }

  // Fallback: search by name
  if (mbArtist == null) {
    try {
      mbArtist = await mb.searchArtist(artistName);
    } catch (_) {}
  }

  if (mbArtist == null) return null;

  // Fetch bio from Wikipedia
  ArtistBio? bio;
  if (mbArtist.wikipediaUrl != null) {
    bio = await mb.getWikipediaBio(mbArtist.wikipediaUrl!);
  }

  // Get artist image: prefer Wikipedia thumbnail, then Wikidata, then MB image relation
  String? imageUrl = bio?.imageUrl;
  if (imageUrl == null && mbArtist.wikidataId != null) {
    imageUrl = await mb.getWikidataImage(mbArtist.wikidataId!);
  }
  imageUrl ??= mbArtist.imageUrl;

  return ArtistBioData(
    artist: mbArtist,
    bio: bio,
    imageUrl: imageUrl,
  );
});

class ArtistBioData {
  final MusicBrainzArtist artist;
  final ArtistBio? bio;
  final String? imageUrl;

  const ArtistBioData({
    required this.artist,
    this.bio,
    this.imageUrl,
  });
}

class ArtistDetailPage extends ConsumerWidget {
  const ArtistDetailPage({super.key, required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final albumsAsync = ref.watch(artistAlbumsProvider(artist.id));
    final tracksAsync = ref.watch(artistTracksProvider(artist.id));
    final bioAsync = ref.watch(artistBioProvider(artist.name));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: albumsAsync.when(
        loading: () => const Center(child: LoonLoader()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (albums) {
          final allTracks = tracksAsync.valueOrNull ?? [];
          final bioData = bioAsync.valueOrNull;

          return CustomScrollView(
            slivers: [
              // Hero header with large image
              _ArtistHeroHeader(
                artist: artist,
                bioData: bioData,
                bioLoading: bioAsync.isLoading,
                albumCount: albums.length,
                trackCount: allTracks.length,
                onPlay: allTracks.isNotEmpty
                    ? () => ref.read(queueProvider.notifier).setQueue(allTracks)
                    : null,
              ),

              // Genre tags
              if (bioData != null && bioData.artist.genres.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: bioData.artist.genres.take(8).map((genre) {
                        return Chip(
                          label: Text(genre),
                          labelStyle: textTheme.labelSmall,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: colorScheme.outlineVariant),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              // Bio section
              if (bioData?.bio != null)
                SliverToBoxAdapter(
                  child: _ArtistBioSection(
                    bio: bioData!.bio!,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                ),

              // Bio loading indicator
              if (bioAsync.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(),
                    ),
                  ),
                ),

              // Members section (for bands)
              if (bioData != null && bioData.artist.members.isNotEmpty)
                SliverToBoxAdapter(
                  child: _MembersSection(
                    members: bioData.artist.members,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
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
                        return GestureDetector(
                          onSecondaryTapUp: (details) {
                            showAlbumContextMenu(context, ref, details.globalPosition, album, hideGoToArtist: true);
                          },
                          child: Card(
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
                                    child: _AlbumGridArt(albumName: album.name),
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
                          showTrackContextMenu(context, ref, details.globalPosition, track, hideGoToArtist: true);
                        },
                        child: ListTile(
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: track.album != null
                              ? MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => navigateToAlbumByName(
                                      context,
                                      ref.read(databaseProvider),
                                      track.album!,
                                    ),
                                    child: Text(
                                      track.album!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall,
                                    ),
                                  ),
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

              // External links
              if (bioData != null && bioData.artist.externalLinks.isNotEmpty)
                SliverToBoxAdapter(
                  child: _ExternalLinksSection(
                    links: bioData.artist.externalLinks,
                    wikipediaUrl: bioData.bio?.pageUrl,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                ),

              // Bottom padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
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

// ─── Hero Header ───────────────────────────────────────────────────────────

class _ArtistHeroHeader extends StatelessWidget {
  const _ArtistHeroHeader({
    required this.artist,
    required this.bioData,
    required this.bioLoading,
    required this.albumCount,
    required this.trackCount,
    required this.onPlay,
  });

  final Artist artist;
  final ArtistBioData? bioData;
  final bool bioLoading;
  final int albumCount;
  final int trackCount;
  final VoidCallback? onPlay;

  String _displayArtistType(String type) {
    return switch (type) {
      'Person' => 'Solo Artist',
      'Group' => 'Band',
      'Orchestra' => 'Orchestra',
      'Choir' => 'Choir',
      'Character' => 'Character',
      'Other' => 'Artist',
      _ => type,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SliverToBoxAdapter(
      child: Stack(
        children: [
          // Background gradient with image
          Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.6),
                  colorScheme.surface,
                ],
              ),
            ),
          ),
          // Content overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Artist image — larger
                      _ArtistImage(
                        imageUrl: bioData?.imageUrl,
                        name: artist.name,
                        radius: 64,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Artist type badge
                            if (bioData?.artist.type != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _displayArtistType(bioData!.artist.type!),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            Text(
                              artist.name,
                              style: textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Metadata row
                            Text(
                              [
                                if (bioData?.artist.country != null)
                                  bioData!.artist.country!,
                                if (bioData?.artist.beginDate != null)
                                  _formatLifespan(
                                    bioData!.artist.beginDate!,
                                    bioData!.artist.endDate,
                                  ),
                                '$albumCount albums',
                                '$trackCount tracks',
                              ].join(' · '),
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (bioData?.artist.disambiguation != null &&
                                bioData!.artist.disambiguation!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  bioData!.artist.disambiguation!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            // Action buttons
                            Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: onPlay,
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Play All'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: onPlay != null
                                      ? () {
                                          // Shuffle play
                                          // The queue provider handles shuffle mode
                                          onPlay?.call();
                                        }
                                      : null,
                                  icon: const Icon(Icons.shuffle, size: 18),
                                  label: const Text('Shuffle'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLifespan(String begin, String? end) {
    final beginYear = begin.length >= 4 ? begin.substring(0, 4) : begin;
    if (end != null) {
      final endYear = end.length >= 4 ? end.substring(0, 4) : end;
      return '$beginYear–$endYear';
    }
    return '$beginYear–present';
  }
}

// ─── Bio Section ───────────────────────────────────────────────────────────

class _ArtistBioSection extends ConsumerStatefulWidget {
  const _ArtistBioSection({
    required this.bio,
    required this.colorScheme,
    required this.textTheme,
  });

  final ArtistBio bio;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  ConsumerState<_ArtistBioSection> createState() => _ArtistBioSectionState();
}

class _ArtistBioSectionState extends ConsumerState<_ArtistBioSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final displayText = _expanded
        ? (widget.bio.fullExtract ?? widget.bio.extract)
        : widget.bio.extract;
    final hasMore = widget.bio.fullExtract != null &&
        widget.bio.fullExtract!.length > widget.bio.extract.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: widget.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              widget.bio.extract,
              style: widget.textTheme.bodyMedium?.copyWith(
                color: widget.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            secondChild: Text(
              displayText,
              style: widget.textTheme.bodyMedium?.copyWith(
                color: widget.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (hasMore)
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Show less' : 'Read more'),
                ),
              if (widget.bio.pageUrl != null)
                TextButton(
                  onPressed: () {
                    ref.read(browserTabsProvider.notifier)
                        .openLinkedContent(widget.bio.pageUrl!);
                  },
                  child: Text(
                    'Wikipedia',
                    style: widget.textTheme.bodySmall?.copyWith(
                      color: widget.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Members Section ───────────────────────────────────────────────────────

class _MembersSection extends StatelessWidget {
  const _MembersSection({
    required this.members,
    required this.colorScheme,
    required this.textTheme,
  });

  final List<ArtistMember> members;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final currentMembers = members.where((m) => m.current).toList();
    final pastMembers = members.where((m) => !m.current).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Members', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          if (currentMembers.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: currentMembers.map((m) => Chip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text(m.name),
                labelStyle: textTheme.bodySmall,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          if (pastMembers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Former members',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: pastMembers.map((m) => Chip(
                avatar: Icon(Icons.person_outline, size: 16,
                    color: colorScheme.onSurfaceVariant),
                label: Text(m.name),
                labelStyle: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── External Links Section ────────────────────────────────────────────────

class _ExternalLinksSection extends ConsumerWidget {
  const _ExternalLinksSection({
    required this.links,
    required this.wikipediaUrl,
    required this.colorScheme,
    required this.textTheme,
  });

  final Map<String, String> links;
  final String? wikipediaUrl;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  IconData _iconForType(String type) {
    return switch (type) {
      'official homepage' => Icons.language,
      'bandcamp' => Icons.album,
      'soundcloud' => Icons.cloud,
      'youtube' => Icons.play_circle,
      'social network' => Icons.people,
      'streaming' => Icons.headphones,
      'discogs' => Icons.library_music,
      'allmusic' => Icons.music_note,
      'last.fm' => Icons.bar_chart,
      'setlist.fm' => Icons.list_alt,
      'IMDb' => Icons.movie,
      _ => Icons.link,
    };
  }

  String _labelForType(String type) {
    return switch (type) {
      'official homepage' => 'Official Website',
      'social network' => 'Social Media',
      'streaming' => 'Streaming',
      _ => type[0].toUpperCase() + type.substring(1),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Links', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: links.entries.map((entry) {
              return ActionChip(
                avatar: Icon(_iconForType(entry.key), size: 16),
                label: Text(_labelForType(entry.key)),
                labelStyle: textTheme.labelSmall,
                onPressed: () {
                  ref.read(browserTabsProvider.notifier)
                      .openLinkedContent(entry.value);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Artist Image Widget ───────────────────────────────────────────────────

class _ArtistImage extends ConsumerWidget {
  const _ArtistImage({
    required this.imageUrl,
    required this.name,
    this.radius = 48,
  });

  final String? imageUrl;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatar(textTheme, colorScheme),
        ),
      );
    }

    // Fall back to album art from this artist's tracks
    final artPathAsync = ref.watch(artistArtPathProvider(name));
    return artPathAsync.when(
      data: (path) {
        if (path != null) {
          return ClipOval(
            child: AlbumArtWidget(
              trackPath: path,
              size: radius * 2,
              borderRadius: 0,
            ),
          );
        }
        return _fallbackAvatar(textTheme, colorScheme);
      },
      loading: () => _fallbackAvatar(textTheme, colorScheme),
      error: (_, __) => _fallbackAvatar(textTheme, colorScheme),
    );
  }

  Widget _fallbackAvatar(TextTheme textTheme, ColorScheme colorScheme) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: (radius >= 48 ? textTheme.headlineLarge : textTheme.headlineMedium)
            ?.copyWith(color: colorScheme.onPrimaryContainer),
      ),
    );
  }
}

// ─── Album Grid Art ────────────────────────────────────────────────────────

class _AlbumGridArt extends ConsumerWidget {
  const _AlbumGridArt({required this.albumName});

  final String albumName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackPathAsync = ref.watch(albumTrackPathProvider(albumName));
    final colorScheme = Theme.of(context).colorScheme;

    return trackPathAsync.when(
      data: (path) {
        if (path == null) {
          return Container(
            color: colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.album, size: 48),
          );
        }
        return AlbumArtWidget(
          trackPath: path,
          size: double.infinity,
          borderRadius: 0,
          iconSize: 48,
        );
      },
      loading: () => Container(color: colorScheme.surfaceContainerHighest),
      error: (_, __) => Container(
        color: colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.album, size: 48),
      ),
    );
  }
}
