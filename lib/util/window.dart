import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class WindowUtil {
  static late SystemTray systemTray;
  static bool isDark = false;
  static bool iconIsDark = true;

  static Future<void> init() async {
    await windowManager.ensureInitialized();
    await initSystemTray();
    Display d = await screenRetriever.getPrimaryDisplay();
    await Window.initialize();
    windowManager.addListener(HideOnBlurWindowListener());
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.hide();
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setMovable(false);
      await windowManager
          .setPosition(Offset(d.size.width - windowOptions.size!.width, 0));
      await Window.setEffect(
        effect: WindowEffect.menu,
        color: const Color(0x00000000),
      );
    });
  }

  static Future<void> initSystemTray() async {
    systemTray = SystemTray();
    await systemTray.initSystemTray(
        iconPath: 'assets/tray.png', isTemplate: true, toolTip: "Alembic");

    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
          label: 'Exit Alembic',
          onClicked: (menuItem) =>
              windowManager.destroy().then((_) => exit(0))),
    ]);

    await systemTray.setContextMenu(menu);

    systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        show();
      } else if (eventName == kSystemTrayEventRightClick) {
        systemTray.popUpContextMenu();
      }
    });
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
    await windowManager.hide();
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
