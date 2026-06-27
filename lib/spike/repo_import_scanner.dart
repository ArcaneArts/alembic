import 'dart:async';
import 'dart:io';

import 'package:alembic/spike/spike_diagnostics.dart';

class DiscoveredRepo {
  final String absolutePath;
  final String relativePath;
  final String? remoteUrl;
  final String? ownerLogin;
  final String? repoName;
  final bool isGitHub;
  final String? defaultBranch;

  const DiscoveredRepo({
    required this.absolutePath,
    required this.relativePath,
    this.remoteUrl,
    this.ownerLogin,
    this.repoName,
    this.isGitHub = false,
    this.defaultBranch,
  });

  String? get slug {
    if (ownerLogin == null || repoName == null) {
      return null;
    }
    return '$ownerLogin/$repoName';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'absolutePath': absolutePath,
        'relativePath': relativePath,
        'remoteUrl': remoteUrl,
        'ownerLogin': ownerLogin,
        'repoName': repoName,
        'isGitHub': isGitHub,
        'slug': slug,
        'defaultBranch': defaultBranch,
      };
}

class ScanProgress {
  final int directoriesVisited;
  final int gitReposFound;
  final int gitHubReposFound;
  final String? currentPath;

  const ScanProgress({
    required this.directoriesVisited,
    required this.gitReposFound,
    required this.gitHubReposFound,
    this.currentPath,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'directoriesVisited': directoriesVisited,
        'gitReposFound': gitReposFound,
        'gitHubReposFound': gitHubReposFound,
        'currentPath': currentPath,
      };
}

class ScanResult {
  final String rootPath;
  final List<DiscoveredRepo> repos;
  final int directoriesVisited;
  final int totalGitRepos;
  final int gitHubRepos;
  final int durationMs;
  final String? errorMessage;
  final List<String> warnings;

  const ScanResult({
    required this.rootPath,
    required this.repos,
    required this.directoriesVisited,
    required this.totalGitRepos,
    required this.gitHubRepos,
    required this.durationMs,
    this.errorMessage,
    this.warnings = const <String>[],
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rootPath': rootPath,
        'repos': repos.map((DiscoveredRepo r) => r.toJson()).toList(),
        'directoriesVisited': directoriesVisited,
        'totalGitRepos': totalGitRepos,
        'gitHubRepos': gitHubRepos,
        'durationMs': durationMs,
        'errorMessage': errorMessage,
        'warnings': warnings,
      };
}

class RepoImportScanner {
  static const int defaultMaxDepth = 4;
  static const int maxDirectoriesToVisit = 5000;
  static final SpikeDiagnostics _diag = SpikeDiagnostics.instance;
  static const String _tag = 'repo_import_scanner';

  final int maxDepth;
  final void Function(ScanProgress progress)? onProgress;

  const RepoImportScanner({
    this.maxDepth = defaultMaxDepth,
    this.onProgress,
  });

  Future<ScanResult> scan(String rootPath) async {
    final DateTime start = DateTime.now();
    _diag.log(_tag, 'scan starting rootPath=$rootPath maxDepth=$maxDepth');

    final Directory root = Directory(rootPath);
    if (!await root.exists()) {
      _diag.error(_tag, 'root does not exist: $rootPath');
      return ScanResult(
        rootPath: rootPath,
        repos: const <DiscoveredRepo>[],
        directoriesVisited: 0,
        totalGitRepos: 0,
        gitHubRepos: 0,
        durationMs: 0,
        errorMessage: 'Directory does not exist: $rootPath',
      );
    }

    final List<DiscoveredRepo> repos = <DiscoveredRepo>[];
    final List<String> warnings = <String>[];
    int directoriesVisited = 0;
    int totalGitRepos = 0;
    int gitHubRepos = 0;

    try {
      await _walk(
        root,
        rootPath,
        0,
        (DiscoveredRepo repo, bool isGit) async {
          if (isGit) {
            totalGitRepos++;
            if (repo.isGitHub) {
              gitHubRepos++;
            }
            repos.add(repo);
            _diag.log(
              _tag,
              'found ${repo.isGitHub ? "GitHub" : "git"} repo '
              '${repo.slug ?? repo.relativePath} at ${repo.absolutePath}',
            );
          }
          directoriesVisited++;
          if (directoriesVisited % 50 == 0) {
            _diag.trace(
              _tag,
              'progress: visited=$directoriesVisited git=$totalGitRepos '
              'github=$gitHubRepos',
            );
            onProgress?.call(ScanProgress(
              directoriesVisited: directoriesVisited,
              gitReposFound: totalGitRepos,
              gitHubReposFound: gitHubRepos,
              currentPath: repo.absolutePath,
            ));
          }
          if (directoriesVisited > maxDirectoriesToVisit) {
            warnings.add(
              'scan capped at $maxDirectoriesToVisit directories; '
              'try a more specific root path',
            );
            _diag.warn(
              _tag,
              'directory cap reached at $directoriesVisited; aborting walk',
            );
            throw _ScanCappedException();
          }
        },
      );
    } on _ScanCappedException {
      // Expected when we hit the directory cap
    } catch (e) {
      _diag.error(_tag, 'walk failed: $e');
      warnings.add('walk failed mid-way: $e');
    }

    final int durationMs = DateTime.now().difference(start).inMilliseconds;
    _diag.success(
      _tag,
      'scan complete: visited=$directoriesVisited git=$totalGitRepos '
      'github=$gitHubRepos durationMs=$durationMs',
    );

    return ScanResult(
      rootPath: rootPath,
      repos: repos,
      directoriesVisited: directoriesVisited,
      totalGitRepos: totalGitRepos,
      gitHubRepos: gitHubRepos,
      durationMs: durationMs,
      warnings: warnings,
    );
  }

