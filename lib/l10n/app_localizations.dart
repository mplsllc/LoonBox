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
