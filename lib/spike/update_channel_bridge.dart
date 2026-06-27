import 'dart:async';
import 'dart:io';

import 'package:alembic/core/app_update_service.dart';
import 'package:alembic/core/update_status.dart';
import 'package:alembic/main.dart' as alembic_main;
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/spike/spike_channels.dart';
import 'package:alembic/spike/spike_diagnostics.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Wires the [AppUpdateService] up to the native layer over the
/// [SpikeChannels.updates] channel.
///
/// The notification is intentionally non-intrusive: there is no modal. The
/// bridge only ever pushes an [UpdateSnapshot] to native, which renders a
/// subtle yellow dot plus an "Updates" settings pane. When auto-check is
/// enabled, a single check runs shortly after boot; the user can also trigger
/// [SpikeUpdatesChannelMethods.checkNow] and [SpikeUpdatesChannelMethods.install]
/// from settings.
class UpdateChannelBridge {
  UpdateChannelBridge({
    AppUpdateService? service,
    DesktopPlatformAdapter? adapter,
    SpikeDiagnostics? diagnostics,
    Duration startupCheckDelay = const Duration(seconds: 4),
  })  : _service = service ?? AppUpdateService(),
        _adapter = adapter ?? DesktopPlatformAdapter.instance,
        _diagnostics = diagnostics ?? SpikeDiagnostics.instance,
        _startupCheckDelay = startupCheckDelay,
        _channel = const MethodChannel(SpikeChannels.updates);

  static const String _logTag = 'update_bridge';

  /// Hive [alembic_main.boxSettings] key controlling the automatic launch check.
  static const String autoCheckKey = 'update_auto_check';

  /// Minimum gap between download-progress state pushes, in milliseconds.
  static const int _progressThrottleMs = 100;

  final AppUpdateService _service;
  final DesktopPlatformAdapter _adapter;
  final SpikeDiagnostics _diagnostics;
  final Duration _startupCheckDelay;
  final MethodChannel _channel;

  bool _attached = false;
  Timer? _startupTimer;

  /// True while a check or install is running, to avoid overlapping work.
  bool _busy = false;
  UpdateSnapshot _snapshot = const UpdateSnapshot(
    status: UpdateStatus.idle,
    autoCheckEnabled: true,
    currentVersion: '',
  );

  /// The last update found, retained so [install] can download/apply it.
  UpdateCheckResult? _pending;

  String get _currentVersion => alembic_main.packageInfo.version.trim();

  bool get _autoCheckEnabled =>
      alembic_main.boxSettings.get(autoCheckKey, defaultValue: true) == true;

  Future<void> attach() async {
    if (_attached) {
      _diagnostics.warn(_logTag, 'attach called twice; ignoring');
      return;
    }
    _attached = true;
    _diagnostics.log(_logTag, 'attaching to channel ${SpikeChannels.updates}');
    _snapshot = UpdateSnapshot.idle(
      autoCheckEnabled: _autoCheckEnabled,
      currentVersion: _currentVersion,
    );
    _channel.setMethodCallHandler(_handle);
    _push();
    if (_autoCheckEnabled) {
      _startupTimer = Timer(_startupCheckDelay, () {
        unawaited(_checkNow());
      });
      _diagnostics.trace(_logTag,
          'startup update check scheduled in ${_startupCheckDelay.inSeconds}s');
    } else {
      _diagnostics.trace(_logTag, 'auto-check disabled; no startup check');
    }
    _diagnostics.success(_logTag, 'updates bridge attached');
  }

  Future<void> dispose() async {
    _attached = false;
    _startupTimer?.cancel();
    _startupTimer = null;
    _service.dispose();
  }

