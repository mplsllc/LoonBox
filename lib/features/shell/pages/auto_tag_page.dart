import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../widgets/loon_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/album_art_service.dart';
import '../../../services/metadata_resolver.dart';
import '../../../services/musicbrainz_service.dart';
import '../../../src/rust/api.dart' as rust;
import '../widgets/album_lookup_dialog.dart';
import '../../../utils/string_utils.dart';
import 'albums_page.dart';
import 'artists_page.dart';
import 'songs_page.dart';

/// A matched pairing of local track to MB recording.
class TrackPairing {
  final Track localTrack;
  final MusicBrainzRecording? mbRecording;
  final bool alreadyTagged;
  bool checked;

  TrackPairing({
    required this.localTrack,
    this.mbRecording,
    this.alreadyTagged = false,
    this.checked = false,
  });
}

/// Result of matching an album to a MusicBrainz release.
class AlbumMatch {
  final Album album;
  final List<Track> tracks;
  final MusicBrainzRelease? bestRelease;
  final List<TrackPairing> pairings;
  final int confidence;
  bool accepted;
  bool skipped;

  AlbumMatch({
    required this.album,
    required this.tracks,
    this.bestRelease,
    this.pairings = const [],
    this.confidence = 0,
    this.accepted = false,
    this.skipped = false,
  });
}

/// Auto-tag state machine.
enum AutoTagPhase { idle, scanning, reviewing, applying, complete }

class AutoTagState {
  final AutoTagPhase phase;
  final int current;
  final int total;
  final List<AlbumMatch> matches;
  final String? error;
  final bool artOnly;
  final String? currentAlbumName;
  final int skippedCount;
  final DateTime? startedAt;

  const AutoTagState({
    this.phase = AutoTagPhase.idle,
    this.current = 0,
    this.total = 0,
    this.matches = const [],
    this.error,
    this.artOnly = false,
    this.currentAlbumName,
    this.skippedCount = 0,
    this.startedAt,
  });

