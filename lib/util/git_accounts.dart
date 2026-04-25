import 'dart:convert';
import 'dart:math';

import 'package:alembic/main.dart';

const String gitAccountsStorageKey = 'git_accounts_v2';
const String gitAccountsPrimaryKey = 'primary_account_id';
const String gitAccountsLegacyTokenKey = '1';
const String gitAccountsLegacyTypeKey = 'token_type';
const String gitAccountsLegacyAuthFlag = 'authenticated';

class GitAccount {
  final String id;
  final String name;
  final String token;
  final String tokenType;
  final String? login;
  final int createdAtMs;

  const GitAccount({
    required this.id,
    required this.name,
    required this.token,
    required this.tokenType,
    required this.login,
    required this.createdAtMs,
  });

  GitAccount copyWith({
    String? name,
    String? token,
    String? tokenType,
    String? login,
  }) {
    return GitAccount(
      id: id,
      name: name ?? this.name,
      token: token ?? this.token,
      tokenType: tokenType ?? this.tokenType,
      login: login ?? this.login,
      createdAtMs: createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'token': token,
        'tokenType': tokenType,
        'login': login,
        'createdAtMs': createdAtMs,
      };

  static GitAccount? fromJson(Map<String, dynamic> data) {
    final String id = (data['id'] as String? ?? '').trim();
    final String token = (data['token'] as String? ?? '').trim();
    if (id.isEmpty || token.isEmpty) {
      return null;
    }
    return GitAccount(
      id: id,
      name: (data['name'] as String? ?? '').trim().isEmpty
          ? 'Account'
          : (data['name'] as String).trim(),
      token: token,
      tokenType: (data['tokenType'] as String? ?? '').trim().isEmpty
          ? detectTokenType(token)
          : (data['tokenType'] as String).trim(),
      login: () {
        final String? raw = data['login'] as String?;
        if (raw == null || raw.trim().isEmpty) {
          return null;
        }
        return raw.trim();
      }(),
      createdAtMs: (data['createdAtMs'] as int?) ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

String detectTokenType(String token) {
  final String trimmed = token.trim();
  if (trimmed.startsWith('github_pat_')) {
    return 'fine_grained';
  }
  if (trimmed.startsWith('ghp_')) {
    return 'personal';
  }
  return 'classic';
}

String describeTokenType(String tokenType) {
  return switch (tokenType) {
    'fine_grained' => 'Fine-grained PAT',
    'personal' => 'Personal token (ghp_)',
    'classic' => 'Classic token',
    _ => tokenType,
  };
}

String generateGitAccountId() {
  final Random random = Random.secure();
  final int high = random.nextInt(1 << 32);
  final int low = random.nextInt(1 << 32);
  return 'acc_${high.toRadixString(16).padLeft(8, '0')}${low.toRadixString(16).padLeft(8, '0')}';
}

List<GitAccount> loadGitAccounts() {
  final dynamic raw = box.get(gitAccountsStorageKey);
  if (raw is! String || raw.trim().isEmpty) {
    return <GitAccount>[];
  }
  try {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return <GitAccount>[];
    }
    final List<GitAccount> accounts = <GitAccount>[];
    for (final dynamic entry in decoded) {
      if (entry is Map<dynamic, dynamic>) {
        final Map<String, dynamic> typed = <String, dynamic>{};
        entry.forEach((dynamic key, dynamic value) {
          typed[key.toString()] = value;
        });
        final GitAccount? account = GitAccount.fromJson(typed);
        if (account != null) {
          accounts.add(account);
        }
      }
    }
    return accounts;
  } catch (_) {
    return <GitAccount>[];
  }
}

Future<void> saveGitAccounts(List<GitAccount> accounts) async {
  final List<Map<String, dynamic>> serialized =
      accounts.map((GitAccount account) => account.toJson()).toList();
  await box.put(gitAccountsStorageKey, jsonEncode(serialized));
  await _syncPrimaryLegacyKeys(accounts);
}

Future<GitAccount> addGitAccount({
  required String name,
  required String token,
  String? tokenType,
  String? login,
}) async {
  final List<GitAccount> accounts = loadGitAccounts();
  final String resolvedType = (tokenType ?? '').trim().isEmpty
      ? detectTokenType(token)
      : tokenType!.trim();
  final GitAccount account = GitAccount(
    id: generateGitAccountId(),
    name: name.trim().isEmpty ? 'Account ${accounts.length + 1}' : name.trim(),
    token: token.trim(),
    tokenType: resolvedType,
    login: login,
    createdAtMs: DateTime.now().millisecondsSinceEpoch,
  );
  accounts.add(account);
  await saveGitAccounts(accounts);
  if (loadPrimaryGitAccountId() == null) {
    await setPrimaryGitAccount(account.id);
  }
  return account;
}

Future<void> updateGitAccount(GitAccount updated) async {
  final List<GitAccount> accounts = loadGitAccounts();
  for (int i = 0; i < accounts.length; i++) {
    if (accounts[i].id == updated.id) {
      accounts[i] = updated;
      break;
    }
  }
  await saveGitAccounts(accounts);
}

Future<void> renameGitAccount(String id, String name) async {
  final List<GitAccount> accounts = loadGitAccounts();
  for (int i = 0; i < accounts.length; i++) {
    if (accounts[i].id == id) {
      accounts[i] = accounts[i].copyWith(name: name);
      break;
    }
  }
  await saveGitAccounts(accounts);
}

Future<void> removeGitAccount(String id) async {
  final List<GitAccount> accounts = loadGitAccounts();
  accounts.removeWhere((GitAccount account) => account.id == id);
  await saveGitAccounts(accounts);
  final String? primaryId = loadPrimaryGitAccountId();
  if (primaryId == id) {
    if (accounts.isNotEmpty) {
      await setPrimaryGitAccount(accounts.first.id);
    } else {
      await box.delete(gitAccountsPrimaryKey);
      await box.delete(gitAccountsLegacyTokenKey);
      await box.delete(gitAccountsLegacyTypeKey);
      await box.put(gitAccountsLegacyAuthFlag, false);
    }
  }
}

Future<void> reorderGitAccounts(List<String> orderedIds) async {
  final List<GitAccount> accounts = loadGitAccounts();
  final Map<String, GitAccount> byId = <String, GitAccount>{};
  for (final GitAccount account in accounts) {
    byId[account.id] = account;
  }
  final List<GitAccount> ordered = <GitAccount>[];
  for (final String id in orderedIds) {
    final GitAccount? account = byId.remove(id);
    if (account != null) {
      ordered.add(account);
    }
  }
  ordered.addAll(byId.values);
  await saveGitAccounts(ordered);
}

String? loadPrimaryGitAccountId() {
  final dynamic raw = box.get(gitAccountsPrimaryKey);
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  return null;
}

GitAccount? loadPrimaryGitAccount() {
  final List<GitAccount> accounts = loadGitAccounts();
  if (accounts.isEmpty) {
    return null;
  }
  final String? primaryId = loadPrimaryGitAccountId();
  if (primaryId != null) {
    for (final GitAccount account in accounts) {
      if (account.id == primaryId) {
        return account;
      }
    }
  }
  return accounts.first;
}

GitAccount? findGitAccountById(String? id) {
  if (id == null || id.trim().isEmpty) {
    return null;
  }
  for (final GitAccount account in loadGitAccounts()) {
    if (account.id == id) {
      return account;
    }
  }
  return null;
}

Future<void> setPrimaryGitAccount(String id) async {
  await box.put(gitAccountsPrimaryKey, id);
  await _syncPrimaryLegacyKeys(loadGitAccounts());
}

Future<bool> migrateLegacyTokenIfNeeded() async {
  final List<GitAccount> existing = loadGitAccounts();
  if (existing.isNotEmpty) {
    await _syncPrimaryLegacyKeys(existing);
    return false;
  }
  final String legacyToken =
      box.get(gitAccountsLegacyTokenKey, defaultValue: '').toString().trim();
  if (legacyToken.isEmpty) {
    return false;
  }
  final String legacyType =
      box.get(gitAccountsLegacyTypeKey, defaultValue: '').toString().trim();
  final String resolvedType =
      legacyType.isEmpty ? detectTokenType(legacyToken) : legacyType;
  await addGitAccount(
    name: 'Default',
    token: legacyToken,
    tokenType: resolvedType,
  );
  return true;
}

bool hasAnyAuthenticatedGitAccount() {
  return loadGitAccounts().isNotEmpty;
}

Future<void> _syncPrimaryLegacyKeys(List<GitAccount> accounts) async {
  if (accounts.isEmpty) {
    await box.delete(gitAccountsLegacyTokenKey);
    await box.delete(gitAccountsLegacyTypeKey);
    await box.put(gitAccountsLegacyAuthFlag, false);
    return;
  }
  final String? primaryId = loadPrimaryGitAccountId();
  GitAccount primary = accounts.first;
  if (primaryId != null) {
    for (final GitAccount account in accounts) {
      if (account.id == primaryId) {
        primary = account;
        break;
      }
    }
  }
  await box.put(gitAccountsLegacyTokenKey, primary.token);
  await box.put(gitAccountsLegacyTypeKey, primary.tokenType);
  await box.put(gitAccountsLegacyAuthFlag, true);
}
