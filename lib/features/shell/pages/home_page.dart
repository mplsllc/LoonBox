import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/home_providers.dart';
import '../widgets/home/coming_soon_card.dart';
import '../widgets/home/discover_section.dart';
import '../widgets/home/home_greeting.dart';
import '../widgets/home/jump_back_in_section.dart';
import '../widgets/home/listening_insights_card.dart';
import '../widgets/home/onboarding_view.dart';
import '../widgets/home/recently_added_section.dart';
import '../widgets/home/recently_played_section.dart';
import '../widgets/home/top_albums_section.dart';
import '../widgets/loon_loader.dart';

/// Home hub page — the flagship experience.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeDataProvider);

    return Scaffold(
      body: homeAsync.when(
        loading: () => const Center(child: LoonLoader()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          // Empty library → onboarding
          if (data.totalTracks == 0) {
            return const OnboardingView();
          }

          final db = ref.read(databaseProvider);
          final l10n = AppLocalizations.of(context)!;

          return ListView(
            children: [
              // Greeting header
              HomeGreeting(hasPlayHistory: data.hasPlayHistory),
              const SizedBox(height: 8),

              // Stats/insights card (always shown)
              ListeningInsightsCard(data: data),

              // Dynamic sections based on available data
              if (data.recentlyPlayed.isNotEmpty)
                RecentlyPlayedSection(albums: data.recentlyPlayed, db: db),

              if (data.topAlbums.isNotEmpty)
                TopAlbumsSection(albums: data.topAlbums, db: db),

              if (data.jumpBackIn.isNotEmpty)
                JumpBackInSection(tracks: data.jumpBackIn),

              // Tremolo card fills empty Recently Played slot
              if (data.recentlyPlayed.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: ComingSoonCard(
                    icon: Icons.storefront,
                    title: l10n.homeTremolo,
                    description: l10n.homeTremoloDesc,
                  ),
                ),

              if (data.recentlyAdded.isNotEmpty)
                RecentlyAddedSection(albums: data.recentlyAdded, db: db),

              // Discover section (hidden for tiny libraries < 5 albums)
              if (data.discover.isNotEmpty && data.totalAlbums >= 5)
                DiscoverSection(
                  albums: data.discover,
                  db: db,
                  onRefresh: () => ref.invalidate(homeDataProvider),
                ),

              // Nest card fills empty Top Albums slot
              if (data.topAlbums.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: ComingSoonCard(
                    icon: Icons.extension,
                    title: l10n.homeNest,
                    description: l10n.homeNestDesc,
                  ),
                ),

              // Bottom store cards row (when not placed inline)
              if (data.recentlyPlayed.isNotEmpty && data.topAlbums.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ComingSoonCard(
                          icon: Icons.storefront,
                          title: l10n.homeTremolo,
                          description: l10n.homeTremoloDesc,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ComingSoonCard(
                          icon: Icons.extension,
                          title: l10n.homeNest,
                          description: l10n.homeNestDesc,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