  AutoTagState copyWith({
    AutoTagPhase? phase,
    int? current,
    int? total,
    List<AlbumMatch>? matches,
    String? error,
    bool? artOnly,
    String? currentAlbumName,
    int? skippedCount,
    DateTime? startedAt,
  }) {
    return AutoTagState(
      phase: phase ?? this.phase,
      current: current ?? this.current,
      total: total ?? this.total,
      matches: matches ?? this.matches,
      error: error ?? this.error,
      artOnly: artOnly ?? this.artOnly,
      currentAlbumName: currentAlbumName ?? this.currentAlbumName,
      skippedCount: skippedCount ?? this.skippedCount,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

class AutoTagNotifier extends StateNotifier<AutoTagState> {
  final Ref _ref;

  AutoTagNotifier(this._ref) : super(const AutoTagState());

  bool _stopRequested = false;

  void setArtOnly(bool value) {
    state = state.copyWith(artOnly: value);
  }

  Future<void> startScan({bool? artOnly}) async {
    final db = _ref.read(databaseProvider);
    final resolver = _ref.read(metadataResolverProvider);
    _stopRequested = false;

    final isArtOnly = artOnly ?? state.artOnly;

    // Get all albums
    final albums = await (db.select(db.albums)
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .get();

    state = state.copyWith(
      phase: AutoTagPhase.scanning,
      current: 0,
      total: albums.length,
      matches: [],
      artOnly: isArtOnly,
      skippedCount: 0,
      startedAt: DateTime.now(),
    );

    final matches = <AlbumMatch>[];
    var skipped = 0;

    for (var i = 0; i < albums.length; i++) {
      if (_stopRequested) break;

      final album = albums[i];
      state = state.copyWith(current: i + 1, currentAlbumName: album.name);

      // Get tracks for this album
      final tracks = await (db.select(db.tracks)
            ..where((t) => t.album.equals(album.name))
            ..orderBy([
              (t) => OrderingTerm.asc(t.discNumber),
              (t) => OrderingTerm.asc(t.trackNumber),
            ]))
          .get();

      // Skip albums where all tracks already have MB track or release IDs
      // (previously matched by auto-tag or manually tagged)
      if (tracks.every((t) =>
          t.musicbrainzTrackId != null || t.musicbrainzReleaseId != null)) {
        skipped++;
        state = state.copyWith(skippedCount: skipped);
        continue;
      }

      try {
        final releases = await resolver.searchReleases(
          album: album.name,
          artist: album.artist,
        );

        if (releases.isEmpty) continue;
        if (_stopRequested) break;

        // Find best release using composite confidence.
        // Optimization: skip candidates with low search scores and
        // exit early when a high-confidence match is found.
        MusicBrainzRelease? bestRelease;
        int bestConfidence = 0;
        List<TrackPairing> bestPairings = [];

        // Filter out low-scoring search results (MB score < 50)
        final viable = releases.where((r) => r.score >= 50).take(3);
        for (final release in viable) {
          if (_stopRequested) break;
          try {
            final fullRelease = await resolver.getRelease(release.id);
            final pairings = _matchTracks(tracks, fullRelease);
            final confidence = _computeConfidence(
              release: release,
              album: album,
              tracks: tracks,
              pairings: pairings,
            );

            if (confidence > bestConfidence) {
              bestConfidence = confidence;
              bestRelease = fullRelease;
              bestPairings = pairings;
            }

            // Early exit: high confidence match found, no need to
            // evaluate remaining candidates (saves 1-2 API calls).
            if (bestConfidence >= 85) break;
          } catch (_) {
            // Skip releases we can't fetch details for
          }
        }

        if (bestRelease != null && bestConfidence >= 50) {
          matches.add(AlbumMatch(
            album: album,
            tracks: tracks,
            bestRelease: bestRelease,
            pairings: bestPairings,
            confidence: bestConfidence,
          ));
          // Update state incrementally so results are preserved if stopped
          state = state.copyWith(matches: List.from(matches));
        }
      } catch (_) {
        // Skip albums that fail lookup entirely
      }
    }

    if (isArtOnly && matches.isNotEmpty) {
      // Art-only mode: skip review, apply all matches directly
      state = state.copyWith(
        phase: AutoTagPhase.applying,
        matches: matches,
        current: 0,
        total: matches.length,
      );

      for (var i = 0; i < matches.length; i++) {
        state = state.copyWith(current: i + 1);
        await applyMatch(matches[i], artOnly: true);
      }

      _ref.invalidate(trackListProvider);
      _ref.invalidate(albumGridProvider);
      _ref.invalidate(artistListProvider);

      state = state.copyWith(phase: AutoTagPhase.complete);
    } else {
      state = state.copyWith(
        phase: AutoTagPhase.reviewing,
        matches: matches,
      );
    }
  }

  void stopScan() {
    _stopRequested = true;
  }

  List<TrackPairing> _matchTracks(List<Track> locals, MusicBrainzRelease release) {
    final mbTracks = List<MusicBrainzRecording>.from(release.tracks);
    final matched = <MusicBrainzRecording>{};
    final results = <TrackPairing>[];

    for (final local in locals) {
      final alreadyTagged = local.musicbrainzTrackId != null;

      MusicBrainzRecording? best;
      if (local.trackNumber != null) {
        final positional = mbTracks.where(
          (mb) => mb.trackNumber == local.trackNumber && !matched.contains(mb),
        );
        if (positional.isNotEmpty) best = positional.first;
      }

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

      results.add(TrackPairing(
        localTrack: local,
        mbRecording: best,
        alreadyTagged: alreadyTagged,
        checked: best != null && !alreadyTagged,
      ));
    }

    return results;
  }

  int _computeConfidence({
    required MusicBrainzRelease release,
    required Album album,
    required List<Track> tracks,
    required List<TrackPairing> pairings,
  }) {
    var score = 0.0;

    // MB search score (0-100), weight 30%
    score += release.score * 0.3;

    // Artist match, weight 30%
    if (album.artist != null && release.artist != null) {
      if (normalizeTitle(album.artist!) == normalizeTitle(release.artist!)) {
        score += 30;
      } else if (normalizeTitle(release.artist!).contains(normalizeTitle(album.artist!))) {
        score += 15;
      }
    }

    // Track count match, weight 20%
    if (release.trackCount > 0 && tracks.isNotEmpty) {
      final ratio = tracks.length / release.trackCount;
      if (ratio >= 0.9 && ratio <= 1.1) {
        score += 20;
      } else if (ratio >= 0.7 && ratio <= 1.3) {
        score += 10;
      }
    }

    // Matched track ratio, weight 20%
    final matchedCount = pairings.where((p) => p.mbRecording != null).length;
    if (pairings.isNotEmpty) {
      score += (matchedCount / pairings.length) * 20;
    }

    return score.round().clamp(0, 100);
  }

  Future<void> applyMatch(AlbumMatch match, {bool artOnly = false}) async {
    final db = _ref.read(databaseProvider);
    final resolver = _ref.read(metadataResolverProvider);

    final checkedPairings = match.pairings
        .where((p) => p.checked && p.mbRecording != null)
        .toList();

    // Batch all DB writes in a single transaction
    await db.transaction(() async {
      for (final pairing in checkedPairings) {
        final track = pairing.localTrack;
        final mb = pairing.mbRecording!;

        // Write lightweight MB ID flag to file
        if (track.filePath != null) {
          try {
            await rust.metadataWriteMbId(
              path: track.filePath!,
              trackId: mb.id,
            );
          } catch (_) {
            // Skip files that can't be written (corrupted, wrong format, etc.)
          }
        }

        if (artOnly) {
          // Art-only mode: only store the MB IDs, skip metadata overlay
          await (db.update(db.tracks)..where((t) => t.id.equals(track.id)))
              .write(TracksCompanion(
            musicbrainzTrackId: Value(mb.id),
            musicbrainzArtistId: Value(mb.artistId),
            musicbrainzReleaseId: Value(mb.releaseId),
          ));
        } else {
          // Full mode: store MB metadata as overlay in DB
          await (db.update(db.tracks)..where((t) => t.id.equals(track.id)))
              .write(TracksCompanion(
            title: Value(mb.title),
            artist: Value(mb.artist),
            album: Value(mb.album),
            trackNumber: Value(mb.trackNumber),
            year: Value(mb.year),
            musicbrainzTrackId: Value(mb.id),
            musicbrainzArtistId: Value(mb.artistId),
            musicbrainzReleaseId: Value(mb.releaseId),
          ));
        }
      }
    });

    // Fetch album art (both modes)
    if (match.bestRelease != null) {
      final hasAnyArt = match.tracks.any((t) => t.hasAlbumArt);
      if (!hasAnyArt) {
        final artBytes = await resolver.resolveArt(match.bestRelease!.id);
        if (artBytes != null && artBytes.isNotEmpty) {
          final artService = _ref.read(albumArtServiceProvider);
          final firstWithPath = match.tracks.firstWhere(
            (t) => t.filePath != null,
            orElse: () => match.tracks.first,
          );
          if (firstWithPath.filePath != null) {
            final artPath = await artService.saveCoverArt(firstWithPath.filePath!, artBytes);
            await resolver.updateCoverArtPath(match.bestRelease!.id, artPath);
            await db.transaction(() async {
              for (final track in match.tracks) {
                await (db.update(db.tracks)
                      ..where((t) => t.id.equals(track.id)))
                    .write(const TracksCompanion(hasAlbumArt: Value(true)));
              }
            });
          }
        }
      }

      // Cache the album→release mapping for future enrichment
      await resolver.cacheMapping(
        albumName: match.album.name,
        artistName: match.album.artist,
        mbReleaseId: match.bestRelease!.id,
        confidence: match.confidence,
      );
    }

    match.accepted = true;
  }

  Future<void> applyAll() async {
    final pending = state.matches.where((m) => !m.accepted && !m.skipped && m.confidence >= 80).toList();

    state = state.copyWith(
      phase: AutoTagPhase.applying,
      current: 0,
      total: pending.length,
    );

    for (var i = 0; i < pending.length; i++) {
      state = state.copyWith(current: i + 1);
      await applyMatch(pending[i]);
    }

    // Refresh UI
    _ref.invalidate(trackListProvider);
    _ref.invalidate(albumGridProvider);
    _ref.invalidate(artistListProvider);

    state = state.copyWith(phase: AutoTagPhase.complete);
  }

  void skipMatch(AlbumMatch match) {
    match.skipped = true;
    state = state.copyWith(matches: List.from(state.matches));
  }

  void reset() {
    state = const AutoTagState();
  }
}

final autoTagProvider = StateNotifierProvider<AutoTagNotifier, AutoTagState>((ref) {
  return AutoTagNotifier(ref);
});

class AutoTagPage extends ConsumerWidget {
  const AutoTagPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(autoTagProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mbAutoTagTitle),
        actions: [
          if (state.phase == AutoTagPhase.reviewing)
            FilledButton.icon(
              onPressed: state.matches.any((m) => !m.accepted && !m.skipped && m.confidence >= 80)
                  ? () => ref.read(autoTagProvider.notifier).applyAll()
                  : null,
              icon: const Icon(Icons.done_all),
              label: Text(l10n.mbAcceptAll),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: switch (state.phase) {
        AutoTagPhase.idle => _buildIdleView(context, ref, l10n, textTheme),
        AutoTagPhase.scanning => _buildScanningView(context, ref, state, l10n, textTheme),
        AutoTagPhase.reviewing => _buildReviewView(context, ref, state, l10n, colorScheme, textTheme),
        AutoTagPhase.applying => _buildApplyingView(context, state, l10n, textTheme),
        AutoTagPhase.complete => _buildCompleteView(context, ref, state, l10n, textTheme),
      },
    );
  }

  Widget _buildIdleView(BuildContext context, WidgetRef ref, AppLocalizations l10n, TextTheme textTheme) {
    final state = ref.watch(autoTagProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_fix_high, size: 64, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(l10n.mbAutoTagTitle, style: textTheme.headlineSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: 400,
            child: Text(
              l10n.mbAutoTagDescription,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: state.artOnly,
                onChanged: (v) => ref.read(autoTagProvider.notifier).setArtOnly(v ?? false),
              ),
              GestureDetector(
                onTap: () => ref.read(autoTagProvider.notifier).setArtOnly(!state.artOnly),
                child: Text(
                  'Album art only',
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Skip metadata changes — only fetch and store cover art.\n'
                    'Faster, and your existing tags stay untouched.',
                child: Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => ref.read(autoTagProvider.notifier).startScan(),
            icon: const Icon(Icons.search),
            label: Text(l10n.mbAutoTagStart),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningView(BuildContext context, WidgetRef ref, AutoTagState state, AppLocalizations l10n, TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;
    final dimStyle = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    // Elapsed + ETA calculation
    String timeInfo = '';
    if (state.startedAt != null && state.current > 0) {
      final elapsed = DateTime.now().difference(state.startedAt!);
      final elapsedStr = _formatDuration(elapsed);
      if (state.current < state.total) {
        final msPerAlbum = elapsed.inMilliseconds / state.current;
        final remaining = Duration(
          milliseconds: (msPerAlbum * (state.total - state.current)).round(),
        );
        timeInfo = '$elapsedStr elapsed · ~${_formatDuration(remaining)} remaining';
      } else {
        timeInfo = '$elapsedStr elapsed';
      }
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LoonLoader(),
          const SizedBox(height: 24),
          Text(
            l10n.mbAutoTagProgress(state.current, state.total),
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          if (state.currentAlbumName != null)
            Text(
              state.currentAlbumName!,
              style: textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          Text(
            '${state.matches.length} matched · ${state.skippedCount} skipped',
            style: dimStyle,
          ),
          if (timeInfo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(timeInfo, style: dimStyle),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: 300,
            child: LinearProgressIndicator(
              value: state.total > 0 ? state.current / state.total : 0,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.minimize, size: 18),
                label: const Text('Minimize'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => ref.read(autoTagProvider.notifier).stopScan(),
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  Widget _buildReviewView(
    BuildContext context,
    WidgetRef ref,
    AutoTagState state,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (state.matches.isEmpty) {
      return Center(child: Text(l10n.mbAutoTagNoMatches));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.matches.length,
      itemBuilder: (context, index) {
        final match = state.matches[index];
        return _AlbumMatchCard(
          match: match,
          onAccept: () async {
            await ref.read(autoTagProvider.notifier).applyMatch(match);
            ref.invalidate(trackListProvider);
            ref.invalidate(albumGridProvider);
            ref.invalidate(artistListProvider);
          },
          onSkip: () {
            ref.read(autoTagProvider.notifier).skipMatch(match);
          },
          onEdit: () {
            showAlbumLookupDialog(context, ref, match.album, match.tracks);
          },
        );
      },
    );
  }

  Widget _buildApplyingView(BuildContext context, AutoTagState state, AppLocalizations l10n, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LoonLoader(),
          const SizedBox(height: 24),
          Text(l10n.mbApplying, style: textTheme.bodyLarge),
          const SizedBox(height: 16),
          SizedBox(
            width: 300,
            child: LinearProgressIndicator(
              value: state.total > 0 ? state.current / state.total : 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteView(
    BuildContext context,
    WidgetRef ref,
    AutoTagState state,
    AppLocalizations l10n,
    TextTheme textTheme,
  ) {
    final accepted = state.matches.where((m) => m.accepted).length;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            l10n.mbAutoTagComplete(accepted),
            style: textTheme.headlineSmall,
          ),
          if (state.artOnly) ...[
            const SizedBox(height: 8),
            Text(
              '$accepted albums got cover art · ${state.skippedCount} skipped',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              ref.read(autoTagProvider.notifier).reset();
              Navigator.pop(context);
            },
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }
}

class _AlbumMatchCard extends StatelessWidget {
  const _AlbumMatchCard({
    required this.match,
    required this.onAccept,
    required this.onSkip,
    required this.onEdit,
  });

  final AlbumMatch match;
  final VoidCallback onAccept;
  final VoidCallback onSkip;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (match.accepted || match.skipped) {
      return Card(
        color: match.accepted
            ? Colors.green.withValues(alpha: 0.1)
            : colorScheme.surfaceContainerHighest,
        child: ListTile(
          leading: Icon(
            match.accepted ? Icons.check_circle : Icons.skip_next,
            color: match.accepted ? Colors.green : colorScheme.onSurfaceVariant,
          ),
          title: Text(match.album.name),
          subtitle: Text(match.album.artist ?? ''),
          trailing: Text(
            match.accepted ? l10n.mbApplied : l10n.mbReject,
            style: textTheme.bodySmall,
          ),
        ),
      );
    }

    final matchedCount = match.pairings.where((p) => p.mbRecording != null).length;

    return Card(
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: match.confidence >= 80
                ? Colors.green.withValues(alpha: 0.2)
                : match.confidence >= 60
                    ? Colors.orange.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.mbConfidence(match.confidence),
            style: textTheme.labelSmall,
          ),
        ),
        title: Text(match.album.name),
        subtitle: Text(
          [
            if (match.album.artist != null) match.album.artist!,
            if (match.bestRelease != null) '→ ${match.bestRelease!.title}',
            l10n.mbTrackMatched(matchedCount, match.pairings.length),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall,
        ),
        children: [
          // Track pairings
          for (final pairing in match.pairings)
            ListTile(
              dense: true,
              leading: SizedBox(
                width: 24,
                child: Text(
                  pairing.localTrack.trackNumber?.toString() ?? '–',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      pairing.localTrack.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: pairing.mbRecording != null ? null : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (pairing.mbRecording != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward, size: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    Expanded(
                      child: Text(
                        pairing.mbRecording!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: pairing.alreadyTagged
                  ? Text(l10n.mbAlreadyTagged, style: textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic))
                  : null,
            ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onSkip,
                  child: Text(l10n.mbReject),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onAccept,
                  child: Text(l10n.mbAccept),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