  Future<dynamic> _handle(MethodCall call) async {
    _diagnostics.trace(_logTag, 'native -> ${call.method}');
    try {
      switch (call.method) {
        case SpikeUpdatesChannelMethods.getState:
          return _snapshot.toJson();
        case SpikeUpdatesChannelMethods.setAutoCheck:
          return await _handleSetAutoCheck(call.arguments);
        case SpikeUpdatesChannelMethods.checkNow:
          await _checkNow();
          return <String, Object?>{'ok': true};
        case SpikeUpdatesChannelMethods.install:
          return await _handleInstall();
        default:
          _diagnostics.warn(_logTag, 'unhandled method ${call.method}');
          return <String, Object?>{
            'ok': false,
            'error': 'Unknown method: ${call.method}',
          };
      }
    } catch (e, stack) {
      _diagnostics.error(_logTag, '${call.method} failed: $e');
      _diagnostics.trace(_logTag, 'stack: $stack');
      return <String, Object?>{'ok': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _handleSetAutoCheck(Object? rawArgs) async {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final dynamic enabled = args?['enabled'];
    if (enabled is bool) {
      await alembic_main.boxSettings.put(autoCheckKey, enabled);
      _snapshot = _snapshot.copyWith(autoCheckEnabled: enabled);
      _push();
      _diagnostics.log(_logTag, 'auto-check set to $enabled');
    }
    return <String, Object?>{'ok': true};
  }

  Future<void> _checkNow() async {
    if (_busy) {
      _diagnostics.trace(_logTag, 'check requested while busy; ignoring');
      return;
    }
    _busy = true;
    _snapshot = UpdateSnapshot.checking(
      autoCheckEnabled: _autoCheckEnabled,
      currentVersion: _currentVersion,
      lastCheckedMs: _snapshot.lastCheckedMs,
    );
    _push();
    try {
      final UpdateCheckResult? result =
          await _service.checkForUpdate(currentVersion: _currentVersion);
      final int now = DateTime.now().millisecondsSinceEpoch;
      if (result == null) {
        _pending = null;
        _snapshot = UpdateSnapshot.upToDate(
          autoCheckEnabled: _autoCheckEnabled,
          currentVersion: _currentVersion,
          lastCheckedMs: now,
        );
        _diagnostics.log(_logTag, 'up to date ($_currentVersion)');
      } else {
        _pending = result;
        _snapshot = UpdateSnapshot.available(
          autoCheckEnabled: _autoCheckEnabled,
          currentVersion: _currentVersion,
          latestVersion: result.manifest.version,
          lastCheckedMs: now,
        );
        _diagnostics.success(
            _logTag, 'update available: ${result.manifest.version}');
      }
    } catch (e) {
      _snapshot = UpdateSnapshot.error(
        autoCheckEnabled: _autoCheckEnabled,
        currentVersion: _currentVersion,
        message: e.toString(),
        latestVersion: _snapshot.latestVersion,
        lastCheckedMs: DateTime.now().millisecondsSinceEpoch,
      );
      _diagnostics.error(_logTag, 'check failed: $e');
    } finally {
      _busy = false;
      _push();
    }
  }

  Future<Map<String, Object?>> _handleInstall() async {
    final UpdateCheckResult? pending = _pending;
    if (pending == null) {
      return <String, Object?>{
        'ok': false,
        'error': 'No update available to install.',
      };
    }
    if (_busy) {
      return <String, Object?>{
        'ok': false,
        'error': 'An update operation is already in progress.',
      };
    }
    _busy = true;
    final String latestVersion = pending.manifest.version;
    _snapshot = UpdateSnapshot.downloading(
      autoCheckEnabled: _autoCheckEnabled,
      currentVersion: _currentVersion,
      latestVersion: latestVersion,
      progress: 0,
      lastCheckedMs: _snapshot.lastCheckedMs,
    );
    _push();
    int lastPushMs = 0;
    try {
      final String tempDir = (await getTemporaryDirectory()).absolute.path;
      final File payload = await _service.downloadAsset(
        asset: pending.asset,
        temporaryDirectory: tempDir,
        onProgress: (int received, int? total) {
          if (total == null || total <= 0) {
            return;
          }
          final int nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - lastPushMs < _progressThrottleMs) {
            return;
          }
          lastPushMs = nowMs;
          _snapshot = UpdateSnapshot.downloading(
            autoCheckEnabled: _autoCheckEnabled,
            currentVersion: _currentVersion,
            latestVersion: latestVersion,
            progress: received / total,
            lastCheckedMs: _snapshot.lastCheckedMs,
          );
          _push();
        },
      );
      final String installTarget = _adapter.currentInstallTarget();
      final String manualUrl = pending.asset.manualUrl.isNotEmpty
          ? pending.asset.manualUrl
          : pending.asset.url;
      final int exitCode = await _adapter.launchSilentUpdateHelper(
        payloadPath: payload.path,
        installTarget: installTarget,
        manualInstallerUrl: manualUrl,
      );
      if (exitCode != 0) {
        throw Exception('Update helper exited with code $exitCode');
      }
      _diagnostics.warn(
          _logTag, 'update helper launched; awaiting app termination');
      // Stay in the downloading state: native terminates the app now so the
      // detached helper can swap the bundle and relaunch. _busy stays true.
      return <String, Object?>{'ok': true};
    } catch (e) {
      _snapshot = UpdateSnapshot.error(
        autoCheckEnabled: _autoCheckEnabled,
        currentVersion: _currentVersion,
        message: e.toString(),
        latestVersion: latestVersion,
        lastCheckedMs: _snapshot.lastCheckedMs,
      );
      _diagnostics.error(_logTag, 'install failed: $e');
      _busy = false;
      _push();
      return <String, Object?>{'ok': false, 'error': e.toString()};
    }
  }

  void _push() {
    if (!_attached) {
      return;
    }
    unawaited(_pushSnapshot(_snapshot));
  }

  Future<void> _pushSnapshot(UpdateSnapshot snapshot) async {
    try {
      await _channel.invokeMethod<void>(
        SpikeUpdatesChannelMethods.state,
        snapshot.toJson(),
      );
    } on MissingPluginException {
      _diagnostics.trace(_logTag, 'native handler not yet attached');
    } on PlatformException catch (e) {
      _diagnostics.error(_logTag, 'state push failed: $e');
    }
  }
}
