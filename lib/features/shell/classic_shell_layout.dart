import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';
import '../../services/audio_service.dart';
import '../browser/browser_provider.dart';
import '../player/domain/player_state.dart';
import '../player/presentation/player_provider.dart';
import '../player/presentation/queue_provider.dart';
import '../player/presentation/album_art_widget.dart';
import 'app_shell.dart';
import 'shell_pages.dart';
import 'pages/playlists_page.dart';

/// Classic shell layout inspired by Songbird/Nightingale:
/// menu bar + top transport bar + tree sidebar (with album art) + content + status bar.
class ClassicShellLayout extends ConsumerWidget {
  const ClassicShellLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasBrowserTab = ref.watch(activeTabProvider) != null;

    return Column(
      children: [
        _ClassicMenuBar(),
        const _ClassicTransportBar(),
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
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 200,
                            child: _ClassicSidebarWithArt(),
                          ),
                          VerticalDivider(width: 1, thickness: 1),
                        ],
                      ),
              ),
              const Expanded(child: ShellContentArea()),
            ],
          ),
        ),
        const _ClassicStatusBar(),
      ],
    );
  }
}

// ── Menu Bar ──
// Left-aligned thin menu bar, matching Nightingale's style.

class _ClassicMenuBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final audio = ref.watch(audioServiceProvider);
    final playback = ref.watch(playbackStateProvider);
    final queueNotifier = ref.read(queueProvider.notifier);
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: const Color(0xFFDDDDDD),
    );
    const menuBg = Color(0xFF2B2B2B);

    final menuStyle = SubmenuButton.styleFrom(
      minimumSize: const Size(0, 28),
      padding: const EdgeInsets.symmetric(horizontal: 10),
    );
    const dropdownBg = Color(0xFFCCCCCC);
    const dropdownText = Color(0xFF2B2B2B);

    return Container(
      color: menuBg,
      alignment: Alignment.centerLeft,
      child: Theme(
        data: Theme.of(context).copyWith(
          menuTheme: MenuThemeData(
            style: MenuStyle(
              backgroundColor: const WidgetStatePropertyAll(dropdownBg),
              surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
          menuButtonTheme: MenuButtonThemeData(
            style: MenuItemButton.styleFrom(
              foregroundColor: dropdownText,
            ),
          ),
        ),
        child: MenuBar(
        style: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(menuBg),
          elevation: WidgetStatePropertyAll(0),
          padding: WidgetStatePropertyAll(EdgeInsets.zero),
        ),
        children: [
          SubmenuButton(
            style: menuStyle,
            menuChildren: [
              MenuItemButton(
                onPressed: () => ref.read(navIndexProvider.notifier).state = 1,
                child: Text(l10n.navSongs),
              ),
              const Divider(),
              MenuItemButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l10n.menuQuit),
              ),
            ],
            child: Text(l10n.menuFile, style: textStyle),
          ),
          SubmenuButton(
            style: menuStyle,
            menuChildren: [
              MenuItemButton(
                onPressed: () => ref.read(navIndexProvider.notifier).state = 6,
                child: Text(l10n.menuPreferences),
              ),
            ],
            child: Text(l10n.menuEdit, style: textStyle),
          ),
          SubmenuButton(
            style: menuStyle,
            menuChildren: [
              MenuItemButton(
                onPressed: () {
                  if (playback.state == PlaybackState.playing) {
                    audio.pause();
                  } else {
                    audio.play();
                  }
                },
                child: Text(playback.state == PlaybackState.playing ? l10n.playerPause : l10n.playerPlay),
              ),
              MenuItemButton(
                onPressed: () => queueNotifier.next(),
                child: Text(l10n.playerNext),
              ),
              MenuItemButton(
                onPressed: () => queueNotifier.previous(),
                child: Text(l10n.playerPrevious),
              ),
            ],
            child: Text(l10n.menuControls, style: textStyle),
          ),
          SubmenuButton(
            style: menuStyle,
            menuChildren: [
              MenuItemButton(
                onPressed: () {
                  ref.read(showNowPlayingProvider.notifier).state =
                      !ref.read(showNowPlayingProvider);
                },
                child: Text(l10n.playerNowPlaying),
              ),
            ],
            child: Text(l10n.menuView, style: textStyle),
          ),
          SubmenuButton(
            style: menuStyle,
            menuChildren: [
              MenuItemButton(
                onPressed: () => ref.read(navIndexProvider.notifier).state = 6,
                child: Text(l10n.settingsEqualizer),
              ),
            ],
            child: Text(l10n.menuTools, style: textStyle),
          ),
          SubmenuButton(
            style: menuStyle,
            menuChildren: [
              MenuItemButton(
                onPressed: () {
                  showAboutDialog(
                    context: context,
                    applicationName: l10n.appTitle,
                    applicationVersion: '0.1.0',
                    applicationLegalese: '\u00a9 2026 MPLS LLC',
                  );
                },
                child: Text(l10n.menuAbout),
              ),
            ],
            child: Text(l10n.menuHelp, style: textStyle),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Transport Bar ──

class _ClassicTransportBar extends ConsumerWidget {
  const _ClassicTransportBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioServiceProvider);
    final playback = ref.watch(playbackStateProvider);
    final queueNotifier = ref.read(queueProvider.notifier);

    final hasTrack = playback.currentTrack != null;
    final posMs = playback.positionMs.toDouble();
    final durMs = playback.durationMs > 0 ? playback.durationMs.toDouble() : 1.0;
    final isPlaying = playback.state == PlaybackState.playing;
    final queue = ref.watch(queueProvider);
    final queueTrack = queue.currentTrack;

    // Volume slider — blue active / gray inactive matching original asset
    final volumeSliderData = SliderTheme.of(context).copyWith(
      trackHeight: 4,
      trackShape: const RoundedRectSliderTrackShape(),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
      activeTrackColor: const Color(0xFF5A8AAD),
      inactiveTrackColor: const Color(0xFF8A8A8A),
      thumbColor: const Color(0xFF6A9BBD),
    );

    // Seekbar — blue active track, small notch thumb
    final seekSliderData = SliderTheme.of(context).copyWith(
      trackHeight: 5,
      trackShape: const RoundedRectSliderTrackShape(),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 6),
      activeTrackColor: const Color(0xFF2F5F82),
      inactiveTrackColor: const Color(0xFF3A3A3A),
      thumbColor: const Color(0xFF5AC0C0),
    );

    return Container(
      height: 58,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCCCCCC), Color(0xFFB4B4B4)],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFF808080), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          // Transport buttons — prev (rounded rect), play (circle), next (rounded rect)
          _TransportButton(
            icon: Icons.skip_previous_rounded,
            svgAsset: 'assets/icons/classic/prev.svg',
            size: 36,
            iconSize: 18,
            circular: false,
            onPressed: () => queueNotifier.previous(),
          ),
          const SizedBox(width: 2),
          _TransportButton(
            icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            svgAsset: isPlaying
                ? 'assets/icons/classic/pause.svg'
                : 'assets/icons/classic/play.svg',
            size: 44,
            iconSize: 22,
            onPressed: () {
              if (isPlaying) {
                audio.pause();
              } else {
                audio.play();
              }
            },
          ),
          const SizedBox(width: 2),
          _TransportButton(
            icon: Icons.skip_next_rounded,
            svgAsset: 'assets/icons/classic/next.svg',
            size: 36,
            iconSize: 18,
            circular: false,
            onPressed: () => queueNotifier.next(),
          ),

          const SizedBox(width: 6),

          // Volume — icon + slider
          SvgPicture.asset(
            playback.isMuted || playback.volume == 0
                ? 'assets/icons/classic/vol_mute.svg'
                : playback.volume < 0.5
                    ? 'assets/icons/classic/vol_low.svg'
                    : 'assets/icons/classic/vol_high.svg',
            width: 14,
            height: 14,
            colorFilter: const ColorFilter.mode(
              Color(0xFF555555),
              BlendMode.srcIn,
            ),
          ),
          SizedBox(
            width: 65,
            child: SliderTheme(data: volumeSliderData, child: Slider(
              value: playback.isMuted ? 0 : playback.volume,
              onChanged: (v) {
                ref.read(playbackStateProvider.notifier).setVolume(v);
                audio.setVolume(v);
              },
            )),
          ),

          const SizedBox(width: 4),

          // Stop, shuffle, repeat — dark rounded rect toggle buttons
          _ToggleButton(
            svgAsset: 'assets/icons/classic/stop.svg',
            icon: Icons.stop_rounded,
            onPressed: () => audio.stop(),
          ),
          _ToggleButton(
            svgAsset: 'assets/icons/classic/shuffle.svg',
            icon: Icons.shuffle_rounded,
            active: queue.isShuffled,
            onPressed: () => queueNotifier.toggleShuffle(),
          ),
          _ToggleButton(
            svgAsset: playback.repeat == RepeatMode.one
                ? 'assets/icons/classic/repeat_one.svg'
                : 'assets/icons/classic/repeat.svg',
            icon: Icons.repeat_rounded,
            active: playback.repeat != RepeatMode.off,
            onPressed: () => ref.read(playbackStateProvider.notifier).cycleRepeat(),
          ),

          const SizedBox(width: 6),

          // ── Faceplate: dark rounded panel with track info + seekbar ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A2A2A), Color(0xFF1E1E1E), Color(0xFF161616)],
                  stops: [0.0, 0.3, 1.0],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0A0A0A), width: 1),
                boxShadow: const [
                  // Outer shadow for depth
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                  // Inner highlight at top edge
                  BoxShadow(
                    color: Color(0x18FFFFFF),
                    blurRadius: 1,
                    offset: Offset(0, -1),
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Track info — bold title • artist • album
                  Row(
                    children: [
                      Expanded(
                        child: hasTrack
                            ? Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: queueTrack?.title ?? '',
                                      style: const TextStyle(
                                        color: Color(0xFFDDDDDD),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (queueTrack?.artist != null)
                                      TextSpan(
                                        text: ' \u2022 ${queueTrack!.artist}',
                                        style: const TextStyle(
                                          color: Color(0xFFAAAAAA),
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    if (queueTrack?.album != null)
                                      TextSpan(
                                        text: ' \u2022 ${queueTrack!.album}',
                                        style: const TextStyle(
                                          color: Color(0xFFAAAAAA),
                                          fontSize: 11.5,
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  // Seekbar with timestamps
                  Row(
                    children: [
                      Text(
                        _formatTime(playback.positionMs),
                        style: const TextStyle(
                          color: Color(0xFF8A8A8A),
                          fontSize: 10,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(data: seekSliderData, child: Slider(
                          value: posMs.clamp(0, durMs),
                          max: durMs,
                          onChanged: hasTrack ? (v) => audio.seek(v.toInt()) : null,
                        )),
                      ),
                      Text(
                        _formatTime(playback.durationMs),
                        style: const TextStyle(
                          color: Color(0xFF8A8A8A),
                          fontSize: 10,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

/// Silver metallic transport button matching Nightingale's brushed-metal look.
/// Play/stop are circular; prev/next are rounded rectangles.
class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    this.svgAsset,
    required this.size,
    required this.iconSize,
    required this.onPressed,
    this.circular = true,
  });

  final IconData icon;
  final String? svgAsset;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    // Fixed silver metallic colors — not theme-derived
    const baseColor = Color(0xFFB8B8B8);
    const highlightColor = Color(0xFFD8D8D8);
    const shadowColor = Color(0xFF888888);
    const iconColor = Color(0xFF4A4A4A);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: circular ? size : size * 0.85,
        decoration: BoxDecoration(
          shape: circular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circular ? null : BorderRadius.circular(6),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [highlightColor, baseColor, shadowColor],
            stops: [0.0, 0.45, 1.0],
          ),
          border: Border.all(color: const Color(0xFF707070), width: 0.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: svgAsset != null
              ? SvgPicture.asset(
                  svgAsset!,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: const ColorFilter.mode(
                    iconColor,
                    BlendMode.srcIn,
                  ),
                )
              : Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }
}

/// Dark rounded-rect toggle button for shuffle/repeat/stop —
/// matches the Nightingale toolbar toggle style.
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    this.svgAsset,
    this.active = false,
    required this.onPressed,
  });

  final IconData icon;
  final String? svgAsset;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bgColor = active ? const Color(0xFF3A3A3A) : const Color(0xFF4A4A4A);
    final iconColor = active ? const Color(0xFF7EB8E0) : const Color(0xFFAAAAAA);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF333333), width: 0.5),
        ),
        child: Center(
          child: svgAsset != null
              ? SvgPicture.asset(
                  svgAsset!,
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                )
              : Icon(icon, size: 14, color: iconColor),
        ),
      ),
    );
  }
}

// ── Sidebar with Album Art Panel ──

/// Combines the tree navigation with an album art panel at the bottom,
/// matching Nightingale's layout where current track art is shown below the tree.
class _ClassicSidebarWithArt extends ConsumerWidget {
  const _ClassicSidebarWithArt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackStateProvider);
    final trackInfo = playback.currentTrack;
    final queue = ref.watch(queueProvider);
    final queueTrack = queue.currentTrack;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          // Tree navigation (scrollable, takes remaining space)
          const Expanded(child: _ClassicTreeSidebar()),

          // Album art panel at bottom of sidebar (like Nightingale)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withAlpha(80),
                ),
              ),
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: trackInfo != null
                  ? GestureDetector(
                      onTap: () {
                        ref.read(showNowPlayingProvider.notifier).state =
                            !ref.read(showNowPlayingProvider);
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AlbumArtWidget(
                            trackPath: trackInfo.path,
                            size: 200,
                            borderRadius: 0,
                            iconSize: 64,
                          ),
                          // Track info overlay at bottom
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withAlpha(180),
                                  ],
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    queueTrack?.title ??
                                        trackInfo.path
                                            .split('/')
                                            .last
                                            .split('\\')
                                            .last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (queueTrack?.artist != null)
                                    Text(
                                      queueTrack!.artist!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.labelSmall?.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Text(
                          'Nothing selected',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tree Sidebar ──

class _ClassicTreeSidebar extends ConsumerWidget {
  const _ClassicTreeSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(navIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final playlistsAsync = ref.watch(playlistListProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _TreeItem(
          icon: Icons.home,
          label: l10n.navHome,
          selected: navIndex == 0,
          onTap: () => _navigate(ref, 0),
        ),

        const Divider(height: 16),

        // Library section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            l10n.navLibrary,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _TreeItem(
          icon: Icons.library_music,
          label: l10n.navSongs,
          selected: navIndex == 1,
          onTap: () => _navigate(ref, 1),
        ),
        _TreeItem(
          icon: Icons.album,
          label: l10n.navAlbums,
          selected: navIndex == 2,
          onTap: () => _navigate(ref, 2),
          indent: 1,
        ),
        _TreeItem(
          icon: Icons.person,
          label: l10n.navArtists,
          selected: navIndex == 3,
          onTap: () => _navigate(ref, 3),
          indent: 1,
        ),

        const Divider(height: 16),

        // Playlists section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            l10n.navPlaylists,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _TreeItem(
          icon: Icons.queue_music,
          label: l10n.navPlaylists,
          selected: navIndex == 4,
          onTap: () => _navigate(ref, 4),
        ),
        // Show actual playlists
        ...playlistsAsync.whenOrNull(
              data: (playlists) => playlists.map(
                (p) => _TreeItem(
                  icon: Icons.music_note,
                  label: p.name,
                  selected: false,
                  onTap: () => _navigate(ref, 4),
                  indent: 1,
                ),
              ),
            ) ??
            [],

        const Divider(height: 16),

        _TreeItem(
          icon: Icons.search,
          label: l10n.navSearch,
          selected: navIndex == 5,
          onTap: () => _navigate(ref, 5),
        ),
        _TreeItem(
          icon: Icons.settings,
          label: l10n.navSettings,
          selected: navIndex == 6,
          onTap: () => _navigate(ref, 6),
        ),
      ],
    );
  }

  void _navigate(WidgetRef ref, int index) {
    if (ref.read(showNowPlayingProvider)) {
      ref.read(showNowPlayingProvider.notifier).state = false;
    }
    final current = ref.read(navIndexProvider);
    if (index == current) {
      shellNavigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      ref.read(navIndexProvider.notifier).state = index;
    }
  }
}

class _TreeItem extends StatelessWidget {
  const _TreeItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.indent = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int indent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0 + indent * 16.0,
            right: 8,
            top: 6,
            bottom: 6,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status Bar (bottom) ──
// Replaces the old track info bar with a Nightingale-style status bar:
// left: current track info with art, right: item count / codec info

class _ClassicStatusBar extends ConsumerWidget {
  const _ClassicStatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackStateProvider);
    final trackInfo = playback.currentTrack;
    final queue = ref.watch(queueProvider);
    final queueTrack = queue.currentTrack;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    final statusStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return GestureDetector(
      onTap: trackInfo != null
          ? () {
              ref.read(showNowPlayingProvider.notifier).state =
                  !ref.read(showNowPlayingProvider);
            }
          : null,
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          color: colorScheme.surfaceDim,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withAlpha(80),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Left: now playing status
            if (trackInfo != null) ...[
              Icon(
                playback.state == PlaybackState.playing
                    ? Icons.play_arrow
                    : Icons.pause,
                size: 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${queueTrack?.title ?? trackInfo.path.split('/').last.split('\\').last}'
                  '${queueTrack?.artist != null ? ' \u2022 ${queueTrack!.artist}' : ''}'
                  '${queueTrack?.album != null ? ' \u2022 ${queueTrack!.album}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: statusStyle,
                ),
              ),
            ] else
              Expanded(
                child: Text(l10n.nothingSelected, style: statusStyle),
              ),

            // Right: codec + queue count
            if (trackInfo != null) ...[
              Text(
                trackInfo.codec.toUpperCase(),
                style: statusStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (queue.tracks.isNotEmpty)
              Text(
                l10n.queueTrackCount(queue.tracks.length),
                style: statusStyle,
              ),
          ],
        ),
      ),
    );
  }
}
