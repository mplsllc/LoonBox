import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/audio_service.dart';
import '../../services/media_controls_service.dart';
import '../player/domain/player_state.dart';
import '../player/presentation/now_playing_bar.dart';
import '../player/presentation/player_provider.dart';
import '../player/presentation/queue_provider.dart';
import 'pages/library_page.dart';
import 'pages/albums_page.dart';
import 'pages/artists_page.dart';
import 'pages/playlists_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';

/// The currently selected navigation index.
final navIndexProvider = StateProvider<int>((ref) => 0);

/// Main app shell: sidebar + content area + persistent now-playing bar.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _mediaControlsInitialized = false;

  @override
  Widget build(BuildContext context) {
    // Activate the audio event listener so engine events update UI state.
    ref.watch(audioEventListenerProvider);

    // Initialize media controls once (needs queue notifier from provider scope)
    if (!_mediaControlsInitialized) {
      _mediaControlsInitialized = true;
      final mediaControls = ref.read(mediaControlsServiceProvider);
      final queueNotifier = ref.read(queueProvider.notifier);
      mediaControls.init(
        () => queueNotifier.next(),
        () => queueNotifier.previous(),
      );
    }

    final navIndex = ref.watch(navIndexProvider);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    const pages = [
      LibraryPage(),
      AlbumsPage(),
      ArtistsPage(),
      PlaylistsPage(),
      SearchPage(),
      SettingsPage(),
    ];

    final audio = ref.watch(audioServiceProvider);
    final playback = ref.watch(playbackStateProvider);
    final queueNotifier = ref.read(queueProvider.notifier);
    final volumeNotifier = ref.read(playbackStateProvider.notifier);

    return CallbackShortcuts(
      bindings: {
        // Space: play/pause
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (playback.state == PlaybackState.playing) {
            audio.pause();
          } else {
            audio.play();
          }
        },
        // Ctrl+Right: next track
        const SingleActivator(LogicalKeyboardKey.arrowRight,
            control: true): () {
          queueNotifier.next();
        },
        // Ctrl+Left: previous track
        const SingleActivator(LogicalKeyboardKey.arrowLeft,
            control: true): () {
          queueNotifier.previous();
        },
        // Ctrl+Up: volume up
        const SingleActivator(LogicalKeyboardKey.arrowUp,
            control: true): () {
          final newVol = (playback.volume + 0.05).clamp(0.0, 1.0);
          volumeNotifier.setVolume(newVol);
          audio.setVolume(newVol);
        },
        // Ctrl+Down: volume down
        const SingleActivator(LogicalKeyboardKey.arrowDown,
            control: true): () {
          final newVol = (playback.volume - 0.05).clamp(0.0, 1.0);
          volumeNotifier.setVolume(newVol);
          audio.setVolume(newVol);
        },
        // Ctrl+M: mute toggle
        const SingleActivator(LogicalKeyboardKey.keyM, control: true): () {
          volumeNotifier.toggleMute();
          audio.setVolume(playback.isMuted ? playback.volume : 0.0);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                          icon: const Icon(Icons.search_outlined),
                          selectedIcon: const Icon(Icons.search),
                          label: Text(l10n.navSearch),
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
        ),
      ),
    );
  }
}
