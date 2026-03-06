import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import 'loon_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/album_art_service.dart';
import '../../../services/metadata_resolver.dart';
import '../../../services/musicbrainz_service.dart' show MusicBrainzRecording, MusicBrainzRelease;
import '../../player/presentation/album_art_widget.dart';
import '../../../src/rust/api.dart' as rust;
import '../../../utils/string_utils.dart';
import '../pages/albums_page.dart';
import '../pages/artists_page.dart';
import '../pages/songs_page.dart';
import '../pages/album_detail_page.dart';

/// Show the MusicBrainz album lookup dialog.
Future<void> showAlbumLookupDialog(
  BuildContext context,
  WidgetRef ref,
  Album album,
  List<Track> tracks,
) async {
  await showDialog(
    context: context,
    builder: (ctx) => _AlbumLookupDialog(album: album, tracks: tracks),
  );
}

/// A pairing of a local track to a MusicBrainz recording.
class _TrackMatch {
  final Track localTrack;
  final MusicBrainzRecording? mbRecording;
  final bool alreadyTagged;
  bool checked;

  _TrackMatch({
    required this.localTrack,
    this.mbRecording,
    this.alreadyTagged = false,
    this.checked = false,
  });
}

class _AlbumLookupDialog extends ConsumerStatefulWidget {
  const _AlbumLookupDialog({required this.album, required this.tracks});

  final Album album;
  final List<Track> tracks;

  @override
  ConsumerState<_AlbumLookupDialog> createState() => _AlbumLookupDialogState();
}

enum _DialogPhase { searchingReleases, selectingRelease, matchingTracks, reviewing, applying }

class _AlbumLookupDialogState extends ConsumerState<_AlbumLookupDialog> {
  _DialogPhase _phase = _DialogPhase.searchingReleases;
  List<MusicBrainzRelease>? _releases;
  MusicBrainzRelease? _selectedRelease;
  List<_TrackMatch> _matches = [];
  String? _error;
  bool _applying = false;
  late final TextEditingController _albumController;
  late final TextEditingController _artistController;

  @override
  void initState() {
    super.initState();
    _albumController = TextEditingController(text: widget.album.name);
    _artistController = TextEditingController(text: widget.album.artist ?? '');
    _searchReleases();
  }

