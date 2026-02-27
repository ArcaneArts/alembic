import 'dart:io';

import 'package:alembic/main.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/cupertino.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class WindowUtil {
  static const double minWidth = 380;
  static const double minHeight = 620;
  static const double defaultWidth = 440;
  static const double defaultHeight = 760;
  static const double maxWidth = 900;
  static const double maxHeight = 1200;

  static bool isDark = false;
  static bool iconIsDark = true;
  static Size _windowSize = const Size(defaultWidth, defaultHeight);
  static bool _hideOnBlur = true;

  static bool get hideOnBlurEnabled => _hideOnBlur;

  static Future<void> init() async {
    if (windowMode) {
      return;
    }

    _windowSize = _loadWindowSize();

    if (!boxSettings.containsKey('hide_on_blur')) {
      await boxSettings.put('hide_on_blur', true);
    }
    if (!boxSettings.containsKey('start_hidden')) {
      await boxSettings.put('start_hidden', true);
    }

    _hideOnBlur = boxSettings.get('hide_on_blur', defaultValue: true) == true;

    verbose("  Starting Window Manager");
    await windowManager.ensureInitialized();
    verbose("  Starting System tray");
    await initSystemTray();
    verbose("  Starting Screen Retriever");
    Display d = await screenRetriever.getPrimaryDisplay();
    verbose("  Setup Blur Listeners");
    windowManager.addListener(HideOnBlurWindowListener());
    verbose("  Waiting for Window to be ready");
    windowManager.waitUntilReadyToShow(_windowOptions, () async {
      verbose("Setting Window Properties (mv=false, bg=transparent)");
      await windowManager.setMovable(false);
      await windowManager
          .setPosition(Offset(d.size.width - _windowSize.width, 0));
      bool startHidden =
          boxSettings.get('start_hidden', defaultValue: true) == true;
      if (startHidden) {
        verbose("Window is Ready. Starting hidden (tray mode).");
        await windowManager.hide();
      } else {
        verbose("Window is Ready. Showing window.");
        await windowManager.show();
        await windowManager.focus();
      }
      await _reassertFramelessVisuals();
      Future<void>.delayed(const Duration(milliseconds: 120), () async {
        await _reassertFramelessVisuals();
      });
      await persistWindowSize();
    });
  }

  static Future<void> _reassertFramelessVisuals() async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    await windowManager.setBackgroundColor(const Color(0x00000000));
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

  static WindowOptions get _windowOptions => WindowOptions(
        size: _windowSize,
        maximumSize: const Size(maxWidth, maxHeight),
        minimumSize: const Size(minWidth, minHeight),
        center: false,
        windowButtonVisibility: false,
        title: 'Alembic',
        alwaysOnTop: false,
        backgroundColor: const Color(0x00000000),
        skipTaskbar: true,
        titleBarStyle: TitleBarStyle.hidden,
      );

  static Size _loadWindowSize() {
    dynamic rawWidth = boxSettings.get('window_width');
    dynamic rawHeight = boxSettings.get('window_height');

    double width = _coerceDimension(
      raw: rawWidth,
      fallback: defaultWidth,
      min: minWidth,
      max: maxWidth,
    );
    double height = _coerceDimension(
      raw: rawHeight,
      fallback: defaultHeight,
      min: minHeight,
      max: maxHeight,
    );

    return Size(width, height);
  }

  static double _coerceDimension({
    required dynamic raw,
    required double fallback,
    required double min,
    required double max,
  }) {
    if (raw is num) {
      double value = raw.toDouble();
      return value.clamp(min, max).toDouble();
    }

    return fallback;
  }

  static Future<void> persistWindowSize() async {
    if (windowMode) {
      return;
    }

    Size size = await windowManager.getSize();
    double width = size.width.clamp(minWidth, maxWidth).toDouble();
    double height = size.height.clamp(minHeight, maxHeight).toDouble();

    _windowSize = Size(width, height);
    await boxSettings.put('window_width', width);
    await boxSettings.put('window_height', height);
  }

  static Future<void> show() async {
    if (windowMode) {
      return;
    }
    Offset cursor = await screenRetriever.getCursorScreenPoint();
    Size windowSize = _windowSize;
    await windowManager.setPosition(
      Offset(
        cursor.dx - windowSize.width / 2 > 0
            ? cursor.dx - windowSize.width / 2
            : 0,
        0,
      ),
    );
    await windowManager.show();
    await _reassertFramelessVisuals();
    Future<void>.delayed(const Duration(milliseconds: 120), () async {
      await _reassertFramelessVisuals();
    });
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
    if (!WindowUtil.hideOnBlurEnabled) {
      return;
    }
    WindowUtil.hide();
  }

  @override
  void onWindowResized() {
    WindowUtil.persistWindowSize();
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
  void onWindowRestore() {}

  @override
  void onWindowUndocked() {}

  @override
  void onWindowUnmaximize() {}
}
