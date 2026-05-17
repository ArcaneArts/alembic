import 'dart:async';
import 'dart:io';

import 'package:alembic/bloc/repository_list_store.dart';
import 'package:alembic/spike/repo_import_scanner.dart';
import 'package:alembic/spike/spike_channels.dart';
import 'package:alembic/spike/spike_diagnostics.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:flutter/services.dart';

class WorkspaceChannelBridge {
  WorkspaceChannelBridge({required RepositoryListStore store}) : _store = store;

  final RepositoryListStore _store;
  static const String _tag = 'workspace_bridge';
  static final SpikeDiagnostics _diag = SpikeDiagnostics.instance;

  final MethodChannel _channel = const MethodChannel(SpikeChannels.workspace);
  bool _attached = false;

  void attach() {
    if (_attached) {
      _diag.warn(_tag, 'attach called twice; ignoring');
      return;
    }
    _attached = true;
    _diag.log(_tag, 'attaching to channel ${SpikeChannels.workspace}');
    _channel.setMethodCallHandler(_handle);
    _diag.success(_tag, 'workspace channel handler installed');
  }

  String _currentWorkspacePath() {
    try {
      return config.workspaceDirectory;
    } catch (e) {
      _diag.warn(_tag, 'could not read config: $e');
      return '';
    }
  }

  Map<String, dynamic> _stateSnapshot() {
    final String path = _currentWorkspacePath();
    Directory dir = Directory(path);
    bool exists = false;
    try {
      exists = dir.existsSync();
    } catch (_) {
      exists = false;
    }
    return <String, dynamic>{
      'workspacePath': path,
      'exists': exists,
    };
  }

  Future<dynamic> _handle(MethodCall call) async {
    _diag.trace(_tag, 'native -> ${call.method}');
    switch (call.method) {
      case SpikeWorkspaceChannelMethods.getWorkspacePath:
        return _stateSnapshot();
      case SpikeWorkspaceChannelMethods.setWorkspacePath:
        return _handleSetWorkspacePath(call.arguments);
      case SpikeWorkspaceChannelMethods.scanDirectory:
        return _handleScanDirectory(call.arguments);
      case SpikeWorkspaceChannelMethods.importDiscovered:
        return _handleImportDiscovered(call.arguments);
      default:
        _diag.warn(_tag, 'unknown method ${call.method}');
        throw MissingPluginException('Unknown method ${call.method}');
    }
  }

  Future<Map<String, dynamic>> _handleSetWorkspacePath(dynamic args) async {
    final Map<dynamic, dynamic>? map = args is Map ? args : null;
    final String? path = map?['path'] as String?;
    if (path == null || path.trim().isEmpty) {
      _diag.warn(_tag, 'setWorkspacePath: empty path');
      return <String, dynamic>{
        'ok': false,
        'error': 'Workspace path cannot be empty',
      };
    }
    try {
      final Directory dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        _diag.log(_tag, 'created workspace directory: $path');
      }
      final AlembicConfig current = config;
      current.workspaceDirectory = path;
      setConfig(current);
      _diag.success(_tag, 'workspace path persisted: $path');
      unawaited(_store.refresh());
      return <String, dynamic>{
        'ok': true,
        'workspacePath': path,
      };
    } catch (e) {
      _diag.error(_tag, 'setWorkspacePath failed: $e');
      return <String, dynamic>{
        'ok': false,
        'error': 'Failed to set workspace: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _handleScanDirectory(dynamic args) async {
    final Map<dynamic, dynamic>? map = args is Map ? args : null;
    final String? path = map?['path'] as String?;
    final int maxDepth =
        (map?['maxDepth'] as int?) ?? RepoImportScanner.defaultMaxDepth;

    if (path == null || path.trim().isEmpty) {
      _diag.warn(_tag, 'scanDirectory: empty path');
      return <String, dynamic>{
        'ok': false,
        'error': 'Scan path cannot be empty',
      };
    }

    _diag.log(_tag, 'scanDirectory starting: path=$path maxDepth=$maxDepth');
    try {
      final RepoImportScanner scanner = RepoImportScanner(
        maxDepth: maxDepth,
        onProgress: (ScanProgress progress) {
          unawaited(_channel.invokeMethod<void>(
            SpikeWorkspaceChannelMethods.scanProgress,
            progress.toJson(),
          ));
        },
      );
      final ScanResult result = await scanner.scan(path);
      _diag.success(
        _tag,
        'scanDirectory complete: ${result.repos.length} repo(s) found',
      );
      return <String, dynamic>{
        'ok': true,
        'result': result.toJson(),
      };
    } catch (e) {
      _diag.error(_tag, 'scanDirectory failed: $e');
      return <String, dynamic>{
        'ok': false,
        'error': 'Scan failed: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _handleImportDiscovered(dynamic args) async {
    final Map<dynamic, dynamic>? map = args is Map ? args : null;
    final String? rootPath = map?['rootPath'] as String?;
    final List<dynamic>? selectedSlugs = map?['selectedSlugs'] as List<dynamic>?;

    if (rootPath == null || rootPath.trim().isEmpty) {
      _diag.warn(_tag, 'importDiscovered: empty rootPath');
      return <String, dynamic>{
        'ok': false,
        'error': 'Root path cannot be empty',
      };
    }

    final List<String> slugs = (selectedSlugs ?? <dynamic>[])
        .whereType<String>()
        .toList();
    _diag.log(
      _tag,
      'importDiscovered: rootPath=$rootPath selectedSlugs=${slugs.length}',
    );

    try {
      final Directory rootDir = Directory(rootPath);
      if (!await rootDir.exists()) {
        _diag.warn(_tag, 'rootPath does not exist: $rootPath');
        return <String, dynamic>{
          'ok': false,
          'error': 'Root path does not exist',
        };
      }

      final AlembicConfig current = config;
      current.workspaceDirectory = rootPath;
      setConfig(current);
      _diag.success(_tag, 'workspace directory updated to $rootPath');

      unawaited(_store.refresh());
      return <String, dynamic>{
        'ok': true,
        'workspacePath': rootPath,
        'importedCount': slugs.length,
      };
    } catch (e) {
      _diag.error(_tag, 'importDiscovered failed: $e');
      return <String, dynamic>{
        'ok': false,
        'error': 'Import failed: $e',
      };
    }
  }
}
