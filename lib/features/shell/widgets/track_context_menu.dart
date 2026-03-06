import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../../../l10n/app_localizations.dart';
import '../../player/presentation/queue_provider.dart';
import '../pages/album_detail_page.dart';
import '../pages/artist_detail_page.dart';
import 'add_to_playlist_dialog.dart';
import 'album_lookup_dialog.dart';
import 'musicbrainz_lookup_dialog.dart';

/// Show a consistent right-click context menu for a track.
///
/// [hideGoToAlbum] / [hideGoToArtist] suppress navigation items
/// when you're already on that page.
void showTrackContextMenu(
  BuildContext context,
  WidgetRef ref,
  Offset position,
  Track track, {
  bool hideGoToAlbum = false,
  bool hideGoToArtist = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  final db = ref.read(databaseProvider);

  showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy),
    items: [
      PopupMenuItem(value: 'play_next', child: Text(l10n.contextPlayNext)),
      PopupMenuItem(value: 'play_later', child: Text(l10n.contextPlayLater)),
      PopupMenuItem(
          value: 'add_playlist', child: Text(l10n.contextAddToPlaylist)),
      if (track.album != null && !hideGoToAlbum)
        PopupMenuItem(value: 'go_album', child: Text(l10n.contextGoToAlbum)),
      if (track.artist != null && !hideGoToArtist)
        PopupMenuItem(
            value: 'go_artist', child: Text(l10n.contextGoToArtist)),
      const PopupMenuDivider(),
      PopupMenuItem(
          value: 'lookup_info', child: Text(l10n.contextLookUpInfo)),
    ],
  ).then((value) async {
    if (value == null) return;
    switch (value) {
      case 'play_next':
        ref.read(queueProvider.notifier).playNext(track);
      case 'play_later':
        ref.read(queueProvider.notifier).playLater(track);
      case 'add_playlist':
        if (context.mounted) {
          showAddToPlaylistDialog(context, ref, track);
        }
      case 'go_album':
        if (context.mounted) {
          navigateToAlbumByName(context, db, track.album!);
        }
      case 'go_artist':
        if (context.mounted) {
          navigateToArtistByName(context, db, track.artist!);
        }
      case 'lookup_info':
        if (context.mounted) {
          showMusicBrainzLookupDialog(context, ref, track);
        }
    }
  });
}

/// Show a consistent right-click context menu for an album.
///
/// [hideGoToArtist] suppresses the artist navigation item
/// when you're already on the artist page.
void showAlbumContextMenu(
  BuildContext context,
  WidgetRef ref,
  Offset position,
  Album album, {
  bool hideGoToArtist = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  final db = ref.read(databaseProvider);

  showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy),
    items: [
      PopupMenuItem(value: 'play_album', child: Text(l10n.contextPlayAlbum)),
      PopupMenuItem(
          value: 'add_to_queue', child: Text(l10n.contextAddAlbumToQueue)),
      if (album.artist != null && !hideGoToArtist)
        PopupMenuItem(
            value: 'go_artist', child: Text(l10n.contextGoToArtist)),
      const PopupMenuDivider(),
      PopupMenuItem(
          value: 'lookup_album', child: Text(l10n.contextLookUpAlbum)),
    ],
  ).then((value) async {
    if (value == null) return;
    switch (value) {
      case 'play_album':
        final tracks = await _getAlbumTracks(db, album);
        if (tracks.isNotEmpty) {
          ref.read(queueProvider.notifier).setQueue(tracks);
        }
      case 'add_to_queue':
        final tracks = await _getAlbumTracks(db, album);
        for (final track in tracks) {
          ref.read(queueProvider.notifier).playLater(track);
        }
      case 'go_artist':
        if (context.mounted) {
          navigateToArtistByName(context, db, album.artist!);
        }
      case 'lookup_album':
        final tracks = await _getAlbumTracks(db, album);
        if (context.mounted) {
          showAlbumLookupDialog(context, ref, album, tracks);
        }
    }
  });
}

/// Navigate to an artist detail page by artist name.
/// Looks up the artist in the database and pushes the detail page.
Future<void> navigateToArtistByName(
  BuildContext context,
  LoonBoxDatabase db,
  String artistName,
) async {
  final artists = await (db.select(db.artists)
        ..where((a) => a.name.equals(artistName)))
      .get();
  if (artists.isNotEmpty && context.mounted) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArtistDetailPage(artist: artists.first),
    ));
  }
}

/// Navigate to an album detail page by album name.
/// Looks up the album in the database and pushes the detail page.
Future<void> navigateToAlbumByName(
  BuildContext context,
  LoonBoxDatabase db,
  String albumName,
) async {
  final albums = await (db.select(db.albums)
        ..where((a) => a.name.equals(albumName)))
      .get();
  if (albums.isNotEmpty && context.mounted) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AlbumDetailPage(album: albums.first),
    ));
  }
}

Future<List<Track>> _getAlbumTracks(LoonBoxDatabase db, Album album) async {
  return (db.select(db.tracks)
        ..where((t) => t.album.equals(album.name))
        ..orderBy([
          (t) => OrderingTerm.asc(t.discNumber),
          (t) => OrderingTerm.asc(t.trackNumber),
        ]))
      .get();
}
