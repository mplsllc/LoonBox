import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'LoonBox'**
  String get appTitle;

  /// Sidebar navigation: Home
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Sidebar navigation: Songs
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get navSongs;

  /// Sidebar navigation: Library
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// Sidebar navigation: Albums
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get navAlbums;

  /// Sidebar navigation: Artists
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get navArtists;

  /// Sidebar navigation: Playlists
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get navPlaylists;

  /// Sidebar navigation: Settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Sidebar navigation: Search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// Play button label
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlay;

  /// Pause button label
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// Stop button label
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get playerStop;

  /// Next track button label
  ///
  /// In en, this message translates to:
  /// **'Next track'**
  String get playerNext;

  /// Previous track button label
  ///
  /// In en, this message translates to:
  /// **'Previous track'**
  String get playerPrevious;

  /// Shuffle button label
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get playerShuffle;

  /// Repeat button label
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get playerRepeat;

  /// Volume slider label
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get playerVolume;

  /// Now playing section header
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get playerNowPlaying;

  /// Queue section header
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get playerQueue;

  /// Shown when no track is playing
  ///
  /// In en, this message translates to:
  /// **'No track loaded'**
  String get playerNoTrack;

  /// Songs screen title
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songsTitle;

  /// Library screen title
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// Shown when library has no tracks
  ///
  /// In en, this message translates to:
  /// **'Your library is empty. Add a watch directory in Settings to get started.'**
  String get libraryEmpty;

  /// Scan progress indicator
  ///
  /// In en, this message translates to:
  /// **'Scanning: {scanned} of {total}'**
  String libraryScanProgress(int scanned, int total);

  /// Scan complete message
  ///
  /// In en, this message translates to:
  /// **'Scan complete: {total} tracks in {seconds}s'**
  String libraryScanComplete(int total, String seconds);

  /// Albums screen title
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albumsTitle;

  /// Artists screen title
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artistsTitle;

  /// Playlists screen title
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlistsTitle;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Audio output device setting
  ///
  /// In en, this message translates to:
  /// **'Audio Output'**
  String get settingsAudioOutput;

  /// Watch directories setting section
  ///
  /// In en, this message translates to:
  /// **'Watch Directories'**
  String get settingsWatchDirs;

  /// Add watch directory button
  ///
  /// In en, this message translates to:
  /// **'Add Directory'**
  String get settingsAddDir;

  /// Remove watch directory button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get settingsRemoveDir;

  /// Rescan library button
  ///
  /// In en, this message translates to:
  /// **'Rescan Library'**
  String get settingsRescanLibrary;

  /// Clean missing tracks button
  ///
  /// In en, this message translates to:
  /// **'Clean Missing Tracks'**
  String get settingsCleanLibrary;

  /// About section
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Theme/feather settings
  ///
  /// In en, this message translates to:
  /// **'Feathers'**
  String get settingsFeathers;

  /// Search field placeholder
  ///
  /// In en, this message translates to:
  /// **'Search tracks, albums, artists...'**
  String get searchHint;

  /// Track column header: title
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get trackTitle;

  /// Track column header: artist
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get trackArtist;

  /// Track column header: album
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get trackAlbum;

  /// Track column header: duration
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get trackDuration;

  /// Track column header: genre
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get trackGenre;

  /// Track column header: year
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get trackYear;

  /// Context menu: play next
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get contextPlayNext;

  /// Context menu: add to end of queue
  ///
  /// In en, this message translates to:
  /// **'Play Later'**
  String get contextPlayLater;

  /// Context menu: navigate to album
  ///
  /// In en, this message translates to:
  /// **'Go to Album'**
  String get contextGoToAlbum;

  /// Context menu: navigate to artist
  ///
  /// In en, this message translates to:
  /// **'Go to Artist'**
  String get contextGoToArtist;

  /// Extensions settings section
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get settingsExtensions;

  /// Shown when no extensions are installed
  ///
  /// In en, this message translates to:
  /// **'No extensions installed.'**
  String get extensionsNone;

  /// Install extension button
  ///
  /// In en, this message translates to:
  /// **'Install Extension'**
  String get extensionsAdd;

  /// Uninstall extension button
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get extensionsRemove;

  /// Extension permissions label
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get extensionsPermissions;

  /// Repeat mode: off
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get playerRepeatOff;

  /// Repeat mode: repeat all
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get playerRepeatAll;

  /// Repeat mode: repeat one
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get playerRepeatOne;

  /// Shuffle enabled
  ///
  /// In en, this message translates to:
  /// **'Shuffle on'**
  String get playerShuffleOn;

  /// Shuffle disabled
  ///
  /// In en, this message translates to:
  /// **'Shuffle off'**
  String get playerShuffleOff;

  /// Queue panel title
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queueTitle;

  /// Shown when queue has no tracks
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queueEmpty;

  /// Clear all tracks from queue
  ///
  /// In en, this message translates to:
  /// **'Clear Queue'**
  String get queueClear;

  /// Track count in queue
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String queueTrackCount(int count);

  /// Track count on album detail
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String albumDetailTracks(int count);

  /// Album count on artist detail
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 album} other{{count} albums}}'**
  String artistAlbumCount(int count);

  /// Now playing full view title
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlayingTitle;

  /// Up next section in now playing view
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get upNext;

  /// Equalizer settings section
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get settingsEqualizer;

  /// EQ toggle label
  ///
  /// In en, this message translates to:
  /// **'Equalizer Enabled'**
  String get eqEnabled;

  /// EQ preset dropdown label
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get eqPreset;

  /// Track count shown in library header
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String libraryTrackCount(int count);

  /// Play all tracks button
  ///
  /// In en, this message translates to:
  /// **'Play All'**
  String get playAll;

  /// Create new playlist button
  ///
  /// In en, this message translates to:
  /// **'New Playlist'**
  String get playlistCreate;

  /// Playlist name field label
  ///
  /// In en, this message translates to:
  /// **'Playlist Name'**
  String get playlistName;

  /// Playlist description field label
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get playlistDescription;

  /// Shown when no playlists exist
  ///
  /// In en, this message translates to:
  /// **'No playlists yet. Create one to get started.'**
  String get playlistEmpty;

  /// Delete playlist action
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist'**
  String get playlistDelete;

  /// Confirm playlist deletion
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String playlistDeleteConfirm(String name);

  /// Rename playlist action
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get playlistRename;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Create button
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Context menu: add track to playlist
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get contextAddToPlaylist;

  /// Shown when search returns no results
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// Visualizer toggle tooltip
  ///
  /// In en, this message translates to:
  /// **'Visualizer'**
  String get visualizer;

  /// Spectrum analyzer visualizer style
  ///
  /// In en, this message translates to:
  /// **'Spectrum'**
  String get visualizerSpectrum;

  /// Waveform visualizer style
  ///
  /// In en, this message translates to:
  /// **'Waveform'**
  String get visualizerWaveform;

  /// Oscilloscope visualizer style
  ///
  /// In en, this message translates to:
  /// **'Oscilloscope'**
  String get visualizerOscilloscope;

  /// VU meter visualizer style
  ///
  /// In en, this message translates to:
  /// **'VU Meter'**
  String get visualizerVuMeter;

  /// Context menu: MusicBrainz metadata lookup
  ///
  /// In en, this message translates to:
  /// **'Look Up Info'**
  String get contextLookUpInfo;

  /// MusicBrainz results dialog title
  ///
  /// In en, this message translates to:
  /// **'MusicBrainz Lookup'**
  String get mbLookupTitle;

  /// Shown when MusicBrainz search returns nothing
  ///
  /// In en, this message translates to:
  /// **'No matches found on MusicBrainz.'**
  String get mbNoResults;

  /// MusicBrainz match confidence
  ///
  /// In en, this message translates to:
  /// **'Match: {score}%'**
  String mbScore(int score);

  /// Apply selected MusicBrainz metadata
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get mbApply;

  /// Snackbar shown while writing MusicBrainz tags
  ///
  /// In en, this message translates to:
  /// **'Writing tags...'**
  String get mbApplying;

  /// Snackbar shown after successful MB tag write
  ///
  /// In en, this message translates to:
  /// **'Metadata updated from MusicBrainz.'**
  String get mbApplied;

  /// Snackbar shown when MB tag write fails
  ///
  /// In en, this message translates to:
  /// **'Failed to update metadata: {error}'**
  String mbApplyError(String error);

  /// Context menu: MusicBrainz album lookup
  ///
  /// In en, this message translates to:
  /// **'Look Up Album'**
  String get contextLookUpAlbum;

  /// MusicBrainz album lookup dialog title
  ///
  /// In en, this message translates to:
  /// **'Album Lookup'**
  String get mbAlbumLookupTitle;

  /// Track matching summary in album lookup
  ///
  /// In en, this message translates to:
  /// **'{matched} of {total} tracks matched'**
  String mbTrackMatched(int matched, int total);

  /// Shown for tracks that already have MusicBrainz IDs
  ///
  /// In en, this message translates to:
  /// **'Already tagged'**
  String get mbAlreadyTagged;

  /// Auto-tag library page title
  ///
  /// In en, this message translates to:
  /// **'Auto-Tag Library'**
  String get mbAutoTagTitle;

  /// Auto-tag scan progress
  ///
  /// In en, this message translates to:
  /// **'Looking up {current} of {total} albums...'**
  String mbAutoTagProgress(int current, int total);

  /// Auto-tag scan complete message
  ///
  /// In en, this message translates to:
  /// **'Found matches for {count} albums'**
  String mbAutoTagComplete(int count);

  /// Shown when auto-tag finds no matches
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get mbAutoTagNoMatches;

  /// Start auto-tag scan button
  ///
  /// In en, this message translates to:
  /// **'Start Scan'**
  String get mbAutoTagStart;

  /// Auto-tag page description
  ///
  /// In en, this message translates to:
  /// **'Scan your library and look up album metadata from MusicBrainz. You can review and accept changes before they are applied.'**
  String get mbAutoTagDescription;

  /// Accept all matched albums in auto-tag
  ///
  /// In en, this message translates to:
  /// **'Accept All'**
  String get mbAcceptAll;

  /// Skip/reject an album match in auto-tag
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get mbReject;

  /// Accept a single album match in auto-tag
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get mbAccept;

  /// Confidence score for album match
  ///
  /// In en, this message translates to:
  /// **'Confidence: {score}%'**
  String mbConfidence(int score);

  /// Classic menu bar: File menu
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// Classic menu bar: Edit menu
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// Classic menu bar: Controls menu
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get menuControls;

  /// Classic menu bar: View menu
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// Classic menu bar: Tools menu
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get menuTools;

  /// Classic menu bar: Help menu
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// Classic menu bar: Quit item
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get menuQuit;

  /// Classic menu bar: Preferences item
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get menuPreferences;

  /// Classic menu bar: About item
  ///
  /// In en, this message translates to:
  /// **'About LoonBox'**
  String get menuAbout;

  /// Classic sidebar: Music library item
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get menuMusic;

  /// Classic track info bar: no track playing
  ///
  /// In en, this message translates to:
  /// **'Nothing selected'**
  String get nothingSelected;

  /// Done/OK button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Button to switch to manual search in MB lookup
  ///
  /// In en, this message translates to:
  /// **'Search manually'**
  String get mbManualSearch;

  /// Manual search field: title
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get mbSearchTitle;

  /// Manual search field: artist
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get mbSearchArtist;

  /// Search button in MB lookup
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get mbSearch;

  /// Context menu: remove track from playlist
  ///
  /// In en, this message translates to:
  /// **'Remove from Playlist'**
  String get contextRemoveFromPlaylist;

  /// Context menu: show track properties
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get contextProperties;

  /// Context menu: play all tracks in album
  ///
  /// In en, this message translates to:
  /// **'Play Album'**
  String get contextPlayAlbum;

  /// Context menu: add all album tracks to queue
  ///
  /// In en, this message translates to:
  /// **'Add Album to Queue'**
  String get contextAddAlbumToQueue;

  /// Home greeting: morning (5am-12pm)
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// Home greeting: afternoon (12pm-5pm)
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// Home greeting: evening (5pm-5am)
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// Home greeting: new user with no play history
  ///
  /// In en, this message translates to:
  /// **'Welcome to LoonBox'**
  String get homeWelcome;

  /// Insights card header
  ///
  /// In en, this message translates to:
  /// **'Your Listening'**
  String get homeYourListening;

  /// Privacy label on insights card
  ///
  /// In en, this message translates to:
  /// **'Private to you'**
  String get homePrivateToYou;

  /// Label under all-time listening stat
  ///
  /// In en, this message translates to:
  /// **'listened all time'**
  String get homeListenedAllTime;

  /// Label under weekly listening stat
  ///
  /// In en, this message translates to:
  /// **'this week'**
  String get homeThisWeek;

  /// Week-over-week trend
  ///
  /// In en, this message translates to:
  /// **'{percent}% vs last week'**
  String homeVsLastWeek(String percent);

  /// Label under streak stat
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get homeStreak;

  /// Label for top artist stat
  ///
  /// In en, this message translates to:
  /// **'Top artist this month'**
  String get homeTopArtistMonth;

  /// Collection stat: tracks
  ///
  /// In en, this message translates to:
  /// **'{count} tracks'**
  String homeStatsTracks(int count);

  /// Collection stat: albums
  ///
  /// In en, this message translates to:
  /// **'{count} albums'**
  String homeStatsAlbums(int count);

  /// Collection stat: artists
  ///
  /// In en, this message translates to:
  /// **'{count} artists'**
  String homeStatsArtists(int count);

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get homeRecentlyPlayed;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Top Albums'**
  String get homeTopAlbums;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Jump Back In'**
  String get homeJumpBackIn;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get homeRecentlyAdded;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Rediscover'**
  String get homeRediscover;

  /// Refresh button on discover section
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get homeRefresh;

  /// Discover reason: forgotten
  ///
  /// In en, this message translates to:
  /// **'You haven\'t listened to this in a while'**
  String get homeForgotten;

  /// Discover reason: never played
  ///
  /// In en, this message translates to:
  /// **'Albums you\'ve never played'**
  String get homeNeverPlayed;

  /// Discover fallback label
  ///
  /// In en, this message translates to:
  /// **'From your collection'**
  String get homeFromCollection;

  /// Play count label on top albums
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 play} other{{count} plays}}'**
  String homePlayCount(int count);

  /// Coming soon badge
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get homeComingSoon;

  /// Tremolo store name
  ///
  /// In en, this message translates to:
  /// **'Tremolo'**
  String get homeTremolo;

  /// Tremolo description
  ///
  /// In en, this message translates to:
  /// **'Discover & support artists directly'**
  String get homeTremoloDesc;

  /// The Nest marketplace name
  ///
  /// In en, this message translates to:
  /// **'The Nest'**
  String get homeNest;

  /// The Nest description
  ///
  /// In en, this message translates to:
  /// **'Feathers & extensions marketplace'**
  String get homeNestDesc;

  /// Onboarding: empty library title
  ///
  /// In en, this message translates to:
  /// **'Welcome to LoonBox'**
  String get homeEmptyTitle;

  /// Onboarding: step 1
  ///
  /// In en, this message translates to:
  /// **'Add your music'**
  String get homeEmptyAddMusic;

  /// Onboarding: step 2
  ///
  /// In en, this message translates to:
  /// **'Auto-tag your library'**
  String get homeEmptyAutoTag;

  /// Onboarding: auto-tag description
  ///
  /// In en, this message translates to:
  /// **'Let LoonBox identify and organize your music using MusicBrainz'**
  String get homeEmptyAutoTagDesc;

  /// Onboarding: auto-tag disabled tooltip
  ///
  /// In en, this message translates to:
  /// **'Add music first'**
  String get homeEmptyAutoTagDisabled;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
