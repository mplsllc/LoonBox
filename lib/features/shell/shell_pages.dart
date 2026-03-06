import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../browser/browser_provider.dart';
import '../browser/browser_tab_content.dart';
import '../player/presentation/now_playing_page.dart';
import 'app_shell.dart';
import 'pages/home_page.dart';
import 'pages/songs_page.dart';
import 'pages/albums_page.dart';
import 'pages/artists_page.dart';
import 'pages/playlists_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';

/// The content pages available in all shell layouts.
/// Index-aligned with [navIndexProvider] values.
const shellPages = <Widget>[
  HomePage(), // 0
  SongsPage(), // 1
  AlbumsPage(), // 2
  ArtistsPage(), // 3
  PlaylistsPage(), // 4
  SearchPage(), // 5
  SettingsPage(), // 6
];

/// Navigator keys for each tab, enabling push/pop within content area.
final shellNavigatorKeys = List.generate(
  shellPages.length,
  (_) => GlobalKey<NavigatorState>(),
);

/// Content area shared by all shell layouts.
/// Shows the Now Playing overlay, a browser tab, or the current library page.
class ShellContentArea extends ConsumerWidget {
  const ShellContentArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeTabProvider);

    // Browser tab active — show browser content
    if (activeTab != null) {
      return BrowserTabContent(tabId: activeTab);
    }

    // Now Playing overlay
    if (ref.watch(showNowPlayingProvider)) {
      return const NowPlayingPage();
    }

    // Library page
    final navIndex = ref.watch(navIndexProvider);
    return Navigator(
      key: shellNavigatorKeys[navIndex],
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => shellPages[navIndex],
      ),
    );
  }
}
