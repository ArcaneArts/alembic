import 'dart:async';
import 'dart:io';

import 'package:alembic/bloc/spike_app_state_store.dart';
import 'package:alembic/domain/spike_app_state.dart';
import 'package:alembic/spike/accounts_channel_bridge.dart';
import 'package:alembic/spike/boot_context.dart';
import 'package:alembic/spike/legacy_data_migrator.dart';
import 'package:alembic/spike/repository_actions_bridge.dart';
import 'package:alembic/spike/repository_channel_bridge.dart';
import 'package:alembic/spike/repository_work_bridge.dart';
import 'package:alembic/spike/settings_channel_bridge.dart';
import 'package:alembic/spike/spike_channels.dart';
import 'package:alembic/spike/spike_diagnostics.dart';
import 'package:alembic/spike/update_channel_bridge.dart';
import 'package:alembic/spike/workspace_channel_bridge.dart';
import 'package:alembic/util/git_accounts.dart';
import 'package:flutter/services.dart';

class AlembicSpikeRuntime {
  AlembicSpikeRuntime({
    SpikeAppStateStore? store,
    RepositoryChannelBridge? repositoryBridge,
    WorkspaceChannelBridge? workspaceBridge,
    RepositoryActionsBridge? actionsBridge,
    RepositoryWorkBridge? workBridge,
    AccountsChannelBridge? accountsBridge,
    SettingsChannelBridge? settingsBridge,
    UpdateChannelBridge? updatesBridge,
    SpikeDiagnostics? diagnostics,
  })  : _store = store ?? SpikeAppStateStore(),
        _updatesBridge = updatesBridge ?? UpdateChannelBridge(),
        _repositoryBridge = repositoryBridge ?? RepositoryChannelBridge(),
        _diagnostics = diagnostics ?? SpikeDiagnostics.instance {
    _workspaceBridge = workspaceBridge ??
        WorkspaceChannelBridge(store: _repositoryBridge.store);
    _actionsBridge = actionsBridge ??
        RepositoryActionsBridge(store: _repositoryBridge.store);
    _workBridge = workBridge ??
        RepositoryWorkBridge(store: _repositoryBridge.store);
    _accountsBridge = accountsBridge ??
        AccountsChannelBridge(store: _repositoryBridge.store);
    _settingsBridge = settingsBridge ??
        SettingsChannelBridge(store: _repositoryBridge.store);
  }

  static const MethodChannel _channel = MethodChannel(SpikeChannels.app);
  static const String _logTag = 'spike_runtime';

  final SpikeAppStateStore _store;
  final RepositoryChannelBridge _repositoryBridge;
  late final WorkspaceChannelBridge _workspaceBridge;
  late final RepositoryActionsBridge _actionsBridge;
  late final RepositoryWorkBridge _workBridge;
  late final AccountsChannelBridge _accountsBridge;
  late final SettingsChannelBridge _settingsBridge;
  final UpdateChannelBridge _updatesBridge;
  final SpikeDiagnostics _diagnostics;
  Timer? _heartbeatTimer;
  StreamSubscription<SpikeAppState>? _stateSubscription;

  Future<void> boot() async {
    _diagnostics.log(_logTag, 'boot() starting');
    _channel.setMethodCallHandler(_handleNativeCall);
    _diagnostics.trace(
        _logTag, 'app channel handler registered (${SpikeChannels.app})');

    _stateSubscription = _store.stream.listen(_pushState);
    _diagnostics.trace(_logTag, 'app state subscription attached');

    _store.mutate((SpikeAppState current) {
      return _enrichWithBootContext(
        current.copyWith(
          status: 'ready',
          epochMillis: DateTime.now().millisecondsSinceEpoch,
          pid: '$pid',
        ),
      );
    });

    _diagnostics.log(_logTag, 'attaching repository channel bridge');
    await _repositoryBridge.attach();

    _diagnostics.log(_logTag, 'attaching workspace channel bridge');
    _workspaceBridge.attach();

    _diagnostics.log(_logTag, 'attaching repository actions bridge');
    await _actionsBridge.attach();

    _diagnostics.log(_logTag, 'attaching repository work bridge');
    await _workBridge.attach();

    _diagnostics.log(_logTag, 'attaching accounts channel bridge');
    await _accountsBridge.attach();

    _diagnostics.log(_logTag, 'attaching settings channel bridge');
    await _settingsBridge.attach();

    _diagnostics.log(_logTag, 'attaching updates channel bridge');
    await _updatesBridge.attach();

    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickHeartbeat(),
    );
    _diagnostics.success(_logTag, 'boot() complete - heartbeat running');
  }

  Future<void> dispose() async {
    _diagnostics.log(_logTag, 'disposing runtime');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _workBridge.dispose();
    await _accountsBridge.dispose();
    await _settingsBridge.dispose();
    await _updatesBridge.dispose();
    await _repositoryBridge.dispose();
    await _store.close();
    _diagnostics.log(_logTag, 'runtime disposed');
  }

  void _tickHeartbeat() {
    _store.mutate((SpikeAppState current) {
      return _enrichWithBootContext(
        current.copyWith(
          tick: current.tick + 1,
          epochMillis: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
  }

  SpikeAppState _enrichWithBootContext(SpikeAppState state) {
    final BootContext context = BootContext.instance;
    final MigrationReport? report = context.migrationReport;
    final List<GitAccount> accounts = loadGitAccounts();
    final GitAccount? primary = loadPrimaryGitAccount();
    return state.copyWith(
      configPath: context.configPath,
      migrationAttempted: report?.attempted ?? false,
      migrationSourcePath: report?.sourcePath,
      migrationCopiedFiles: report?.copied ?? const <String>[],
      migrationSkippedFiles: report?.skipped ?? const <String>[],
      migrationSearchedPaths: report?.searchedPaths ?? const <String>[],
      hiveEntries: context.hiveEntries,
      accountCount: accounts.length,
      primaryAccountLogin: primary?.login,
    );
  }

  Future<void> _pushState(SpikeAppState state) async {
    await _safeInvoke(SpikeAppChannelMethods.state, state.toJson());
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    _diagnostics.trace(_logTag, 'app call from native: ${call.method}');
    switch (call.method) {
      case SpikeAppChannelMethods.echo:
        final Map<dynamic, dynamic>? args =
            call.arguments is Map ? call.arguments as Map : null;
        final Object? value = args?['value'];
        return <String, Object?>{
          'echoedFrom': 'dart',
          'value': value,
          'tick': _store.value.tick,
        };
      case SpikeAppChannelMethods.setStatus:
        final Map<dynamic, dynamic>? args =
            call.arguments is Map ? call.arguments as Map : null;
        final Object? next = args?['status'];
        if (next is String) {
          _diagnostics.log(_logTag, 'status set by native: $next');
          _store.mutate((SpikeAppState current) {
            return _enrichWithBootContext(current.copyWith(status: next));
          });
        }
        return null;
      case SpikeAppChannelMethods.shutdown:
        await dispose();
        return null;
      default:
        _diagnostics.warn(_logTag, 'unhandled app call: ${call.method}');
        return null;
    }
  }

  Future<void> _safeInvoke(String method, Object? arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Native side may not be attached yet on first ticks; ignore quietly.
    } on PlatformException {
      // Channel failure during shutdown.
    }
  }
}
