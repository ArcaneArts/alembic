import 'dart:async';

import 'package:alembic/bloc/repository_list_store.dart';
import 'package:alembic/core/token_validator.dart';
import 'package:alembic/spike/spike_channels.dart';
import 'package:alembic/spike/spike_diagnostics.dart';
import 'package:alembic/util/git_accounts.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:alembic/main.dart' as alembic_main;

class AccountsChannelBridge {
  AccountsChannelBridge({
    required RepositoryListStore store,
    SpikeDiagnostics? diagnostics,
  })  : _store = store,
        _diagnostics = diagnostics ?? SpikeDiagnostics.instance,
        _channel = const MethodChannel(SpikeChannels.accounts);

  static const String _logTag = 'accounts_bridge';

  final RepositoryListStore _store;
  final SpikeDiagnostics _diagnostics;
  final MethodChannel _channel;
  StreamSubscription<BoxEvent>? _watch;
  bool _attached = false;

  Future<void> attach() async {
    if (_attached) {
      _diagnostics.warn(_logTag, 'attach called twice; ignoring');
      return;
    }
    _attached = true;
    _diagnostics.log(_logTag, 'attaching to channel ${SpikeChannels.accounts}');
    _channel.setMethodCallHandler(_handle);

    _watch = alembic_main.box.watch().listen((BoxEvent event) {
      final String? key = event.key as String?;
      if (key == null) {
        return;
      }
      if (key == gitAccountsStorageKey ||
          key == gitAccountsPrimaryKey ||
          key == gitAccountsLegacyTokenKey ||
          key == gitAccountsLegacyTypeKey ||
          key == gitAccountsLegacyAuthFlag) {
        _push();
      }
    });
    _push();
    _diagnostics.success(_logTag, 'accounts bridge attached');
  }

  Future<void> dispose() async {
    _attached = false;
    await _watch?.cancel();
    _watch = null;
  }

  Future<dynamic> _handle(MethodCall call) async {
    _diagnostics.trace(_logTag, 'native -> ${call.method}');
    try {
      switch (call.method) {
        case SpikeAccountChannelMethods.getAll:
          return _buildSnapshot();
        case SpikeAccountChannelMethods.add:
          return await _handleAdd(call.arguments);
        case SpikeAccountChannelMethods.remove:
          return await _handleRemove(call.arguments);
        case SpikeAccountChannelMethods.rename:
          return await _handleRename(call.arguments);
        case SpikeAccountChannelMethods.setPrimary:
          return await _handleSetPrimary(call.arguments);
        case SpikeAccountChannelMethods.reorder:
          return await _handleReorder(call.arguments);
        default:
          _diagnostics.warn(_logTag, 'unhandled method ${call.method}');
          return <String, Object?>{
            'ok': false,
            'error': 'Unknown action: ${call.method}',
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

  Future<Map<String, Object?>> _handleAdd(Object? rawArgs) async {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final String token = (args?['token'] as String? ?? '').trim();
    final String name = (args?['name'] as String? ?? '').trim();
    if (token.isEmpty) {
      return <String, Object?>{
        'ok': false,
        'error': 'Token is required.',
      };
    }
    final TokenValidator validator = const TokenValidator();
    final TokenValidationResult result = await validator.validate(token);
    if (!result.isValid) {
      return <String, Object?>{
        'ok': false,
        'error': result.message,
      };
    }
    final String accountName =
        name.isNotEmpty ? name : (result.login ?? 'GitHub');
    final GitAccount account = await addGitAccount(
      name: accountName,
      token: token,
      login: result.login,
    );
    _store.registry.refreshFromStorage();
    unawaited(_store.refresh());
    return <String, Object?>{
      'ok': true,
      'accountId': account.id,
      'login': result.login,
    };
  }

  Future<Map<String, Object?>> _handleRemove(Object? rawArgs) async {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final String id = (args?['accountId'] as String? ?? '').trim();
    if (id.isEmpty) {
      return <String, Object?>{
        'ok': false,
        'error': 'Account id is required.',
      };
    }
    await removeGitAccount(id);
    _store.registry.refreshFromStorage();
    unawaited(_store.refresh());
    return <String, Object?>{'ok': true};
  }

  Future<Map<String, Object?>> _handleRename(Object? rawArgs) async {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final String id = (args?['accountId'] as String? ?? '').trim();
    final String name = (args?['name'] as String? ?? '').trim();
    if (id.isEmpty || name.isEmpty) {
      return <String, Object?>{
        'ok': false,
        'error': 'Account id and name are required.',
      };
    }
    await renameGitAccount(id, name);
    _store.registry.refreshFromStorage();
    return <String, Object?>{'ok': true};
  }

  Future<Map<String, Object?>> _handleSetPrimary(Object? rawArgs) async {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final String id = (args?['accountId'] as String? ?? '').trim();
    if (id.isEmpty) {
      return <String, Object?>{
        'ok': false,
        'error': 'Account id is required.',
      };
    }
    await setPrimaryGitAccount(id);
    _store.registry.refreshFromStorage();
    unawaited(_store.refresh());
    return <String, Object?>{'ok': true};
  }

  Future<Map<String, Object?>> _handleReorder(Object? rawArgs) async {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final List<dynamic>? rawOrder = args?['order'] as List<dynamic>?;
    if (rawOrder == null) {
      return <String, Object?>{
        'ok': false,
        'error': 'Order list is required.',
      };
    }
    final List<String> order = rawOrder
        .whereType<String>()
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
    await reorderGitAccounts(order);
    return <String, Object?>{'ok': true};
  }

  void _push() {
    if (!_attached) {
      return;
    }
    final Map<String, Object?> snapshot = _buildSnapshot();
    try {
      _channel.invokeMethod<void>(
        SpikeAccountChannelMethods.state,
        snapshot,
      );
    } on MissingPluginException {
      _diagnostics.trace(_logTag, 'native handler not yet attached');
    } on PlatformException catch (e) {
      _diagnostics.error(_logTag, 'state push failed: $e');
    }
  }

  Map<String, Object?> _buildSnapshot() {
    final List<GitAccount> accounts = loadGitAccounts();
    final String? primaryId = loadPrimaryGitAccountId();
    return <String, Object?>{
      'accounts': accounts.map(_accountToJson).toList(growable: false),
      'primaryAccountId': primaryId,
    };
  }

  Map<String, Object?> _accountToJson(GitAccount account) {
    return <String, Object?>{
      'id': account.id,
      'name': account.name,
      'login': account.login,
      'tokenType': account.tokenType,
      'tokenDescription': describeTokenType(account.tokenType),
      'createdAtMs': account.createdAtMs,
    };
  }
}
