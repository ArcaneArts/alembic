import 'dart:io';

import 'package:alembic/main.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class WindowUtil {
  static const double minWidth = 1024;
  static const double minHeight = 720;
  static const double defaultWidth = 1380;
  static const double defaultHeight = 860;
  static const double maxWidth = 1800;
  static const double maxHeight = 1400;
  static const double trayOffset = 12;
  static const double visibleMargin = 8;

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
      await boxSettings.put('hide_on_blur', Platform.isMacOS);
    }
    if (!boxSettings.containsKey('start_hidden')) {
      await boxSettings.put('start_hidden', Platform.isMacOS);
    }

    _hideOnBlur = boxSettings.get('hide_on_blur', defaultValue: true) == true;

    verbose("  Starting Window Manager");
    await windowManager.ensureInitialized();
    verbose("  Starting System tray");
    await initSystemTray();
    verbose("  Setup Blur Listeners");
    windowManager.addListener(HideOnBlurWindowListener());
    verbose("  Waiting for Window to be ready");
    windowManager.waitUntilReadyToShow(_windowOptions, () async {
      verbose("Setting Window Properties (mv=false, bg=transparent)");
      await windowManager.setMovable(false);
      await windowManager.center();
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
    await trayManager.setIcon('assets/tray.png', isTemplate: Platform.isMacOS);
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
        skipTaskbar: Platform.isMacOS,
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
    await _positionNearTray();
    await windowManager.show();
    await windowManager.focus();
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

  static Future<void> setHideOnBlur(bool value) async {
    _hideOnBlur = value;
    await boxSettings.put('hide_on_blur', value);
  }

  static Future<void> setStartHidden(bool value) {
    return boxSettings.put('start_hidden', value);
  }

  static Future<void> _positionNearTray() async {
    Rect? trayBounds = await trayManager.getBounds();
    if (trayBounds == null) {
      return;
    }

    List<Display> displays = await screenRetriever.getAllDisplays();
    if (displays.isEmpty) {
      return;
    }

    Display display = _displayForTrayBounds(
      trayBounds: trayBounds,
      displays: displays,
    );
    Rect visibleBounds = _visibleBoundsForDisplay(display);
    Size windowSize = await _currentWindowSize();
    Offset position = _positionForTrayBounds(
      trayBounds: trayBounds,
      visibleBounds: visibleBounds,
      windowSize: windowSize,
    );
    await windowManager.setPosition(position, animate: false);
  }

  static Future<Size> _currentWindowSize() async {
    try {
      return await windowManager.getSize();
    } catch (_) {
      return _windowSize;
    }
  }

  static Display _displayForTrayBounds({
    required Rect trayBounds,
    required List<Display> displays,
  }) {
    Offset trayCenter = trayBounds.center;
    Display bestDisplay = displays.first;
    double bestDistance = double.infinity;

    for (Display display in displays) {
      Rect visibleBounds = _visibleBoundsForDisplay(display);
      double distance = _distanceToRect(
        point: trayCenter,
        rect: visibleBounds,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        bestDisplay = display;
      }
    }

    return bestDisplay;
  }

  static Rect _visibleBoundsForDisplay(Display display) {
    Offset visiblePosition = display.visiblePosition ?? Offset.zero;
    Size visibleSize = display.visibleSize ?? display.size;
    return Rect.fromLTWH(
      visiblePosition.dx,
      visiblePosition.dy,
      visibleSize.width,
      visibleSize.height,
    );
  }

  static Offset _positionForTrayBounds({
    required Rect trayBounds,
    required Rect visibleBounds,
    required Size windowSize,
  }) {
    _TrayEdge edge = _edgeForTrayBounds(
      trayBounds: trayBounds,
      visibleBounds: visibleBounds,
    );
    double proposedX = visibleBounds.left + visibleMargin;
    double proposedY = visibleBounds.top + visibleMargin;

    if (edge == _TrayEdge.top) {
      proposedX = trayBounds.center.dx - (windowSize.width / 2);
      proposedY = trayBounds.bottom + trayOffset;
    } else if (edge == _TrayEdge.bottom) {
      proposedX = trayBounds.center.dx - (windowSize.width / 2);
      proposedY = trayBounds.top - windowSize.height - trayOffset;
    } else if (edge == _TrayEdge.left) {
      proposedX = trayBounds.right + trayOffset;
      proposedY = trayBounds.center.dy - (windowSize.height / 2);
    } else {
      proposedX = trayBounds.left - windowSize.width - trayOffset;
      proposedY = trayBounds.center.dy - (windowSize.height / 2);
    }

    double minX = visibleBounds.left + visibleMargin;
    double maxX = visibleBounds.right - windowSize.width - visibleMargin;
    double minY = visibleBounds.top + visibleMargin;
    double maxY = visibleBounds.bottom - windowSize.height - visibleMargin;

    return Offset(
      _clampToVisibleRange(
        value: proposedX,
        min: minX,
        max: maxX,
      ),
      _clampToVisibleRange(
        value: proposedY,
        min: minY,
        max: maxY,
      ),
    );
  }

  static _TrayEdge _edgeForTrayBounds({
    required Rect trayBounds,
    required Rect visibleBounds,
  }) {
    if (trayBounds.bottom <= visibleBounds.top) {
      return _TrayEdge.top;
    }
    if (trayBounds.top >= visibleBounds.bottom) {
      return _TrayEdge.bottom;
    }
    if (trayBounds.right <= visibleBounds.left) {
      return _TrayEdge.left;
    }
    if (trayBounds.left >= visibleBounds.right) {
      return _TrayEdge.right;
    }

    double topDistance = (trayBounds.center.dy - visibleBounds.top).abs();
    double bottomDistance = (visibleBounds.bottom - trayBounds.center.dy).abs();
    double leftDistance = (trayBounds.center.dx - visibleBounds.left).abs();
    double rightDistance = (visibleBounds.right - trayBounds.center.dx).abs();
    double smallestDistance = topDistance;
    _TrayEdge edge = _TrayEdge.top;

    if (bottomDistance < smallestDistance) {
      smallestDistance = bottomDistance;
      edge = _TrayEdge.bottom;
    }
    if (leftDistance < smallestDistance) {
      smallestDistance = leftDistance;
      edge = _TrayEdge.left;
    }
    if (rightDistance < smallestDistance) {
      edge = _TrayEdge.right;
    }

    return edge;
  }

  static double _distanceToRect({
    required Offset point,
    required Rect rect,
  }) {
    double dx = 0;
    double dy = 0;

    if (point.dx < rect.left) {
      dx = rect.left - point.dx;
    } else if (point.dx > rect.right) {
      dx = point.dx - rect.right;
    }

    if (point.dy < rect.top) {
      dy = rect.top - point.dy;
    } else if (point.dy > rect.bottom) {
      dy = point.dy - rect.bottom;
    }

    return (dx * dx) + (dy * dy);
  }

  static double _clampToVisibleRange({
    required double value,
    required double min,
    required double max,
  }) {
    if (max < min) {
      return min;
    }
    return value.clamp(min, max).toDouble();
  }
}

enum _TrayEdge {
  top,
  bottom,
  left,
  right,
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
