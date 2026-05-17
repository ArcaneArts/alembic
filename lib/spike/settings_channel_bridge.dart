import 'dart:async';
import 'dart:io';

import 'package:alembic/bloc/repository_list_store.dart';
import 'package:alembic/main.dart' as alembic_main;
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/spike/spike_channels.dart';
import 'package:alembic/spike/spike_diagnostics.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:flutter/services.dart';
import 'package:github/github.dart';
import 'package:hive_flutter/adapters.dart';

class SettingsChannelBridge {
  SettingsChannelBridge({
    required RepositoryListStore store,
    SpikeDiagnostics? diagnostics,
  })  : _store = store,
        _diagnostics = diagnostics ?? SpikeDiagnostics.instance,
        _channel = const MethodChannel(SpikeChannels.settings);

  static const String _logTag = 'settings_bridge';

  final RepositoryListStore _store;
  final SpikeDiagnostics _diagnostics;
  final MethodChannel _channel;
  StreamSubscription<BoxEvent>? _watch;
  bool _attached = false;
  Timer? _debounce;

  Future<void> attach() async {
    if (_attached) {
      _diagnostics.warn(_logTag, 'attach called twice; ignoring');
      return;
    }
    _attached = true;
    _diagnostics.log(_logTag, 'attaching to channel ${SpikeChannels.settings}');
    _channel.setMethodCallHandler(_handle);
    _watch = alembic_main.boxSettings.watch().listen((BoxEvent event) {
      _schedulePush();
    });
    _push();
    _diagnostics.success(_logTag, 'settings bridge attached');
  }

  Future<void> dispose() async {
    _attached = false;
    _debounce?.cancel();
    _debounce = null;
    await _watch?.cancel();
    _watch = null;
  }

