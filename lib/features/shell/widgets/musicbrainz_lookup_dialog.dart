import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import 'loon_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/album_art_service.dart';
import '../../../services/metadata_resolver.dart';
import '../../../services/musicbrainz_service.dart' show MusicBrainzRecording;
import '../../../src/rust/api.dart' as rust;
import '../pages/albums_page.dart';
import '../pages/artists_page.dart';
import '../pages/songs_page.dart';

/// Show the MusicBrainz lookup dialog for a track.
Future<void> showMusicBrainzLookupDialog(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  await showDialog(
    context: context,
    builder: (ctx) => _MusicBrainzLookupDialog(track: track),
  );
}

/// Try to parse a messy title like "019 - Nine Days - Absolutely [Story Of..."
/// into separate title and artist components.
({String title, String? artist}) _parseTrackTitle(String raw) {
  var cleaned = raw;

  // Strip leading track number patterns: "019 - ", "01. ", "1 - ", etc.
  cleaned = cleaned.replaceFirst(RegExp(r'^\d{1,3}\s*[-.)]\s*'), '');

  // Strip trailing brackets/parens: "[Story Of..." or "(Remastered)"
  cleaned = cleaned.replaceFirst(RegExp(r'\s*[\[\(].*$'), '');

  cleaned = cleaned.trim();

  // Try to split "Artist - Title" pattern
  final dashParts = cleaned.split(RegExp(r'\s+-\s+'));
  if (dashParts.length >= 2) {
    return (
      artist: dashParts.first.trim(),
      title: dashParts.sublist(1).join(' - ').trim(),
    );
  }

  return (title: cleaned, artist: null);
}

class _MusicBrainzLookupDialog extends ConsumerStatefulWidget {
  const _MusicBrainzLookupDialog({required this.track});

  final Track track;

  @override
  ConsumerState<_MusicBrainzLookupDialog> createState() =>
      _MusicBrainzLookupDialogState();
}

