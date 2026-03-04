import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'audio_service.dart';

/// Manages the system tray icon and context menu for desktop platforms.
class TrayService with TrayListener {
  TrayService(this._audio);

  final AudioService _audio;
  bool _initialized = false;

  Future<void> init() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    if (_initialized) return;
    _initialized = true;

    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/icons/app_icon.ico'
          : 'assets/icons/app_icon.png',
    );
    await trayManager.setToolTip('LoonBox');
    await _updateMenu();

    trayManager.addListener(this);
  }

  Future<void> _updateMenu() async {
    final menu = Menu(items: [
      MenuItem(key: 'show', label: 'Show LoonBox'),
      MenuItem.separator(),
      MenuItem(key: 'play_pause', label: 'Play / Pause'),
      MenuItem(key: 'next', label: 'Next Track'),
      MenuItem(key: 'previous', label: 'Previous Track'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]);
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
      case 'play_pause':
        _audio.getState().then((state) {
          if (state.name == 'playing') {
            _audio.pause();
          } else {
            _audio.play();
          }
        });
      case 'next':
        _audio.queueNext();
      case 'previous':
        _audio.queuePrevious();
      case 'quit':
        windowManager.destroy();
    }
  }

  void dispose() {
    trayManager.removeListener(this);
    trayManager.destroy();
  }
}

final trayServiceProvider = Provider<TrayService>((ref) {
  final audio = ref.watch(audioServiceProvider);
  final service = TrayService(audio);
  ref.onDispose(() => service.dispose());
  return service;
});
