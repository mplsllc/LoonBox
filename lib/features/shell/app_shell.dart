import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../services/audio_service.dart';
import '../../services/media_controls_service.dart';
import '../../services/tray_service.dart';
import '../../theme/feather_manifest.dart';
import '../../theme/loonbox_theme.dart';
import '../player/domain/player_state.dart';
import '../player/presentation/player_provider.dart';
import '../player/presentation/queue_provider.dart';
import 'classic_shell_layout.dart';
import 'modern_shell_layout.dart';
import 'widgets/app_title_bar.dart';
import 'widgets/auto_tag_mini_banner.dart';

/// The currently selected navigation index.
final navIndexProvider = StateProvider<int>((ref) => 0);

/// Whether the full Now Playing view is shown (overlays content area).
final showNowPlayingProvider = StateProvider<bool>((ref) => false);

/// Main app shell: shared concerns (services, shortcuts, window lifecycle)
/// with layout delegated to shell widgets based on the active feather.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WindowListener {
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    // Activate the audio event listener so engine events update UI state.
    ref.watch(audioEventListenerProvider);

    // Initialize media controls + tray once (needs provider scope)
    if (!_servicesInitialized) {
      _servicesInitialized = true;
      final mediaControls = ref.read(mediaControlsServiceProvider);
      final queueNotifier = ref.read(queueProvider.notifier);
      mediaControls.init(
        () => queueNotifier.next(),
        () => queueNotifier.previous(),
      );
      ref.read(trayServiceProvider).init();
    }

    final audio = ref.watch(audioServiceProvider);
    final playback = ref.watch(playbackStateProvider);
    final queueNotifier = ref.read(queueProvider.notifier);
    final volumeNotifier = ref.read(playbackStateProvider.notifier);

    // Select shell layout based on active feather
    final feather = ref.watch(loonBoxThemeProvider);
    final sidebarStyle = feather.manifest?.sidebarStyle ?? SidebarStyle.rail;
    final shellLayout = switch (sidebarStyle) {
      SidebarStyle.tree => const ClassicShellLayout(),
      _ => const ModernShellLayout(),
    };

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (playback.state == PlaybackState.playing) {
            audio.pause();
          } else {
            audio.play();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight,
            control: true): () {
          queueNotifier.next();
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft,
            control: true): () {
          queueNotifier.previous();
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp,
            control: true): () {
          final newVol = (playback.volume + 0.05).clamp(0.0, 1.0);
          volumeNotifier.setVolume(newVol);
          audio.setVolume(newVol);
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown,
            control: true): () {
          final newVol = (playback.volume - 0.05).clamp(0.0, 1.0);
          volumeNotifier.setVolume(newVol);
          audio.setVolume(newVol);
        },
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
              const AppTitleBar(),
              const AutoTagMiniBanner(),
              Expanded(child: shellLayout),
            ],
          ),
        ),
      ),
    );
  }
}
