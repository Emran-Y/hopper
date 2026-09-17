import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_controller.dart';

/// System-tray icon + hide-to-tray behaviour on Windows/macOS/Linux.
class DesktopShell with TrayListener, WindowListener {
  final AppController app;
  DesktopShell(this.app);

  static bool get supported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  Future<void> init() async {
    if (!supported) return;
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(const WindowOptions(
      size: Size(1040, 720), minimumSize: Size(720, 520), center: true, title: 'Hopper',
    ), () async {
      if (app.settings.startMinimized) { await windowManager.hide(); } else { await windowManager.show(); }
    });
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    trayManager.addListener(this);
    await trayManager.setIcon(Platform.isWindows ? 'assets/tray/hopper.ico' : 'assets/tray/hopper.png');
    if (!Platform.isLinux) await trayManager.setToolTip('Hopper — clipboard sync');
    await refreshMenu();
    app.addListener(refreshMenu);
  }

  Future<void> refreshMenu() async {
    if (!supported) return;
    final connected = app.peers.where((p) => app.isConnected(p.id)).length;
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(label: connected == 0 ? 'No devices in range' : '$connected device(s) connected', disabled: true),
      MenuItem.separator(),
      MenuItem(key: 'send', label: 'Send clipboard now'),
      MenuItem(key: 'pause', label: app.settings.paused ? 'Resume syncing' : 'Pause syncing'),
      MenuItem.separator(),
      MenuItem(key: 'open', label: 'Open Hopper'),
      MenuItem(key: 'quit', label: 'Quit'),
    ]));
  }

  @override
  void onTrayIconMouseDown() => windowManager.isVisible().then((v) => v ? windowManager.hide() : _show());
  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'send': await app.sendCurrentClipboard();
      case 'pause': await app.setPaused(!app.settings.paused);
      case 'open': await _show();
      case 'quit': await windowManager.setPreventClose(false); await windowManager.destroy(); exit(0);
    }
  }

  Future<void> _show() async { await windowManager.show(); await windowManager.focus(); }

  @override
  void onWindowClose() async {
    // Closing the window hides to tray; Quit is in the tray menu.
    await windowManager.hide();
  }
}
