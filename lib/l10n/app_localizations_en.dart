// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LoonBox';

  @override
  String get navLibrary => 'Library';

  @override
  String get navAlbums => 'Albums';

  @override
  String get navArtists => 'Artists';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navSettings => 'Settings';

  @override
  String get navSearch => 'Search';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerStop => 'Stop';

  @override
  String get playerNext => 'Next track';

  @override
  String get playerPrevious => 'Previous track';

  @override
  String get playerShuffle => 'Shuffle';

  @override
  String get playerRepeat => 'Repeat';

  @override
  String get playerVolume => 'Volume';

  @override
  String get playerNowPlaying => 'Now Playing';

  @override
  String get playerQueue => 'Queue';

  @override
  String get playerNoTrack => 'No track loaded';

  @override
  String get libraryTitle => 'Library';

  @override
  String get libraryEmpty =>
      'Your library is empty. Add a watch directory in Settings to get started.';

  @override
  String libraryScanProgress(int scanned, int total) {
    return 'Scanning: $scanned of $total';
  }

  @override
  String libraryScanComplete(int total, String seconds) {
    return 'Scan complete: $total tracks in ${seconds}s';
  }

  @override
  String get albumsTitle => 'Albums';

  @override
  String get artistsTitle => 'Artists';

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAudioOutput => 'Audio Output';

  @override
  String get settingsWatchDirs => 'Watch Directories';

  @override
  String get settingsAddDir => 'Add Directory';

  @override
  String get settingsRemoveDir => 'Remove';

  @override
  String get settingsRescanLibrary => 'Rescan Library';

  @override
  String get settingsCleanLibrary => 'Clean Missing Tracks';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsFeathers => 'Feathers';

  @override
  String get searchHint => 'Search tracks, albums, artists...';

  @override
  String get trackTitle => 'Title';

  @override
  String get trackArtist => 'Artist';

  @override
  String get trackAlbum => 'Album';

  @override
  String get trackDuration => 'Duration';

  @override
  String get trackGenre => 'Genre';

  @override
  String get trackYear => 'Year';

  @override
  String get contextPlayNext => 'Play Next';

  @override
  String get contextPlayLater => 'Play Later';

  @override
  String get contextGoToAlbum => 'Go to Album';

  @override
  String get contextGoToArtist => 'Go to Artist';

  @override
  String get settingsExtensions => 'Extensions';

  @override
  String get extensionsNone => 'No extensions installed.';

  @override
  String get extensionsAdd => 'Install Extension';

  @override
  String get extensionsRemove => 'Uninstall';

  @override
  String get extensionsPermissions => 'Permissions';

  @override
  String get playerRepeatOff => 'Repeat off';

  @override
  String get playerRepeatAll => 'Repeat all';

  @override
  String get playerRepeatOne => 'Repeat one';

  @override
  String get playerShuffleOn => 'Shuffle on';

  @override
  String get playerShuffleOff => 'Shuffle off';

  @override
  String get queueTitle => 'Queue';

  @override
  String get queueEmpty => 'Queue is empty';

  @override
  String get queueClear => 'Clear Queue';

  @override
  String queueTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String albumDetailTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String artistAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String get nowPlayingTitle => 'Now Playing';

  @override
  String get upNext => 'Up Next';

  @override
  String get settingsEqualizer => 'Equalizer';

  @override
  String get eqEnabled => 'Equalizer Enabled';

  @override
  String get eqPreset => 'Preset';

  @override
  String libraryTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String get playAll => 'Play All';

  @override
  String get playlistCreate => 'New Playlist';

  @override
  String get playlistName => 'Playlist Name';

  @override
  String get playlistDescription => 'Description (optional)';

  @override
  String get playlistEmpty => 'No playlists yet. Create one to get started.';

  @override
  String get playlistDelete => 'Delete Playlist';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get playlistRename => 'Rename';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get contextAddToPlaylist => 'Add to Playlist';

  @override
  String get searchNoResults => 'No results found';
}
