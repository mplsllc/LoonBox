import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_chrome.dart';
import 'browser_pane.dart';
import 'browser_provider.dart';

/// Content widget for a single browser tab.
/// Shows BrowserChrome (for linkedContent mode) + BrowserPane.
class BrowserTabContent extends ConsumerWidget {
  final String tabId;

  const BrowserTabContent({super.key, required this.tabId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(browserTabsProvider);
    final tab = tabs.where((t) => t.id == tabId).firstOrNull;
    if (tab == null) return const SizedBox.shrink();

    final nav = ref.watch(browserNavProvider);

    return Column(
      children: [
        if (tab.mode == BrowserMode.linkedContent)
          BrowserChrome(
            tabId: tabId,
            onBack: () => nav?.goBack(),
            onForward: () => nav?.goForward(),
            onRefresh: () => nav?.reload(),
            onClose: () =>
                ref.read(browserTabsProvider.notifier).closeTab(tabId),
          ),
        Expanded(
          child: BrowserPane(
            key: ValueKey(tabId),
            tabId: tabId,
          ),
        ),
      ],
    );
  }
}
