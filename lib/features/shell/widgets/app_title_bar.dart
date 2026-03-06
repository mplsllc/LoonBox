import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../browser/browser_provider.dart';

/// Custom 32px title bar replacing system chrome.
///
/// Shows a "LoonBox" home tab, any open browser tabs, and window caption buttons.
/// Uses window_manager's built-in [DragToMoveArea] for drag-to-move and
/// [WindowCaptionButton] for pixel-perfect Windows 11 caption buttons.
class AppTitleBar extends ConsumerStatefulWidget {
  const AppTitleBar({super.key});

  @override
  ConsumerState<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends ConsumerState<AppTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _updateMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _updateMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted && maximized != _isMaximized) {
      setState(() => _isMaximized = maximized);
    }
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final tabs = ref.watch(browserTabsProvider);
    final activeTab = ref.watch(activeTabProvider);

    return Container(
      height: 32,
      color: colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          // Home tab
          _TabChip(
            icon: Icons.album,
            iconColor: colorScheme.primary,
            label: 'LoonBox',
            isActive: activeTab == null,
            onTap: () =>
                ref.read(activeTabProvider.notifier).state = null,
          ),
          // Browser tabs
          for (final tab in tabs)
            _TabChip(
              icon: Icons.language,
              label: tab.title ?? _shortenUrl(tab.url),
              isActive: activeTab == tab.id,
              closable: true,
              onTap: () =>
                  ref.read(activeTabProvider.notifier).state = tab.id,
              onClose: () =>
                  ref.read(browserTabsProvider.notifier).closeTab(tab.id),
            ),
          // Draggable empty space
          Expanded(
            child: DragToMoveArea(
              child: const SizedBox(height: 32),
            ),
          ),
          // Window control buttons
          WindowCaptionButton.minimize(
            brightness: brightness,
            onPressed: () async {
              final isMinimized = await windowManager.isMinimized();
              if (isMinimized) {
                windowManager.restore();
              } else {
                windowManager.minimize();
              }
            },
          ),
          _isMaximized
              ? WindowCaptionButton.unmaximize(
                  brightness: brightness,
                  onPressed: () => windowManager.unmaximize(),
                )
              : WindowCaptionButton.maximize(
                  brightness: brightness,
                  onPressed: () => windowManager.maximize(),
                ),
          WindowCaptionButton.close(
            brightness: brightness,
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }

  String _shortenUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return url;
    }
  }
}

/// A single tab chip in the title bar (32px tall).
class _TabChip extends StatefulWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final bool isActive;
  final bool closable;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _TabChip({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.isActive,
    this.closable = false,
    required this.onTap,
    this.onClose,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bgColor = widget.isActive
        ? colorScheme.surfaceContainerLow
        : _hovering
            ? colorScheme.surfaceContainerHigh
            : colorScheme.surfaceContainerHighest;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          height: 32,
          padding: EdgeInsets.only(
            left: 10,
            right: widget.closable ? 4 : 10,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: widget.isActive
                  ? BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    )
                  : BorderSide.none,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.iconColor ?? colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: widget.isActive
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (widget.closable) ...[
                const SizedBox(width: 4),
                _CloseTabButton(onPressed: widget.onClose!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny close button for browser tabs.
class _CloseTabButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _CloseTabButton({required this.onPressed});

  @override
  State<_CloseTabButton> createState() => _CloseTabButtonState();
}

class _CloseTabButtonState extends State<_CloseTabButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _hovering
                ? colorScheme.onSurface.withAlpha(30)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.close,
            size: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
