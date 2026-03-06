import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/audio_service.dart';
import '../../shell/app_shell.dart';
import '../../shell/widgets/track_context_menu.dart';
import '../domain/player_state.dart';
import 'album_art_widget.dart';
import 'player_provider.dart';
import 'queue_provider.dart';

/// Persistent now-playing bar shown at the bottom of the app.
class NowPlayingBar extends ConsumerWidget {
  const NowPlayingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playback = ref.watch(playbackStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final audio = ref.watch(audioServiceProvider);

    final queue = ref.watch(queueProvider);
    final hasTrack = playback.currentTrack != null;
    final isPlaying = playback.state == PlaybackState.playing;
    final queueTrack = queue.currentTrack;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Interactive seek bar
          if (hasTrack && playback.durationMs > 0)
            SizedBox(
              height: 4,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                  activeTrackColor: colorScheme.primary,
                  inactiveTrackColor: colorScheme.surfaceContainerHighest,
                ),
                child: Slider(
                  value: playback.positionMs.toDouble().clamp(0, playback.durationMs.toDouble()),
                  max: playback.durationMs.toDouble(),
                  onChanged: (v) => audio.seek(v.toInt()),
                ),
              ),
            )
          else
            const SizedBox(height: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Left: Album art + track info
                  Expanded(
                    child: GestureDetector(
                      onTap: hasTrack
                          ? () {
                              final notifier = ref.read(showNowPlayingProvider.notifier);
                              notifier.state = !notifier.state;
                            }
                          : null,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          AlbumArtWidget(
                            trackPath: playback.currentTrack?.path,
                            size: 48,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: hasTrack
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        queueTrack?.title ?? playback.currentTrack!.path.split('/').last.split('\\').last,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      queueTrack?.artist != null
                                          ? MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: GestureDetector(
                                                onTap: () => navigateToArtistByName(
                                                  context,
                                                  ref.read(databaseProvider),
                                                  queueTrack!.artist!,
                                                ),
                                                child: Text(
                                                  queueTrack!.artist!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: textTheme.bodySmall?.copyWith(
                                                    color: colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Text(
                                              '${playback.currentTrack!.codec} · ${playback.currentTrack!.sampleRate}Hz',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: textTheme.bodySmall?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                    ],
                                  )
                                : Text(
                                    l10n.playerNoTrack,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Center: Transport controls
                  Semantics(
                    label: queue.isShuffled ? l10n.playerShuffleOn : l10n.playerShuffleOff,
                    child: IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        color: queue.isShuffled ? colorScheme.primary : null,
                      ),
                      iconSize: 20,
                      onPressed: hasTrack ? () => ref.read(queueProvider.notifier).toggleShuffle() : null,
                      tooltip: l10n.playerShuffle,
                    ),
                  ),
                  Semantics(
                    label: l10n.playerPrevious,
                    child: IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: hasTrack ? () => ref.read(queueProvider.notifier).previous() : null,
                      tooltip: l10n.playerPrevious,
                    ),
                  ),
                  Semantics(
                    label: isPlaying ? l10n.playerPause : l10n.playerPlay,
                    child: IconButton(
                      icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                      iconSize: 36,
                      onPressed: hasTrack
                          ? () {
                              if (isPlaying) {
                                audio.pause();
                              } else {
                                audio.play();
                              }
                            }
                          : null,
                      tooltip: isPlaying ? l10n.playerPause : l10n.playerPlay,
                    ),
                  ),
                  Semantics(
                    label: l10n.playerNext,
                    child: IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: hasTrack ? () => ref.read(queueProvider.notifier).next() : null,
                      tooltip: l10n.playerNext,
                    ),
                  ),
                  Semantics(
                    label: switch (playback.repeat) {
                      RepeatMode.off => l10n.playerRepeatOff,
                      RepeatMode.all => l10n.playerRepeatAll,
                      RepeatMode.one => l10n.playerRepeatOne,
                    },
                    child: IconButton(
                      icon: Icon(
                        playback.repeat == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
                        color: playback.repeat != RepeatMode.off ? colorScheme.primary : null,
                      ),
                      iconSize: 20,
                      onPressed: hasTrack ? () => ref.read(playbackStateProvider.notifier).cycleRepeat() : null,
                      tooltip: l10n.playerRepeat,
                    ),
                  ),
                  // Right: Time + Volume
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (hasTrack)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '${_formatTime(playback.positionMs)} / ${_formatTime(playback.durationMs)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontFeatures: [const FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        IconButton(
                          icon: Icon(
                            playback.isMuted || playback.volume == 0
                                ? Icons.volume_off
                                : playback.volume < 0.5
                                    ? Icons.volume_down
                                    : Icons.volume_up,
                          ),
                          iconSize: 20,
                          onPressed: () {
                            final notifier = ref.read(playbackStateProvider.notifier);
                            notifier.toggleMute();
                            audio.setVolume(playback.isMuted ? playback.volume : 0.0);
                          },
                          tooltip: l10n.playerVolume,
                        ),
                        Semantics(
                          label: l10n.playerVolume,
                          child: SizedBox(
                            width: 100,
                            child: Slider(
                              value: playback.isMuted ? 0 : playback.volume,
                              onChanged: (v) {
                                final notifier = ref.read(playbackStateProvider.notifier);
                                if (playback.isMuted) notifier.toggleMute();
                                notifier.setVolume(v);
                                audio.setVolume(v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
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
    final total = Duration(milliseconds: ms);
    final m = total.inMinutes;
    final s = total.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
