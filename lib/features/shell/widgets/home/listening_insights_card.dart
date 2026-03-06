import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../database/database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/home_providers.dart';
import '../track_context_menu.dart';

/// Premium stats/insights card with privacy copy.
class ListeningInsightsCard extends ConsumerWidget {
  const ListeningInsightsCard({super.key, required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final db = ref.read(databaseProvider);

    final collectionSummary =
        '${l10n.homeStatsTracks(data.totalTracks)} · '
        '${l10n.homeStatsAlbums(data.totalAlbums)} · '
        '${l10n.homeStatsArtists(data.totalArtists)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withAlpha(80),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Collection summary (hero line) + privacy watermark
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    collectionSummary,
                    style: textTheme.bodyLarge,
                  ),
                ),
                // Privacy watermark — subtle, right-aligned
                Opacity(
                  opacity: 0.45,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 12, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        l10n.homePrivateToYou,
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Listening stats (only if there's play history)
            if (data.hasPlayHistory) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  // All-time listening
                  _StatTile(
                    value: _formatDuration(data.totalListeningTimeMs),
                    label: l10n.homeListenedAllTime,
                  ),
                  const SizedBox(width: 32),
                  // This week + trend
                  _StatTile(
                    value: _formatDuration(data.listeningTimeThisWeekMs),
                    label: l10n.homeThisWeek,
                    trend: _weekTrend(l10n),
                  ),
                  const SizedBox(width: 32),
                  // Streak
                  if (data.longestStreakDays > 0)
                    _StatTile(
                      value: '${data.longestStreakDays}',
                      label: l10n.homeStreak,
                    ),
                ],
              ),
            ],

            // Top artist
            if (data.topArtistThisMonth != null) ...[
              const SizedBox(height: 16),
              Divider(color: colorScheme.outlineVariant.withAlpha(60), height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${l10n.homeTopArtistMonth}: ',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => navigateToArtistByName(context, db, data.topArtistThisMonth!),
                      child: Text(
                        data.topArtistThisMonth!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Only show week-over-week trend when both weeks > 30 min.
  String? _weekTrend(AppLocalizations l10n) {
    const threshold = 30 * 60 * 1000; // 30 minutes in ms
    if (data.listeningTimeThisWeekMs < threshold ||
        data.listeningTimeLastWeekMs < threshold) {
      return null;
    }
    if (data.listeningTimeLastWeekMs == 0) return null;

    final pct = ((data.listeningTimeThisWeekMs - data.listeningTimeLastWeekMs) /
            data.listeningTimeLastWeekMs * 100)
        .round();
    final sign = pct >= 0 ? '\u2191' : '\u2193';
    return '$sign${pct.abs()}%';
  }

  String _formatDuration(int ms) {
    final hours = ms ~/ (1000 * 60 * 60);
    final minutes = (ms ~/ (1000 * 60)) % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    this.trend,
  });

  final String value;
  final String label;
  final String? trend;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            if (trend != null) ...[
              const SizedBox(width: 6),
              Text(
                trend!,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
