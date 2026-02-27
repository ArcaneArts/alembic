import 'dart:io';

import 'package:alembic/main.dart';
import 'package:rxdart/rxdart.dart';

class GitSigningStatus {
  final bool commitSigningEnabled;
  final String? signingFormat;
  final String? signingKey;

  const GitSigningStatus({
    required this.commitSigningEnabled,
    required this.signingFormat,
    required this.signingKey,
  });

  bool get isConfigured {
    final String format = (signingFormat ?? '').trim().toLowerCase();
    final String key = (signingKey ?? '').trim();
    return commitSigningEnabled && format == 'ssh' && key.isNotEmpty;
  }

  String get label {
    if (isConfigured) {
      return 'Configured (SSH signing enabled)';
    }
    if ((signingKey ?? '').trim().isNotEmpty ||
        (signingFormat ?? '').trim().isNotEmpty ||
        commitSigningEnabled) {
      return 'Partially configured';
    }
    return 'Not configured';
  }
}

class GitSigningManager {
  final CommandRunner commandRunner;
  final String? homeDirectory;

  const GitSigningManager({
    this.commandRunner = cmd,
    this.homeDirectory,
  });

  Future<GitSigningStatus> inspectGlobalSigning() async {
    final String? signingEnabled = await _readGitConfig(
      <String>['config', '--global', '--get', 'commit.gpgsign'],
    );
    final String? signingFormat = await _readGitConfig(
      <String>['config', '--global', '--get', 'gpg.format'],
    );
    final String? signingKey = await _readGitConfig(
      <String>['config', '--global', '--get', 'user.signingkey'],
    );

    return GitSigningStatus(
      commitSigningEnabled:
          (signingEnabled ?? '').trim().toLowerCase() == 'true',
      signingFormat: signingFormat?.trim(),
      signingKey: signingKey?.trim(),
    );
  }

  Future<GitSigningStatus> ensureGlobalIntrinsicSigning() async {
    GitSigningStatus status = await inspectGlobalSigning();
    String signingFormat = (status.signingFormat ?? '').trim().toLowerCase();
    String signingKey = (status.signingKey ?? '').trim();

    if (signingFormat.isNotEmpty && signingKey.isNotEmpty) {
      if (!status.commitSigningEnabled) {
        await _setGitConfig(
          <String>['config', '--global', 'commit.gpgsign', 'true'],
        );
      }
      return inspectGlobalSigning();
    }

    if (signingFormat.isEmpty) {
      await _setGitConfig(
        <String>['config', '--global', 'gpg.format', 'ssh'],
      );
      signingFormat = 'ssh';
    }

    if (signingFormat != 'ssh' && signingKey.isEmpty) {
      await _setGitConfig(
        <String>['config', '--global', 'gpg.format', 'ssh'],
      );
      signingFormat = 'ssh';
    }

    if (signingFormat == 'ssh' && signingKey.isEmpty) {
      final String? resolvedKey = await _resolveSigningKey();
      signingKey = (resolvedKey ?? '').trim();
      if (signingKey.isNotEmpty) {
        await _setGitConfig(
          <String>['config', '--global', 'user.signingkey', signingKey],
        );
      }
    }

    if (!status.commitSigningEnabled) {
      await _setGitConfig(
        <String>['config', '--global', 'commit.gpgsign', 'true'],
      );
    }

    return inspectGlobalSigning();
  }

  Future<void> ensureRepoSigningGuard(String repoPath) async {
    final GitSigningStatus globalStatus = await ensureGlobalIntrinsicSigning();
    await _setGitConfig(
      <String>['-C', repoPath, 'config', '--local', 'commit.gpgsign', 'true'],
    );

    final String? localFormat = await _readGitConfig(
      <String>['-C', repoPath, 'config', '--local', '--get', 'gpg.format'],
    );
    if ((localFormat ?? '').trim().isEmpty) {
      final String globalFormat = (globalStatus.signingFormat ?? '').trim();
      await _setGitConfig(
        <String>[
          '-C',
          repoPath,
          'config',
          '--local',
          'gpg.format',
          globalFormat.isEmpty ? 'ssh' : globalFormat,
        ],
      );
    }

    final String? localSigningKey = await _readGitConfig(
      <String>['-C', repoPath, 'config', '--local', '--get', 'user.signingkey'],
    );
    if ((localSigningKey ?? '').trim().isEmpty &&
        (globalStatus.signingKey ?? '').trim().isNotEmpty) {
      await _setGitConfig(
        <String>[
          '-C',
          repoPath,
          'config',
          '--local',
          'user.signingkey',
          globalStatus.signingKey!.trim(),
        ],
      );
    }
  }

  Future<String?> _resolveSigningKey() async {
    final String root = _homeDirectory();
    final Directory sshDirectory = Directory('$root/.ssh');
    if (!await sshDirectory.exists()) {
      await sshDirectory.create(recursive: true);
    }

    final File preferred = File('${sshDirectory.path}/id_ed25519.pub');
    if (await preferred.exists()) {
      return preferred.path;
    }

    final List<FileSystemEntity> all = sshDirectory.listSync(followLinks: false);
    final List<File> publicKeys = all
        .whereType<File>()
        .where((File file) => file.path.endsWith('.pub'))
        .toList();
    if (publicKeys.isNotEmpty) {
      publicKeys.sort((File a, File b) => a.path.compareTo(b.path));
      return publicKeys.first.path;
    }

    final String privateKeyPath = '${sshDirectory.path}/id_ed25519';
    final int exitCode = await commandRunner(
      'ssh-keygen',
      <String>['-t', 'ed25519', '-f', privateKeyPath, '-N', '', '-q'],
    );
    if (exitCode != 0) {
      throw Exception('Failed to generate SSH signing key');
    }
    final File generatedPublic = File('$privateKeyPath.pub');
    if (!await generatedPublic.exists()) {
      throw Exception('Generated SSH public key not found');
    }
    return generatedPublic.path;
  }

  String _homeDirectory() {
    if ((homeDirectory ?? '').trim().isNotEmpty) {
      return homeDirectory!.trim();
    }
    return Platform.environment['HOME'] ?? '';
  }

  Future<String?> _readGitConfig(List<String> args) async {
    final BehaviorSubject<String> stdout = BehaviorSubject<String>();
    final BehaviorSubject<String> stderr = BehaviorSubject<String>();
    try {
      final int exitCode = await commandRunner(
        'git',
        args,
        stdout: stdout,
        stderr: stderr,
      );
      if (exitCode != 0) {
        return null;
      }
      final String? value = stdout.valueOrNull;
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      return value.trim();
    } finally {
      await stdout.close();
      await stderr.close();
    }
  }

  Future<void> _setGitConfig(List<String> args) async {
    final int exitCode = await commandRunner('git', args);
    if (exitCode != 0) {
      throw Exception('Failed running git ${args.join(" ")}');
    }
  }
}
