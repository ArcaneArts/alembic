import 'dart:async';

import 'package:alembic/bloc/repository_list_store.dart';
import 'package:alembic/core/token_validator.dart';
import 'package:alembic/domain/repository_dto.dart';
import 'package:alembic/spike/spike_channels.dart';
import 'package:alembic/spike/spike_diagnostics.dart';
import 'package:alembic/util/git_accounts.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class RepositoryChannelBridge {
  RepositoryChannelBridge({
    RepositoryListStore? store,
    SpikeDiagnostics? diagnostics,
  })  : _store = store ?? RepositoryListStore(),
        _diagnostics = diagnostics ?? SpikeDiagnostics.instance,
        _channel = const MethodChannel(SpikeChannels.repositories);

  static const String _logTag = 'repo_bridge';

  final RepositoryListStore _store;
  final SpikeDiagnostics _diagnostics;
  final MethodChannel _channel;
  StreamSubscription<RepositoryListState>? _subscription;
  int _pushSeq = 0;

  RepositoryListStore get store => _store;

  Future<void> attach() async {
    _diagnostics.log(_logTag, 'attaching to channel ${SpikeChannels.repositories}');
    _channel.setMethodCallHandler(_handle);
    _subscription = _store.stream.listen(_push);
    await _push(_store.value);
    _diagnostics.log(_logTag, 'initial state pushed; scheduling first refresh');
    unawaited(_store.refresh());
  }

  Future<void> dispose() async {
    _diagnostics.log(_logTag, 'disposing repository channel bridge');
    await _subscription?.cancel();
    _subscription = null;
    await _store.close();
  }

  Future<dynamic> _handle(MethodCall call) async {
    _diagnostics.trace(_logTag, 'native -> dart: ${call.method}');
    switch (call.method) {
      case SpikeRepositoryChannelMethods.refresh:
        await _store.refresh();
        return null;
      case SpikeRepositoryChannelMethods.retry:
        await _store.retry();
        return null;
      case SpikeRepositoryChannelMethods.openInBrowser:
        return _handleOpenInBrowser(call);
      case SpikeRepositoryChannelMethods.signInWithToken:
        return _handleSignInWithToken(call);
      case SpikeRepositoryChannelMethods.signOut:
        return _handleSignOut(call);
      default:
        _diagnostics.warn(_logTag, 'unhandled native call: ${call.method}');
        return null;
    }
  }

  Future<void> _handleOpenInBrowser(MethodCall call) async {
    final Map<dynamic, dynamic>? args =
        call.arguments is Map ? call.arguments as Map : null;
    final Object? url = args?['url'];
    if (url is String && url.isNotEmpty) {
      _diagnostics.log(_logTag, 'opening url in browser: $url');
      try {
        await launchUrl(Uri.parse(url));
      } catch (e) {
        _diagnostics.error(_logTag, 'launchUrl failed for $url: $e');
      }
    } else {
      _diagnostics.warn(_logTag, 'openInBrowser missing url argument');
    }
  }

  Future<Map<String, Object?>> _handleSignInWithToken(MethodCall call) async {
    final Map<dynamic, dynamic>? args =
        call.arguments is Map ? call.arguments as Map : null;
    final String token = (args?['token'] as String? ?? '').trim();
    final String name = (args?['name'] as String? ?? '').trim();
    _diagnostics.log(_logTag,
        'signInWithToken received (token length=${token.length}, name="$name")');
    if (token.isEmpty) {
      _diagnostics.warn(_logTag, 'signInWithToken rejected: empty token');
      return <String, Object?>{
        'ok': false,
        'error': 'Token is required.',
      };
    }
    final TokenValidator validator = const TokenValidator();
    _diagnostics.trace(_logTag, 'validating token via api.github.com/user');
    final TokenValidationResult result = await validator.validate(token);
    if (!result.isValid) {
      _diagnostics.error(_logTag, 'token rejected: ${result.message}');
      return <String, Object?>{
        'ok': false,
        'error': result.message,
      };
    }
    _diagnostics.success(_logTag,
        'token validated as ${result.login ?? '(no login)'}');
    final String accountName =
        name.isNotEmpty ? name : (result.login ?? 'GitHub');
    final GitAccount account = await addGitAccount(
      name: accountName,
      token: token,
      login: result.login,
    );
    _diagnostics.log(_logTag,
        'account persisted (id=${account.id}, login=${result.login}); refreshing repository list');
    unawaited(_store.refresh());
    return <String, Object?>{
      'ok': true,
      'accountId': account.id,
      'login': result.login,
    };
  }

  Future<Map<String, Object?>> _handleSignOut(MethodCall call) async {
    final Map<dynamic, dynamic>? args =
        call.arguments is Map ? call.arguments as Map : null;
    final String accountId = (args?['accountId'] as String? ?? '').trim();
    if (accountId.isEmpty) {
      _diagnostics.warn(_logTag, 'signOut rejected: missing accountId');
      return <String, Object?>{
        'ok': false,
        'error': 'Account id is required.',
      };
    }
    _diagnostics.log(_logTag, 'signing out account $accountId');
    await removeGitAccount(accountId);
    unawaited(_store.refresh());
    return <String, Object?>{'ok': true};
  }

  Future<void> _push(RepositoryListState state) async {
    _pushSeq += 1;
    final int seq = _pushSeq;
    _diagnostics.trace(
      _logTag,
      'push #$seq status=${state.status} phase=${state.phase} '
      'fetched=${state.fetchedCount} attempt=${state.attempt}',
    );
    try {
      await _channel.invokeMethod<void>(
        SpikeRepositoryChannelMethods.state,
        state.toJson(),
      );
    } on MissingPluginException {
      _diagnostics.warn(_logTag,
          'push #$seq dropped: native repository handler not yet registered');
    } on PlatformException catch (e) {
      _diagnostics.error(_logTag, 'push #$seq failed: $e');
    }
  }
}