class _MusicBrainzLookupDialogState
    extends ConsumerState<_MusicBrainzLookupDialog> {
  List<MusicBrainzRecording>? _results;
  bool _loading = true;
  String? _error;
  int _selectedIndex = -1;
  bool _applying = false;
  bool _showManualSearch = false;

  late final TextEditingController _titleController;
  late final TextEditingController _artistController;

  @override
  void initState() {
    super.initState();
    // Pre-populate with parsed values
    final parsed = _parseTrackTitle(widget.track.title);
    _titleController = TextEditingController(
      text: parsed.title,
    );
    _artistController = TextEditingController(
      text: parsed.artist ?? widget.track.artist ?? '',
    );
    _search();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  Future<void> _search({String? title, String? artist}) async {
    setState(() {
      _loading = true;
      _error = null;
      _results = null;
      _selectedIndex = -1;
    });

    try {
      final resolver = ref.read(metadataResolverProvider);

      // Use provided overrides, or fall back to track fields
      final searchTitle = title ?? widget.track.title;
      final searchArtist = artist ?? widget.track.artist;

      final results = await resolver.searchRecordings(
        title: searchTitle,
        artist: searchArtist,
        album: widget.track.album,
      );

      // If automatic search got no results, try with parsed title
      if (results.isEmpty && title == null) {
        final parsed = _parseTrackTitle(widget.track.title);
        if (parsed.title != widget.track.title ||
            parsed.artist != null) {
          final retryResults = await resolver.searchRecordings(
            title: parsed.title,
            artist: parsed.artist ?? searchArtist,
            album: widget.track.album,
          );
          if (mounted) {
            setState(() {
              _results = retryResults;
              _loading = false;
              _showManualSearch = retryResults.isEmpty;
              if (retryResults.isNotEmpty && retryResults.first.score >= 90) {
                _selectedIndex = 0;
              }
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
          // Show manual search if no results
          _showManualSearch = results.isEmpty;
          // Auto-select first result if high confidence
          if (results.isNotEmpty && results.first.score >= 90) {
            _selectedIndex = 0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _manualSearch() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final artist = _artistController.text.trim();
    _search(
      title: title,
      artist: artist.isNotEmpty ? artist : null,
    );
  }

  Future<void> _apply(MusicBrainzRecording result) async {
    if (_applying) return;
    setState(() => _applying = true);

    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    messenger.showSnackBar(SnackBar(content: Text(l10n.mbApplying)));

    try {
      final resolver = ref.read(metadataResolverProvider);

      // 1. Write only MB ID flag to file (lightweight)
      if (widget.track.filePath != null) {
        await rust.metadataWriteMbId(
          path: widget.track.filePath!,
          trackId: result.id,
        );
      }

      // 2. Store full metadata in DB as overlay
      await (db.update(db.tracks)
            ..where((t) => t.id.equals(widget.track.id)))
          .write(TracksCompanion(
        title: Value(result.title),
        artist: Value(result.artist),
        album: Value(result.album),
        trackNumber: Value(result.trackNumber),
        year: Value(result.year),
        musicbrainzTrackId: Value(result.id),
        musicbrainzArtistId: Value(result.artistId),
        musicbrainzReleaseId: Value(result.releaseId),
      ));

      // 3. Fetch cover art via resolver (tiered: local → community → CAA)
      if (!widget.track.hasAlbumArt && result.releaseId != null) {
        final artBytes = await resolver.resolveArt(result.releaseId!);
        if (artBytes != null && artBytes.isNotEmpty) {
          final artService = ref.read(albumArtServiceProvider);
          await artService.saveCoverArt(widget.track.filePath!, artBytes);
          await (db.update(db.tracks)
                ..where((t) => t.id.equals(widget.track.id)))
              .write(const TracksCompanion(hasAlbumArt: Value(true)));
        }
      }

      // 4. Refresh UI
      ref.invalidate(trackListProvider);
      ref.invalidate(albumGridProvider);
      ref.invalidate(artistListProvider);

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

  String _formatDuration(int? ms) {
    if (ms == null) return '';
    final total = Duration(milliseconds: ms);
    final m = total.inMinutes;
    final s = total.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(l10n.mbLookupTitle),
      content: SizedBox(
        width: 500,
        height: 450,
        child: Column(
          children: [
            // Manual search fields
            if (_showManualSearch) ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: l10n.mbSearchTitle,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _manualSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _artistController,
                      decoration: InputDecoration(
                        labelText: l10n.mbSearchArtist,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _manualSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _loading ? null : _manualSearch,
                    icon: const Icon(Icons.search),
                    tooltip: l10n.mbSearch,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Results area
            Expanded(
              child: _loading
                  ? const Center(child: LoonLoader())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _results == null || _results!.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(l10n.mbNoResults),
                                  if (!_showManualSearch) ...[
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                      onPressed: () => setState(
                                          () => _showManualSearch = true),
                                      icon: const Icon(Icons.edit),
                                      label: Text(l10n.mbManualSearch),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                // Toggle manual search when results exist
                                if (!_showManualSearch)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => setState(
                                          () => _showManualSearch = true),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: Text(
                                        l10n.mbManualSearch,
                                        style: textTheme.labelSmall,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _results!.length,
                                    itemBuilder: (context, index) {
                                      final r = _results![index];
                                      final isSelected =
                                          index == _selectedIndex;
                                      return Card(
                                        color: isSelected
                                            ? colorScheme.primaryContainer
                                            : null,
                                        child: ListTile(
                                          selected: isSelected,
                                          onTap: () => setState(
                                              () => _selectedIndex = index),
                                          title: Text(
                                            r.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            [
                                              if (r.artist != null) r.artist!,
                                              if (r.album != null) r.album!,
                                              if (r.year != null) '${r.year}',
                                              if (r.trackNumber != null)
                                                'Track ${r.trackNumber}',
                                              _formatDuration(r.durationMs),
                                            ]
                                                .where((s) => s.isNotEmpty)
                                                .join(' · '),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.bodySmall,
                                          ),
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: r.score >= 90
                                                  ? Colors.green
                                                      .withValues(alpha: 0.2)
                                                  : r.score >= 70
                                                      ? Colors.orange.withValues(
                                                          alpha: 0.2)
                                                      : Colors.grey.withValues(
                                                          alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              l10n.mbScore(r.score),
                                              style: textTheme.labelSmall,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _applying ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _selectedIndex >= 0 && !_applying
              ? () => _apply(_results![_selectedIndex])
              : null,
          child: Text(l10n.mbApply),
        ),
      ],
    );
  }
}