  Future<void> _walk(
    Directory dir,
    String rootPath,
    int depth,
    Future<void> Function(DiscoveredRepo repo, bool isGit) callback,
  ) async {
    if (depth > maxDepth) {
      return;
    }

    final Directory gitDir = Directory('${dir.path}/.git');
    if (await gitDir.exists()) {
      final DiscoveredRepo repo = await _inspectGitRepo(dir, rootPath);
      await callback(repo, true);
      return;
    }

    final String dirName = dir.path.split(Platform.pathSeparator).last;
    if (_shouldSkipDirectory(dirName)) {
      return;
    }

    try {
      await for (FileSystemEntity entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          await _walk(entity, rootPath, depth + 1, callback);
        }
      }
    } catch (e) {
      _diag.warn(_tag, 'cannot list $dir: $e');
      return;
    }
  }

  bool _shouldSkipDirectory(String name) {
    if (name.startsWith('.')) {
      return true;
    }
    const Set<String> skips = <String>{
      'node_modules',
      'build',
      'dist',
      'target',
      'Pods',
      'DerivedData',
      'venv',
      '.venv',
      '__pycache__',
      'Library',
      'System',
      'Applications',
    };
    return skips.contains(name);
  }

  Future<DiscoveredRepo> _inspectGitRepo(
    Directory dir,
    String rootPath,
  ) async {
    final String absolutePath = dir.path;
    String relativePath = absolutePath.startsWith(rootPath) &&
            absolutePath.length > rootPath.length
        ? absolutePath.substring(rootPath.length + 1)
        : absolutePath;

    final String? remoteUrl = await _readGitRemoteUrl(dir);
    String? ownerLogin;
    String? repoName;
    bool isGitHub = false;

    if (remoteUrl != null) {
      final _ParsedRemote? parsed = _parseGitHubRemote(remoteUrl);
      if (parsed != null) {
        ownerLogin = parsed.owner;
        repoName = parsed.name;
        isGitHub = true;
      }
    }

    String? defaultBranch;
    try {
      final File headFile = File('${dir.path}/.git/HEAD');
      if (await headFile.exists()) {
        final String contents = (await headFile.readAsString()).trim();
        if (contents.startsWith('ref: refs/heads/')) {
          defaultBranch = contents.substring('ref: refs/heads/'.length).trim();
        }
      }
    } catch (e) {
      _diag.trace(_tag, 'could not read HEAD for $absolutePath: $e');
    }

    return DiscoveredRepo(
      absolutePath: absolutePath,
      relativePath: relativePath,
      remoteUrl: remoteUrl,
      ownerLogin: ownerLogin,
      repoName: repoName,
      isGitHub: isGitHub,
      defaultBranch: defaultBranch,
    );
  }

  Future<String?> _readGitRemoteUrl(Directory dir) async {
    try {
      final File configFile = File('${dir.path}/.git/config');
      if (!await configFile.exists()) {
        return null;
      }
      final List<String> lines = await configFile.readAsLines();
      bool inOriginSection = false;
      for (final String rawLine in lines) {
        final String line = rawLine.trim();
        if (line.startsWith('[remote "origin"]')) {
          inOriginSection = true;
          continue;
        }
        if (line.startsWith('[')) {
          inOriginSection = false;
          continue;
        }
        if (inOriginSection && line.startsWith('url =')) {
          return line.substring('url ='.length).trim();
        }
        if (inOriginSection && line.startsWith('url=')) {
          return line.substring('url='.length).trim();
        }
      }
      return null;
    } catch (e) {
      _diag.trace(_tag, 'could not read .git/config for $dir: $e');
      return null;
    }
  }

  _ParsedRemote? _parseGitHubRemote(String url) {
    final String cleaned = url.trim();
    if (cleaned.isEmpty) {
      return null;
    }

    final RegExp httpsRe = RegExp(
      r'^https?://(?:[^@/]+@)?github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$',
      caseSensitive: false,
    );
    final RegExpMatch? httpsMatch = httpsRe.firstMatch(cleaned);
    if (httpsMatch != null) {
      return _ParsedRemote(
        owner: httpsMatch.group(1)!,
        name: httpsMatch.group(2)!,
      );
    }

    final RegExp sshRe = RegExp(
      r'^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?/?$',
      caseSensitive: false,
    );
    final RegExpMatch? sshMatch = sshRe.firstMatch(cleaned);
    if (sshMatch != null) {
      return _ParsedRemote(
        owner: sshMatch.group(1)!,
        name: sshMatch.group(2)!,
      );
    }

    final RegExp gitProtoRe = RegExp(
      r'^git://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$',
      caseSensitive: false,
    );
    final RegExpMatch? gitProtoMatch = gitProtoRe.firstMatch(cleaned);
    if (gitProtoMatch != null) {
      return _ParsedRemote(
        owner: gitProtoMatch.group(1)!,
        name: gitProtoMatch.group(2)!,
      );
    }

    return null;
  }
}

class _ParsedRemote {
  final String owner;
  final String name;

  const _ParsedRemote({required this.owner, required this.name});
}

class _ScanCappedException implements Exception {}
