import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/auto_tag_page.dart';

/// Compact persistent banner shown when auto-tag is running in the background.
/// Tapping navigates to the full auto-tag page.
class AutoTagMiniBanner extends ConsumerWidget {
  const AutoTagMiniBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(autoTagProvider);

    // Only show during scanning or applying phases
    if (state.phase != AutoTagPhase.scanning &&
        state.phase != AutoTagPhase.applying) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = state.total > 0 ? state.current / state.total : 0.0;

    final label = state.phase == AutoTagPhase.applying
        ? 'Applying: ${state.current}/${state.total}'
        : 'Auto-tagging: ${state.current}/${state.total} · ${state.matches.length} matched';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AutoTagPage()),
        );
      },
      child: Container(
        height: 32,
        color: colorScheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}
