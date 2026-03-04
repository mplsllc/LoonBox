import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/audio_service.dart';
import '../domain/player_state.dart';
import 'player_provider.dart';

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

    final hasTrack = playback.currentTrack != null;
    final isPlaying = playback.state == PlaybackState.playing;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Seek progress bar
          if (hasTrack && playback.durationMs > 0)
            LinearProgressIndicator(
              value: playback.positionMs / playback.durationMs,
              minHeight: 2,
              backgroundColor: colorScheme.surfaceContainerHighest,
            )
          else
            const SizedBox(height: 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Album art placeholder
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.music_note,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Track info
                  Expanded(
                    child: hasTrack
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playback.currentTrack!.path.split('/').last.split('\\').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
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
                  // Position / duration
                  if (hasTrack)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        '${_formatTime(playback.positionMs)} / ${_formatTime(playback.durationMs)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  // Transport controls
                  Semantics(
                    label: l10n.playerPrevious,
                    child: IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: hasTrack ? () => audio.queuePrevious() : null,
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
                      onPressed: hasTrack ? () => audio.queueNext() : null,
                      tooltip: l10n.playerNext,
                    ),
                  ),
                  // Volume
                  Semantics(
                    label: l10n.playerVolume,
                    child: SizedBox(
                      width: 120,
                      child: Slider(
                        value: playback.volume,
                        onChanged: (v) {
                          ref.read(playbackStateProvider.notifier).setVolume(v);
                          audio.setVolume(v);
                        },
                      ),
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