  Future<dynamic> _handle(MethodCall call) async {
    _diagnostics.trace(_logTag, 'native -> ${call.method}');
    try {
      switch (call.method) {
        case SpikeSettingsChannelMethods.getAll:
          return _buildSnapshot();
        case SpikeSettingsChannelMethods.setGeneral:
          return await _handleSetGeneral(call.arguments);
        case SpikeSettingsChannelMethods.setWorkspace:
          return await _handleSetWorkspace(call.arguments);
        case SpikeSettingsChannelMethods.setTools:
          return await _handleSetTools(call.arguments);
        case SpikeSettingsChannelMethods.setArchiveMaster:
          return await _handleSetArchiveMaster(call.arguments);
        case SpikeSettingsChannelMethods.getRepoConfig:
          return _handleGetRepoConfig(call.arguments);
        case SpikeSettingsChannelMethods.setRepoConfig:
          return await _handleSetRepoConfig(call.arguments);
        case SpikeSettingsChannelMethods.revealDataFolder:
          return await _handleRevealDataFolder();
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
      return <String, Object?>{
        'ok': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, Object?>> _handleSetGeneral(Object? rawArgs) async {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final AlembicConfig cfg = config;
    final dynamic autolaunch = args?['autolaunch'];
    if (autolaunch is bool) {
      await alembic_main.boxSettings.put('autolaunch', autolaunch);
      await alembic_main.applyLaunchAtStartupPreference(autolaunch);
    }
    setConfig(cfg);
    return <String, Object?>{'ok': true};
  }

  Future<Map<String, Object?>> _handleSetWorkspace(Object? rawArgs) async {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final AlembicConfig cfg = config;
    final String? workspaceDirectory = (args?['workspaceDirectory'] as String?)?.trim();
    final String? archiveDirectory = (args?['archiveDirectory'] as String?)?.trim();
    final String? archiveMasterDirectory = (args?['archiveMasterDirectory'] as String?)?.trim();
    final int? daysToArchive = args?['daysToArchive'] as int?;
    if (workspaceDirectory != null && workspaceDirectory.isNotEmpty) {
      cfg.workspaceDirectory = workspaceDirectory;
    }
    if (archiveDirectory != null && archiveDirectory.isNotEmpty) {
      cfg.archiveDirectory = archiveDirectory;
    }
    if (archiveMasterDirectory != null && archiveMasterDirectory.isNotEmpty) {
      cfg.archiveMasterDirectory = archiveMasterDirectory;
    }
    if (daysToArchive != null && daysToArchive > 0) {
      cfg.daysToArchive = daysToArchive;
    }
    setConfig(cfg);
    return <String, Object?>{'ok': true};
  }

  Future<Map<String, Object?>> _handleSetTools(Object? rawArgs) async {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final AlembicConfig cfg = config;
    final String? editorToolName = (args?['editorTool'] as String?)?.trim();
    final String? gitToolName = (args?['gitTool'] as String?)?.trim();
    if (editorToolName != null && editorToolName.isNotEmpty) {
      cfg.editorTool = ApplicationTool.values.firstWhere(
        (ApplicationTool tool) =>
            tool.name == editorToolName && tool.supportedOnCurrentPlatform,
        orElse: () => cfg.editorTool ?? ApplicationTool.intellij,
      );
    }
    if (gitToolName != null && gitToolName.isNotEmpty) {
      cfg.gitTool = GitTool.values.firstWhere(
        (GitTool tool) =>
            tool.name == gitToolName && tool.supportedOnCurrentPlatform,
        orElse: () => cfg.gitTool ?? GitTool.gitkraken,
      );
    }
    setConfig(cfg);
    return <String, Object?>{'ok': true};
  }

  Future<Map<String, Object?>> _handleSetArchiveMaster(Object? rawArgs) async {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final AlembicConfig cfg = config;
    final int? interval = args?['archiveMasterIntervalMinutes'] as int?;
    if (interval != null && interval > 0) {
      cfg.archiveMasterIntervalMinutes = interval;
    }
    setConfig(cfg);
    return <String, Object?>{'ok': true};
  }

  Map<String, Object?> _handleGetRepoConfig(Object? rawArgs) {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final String fullName = (args?['fullName'] as String? ?? '').trim();
    if (fullName.isEmpty) {
      return <String, Object?>{
        'ok': false,
        'error': 'fullName is required.',
      };
    }
    final Repository? repo = _store.findRepository(fullName);
    if (repo == null) {
      return <String, Object?>{
        'ok': false,
        'error': 'Repository not in cache.',
      };
    }
    final AlembicRepoConfig repoConfig = getRepoConfig(repo);
    return <String, Object?>{
      'ok': true,
      'fullName': repo.fullName,
      'config': _repoConfigToJson(repoConfig),
    };
  }

  Future<Map<String, Object?>> _handleSetRepoConfig(Object? rawArgs) async {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final String fullName = (args?['fullName'] as String? ?? '').trim();
    if (fullName.isEmpty) {
      return <String, Object?>{
        'ok': false,
        'error': 'fullName is required.',
      };
    }
    final Repository? repo = _store.findRepository(fullName);
    if (repo == null) {
      return <String, Object?>{
        'ok': false,
        'error': 'Repository not in cache.',
      };
    }
    final AlembicRepoConfig cfg = getRepoConfig(repo);
    final String? editorToolName = (args?['editorTool'] as String?)?.trim();
    final String? gitToolName = (args?['gitTool'] as String?)?.trim();
    final String? openDirectory = (args?['openDirectory'] as String?)?.trim();
    final String? accountId = (args?['accountId'] as String?)?.trim();
    final dynamic clearEditor = args?['clearEditor'];
    final dynamic clearGit = args?['clearGit'];
    final dynamic clearAccount = args?['clearAccount'];

    if (clearEditor == true) {
      cfg.editorTool = null;
    } else if (editorToolName != null && editorToolName.isNotEmpty) {
      cfg.editorTool = ApplicationTool.values.firstWhere(
        (ApplicationTool tool) =>
            tool.name == editorToolName && tool.supportedOnCurrentPlatform,
        orElse: () => cfg.editorTool ?? config.editorTool ?? ApplicationTool.intellij,
      );
    }
    if (clearGit == true) {
      cfg.gitTool = null;
    } else if (gitToolName != null && gitToolName.isNotEmpty) {
      cfg.gitTool = GitTool.values.firstWhere(
        (GitTool tool) =>
            tool.name == gitToolName && tool.supportedOnCurrentPlatform,
        orElse: () => cfg.gitTool ?? config.gitTool ?? GitTool.gitkraken,
      );
    }
    if (openDirectory != null && openDirectory.isNotEmpty) {
      cfg.openDirectory = openDirectory;
    }
    if (clearAccount == true) {
      cfg.accountId = null;
    } else if (accountId != null && accountId.isNotEmpty) {
      cfg.accountId = accountId;
    }
    setRepoConfig(repo, cfg);
    return <String, Object?>{
      'ok': true,
      'fullName': repo.fullName,
      'config': _repoConfigToJson(cfg),
    };
  }

  Future<Map<String, Object?>> _handleRevealDataFolder() async {
    final String path = alembic_main.configPath;
    try {
      await DesktopPlatformAdapter.instance.openInFileExplorer(path);
      return <String, Object?>{'ok': true, 'path': path};
    } catch (e) {
      return <String, Object?>{
        'ok': false,
        'error': e.toString(),
      };
    }
  }

  void _schedulePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), _push);
  }

  void _push() {
    if (!_attached) {
      return;
    }
    final Map<String, Object?> snapshot = _buildSnapshot();
    try {
      _channel.invokeMethod<void>(
        SpikeSettingsChannelMethods.state,
        snapshot,
      );
    } on MissingPluginException {
      _diagnostics.trace(_logTag, 'native handler not yet attached');
    } on PlatformException catch (e) {
      _diagnostics.error(_logTag, 'state push failed: $e');
    }
  }

  Map<String, Object?> _buildSnapshot() {
    final AlembicConfig cfg = config;
    final DesktopPlatformAdapter adapter = DesktopPlatformAdapter.instance;
    return <String, Object?>{
      'workspaceDirectory': cfg.workspaceDirectory,
      'archiveDirectory': cfg.archiveDirectory,
      'archiveMasterDirectory': cfg.archiveMasterDirectory,
      'defaultWorkspaceDirectory': cfg.defaultWorkspaceDirectory,
      'defaultArchiveDirectory': cfg.defaultArchiveDirectory,
      'defaultArchiveMasterDirectory': cfg.defaultArchiveMasterDirectory,
      'daysToArchive': cfg.daysToArchive,
      'archiveMasterIntervalMinutes': cfg.archiveMasterIntervalMinutes,
      'editorTool': cfg.editorTool?.name,
      'gitTool': cfg.gitTool?.name,
      'autolaunch':
          alembic_main.boxSettings.get('autolaunch', defaultValue: true) ==
              true,
      'configPath': alembic_main.configPath,
      'supportedEditorTools': ApplicationTool.values
          .where((ApplicationTool tool) => tool.supportedOnCurrentPlatform)
          .map(_editorToolToJson)
          .toList(growable: false),
      'supportedGitTools': GitTool.values
          .where((GitTool tool) => tool.supportedOnCurrentPlatform)
          .map(_gitToolToJson)
          .toList(growable: false),
      'platform': <String, Object?>{
        'isMacOS': adapter.isMacOS,
        'isWindows': adapter.isWindows,
        'pathSeparator': Platform.pathSeparator,
      },
    };
  }

  Map<String, Object?> _editorToolToJson(ApplicationTool tool) {
    return <String, Object?>{
      'name': tool.name,
      'displayName': tool.displayName,
      'help': tool.help,
    };
  }

  Map<String, Object?> _gitToolToJson(GitTool tool) {
    return <String, Object?>{
      'name': tool.name,
      'displayName': tool.displayName,
    };
  }

  Map<String, Object?> _repoConfigToJson(AlembicRepoConfig cfg) {
    return <String, Object?>{
      'editorTool': cfg.editorTool?.name,
      'gitTool': cfg.gitTool?.name,
      'openDirectory': cfg.openDirectory,
      'lastOpenMs': cfg.lastOpen,
      'accountId': cfg.accountId,
    };
  }
}
