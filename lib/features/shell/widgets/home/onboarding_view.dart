import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../app_shell.dart';
import 'coming_soon_card.dart';

/// Empty library welcome + two-step setup.
class OnboardingView extends ConsumerWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 80,
              color: colorScheme.primary.withAlpha(180),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.homeEmptyTitle,
              style: textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Step 1: Add music
            _OnboardingStep(
              number: '1',
              title: l10n.homeEmptyAddMusic,
              icon: Icons.folder_open,
              onPressed: () => ref.read(navIndexProvider.notifier).state = 6,
            ),
            const SizedBox(height: 16),

            // Step 2: Auto-tag (disabled until tracks exist)
            Tooltip(
              message: l10n.homeEmptyAutoTagDisabled,
              child: _OnboardingStep(
                number: '2',
                title: l10n.homeEmptyAutoTag,
                subtitle: l10n.homeEmptyAutoTagDesc,
                icon: Icons.auto_fix_high,
                enabled: false,
              ),
            ),
            const SizedBox(height: 32),

            // Tremolo card
            ComingSoonCard(
              icon: Icons.storefront,
              title: l10n.homeTremolo,
              description: l10n.homeTremoloDesc,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.number,
    required this.title,
    this.subtitle,
    required this.icon,
    this.onPressed,
    this.enabled = true,
  });

  final String number;
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleSmall),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  icon,
                  color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
