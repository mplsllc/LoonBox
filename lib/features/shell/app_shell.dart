import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../player/presentation/now_playing_bar.dart';
import 'pages/library_page.dart';
import 'pages/albums_page.dart';
import 'pages/artists_page.dart';
import 'pages/playlists_page.dart';
import 'pages/settings_page.dart';

/// The currently selected navigation index.
final navIndexProvider = StateProvider<int>((ref) => 0);

/// Main app shell: sidebar + content area + persistent now-playing bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(navIndexProvider);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final pages = const [
      LibraryPage(),
      AlbumsPage(),
      ArtistsPage(),
      PlaylistsPage(),
      SettingsPage(),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Sidebar
                NavigationRail(
                  selectedIndex: navIndex,
                  onDestinationSelected: (index) {
                    ref.read(navIndexProvider.notifier).state = index;
                  },
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: colorScheme.surfaceContainerLow,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.library_music_outlined),
                      selectedIcon: const Icon(Icons.library_music),
                      label: Text(l10n.navLibrary),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.album_outlined),
                      selectedIcon: const Icon(Icons.album),
                      label: Text(l10n.navAlbums),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_outlined),
                      selectedIcon: const Icon(Icons.person),
                      label: Text(l10n.navArtists),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.queue_music_outlined),
                      selectedIcon: const Icon(Icons.queue_music),
                      label: Text(l10n.navPlaylists),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.settings_outlined),
                      selectedIcon: const Icon(Icons.settings),
                      label: Text(l10n.navSettings),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                // Content area
                Expanded(
                  child: pages[navIndex],
                ),
              ],
            ),
          ),
          // Now-playing bar at bottom
          const NowPlayingBar(),
        ],
      ),
    );
  }
}
