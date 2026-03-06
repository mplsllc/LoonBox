import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_provider.dart';

/// Address bar + navigation controls for linked content mode.
/// 48px tall, matches title bar aesthetic.
class BrowserChrome extends ConsumerWidget {
  final String tabId;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh;
  final VoidCallback onClose;
  final bool canGoBack;
  final bool canGoForward;

  const BrowserChrome({
    super.key,
    required this.tabId,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onClose,
    this.canGoBack = false,
    this.canGoForward = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(browserTabsProvider);
    final tab = tabs.where((t) => t.id == tabId).firstOrNull;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      height: 48,
      color: colors.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Back
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: canGoBack ? onBack : null,
            tooltip: 'Back',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
          // Forward
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 20),
            onPressed: canGoForward ? onForward : null,
            tooltip: 'Forward',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: onRefresh,
            tooltip: 'Refresh',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          // URL display
          Expanded(
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              child: Text(
                tab?.title ?? tab?.url ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Shield icon (blocked count placeholder)
          IconButton(
            icon: const Icon(Icons.shield_outlined, size: 20),
            onPressed: () {},
            tooltip: 'Ad blocking active',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
          // Close
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onClose,
            tooltip: 'Close',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
