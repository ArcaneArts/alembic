import 'dart:async';
import 'dart:io';

import 'package:alembic/main.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/platform/macos_tray_service.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class WindowUtil {
  static const double minWidth = 460;
  static const double minHeight = 640;
  static const double defaultWidth = 560;
  static const double defaultHeight = 760;
  static const double maxWidth = 680;
  static const double maxHeight = 980;
  static const double trayOffset = 12;
  static const double visibleMargin = 8;
  static const String _windowsIconAsset = 'assets/app_icon.ico';
  static const String _defaultTrayIconAsset = 'assets/tray.png';

  static bool isDark = false;
  static bool iconIsDark = true;
  static Size _windowSize = const Size(defaultWidth, defaultHeight);
  static bool _hideOnBlur = true;
  static int _hideOnBlurSuspendCount = 0;
  static DateTime _hideOnBlurBlockedUntil = DateTime.fromMillisecondsSinceEpoch(
    0,
  );
  static StreamSubscription<MacOSTrayEvent>? _macOSTraySubscription;

  static bool get hideOnBlurEnabled =>
      _hideOnBlur &&
      _hideOnBlurSuspendCount == 0 &&
      DateTime.now().isAfter(_hideOnBlurBlockedUntil);

  static Future<void> init() async {
    if (windowMode) {
      return;
    }

    _windowSize = _loadWindowSize();

    if (!boxSettings.containsKey('hide_on_blur')) {
      await boxSettings.put(
        'hide_on_blur',
        DesktopPlatformAdapter.instance.isTrayFirstPlatform,
      );
    }
    if (!boxSettings.containsKey('start_hidden')) {
      await boxSettings.put(
        'start_hidden',
        DesktopPlatformAdapter.instance.isTrayFirstPlatform,
      );
    }

    _hideOnBlur = boxSettings.get(
          'hide_on_blur',
          defaultValue: DesktopPlatformAdapter.instance.isTrayFirstPlatform,
        ) ==
        true;

    verbose("  Starting Window Manager");
    await windowManager.ensureInitialized();
    verbose("  Starting System tray");
    await initSystemTray();
    verbose("  Setup Blur Listeners");
    windowManager.addListener(HideOnBlurWindowListener());
    await _safeWindowCall(
      'prevent close',
      () => windowManager.setPreventClose(true),
    );
    verbose("  Waiting for Window to be ready");
    windowManager.waitUntilReadyToShow(_windowOptions, () async {
      verbose("Setting Window Properties (mv=false, bg=transparent)");
      if (DesktopPlatformAdapter.instance.isMacOS) {
        await _safeWindowCall(
          'disable native window movement',
          () => windowManager.setMovable(false),
        );
      }
      if (DesktopPlatformAdapter.instance.isWindows) {
        await _safeWindowCall(
          'set Windows taskbar icon',
          () => windowManager.setIcon(_windowsIconAsset),
        );
      }
      await _safeWindowCall('center window', () => windowManager.center());
      bool startHidden = boxSettings.get(
            'start_hidden',
            defaultValue: DesktopPlatformAdapter.instance.isTrayFirstPlatform,
          ) ==
          true;
      if (startHidden) {
        verbose("Window is Ready. Starting hidden (tray mode).");
        await _setWindowsTaskbarVisibility(visible: false);
        await _safeWindowCall('hide window', () => windowManager.hide());
      } else {
        verbose("Window is Ready. Showing window.");
        await _setWindowsTaskbarVisibility(visible: true);
        await _safeWindowCall('show window', () => windowManager.show());
        await _safeWindowCall('focus window', () => windowManager.focus());
      }
      await _reassertFramelessVisuals();
      Future<void>.delayed(const Duration(milliseconds: 120), () async {
        await _reassertFramelessVisuals();
      });
      await persistWindowSize();
    });
  }

  static Future<void> _reassertFramelessVisuals() async {
    await _safeWindowCall(
      'make window frameless',
      windowManager.setAsFrameless,
    );
    await _safeWindowCall(
      'disable window shadow',
      () => windowManager.setHasShadow(false),
    );
    await _safeWindowCall(
      'set transparent window background',
      () => windowManager.setBackgroundColor(const Color(0x00000000)),
    );
  }

  static Future<void> _safeWindowCall(
    String action,
    Future<void> Function() call,
  ) async {
    try {
      await call();
    } on MissingPluginException catch (e) {
      warn('Window manager does not support $action on this platform: $e');
    } on PlatformException catch (e) {
      warn('Window manager failed to $action: ${e.message ?? e.code}');
    } catch (e) {
      warn('Window manager failed to $action: $e');
    }
  }

  static Future<void> _setWindowsTaskbarVisibility({
    required bool visible,
  }) async {
    if (!DesktopPlatformAdapter.instance.isWindows) {
      return;
    }
    await _safeWindowCall(
      visible ? 'show window in taskbar' : 'hide window from taskbar',
      () => windowManager.setSkipTaskbar(!visible),
    );
  }

  static String get _trayIconAsset => DesktopPlatformAdapter.instance.isWindows
      ? _windowsIconAsset
      : _defaultTrayIconAsset;

  static Future<void> initSystemTray() async {
    if (windowMode) {
      if (DesktopPlatformAdapter.instance.isMacOS) {
        verbose("    Window mode active: switching macOS to regular policy");
        await MacOSTrayService.instance.setActivationPolicy('regular');
      }
      return;
    }
    if (DesktopPlatformAdapter.instance.isMacOS) {
      verbose("    Wiring native macOS tray service");
      _macOSTraySubscription ??=
          MacOSTrayService.instance.events.listen(_handleMacOSTrayEvent);
      await MacOSTrayService.instance.init();
      await MacOSTrayService.instance.setTooltip('Alembic');
      verbose("    Native macOS tray ready");
      _scheduleMacOSTrayDebugDumps();
      return;
    }
    await trayManager.setIcon(_trayIconAsset, isTemplate: Platform.isMacOS);
    await trayManager.setToolTip('Alembic');
    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'show',
          label: 'Show Alembic',
        ),
        MenuItem(
          key: 'hide',
          label: 'Hide Alembic',
        ),
        MenuItem.separator(),
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

  static void _handleMacOSTrayEvent(MacOSTrayEvent event) {
    if (event is MacOSTrayLeftClick) {
      verbose('macOS tray left-click: showing window');
      WindowUtil.show();
      return;
    }
    if (event is! MacOSTrayMenuItem) {
      return;
    }
    String key = event.key;
    verbose('macOS tray menu item: $key');
    if (key == 'hide') {
      WindowUtil.hide();
      return;
    }
    if (key == 'exit') {
      windowManager.destroy().then((_) => exit(0));
      return;
    }
    if (key == 'show' || key == 'settings' || key == 'update') {
      WindowUtil.show();
    }
  }

  static void _scheduleMacOSTrayDebugDumps() {
    List<Duration> delays = <Duration>[
      const Duration(seconds: 1),
      const Duration(seconds: 5),
    ];
    for (Duration delay in delays) {
      Future<void>.delayed(delay, () async {
        await dumpMacOSTrayDebug(label: 'auto +${delay.inMilliseconds}ms');
      });
    }
  }

  static Future<void> dumpMacOSTrayDebug({String label = 'manual'}) async {
    if (!DesktopPlatformAdapter.instance.isMacOS) {
      return;
    }
    Map<String, Object?> data = await MacOSTrayService.instance.dumpFullDebug();
    if (data.isEmpty) {
      warn('mac-tray dump [$label]: empty payload');
      return;
    }
    info('mac-tray dump [$label] BEGIN');
    List<String> keys = data.keys.toList()..sort();
    for (String key in keys) {
      Object? value = data[key];
      if (value is List) {
        info('  $key: [list of ${value.length}]');
        for (int i = 0; i < value.length; i++) {
          info('    [$i] ${value[i]}');
        }
      } else {
        info('  $key: $value');
      }
    }
    info('mac-tray dump [$label] END');
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
        skipTaskbar: DesktopPlatformAdapter.instance.isTrayFirstPlatform,
        titleBarStyle: TitleBarStyle.hidden,
      );

  static Size _loadWindowSize() {
    dynamic rawWidth = boxSettings.get('window_width');
    dynamic rawHeight = boxSettings.get('window_height');

    if ((rawWidth == 1380 && rawHeight == 860) ||
        (rawWidth == 1280 && rawHeight == 800) ||
        (rawWidth == 980 && rawHeight == 740) ||
        (rawWidth == 900 && rawHeight == 740)) {
      return const Size(defaultWidth, defaultHeight);
    }

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
    await _setWindowsTaskbarVisibility(visible: true);
    await _positionNearTray();
    await _safeWindowCall('show window', () => windowManager.show());
    await _safeWindowCall('focus window', () => windowManager.focus());
    await _reassertFramelessVisuals();
    Future<void>.delayed(const Duration(milliseconds: 120), () async {
      await _reassertFramelessVisuals();
    });
  }

  static Future<void> hide() async {
    if (windowMode) {
      return;
    }
    await _safeWindowCall('hide window', () => windowManager.hide());
    await _setWindowsTaskbarVisibility(visible: false);
  }

  static Future<T> withHideOnBlurSuspended<T>(
    Future<T> Function() action, {
    bool ensureVisibleAfter = false,
  }) async {
    suspendHideOnBlur();
    try {
      return await action();
    } finally {
      await resumeHideOnBlur(ensureVisible: ensureVisibleAfter);
    }
  }

  static void suspendHideOnBlur() {
    _hideOnBlurSuspendCount++;
  }

  static Future<void> resumeHideOnBlur({bool ensureVisible = false}) async {
    if (_hideOnBlurSuspendCount > 0) {
      _hideOnBlurSuspendCount--;
    }
    if (ensureVisible) {
      _hideOnBlurBlockedUntil = DateTime.now().add(
        const Duration(milliseconds: 750),
      );
      await show();
    }
  }

  static Future<void> setHideOnBlur(bool value) async {
    _hideOnBlur = value;
    await boxSettings.put('hide_on_blur', value);
  }

  static Future<void> setStartHidden(bool value) {
    return boxSettings.put('start_hidden', value);
  }

  static Future<void> _positionNearTray() async {
    Rect? trayBounds = DesktopPlatformAdapter.instance.isMacOS
        ? await MacOSTrayService.instance.getBounds()
        : await trayManager.getBounds();
    List<Display> displays = await screenRetriever.getAllDisplays();
    if (displays.isEmpty) {
      return;
    }

    Rect? usableTrayBounds = _usableTrayBounds(trayBounds);
    Display display = usableTrayBounds == null
        ? await _defaultDisplay(displays)
        : _displayForTrayBounds(
            trayBounds: usableTrayBounds,
            displays: displays,
          );
    Rect visibleBounds = _visibleBoundsForDisplay(display);
    Size windowSize = await _currentWindowSize();
    Offset position = usableTrayBounds == null
        ? _defaultTrayFallbackPosition(
            visibleBounds: visibleBounds,
            windowSize: windowSize,
          )
        : _positionForTrayBounds(
            trayBounds: usableTrayBounds,
            visibleBounds: visibleBounds,
            windowSize: windowSize,
          );
    await _safeWindowCall(
      'move window near tray',
      () => windowManager.setPosition(position, animate: false),
    );
  }

  static Rect? _usableTrayBounds(Rect? trayBounds) {
    if (trayBounds == null || trayBounds.isEmpty) {
      return null;
    }
    if (!trayBounds.left.isFinite ||
        !trayBounds.top.isFinite ||
        !trayBounds.right.isFinite ||
        !trayBounds.bottom.isFinite) {
      return null;
    }
    return trayBounds;
  }

  static Future<Display> _defaultDisplay(List<Display> displays) async {
    try {
      return await screenRetriever.getPrimaryDisplay();
    } catch (_) {
      return displays.first;
    }
  }

  static Offset _defaultTrayFallbackPosition({
    required Rect visibleBounds,
    required Size windowSize,
  }) {
    return Offset(
      _clampToVisibleRange(
        value: visibleBounds.right - windowSize.width - trayOffset,
        min: visibleBounds.left + visibleMargin,
        max: visibleBounds.right - windowSize.width - visibleMargin,
      ),
      _clampToVisibleRange(
        value: visibleBounds.bottom - windowSize.height - trayOffset,
        min: visibleBounds.top + visibleMargin,
        max: visibleBounds.bottom - windowSize.height - visibleMargin,
      ),
    );
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
  void onTrayIconMouseDown() {
    // On Windows, the plugin dispatches `onTrayIconMouseDown` for
    // `WM_LBUTTONUP`, so this is the click event we receive.
    if (Platform.isWindows) {
      WindowUtil.show();
    }
  }

  @override
  void onTrayIconMouseUp() {
    // macOS dispatches both Down and Up. Use Up to mirror the original
    // behaviour while leaving Windows handled in `onTrayIconMouseDown`.
    if (!Platform.isWindows) {
      WindowUtil.show();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    // On Windows, the plugin dispatches `onTrayIconRightMouseDown` for
    // `WM_RBUTTONUP`, so this is when we should pop the context menu.
    if (Platform.isWindows) {
      trayManager.popUpContextMenu();
    }
  }

  @override
  void onTrayIconRightMouseUp() {
    if (!Platform.isWindows) {
      trayManager.popUpContextMenu();
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      WindowUtil.show();
      return;
    }
    if (menuItem.key == 'hide') {
      WindowUtil.hide();
      return;
    }
    if (menuItem.key == 'exit') {
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
  void onWindowClose() {
    WindowUtil.hide();
  }

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