  @override
  void dispose() {
    _albumController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  Future<void> _searchReleases() async {
    try {
      final resolver = ref.read(metadataResolverProvider);
      final results = await resolver.searchReleases(
        album: widget.album.name,
        artist: widget.album.artist,
      );
      if (mounted) {
        setState(() {
          _releases = results;
          _phase = _DialogPhase.selectingRelease;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _phase = _DialogPhase.selectingRelease;
        });
      }
    }
  }

  Future<void> _manualSearch() async {
    final album = _albumController.text.trim();
    final artist = _artistController.text.trim();
    if (album.isEmpty && artist.isEmpty) return;

    setState(() {
      _phase = _DialogPhase.searchingReleases;
      _error = null;
      _releases = null;
    });

    try {
      final resolver = ref.read(metadataResolverProvider);
      final results = await resolver.searchReleases(
        album: album.isNotEmpty ? album : artist,
        artist: album.isNotEmpty && artist.isNotEmpty ? artist : null,
      );
      if (mounted) {
        setState(() {
          _releases = results;
          _phase = _DialogPhase.selectingRelease;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _phase = _DialogPhase.selectingRelease;
        });
      }
    }
  }

  Future<void> _selectRelease(MusicBrainzRelease release) async {
    setState(() => _phase = _DialogPhase.matchingTracks);

    try {
      final resolver = ref.read(metadataResolverProvider);
      final fullRelease = await resolver.getRelease(release.id);
      if (mounted) {
        setState(() {
          _selectedRelease = fullRelease;
          _matches = _matchTracks(widget.tracks, fullRelease);
          _phase = _DialogPhase.reviewing;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _phase = _DialogPhase.reviewing;
        });
      }
    }
  }

  List<_TrackMatch> _matchTracks(List<Track> locals, MusicBrainzRelease release) {
    final mbTracks = List<MusicBrainzRecording>.from(release.tracks);
    final matched = <MusicBrainzRecording>{};
    final results = <_TrackMatch>[];

    for (final local in locals) {
      final alreadyTagged = local.musicbrainzTrackId != null;

      // Try position match first
      MusicBrainzRecording? best;
      if (local.trackNumber != null) {
        final positional = mbTracks.where(
          (mb) => mb.trackNumber == local.trackNumber && !matched.contains(mb),
        );
        if (positional.isNotEmpty) {
          best = positional.first;
        }
      }

      // Fallback: normalized title comparison
      if (best == null) {
        final localNorm = normalizeTitle(local.title);
        for (final mb in mbTracks) {
          if (matched.contains(mb)) continue;
          if (normalizeTitle(mb.title) == localNorm) {
            best = mb;
            break;
          }
        }
      }

      if (best != null) matched.add(best);

      results.add(_TrackMatch(
        localTrack: local,
        mbRecording: best,
        alreadyTagged: alreadyTagged,
        // Default checked: matched and not already tagged
        checked: best != null && !alreadyTagged,
      ));
    }

    return results;
  }

  Future<void> _apply() async {
    if (_applying) return;
    setState(() {
      _applying = true;
      _phase = _DialogPhase.applying;
    });

    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    messenger.showSnackBar(SnackBar(content: Text(l10n.mbApplying)));

    try {
      final checkedMatches = _matches.where((m) => m.checked && m.mbRecording != null).toList();

      final resolver = ref.read(metadataResolverProvider);

      await db.transaction(() async {
        for (final match in checkedMatches) {
          final track = match.localTrack;
          final mb = match.mbRecording!;

          // Write only MB ID flag to file (lightweight)
          if (track.filePath != null) {
            await rust.metadataWriteMbId(
              path: track.filePath!,
              trackId: mb.id,
            );
          }

          // Store full metadata in DB as overlay
          await (db.update(db.tracks)..where((t) => t.id.equals(track.id))).write(
            TracksCompanion(
              title: Value(mb.title),
              artist: Value(mb.artist),
              album: Value(mb.album),
              trackNumber: Value(mb.trackNumber),
              year: Value(mb.year),
              musicbrainzTrackId: Value(mb.id),
              musicbrainzArtistId: Value(mb.artistId),
              musicbrainzReleaseId: Value(mb.releaseId),
            ),
          );
        }
      });

      // Fetch album art via resolver (tiered: local → community → CAA)
      if (_selectedRelease != null) {
        final artBytes = await resolver.resolveArt(_selectedRelease!.id);
        if (artBytes != null && artBytes.isNotEmpty) {
          final artService = ref.read(albumArtServiceProvider);
          String? firstArtPath;
          for (final track in widget.tracks) {
            if (track.filePath != null) {
              final artPath = await artService.saveCoverArt(track.filePath!, artBytes);
              firstArtPath ??= artPath;
              await (db.update(db.tracks)..where((t) => t.id.equals(track.id)))
                  .write(const TracksCompanion(hasAlbumArt: Value(true)));
            }
          }
          if (firstArtPath != null) {
            await resolver.updateCoverArtPath(_selectedRelease!.id, firstArtPath);
          }
        }

        // Cache the album→release mapping for future enrichment
        await resolver.cacheMapping(
          albumName: widget.album.name,
          artistName: widget.album.artist,
          mbReleaseId: _selectedRelease!.id,
          confidence: 100, // manual selection = full confidence
        );
      }

      // Refresh UI — invalidate art cache for all affected tracks
      for (final track in widget.tracks) {
        if (track.filePath != null) {
          ref.invalidate(albumArtPathProvider(track.filePath!));
        }
      }
      ref.invalidate(albumTrackPathProvider(widget.album.name));
      ref.invalidate(trackListProvider);
      ref.invalidate(albumGridProvider);
      ref.invalidate(artistListProvider);
      ref.invalidate(albumTracksProvider(widget.album.id));

      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text(l10n.mbApplied)));
      navigator.pop();
    } catch (e) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.mbApplyError(e.toString()))),
      );
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(l10n.mbAlbumLookupTitle),
      content: SizedBox(
        width: 700,
        height: 500,
        child: switch (_phase) {
          _DialogPhase.searchingReleases || _DialogPhase.matchingTracks =>
            const Center(child: LoonLoader()),
          _DialogPhase.selectingRelease => _buildReleaseList(l10n, colorScheme, textTheme),
          _DialogPhase.reviewing => _buildReviewTable(l10n, colorScheme, textTheme),
          _DialogPhase.applying => const Center(child: LoonLoader()),
        },
      ),
      actions: [
        if (_phase == _DialogPhase.reviewing && _selectedRelease != null)
          TextButton(
            onPressed: () => setState(() {
              _phase = _DialogPhase.selectingRelease;
              _selectedRelease = null;
              _matches = [];
            }),
            child: const Text('Back'),
          ),
        TextButton(
          onPressed: _applying ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        if (_phase == _DialogPhase.reviewing)
          FilledButton(
            onPressed: _matches.any((m) => m.checked) && !_applying ? () => _apply() : null,
            child: Text(l10n.mbApply),
          ),
      ],
    );
  }

  Widget _buildReleaseList(AppLocalizations l10n, ColorScheme colorScheme, TextTheme textTheme) {
    final hasResults = _releases != null && _releases!.isNotEmpty;

    return Column(
      children: [
        // Search fields — always visible
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _albumController,
                decoration: InputDecoration(
                  labelText: l10n.navAlbums,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _manualSearch(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _artistController,
                decoration: InputDecoration(
                  labelText: l10n.navArtists,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _manualSearch(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _manualSearch,
              icon: const Icon(Icons.search, size: 18),
              label: Text(l10n.navSearch),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Expanded(child: Center(child: Text(_error!)))
        else if (!hasResults)
          Expanded(child: Center(child: Text(l10n.mbNoResults)))
        else
          Expanded(
            child: ListView.builder(
              itemCount: _releases!.length,
              itemBuilder: (context, index) {
                final r = _releases![index];
                return Card(
                  child: ListTile(
                    onTap: () => _selectRelease(r),
                    title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [
                        if (r.artist != null) r.artist!,
                        if (r.year != null) '${r.year}',
                        '${r.trackCount} tracks',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: r.score >= 90
                            ? Colors.green.withValues(alpha: 0.2)
                            : r.score >= 70
                                ? Colors.orange.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(l10n.mbScore(r.score), style: textTheme.labelSmall),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildReviewTable(AppLocalizations l10n, ColorScheme colorScheme, TextTheme textTheme) {
    if (_error != null) return Center(child: Text(_error!));

    final matchedCount = _matches.where((m) => m.mbRecording != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: release info + match summary
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedRelease?.title ?? '',
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        if (_selectedRelease?.artist != null) _selectedRelease!.artist!,
                        if (_selectedRelease?.year != null) '${_selectedRelease!.year}',
                      ].join(' · '),
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: matchedCount == _matches.length
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.mbTrackMatched(matchedCount, _matches.length),
                  style: textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Track matching table
        Expanded(
          child: ListView.builder(
            itemCount: _matches.length,
            itemBuilder: (context, index) {
              final match = _matches[index];
              final hasMatch = match.mbRecording != null;

              return ListTile(
                dense: true,
                leading: SizedBox(
                  width: 32,
                  child: Text(
                    match.localTrack.trackNumber?.toString() ?? '–',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        match.localTrack.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: hasMatch ? null : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (hasMatch) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 16, color: colorScheme.onSurfaceVariant),
                      ),
                      Expanded(
                        child: Text(
                          match.mbRecording!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          '—',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: match.alreadyTagged
                    ? Text(
                        l10n.mbAlreadyTagged,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : null,
                trailing: hasMatch
                    ? Checkbox(
                        value: match.checked,
                        onChanged: (v) => setState(() => match.checked = v ?? false),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
