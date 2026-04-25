import 'package:alembic/util/git_accounts.dart';
import 'package:github/github.dart';

class AccountClient {
  final GitAccount account;
  final GitHub github;

  AccountClient({
    required this.account,
    required this.github,
  });
}

class AccountRegistry {
  final Map<String, AccountClient> _clientsById = <String, AccountClient>{};
  String? _primaryAccountId;

  AccountRegistry();

  factory AccountRegistry.fromCurrentStorage() {
    final AccountRegistry registry = AccountRegistry();
    registry.refreshFromStorage();
    return registry;
  }

  List<GitAccount> get accounts =>
      _clientsById.values.map((AccountClient client) => client.account).toList()
        ..sort((GitAccount a, GitAccount b) =>
            a.createdAtMs.compareTo(b.createdAtMs));

  List<AccountClient> get clients => _clientsById.values.toList()
    ..sort((AccountClient a, AccountClient b) =>
        a.account.createdAtMs.compareTo(b.account.createdAtMs));

  String? get primaryAccountId => _primaryAccountId;

  GitAccount? get primaryAccount {
    if (_primaryAccountId == null) {
      return null;
    }
    final AccountClient? client = _clientsById[_primaryAccountId];
    return client?.account;
  }

  GitHub? get primaryGitHub {
    if (_primaryAccountId == null) {
      return null;
    }
    return _clientsById[_primaryAccountId]?.github;
  }

  GitHub? githubForAccount(String accountId) =>
      _clientsById[accountId]?.github;

  GitAccount? accountById(String? id) {
    if (id == null) {
      return null;
    }
    return _clientsById[id]?.account;
  }

  bool get isEmpty => _clientsById.isEmpty;

  bool get isNotEmpty => _clientsById.isNotEmpty;

  void refreshFromStorage() {
    final List<GitAccount> stored = loadGitAccounts();
    final Set<String> nextIds = stored.map((GitAccount account) => account.id)
        .toSet();
    final List<String> toRemove = _clientsById.keys
        .where((String id) => !nextIds.contains(id))
        .toList();
    for (final String id in toRemove) {
      _clientsById.remove(id)?.github.dispose();
    }
    for (final GitAccount account in stored) {
      final AccountClient? existing = _clientsById[account.id];
      if (existing == null) {
        _clientsById[account.id] = AccountClient(
          account: account,
          github: GitHub(auth: Authentication.withToken(account.token)),
        );
        continue;
      }
      if (existing.account.token != account.token) {
        existing.github.dispose();
        _clientsById[account.id] = AccountClient(
          account: account,
          github: GitHub(auth: Authentication.withToken(account.token)),
        );
      } else if (existing.account.name != account.name ||
          existing.account.tokenType != account.tokenType ||
          existing.account.login != account.login) {
        _clientsById[account.id] = AccountClient(
          account: account,
          github: existing.github,
        );
      }
    }
    _primaryAccountId = loadPrimaryGitAccountId();
    if (_primaryAccountId != null && !_clientsById.containsKey(_primaryAccountId)) {
      _primaryAccountId = stored.isEmpty ? null : stored.first.id;
    }
  }

  Future<void> dispose() async {
    for (final AccountClient client in _clientsById.values) {
      client.github.dispose();
    }
    _clientsById.clear();
  }
}
