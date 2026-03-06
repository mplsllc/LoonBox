import 'package:flutter_riverpod/flutter_riverpod.dart';

int _nextTabId = 0;

/// Maximum number of browser tabs allowed (WebView2 is heavyweight).
const maxBrowserTabs = 8;

/// Browser display mode.
enum BrowserMode {
  /// First-party content (Nest, Tremolo) — no chrome, JS bridge active.
  trusted,

  /// External links — address bar, back/close, sandboxed (no JS bridge).
  linkedContent,
}

/// A single browser tab.
class BrowserTab {
  final String id;
  final String url;
  final String? title;
  final BrowserMode mode;

  const BrowserTab({
    required this.id,
    required this.url,
    this.title,
    required this.mode,
  });

  BrowserTab copyWith({String? url, String? title, BrowserMode? mode}) {
    return BrowserTab(
      id: id,
      url: url ?? this.url,
      title: title ?? this.title,
      mode: mode ?? this.mode,
    );
  }
}

/// Manages the list of open browser tabs.
class BrowserTabsNotifier extends StateNotifier<List<BrowserTab>> {
  final Ref _ref;

  BrowserTabsNotifier(this._ref) : super([]);

  /// Open a new tab. Returns the tab id, or null if at cap.
  String? openTab(String url, BrowserMode mode) {
    if (state.length >= maxBrowserTabs) return null;

    final tab = BrowserTab(
      id: 'tab_${_nextTabId++}',
      url: url,
      mode: mode,
    );
    state = [...state, tab];
    _ref.read(activeTabProvider.notifier).state = tab.id;
    return tab.id;
  }

  /// Close a tab by id.
  void closeTab(String id) {
    final index = state.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final wasActive = _ref.read(activeTabProvider) == id;
    state = [
      for (final t in state)
        if (t.id != id) t,
    ];

    if (wasActive) {
      // Fall back to home tab
      _ref.read(activeTabProvider.notifier).state = null;
    }
  }

  /// Update a tab's title.
  void updateTitle(String id, String title) {
    state = [
      for (final t in state)
        if (t.id == id) t.copyWith(title: title) else t,
    ];
  }

  /// Open an external link in sandboxed mode.
  void openLinkedContent(String url) {
    if (!url.startsWith('https://') && !url.startsWith('http://')) return;
    openTab(url, BrowserMode.linkedContent);
  }

  /// Open a trusted page (Nest, Tremolo).
  void openTrusted(String url) {
    openTab(url, BrowserMode.trusted);
  }
}

/// All open browser tabs.
final browserTabsProvider =
    StateNotifierProvider<BrowserTabsNotifier, List<BrowserTab>>(
  (ref) => BrowserTabsNotifier(ref),
);

/// The currently active tab id. null = home tab (library content).
final activeTabProvider = StateProvider<String?>((ref) => null);

/// Callback interface for browser navigation actions.
class BrowserNavCallbacks {
  final Future<void> Function() goBack;
  final Future<void> Function() goForward;
  final Future<void> Function() reload;

  const BrowserNavCallbacks({
    required this.goBack,
    required this.goForward,
    required this.reload,
  });
}

/// Navigation callbacks from the active WebView controller.
final browserNavProvider = StateProvider<BrowserNavCallbacks?>((ref) => null);
