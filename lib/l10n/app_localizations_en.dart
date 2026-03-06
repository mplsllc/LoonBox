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
  String get navHome => 'Home';

  @override
  String get navSongs => 'Songs';

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
  String get songsTitle => 'Songs';

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

  @override
  String get visualizer => 'Visualizer';

  @override
  String get visualizerSpectrum => 'Spectrum';

  @override
  String get visualizerWaveform => 'Waveform';

  @override
  String get visualizerOscilloscope => 'Oscilloscope';

  @override
  String get visualizerVuMeter => 'VU Meter';

  @override
  String get contextLookUpInfo => 'Look Up Info';

  @override
  String get mbLookupTitle => 'MusicBrainz Lookup';

  @override
  String get mbNoResults => 'No matches found on MusicBrainz.';

  @override
  String mbScore(int score) {
    return 'Match: $score%';
  }

  @override
  String get mbApply => 'Apply';

  @override
  String get mbApplying => 'Writing tags...';

  @override
  String get mbApplied => 'Metadata updated from MusicBrainz.';

  @override
  String mbApplyError(String error) {
    return 'Failed to update metadata: $error';
  }

  @override
  String get contextLookUpAlbum => 'Look Up Album';

  @override
  String get mbAlbumLookupTitle => 'Album Lookup';

  @override
  String mbTrackMatched(int matched, int total) {
    return '$matched of $total tracks matched';
  }

  @override
  String get mbAlreadyTagged => 'Already tagged';

  @override
  String get mbAutoTagTitle => 'Auto-Tag Library';

  @override
  String mbAutoTagProgress(int current, int total) {
    return 'Looking up $current of $total albums...';
  }

  @override
  String mbAutoTagComplete(int count) {
    return 'Found matches for $count albums';
  }

  @override
  String get mbAutoTagNoMatches => 'No matches found';

  @override
  String get mbAutoTagStart => 'Start Scan';

  @override
  String get mbAutoTagDescription =>
      'Scan your library and look up album metadata from MusicBrainz. You can review and accept changes before they are applied.';

  @override
  String get mbAcceptAll => 'Accept All';

  @override
  String get mbReject => 'Skip';

  @override
  String get mbAccept => 'Accept';

  @override
  String mbConfidence(int score) {
    return 'Confidence: $score%';
  }

  @override
  String get menuFile => 'File';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuControls => 'Controls';

  @override
  String get menuView => 'View';

  @override
  String get menuTools => 'Tools';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuQuit => 'Quit';

  @override
  String get menuPreferences => 'Preferences';

  @override
  String get menuAbout => 'About LoonBox';

  @override
  String get menuMusic => 'Music';

  @override
  String get nothingSelected => 'Nothing selected';

  @override
  String get done => 'Done';

  @override
  String get mbManualSearch => 'Search manually';

  @override
  String get mbSearchTitle => 'Title';

  @override
  String get mbSearchArtist => 'Artist';

  @override
  String get mbSearch => 'Search';

  @override
  String get contextRemoveFromPlaylist => 'Remove from Playlist';

  @override
  String get contextProperties => 'Properties';

  @override
  String get contextPlayAlbum => 'Play Album';

  @override
  String get contextAddAlbumToQueue => 'Add Album to Queue';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeWelcome => 'Welcome to LoonBox';

  @override
  String get homeYourListening => 'Your Listening';

  @override
  String get homePrivateToYou => 'Private to you';

  @override
  String get homeListenedAllTime => 'listened all time';

  @override
  String get homeThisWeek => 'this week';

  @override
  String homeVsLastWeek(String percent) {
    return '$percent% vs last week';
  }

  @override
  String get homeStreak => 'day streak';

  @override
  String get homeTopArtistMonth => 'Top artist this month';

  @override
  String homeStatsTracks(int count) {
    return '$count tracks';
  }

  @override
  String homeStatsAlbums(int count) {
    return '$count albums';
  }

  @override
  String homeStatsArtists(int count) {
    return '$count artists';
  }

  @override
  String get homeRecentlyPlayed => 'Recently Played';

  @override
  String get homeTopAlbums => 'Top Albums';

  @override
  String get homeJumpBackIn => 'Jump Back In';

  @override
  String get homeRecentlyAdded => 'Recently Added';

  @override
  String get homeRediscover => 'Rediscover';

  @override
  String get homeRefresh => 'Refresh';

  @override
  String get homeForgotten => 'You haven\'t listened to this in a while';

  @override
  String get homeNeverPlayed => 'Albums you\'ve never played';

  @override
  String get homeFromCollection => 'From your collection';

  @override
  String homePlayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plays',
      one: '1 play',
    );
    return '$_temp0';
  }

  @override
  String get homeComingSoon => 'Coming Soon';

  @override
  String get homeTremolo => 'Tremolo';

  @override
  String get homeTremoloDesc => 'Discover & support artists directly';

  @override
  String get homeNest => 'The Nest';

  @override
  String get homeNestDesc => 'Feathers & extensions marketplace';

  @override
  String get homeEmptyTitle => 'Welcome to LoonBox';

  @override
  String get homeEmptyAddMusic => 'Add your music';

  @override
  String get homeEmptyAutoTag => 'Auto-tag your library';

  @override
  String get homeEmptyAutoTagDesc =>
      'Let LoonBox identify and organize your music using MusicBrainz';

  @override
  String get homeEmptyAutoTagDisabled => 'Add music first';
}
