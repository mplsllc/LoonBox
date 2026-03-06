import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../browser/browser_provider.dart';
import '../player/presentation/now_playing_bar.dart';
import 'app_shell.dart';
import 'shell_pages.dart';

/// Modern shell layout: NavigationRail sidebar + content area + NowPlayingBar.
class ModernShellLayout extends ConsumerWidget {
  const ModernShellLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(navIndexProvider);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final hasBrowserTab = ref.watch(activeTabProvider) != null;

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Sidebar collapses smoothly when a browser tab is active
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.centerLeft,
                child: hasBrowserTab
                    ? const SizedBox.shrink()
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NavigationRail(
                            selectedIndex: navIndex,
                            onDestinationSelected: (index) {
                              if (ref.read(showNowPlayingProvider)) {
                                ref
                                    .read(showNowPlayingProvider.notifier)
                                    .state = false;
                              }
                              if (index == navIndex) {
                                shellNavigatorKeys[index]
                                    .currentState
                                    ?.popUntil((route) => route.isFirst);
                              } else {
                                ref.read(navIndexProvider.notifier).state =
                                    index;
                              }
                            },
                            labelType: NavigationRailLabelType.all,
                            backgroundColor: colorScheme.surfaceContainerLow,
                            destinations: [
                              NavigationRailDestination(
                                icon: const Icon(Icons.home_outlined),
                                selectedIcon: const Icon(Icons.home),
                                label: Text(l10n.navHome),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.library_music_outlined),
                                selectedIcon: const Icon(Icons.library_music),
                                label: Text(l10n.navSongs),
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
                        ],
                      ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft:
                        hasBrowserTab ? Radius.zero : const Radius.circular(8),
                  ),
                  child: const ShellContentArea(),
                ),
              ),
            ],
          ),
        ),
        const NowPlayingBar(),
      ],
    );
  }
}
