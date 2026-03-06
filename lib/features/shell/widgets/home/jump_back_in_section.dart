import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../database/database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../player/presentation/queue_provider.dart';
import 'home_section.dart';
import 'track_card.dart';

/// Individual tracks played recently — tappable to play.
class JumpBackInSection extends ConsumerWidget {
  const JumpBackInSection({super.key, required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return HomeSection(
      title: l10n.homeJumpBackIn,
      child: SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: tracks.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final track = tracks[index];
            return TrackCard(
              track: track,
              onTap: () => ref.read(queueProvider.notifier).setQueue(
                tracks,
                startIndex: index,
              ),
            );
          },
        ),
      ),
    );
  }
}
