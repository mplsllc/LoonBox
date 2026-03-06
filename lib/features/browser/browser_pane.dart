import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../services/audio_service.dart';
import 'browser_provider.dart';
import 'browser_service.dart';
import 'js_bridge.dart';

/// WebView2-based browser pane. Each instance is keyed by tab id
/// so it maintains its own WebView controller per tab.
class BrowserPane extends ConsumerStatefulWidget {
  final String tabId;

  const BrowserPane({super.key, required this.tabId});

  @override
  ConsumerState<BrowserPane> createState() => _BrowserPaneState();
}

class _BrowserPaneState extends ConsumerState<BrowserPane> {
  final _controller = WebviewController();
  bool _initialized = false;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final browserService = ref.read(browserServiceProvider);
    final port = browserService.proxyPort;

    // Initialize the environment with proxy before first controller init
    try {
      await WebviewController.initializeEnvironment(
        additionalArguments: '--proxy-server=http://127.0.0.1:$port',
      );
    } catch (_) {
      // Already initialized (shared environment) — that's fine
    }

    await _controller.initialize();

    if (!mounted) return;

    // Set background to match app surface
    final theme = Theme.of(context);
    await _controller.setBackgroundColor(theme.colorScheme.surface);

    // Block popups
    await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

    // Listen for title changes
    _subs.add(_controller.title.listen((title) {
      if (mounted) {
        ref
            .read(browserTabsProvider.notifier)
            .updateTitle(widget.tabId, title);
      }
    }));

    // Listen for URL changes
    _subs.add(_controller.url.listen((url) {}));

    // Listen for web messages (JS bridge)
    _subs.add(_controller.webMessage.listen((message) {
      _handleBridgeMessage(message);
    }));

    // Expose navigation callbacks for the chrome bar
    ref.read(browserNavProvider.notifier).state = BrowserNavCallbacks(
      goBack: _controller.goBack,
      goForward: _controller.goForward,
      reload: _controller.reload,
    );

    setState(() => _initialized = true);

    // Load the initial URL from the tab
    final tabs = ref.read(browserTabsProvider);
    final tab = tabs.where((t) => t.id == widget.tabId).firstOrNull;
    if (tab != null) {
      _loadUrl(tab.url, tab.mode);
    }
  }

  void _loadUrl(String url, BrowserMode mode) {
    if (!_initialized) return;

    if (mode == BrowserMode.trusted) {
      // Inject JS bridge script on every document load (trusted mode only)
      _controller.addScriptToExecuteOnDocumentCreated(jsBridgeScript);
    }

    _controller.loadUrl(url);
  }

  void _handleBridgeMessage(dynamic message) {
    if (message is! Map) return;

    // Check if this tab is trusted
    final tabs = ref.read(browserTabsProvider);
    final tab = tabs.where((t) => t.id == widget.tabId).firstOrNull;
    if (tab == null || tab.mode != BrowserMode.trusted) return;

    final id = message['id'] as int?;
    final cmd = message['cmd'] as String?;
    final args = message['args'];

    if (id == null || cmd == null) return;

    _dispatchCommand(id, cmd, args);
  }

  Future<void> _dispatchCommand(int id, String cmd, dynamic args) async {
    final audio = ref.read(audioServiceProvider);

    try {
      dynamic result;

      switch (cmd) {
        case 'player.play':
          await audio.play();
          result = true;
        case 'player.pause':
          await audio.pause();
          result = true;
        case 'player.stop':
          await audio.stop();
          result = true;
        case 'player.seek':
          final posMs = (args is Map ? args['position'] : args) as int? ?? 0;
          await audio.seek(posMs);
          result = true;
        case 'player.getState':
          final state = await audio.getState();
          result = state.name;
        case 'player.getPosition':
          result = await audio.getPosition();
        case 'browser.loadUrl':
          final url = (args is Map ? args['url'] : args) as String?;
          if (url != null) {
            ref.read(browserTabsProvider.notifier).openLinkedContent(url);
          }
          result = true;
        default:
          _sendBridgeError(id, 'Unknown command: $cmd');
          return;
      }

      _sendBridgeResponse(id, result);
    } catch (e) {
      _sendBridgeError(id, e.toString());
    }
  }

  void _sendBridgeResponse(int id, dynamic result) {
    final response = jsonEncode({
      'type': 'response',
      'id': id,
      'result': result,
    });
    _controller.postWebMessage(response);
  }

  void _sendBridgeError(int id, String error) {
    final response = jsonEncode({
      'type': 'response',
      'id': id,
      'error': error,
    });
    _controller.postWebMessage(response);
  }

  @override
  Widget build(BuildContext context) {
    // Update nav callbacks when this tab becomes active
    ref.listen(activeTabProvider, (prev, next) {
      if (next == widget.tabId && _initialized) {
        ref.read(browserNavProvider.notifier).state = BrowserNavCallbacks(
          goBack: _controller.goBack,
          goForward: _controller.goForward,
          reload: _controller.reload,
        );
      }
    });

    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Webview(_controller);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _controller.dispose();
    super.dispose();
  }
}
