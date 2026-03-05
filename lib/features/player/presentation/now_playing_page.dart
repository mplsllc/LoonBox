import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/audio_service.dart';
import '../../shell/app_shell.dart';
import '../domain/player_state.dart';
import 'album_art_widget.dart';
import 'player_provider.dart';
import 'queue_provider.dart';
import 'visualization_provider.dart';
import 'visualizer_widget.dart';

/// Full-screen now-playing view with large album art and queue.
class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playback = ref.watch(playbackStateProvider);
    final queue = ref.watch(queueProvider);
    final audio = ref.watch(audioServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isPlaying = playback.state == PlaybackState.playing;
    final queueTrack = queue.currentTrack;
    final vizEnabled = ref.watch(visualizationEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(showNowPlayingProvider.notifier).state = false,
        ),
        title: Text(l10n.nowPlayingTitle),
        actions: [
          // Visualizer toggle
          IconButton(
            icon: Icon(
              Icons.equalizer,
              color: vizEnabled ? colorScheme.primary : null,
            ),
            tooltip: l10n.visualizer,
            onPressed: () {
              ref.read(visualizationEnabledProvider.notifier).state =
                  !vizEnabled;
            },
          ),
          if (queue.tracks.isNotEmpty)
            TextButton.icon(
              onPressed: () => ref.read(queueProvider.notifier).clear(),
              icon: const Icon(Icons.clear_all, size: 18),
              label: Text(l10n.queueClear),
            ),
        ],
      ),
      body: Row(
        children: [
          // Left side: current track
          Expanded(
            flex: 3,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Album art
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: AlbumArtWidget(
                        trackPath: playback.currentTrack?.path,
                        size: vizEnabled ? 220 : 300,
                        borderRadius: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Visualizer (shown between art and info when enabled)
                    if (vizEnabled)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const VisualizerWidget(height: 120),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                    // Track info
                    Text(
                      queueTrack?.title ??
                          playback.currentTrack?.path
                              .split('/')
                              .last
                              .split('\\')
                              .last ??
                          l10n.playerNoTrack,
                      style: textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      queueTrack?.artist ?? '',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (queueTrack?.album != null)
                      Text(
                        queueTrack!.album!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 24),
                    // Seek slider
                    if (playback.durationMs > 0) ...[
                      Slider(
                        value: playback.positionMs
                            .toDouble()
                            .clamp(0, playback.durationMs.toDouble()),
                        max: playback.durationMs.toDouble(),
                        onChanged: (v) => audio.seek(v.toInt()),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTime(playback.positionMs),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontFeatures: [
                                  const FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            Text(
                              _formatTime(playback.durationMs),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontFeatures: [
                                  const FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Transport controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle,
                            color:
                                queue.isShuffled ? colorScheme.primary : null,
                          ),
                          onPressed: () =>
                              ref.read(queueProvider.notifier).toggleShuffle(),
                          tooltip: l10n.playerShuffle,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          iconSize: 36,
                          onPressed: () =>
                              ref.read(queueProvider.notifier).previous(),
                          tooltip: l10n.playerPrevious,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled),
                          iconSize: 56,
                          onPressed: () {
                            if (isPlaying) {
                              audio.pause();
                            } else {
                              audio.play();
                            }
                          },
                          tooltip: isPlaying
                              ? l10n.playerPause
                              : l10n.playerPlay,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          iconSize: 36,
                          onPressed: () =>
                              ref.read(queueProvider.notifier).next(),
                          tooltip: l10n.playerNext,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            playback.repeat == RepeatMode.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: playback.repeat != RepeatMode.off
                                ? colorScheme.primary
                                : null,
                          ),
                          onPressed: () => ref
                              .read(playbackStateProvider.notifier)
                              .cycleRepeat(),
                          tooltip: l10n.playerRepeat,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // Right side: queue
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(l10n.upNext, style: textTheme.titleMedium),
                      const Spacer(),
                      Text(
                        l10n.queueTrackCount(queue.tracks.length),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: queue.tracks.isEmpty
                      ? Center(
                          child: Text(
                            l10n.queueEmpty,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: queue.tracks.length,
                          onReorder: (oldIdx, newIdx) {
                            ref
                                .read(queueProvider.notifier)
                                .reorder(oldIdx, newIdx);
                          },
                          itemBuilder: (context, index) {
                            final track = queue.tracks[index];
                            final isCurrent = index == queue.currentIndex;
                            return ListTile(
                              key: ValueKey('${track.id}_$index'),
                              leading: isCurrent
                                  ? Icon(Icons.play_arrow,
                                      color: colorScheme.primary)
                                  : ReorderableDragStartListener(
                                      index: index,
                                      child: const Icon(Icons.drag_handle),
                                    ),
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: isCurrent
                                    ? textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      )
                                    : null,
                              ),
                              subtitle: Text(
                                track.artist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  ref
                                      .read(queueProvider.notifier)
                                      .removeAt(index);
                                },
                              ),
                              onTap: () {
                                ref.read(queueProvider.notifier).jumpTo(index);
                              },
                            );
                          },
                        ),
                ),
              ],
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
