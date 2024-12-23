import 'dart:io';

import 'package:alembic/main.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class WindowUtil {
  static bool isDark = false;
  static bool iconIsDark = true;

  static Future<void> init() async {
    if (windowMode) {
      return;
    }

    verbose("  Starting Window Manager");
    await windowManager.ensureInitialized();
    verbose("  Starting System tray");
    await initSystemTray();
    verbose("  Starting Screen Retriever");
    Display d = await screenRetriever.getPrimaryDisplay();
    verbose("  Initializing Window");
    await Window.initialize();
    verbose("  Setup Blur Listeners");
    windowManager.addListener(HideOnBlurWindowListener());
    verbose("  Waiting for Window to be ready");
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      verbose("Window is Ready. Hiding...");
      await windowManager.hide();
      verbose("Setting Window Properties (mv=false, bg=transparent)");
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setMovable(false);
      verbose("Setting Window Position");
      await windowManager
          .setPosition(Offset(d.size.width - windowOptions.size!.width, 0));
      verbose("Setting Window Effect to menu 0x0000");
      await Window.setEffect(
        effect: WindowEffect.menu,
        color: const Color(0x00000000),
      );
    });
  }

  static Future<void> initSystemTray() async {
    if (windowMode) {
      return;
    }
    await trayManager.setIcon('assets/tray.png', isTemplate: true);
    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'exit',
          label: 'Exit Alembic',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
    verbose("    Registering System Tray Event Handler");
    trayManager.addListener(AlembicTrayListener());
    verbose("    System Tray Ready");
  }

  static const WindowOptions windowOptions = WindowOptions(
    size: Size(400, 700),
    maximumSize: Size(400, 700),
    minimumSize: Size(400, 700),
    center: false,
    windowButtonVisibility: false,
    title: 'Alembic',
    alwaysOnTop: false,
    backgroundColor: Color(0x00000000),
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  static Future<void> show() async {
    if (windowMode) {
      return;
    }
    Offset cursor = await screenRetriever.getCursorScreenPoint();
    Size windowSize = windowOptions.size!;
    await windowManager.setPosition(Offset(
        cursor.dx - windowSize.width / 2 > 0
            ? cursor.dx - windowSize.width / 2
            : 0,
        0));
    await windowManager.show();
  }

  static Future<void> hide() async {
    if (windowMode) {
      return;
    }
    await windowManager.hide();
  }
}

class AlembicTrayListener implements TrayListener {
  @override
  void onTrayIconMouseDown() {}

  @override
  void onTrayIconMouseUp() {
    WindowUtil.show();
  }

  @override
  void onTrayIconRightMouseDown() {}

  @override
  void onTrayIconRightMouseUp() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == "exit") {
      windowManager.destroy().then((_) => exit(0));
    }
  }
}

class HideOnBlurWindowListener implements WindowListener {
  @override
  void onWindowBlur() {
    WindowUtil.hide();
  }

  @override
  void onWindowClose() {}

  @override
  void onWindowDocked() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowEvent(String eventName) {}

  @override
  void onWindowFocus() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowMinimize() {}

  @override
  void onWindowMove() {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowResize() {}

  @override
  void onWindowResized() {}

  @override
  void onWindowRestore() {}

  @override
  void onWindowUndocked() {}

  @override
  void onWindowUnmaximize() {}
}
