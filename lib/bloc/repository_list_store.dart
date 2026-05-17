import 'dart:async';
import 'dart:convert';

import 'package:alembic/core/account_registry.dart';
import 'package:alembic/domain/repository_dto.dart';
import 'package:alembic/spike/spike_channels.dart';
import 'package:alembic/spike/spike_diagnostics.dart';
import 'package:alembic/util/git_accounts.dart';
import 'package:github/github.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/subjects.dart';

class RepositoryListStore {
  RepositoryListStore({
    AccountRegistry? registry,
    Duration? fetchTimeout,
    Duration? perPageTimeout,
    int? maxPages,
    SpikeDiagnostics? diagnostics,
  })  : _registry = registry ?? AccountRegistry.fromCurrentStorage(),
        _fetchTimeout = fetchTimeout ?? const Duration(seconds: 45),
        _perPageTimeout = perPageTimeout ?? const Duration(seconds: 15),
        _maxPages = maxPages ?? 50,
        _diagnostics = diagnostics ?? SpikeDiagnostics.instance,
        _subject = BehaviorSubject<RepositoryListState>.seeded(
          RepositoryListState.initial(),
        );

  static const String _logTag = 'repo_store';

  final AccountRegistry _registry;
  final BehaviorSubject<RepositoryListState> _subject;
  final Duration _fetchTimeout;
  final Duration _perPageTimeout;
  final int _maxPages;
  final SpikeDiagnostics _diagnostics;
  bool _busy = false;
  int _attemptCounter = 0;
  final Map<String, Repository> _repositoryCache = <String, Repository>{};

  Stream<RepositoryListState> get stream => _subject.stream;

  RepositoryListState get value => _subject.value;

  AccountRegistry get registry => _registry;

  Repository? findRepository(String fullName) {
    return _repositoryCache[fullName.toLowerCase()];
  }

  List<Repository> get cachedRepositories =>
      List<Repository>.unmodifiable(_repositoryCache.values);

  Future<void> refresh() async {
    if (_busy) {
      _diagnostics.warn(_logTag, 'refresh ignored: store is busy');
      return;
    }
    _busy = true;
    _attemptCounter += 1;
    final int attempt = _attemptCounter;
    final int startMillis = DateTime.now().millisecondsSinceEpoch;
    final Stopwatch stopwatch = Stopwatch()..start();
    _diagnostics.log(_logTag, 'refresh attempt $attempt started');

    try {
      _emit(value.copyWith(
        status: SpikeRepositoryStatus.loading,
        phase: 'preparing',
        attempt: attempt,
        requestStartedMillis: startMillis,
        requestDurationMillis: 0,
        pageNumber: 0,
        pagesCompleted: 0,
        lastHttpStatus: 0,
        lastResponseBytes: 0,
        lastResponseDurationMillis: 0,
        endpoint: '',
        diagnosticTail: 'Preparing request...',
        clearError: true,
        clearErrorCode: true,
      ));

      _diagnostics.trace(_logTag, 'refreshing account registry from storage');
      _registry.refreshFromStorage();
      _emit(value.copyWith(
        phase: 'resolving_account',
        diagnosticTail: 'Resolving account from storage...',
      ));

      final GitAccount? primary = _registry.primaryAccount;
      final GitHub? github = _registry.primaryGitHub;

      if (primary == null || github == null) {
        _diagnostics.warn(
            _logTag, 'no primary account configured; emitting noAccount state');
        stopwatch.stop();
        _emit(value.copyWith(
          status: SpikeRepositoryStatus.noAccount,
          phase: 'no_account',
          repositories: const <RepositoryDto>[],
          fetchedCount: 0,
          requestDurationMillis: stopwatch.elapsedMilliseconds,
          diagnosticTail: 'No GitHub account configured.',
          clearAccountLogin: true,
          clearError: true,
          clearErrorCode: true,
        ));
        return;
      }

      final String accountLogin = primary.login ?? primary.name;
      _diagnostics.log(_logTag,
          'primary account resolved: $accountLogin (id=${primary.id}, type=${primary.tokenType})');
      _emit(value.copyWith(
        accountLogin: accountLogin,
        phase: 'connecting',
        endpoint: 'GET /user/repos',
        diagnosticTail: 'Connecting to api.github.com as $accountLogin...',
      ));

      final List<RepositoryDto> fetched = await _fetchRepositoriesWithTimeout(
        github: github,
        accountLogin: accountLogin,
      );

      stopwatch.stop();
      final int durationMillis = stopwatch.elapsedMilliseconds;

      if (fetched.isEmpty) {
        _diagnostics.warn(_logTag,
            'fetch completed in ${durationMillis}ms but returned 0 repositories');
        _emit(value.copyWith(
          status: SpikeRepositoryStatus.empty,
          phase: 'completed_empty',
          accountLogin: accountLogin,
          repositories: const <RepositoryDto>[],
          fetchedCount: 0,
          lastRefreshMillis: DateTime.now().millisecondsSinceEpoch,
          requestDurationMillis: durationMillis,
          diagnosticTail:
              'Completed in ${durationMillis}ms with 0 repositories.',
          clearError: true,
          clearErrorCode: true,
        ));
        return;
      }

      _diagnostics.success(_logTag,
          'fetch completed in ${durationMillis}ms with ${fetched.length} repositories');
      _emit(value.copyWith(
        status: SpikeRepositoryStatus.ready,
        phase: 'completed_ready',
        accountLogin: accountLogin,
        repositories: fetched,
        fetchedCount: fetched.length,
        lastRefreshMillis: DateTime.now().millisecondsSinceEpoch,
        requestDurationMillis: durationMillis,
        diagnosticTail: 'Loaded ${fetched.length} repositories in '
            '${durationMillis}ms across ${value.pagesCompleted} pages.',
        clearError: true,
        clearErrorCode: true,
      ));
    } on TimeoutException catch (e) {
      stopwatch.stop();
      _diagnostics.error(_logTag,
          'fetch timed out after ${stopwatch.elapsedMilliseconds}ms: ${e.message ?? 'no detail'}');
      _emit(value.copyWith(
        status: SpikeRepositoryStatus.error,
        phase: 'timeout',
        errorMessage:
            'Fetch timed out after ${_fetchTimeout.inSeconds} seconds. '
            'Check your internet connection or token permissions.',
        errorCode: 'timeout',
        requestDurationMillis: stopwatch.elapsedMilliseconds,
        diagnosticTail: 'Timed out: ${e.message ?? 'no detail'}',
      ));
    } on GitHubError catch (e) {
      stopwatch.stop();
      _diagnostics.error(_logTag,
          'GitHub API error after ${stopwatch.elapsedMilliseconds}ms: ${e.message}');
      _emit(value.copyWith(
        status: SpikeRepositoryStatus.error,
        phase: 'github_error',
        errorMessage: e.message,
        errorCode: 'github_error',
        requestDurationMillis: stopwatch.elapsedMilliseconds,
        diagnosticTail: 'GitHub API error: ${e.message}',
      ));
    } catch (e, stackTrace) {
      stopwatch.stop();
      _diagnostics.error(_logTag,
          'fetch failed after ${stopwatch.elapsedMilliseconds}ms: ${e.runtimeType}: $e');
      _diagnostics.trace(_logTag, 'stack trace: $stackTrace');
      _emit(value.copyWith(
        status: SpikeRepositoryStatus.error,
        phase: 'exception',
        errorMessage: e.toString(),
        errorCode: e.runtimeType.toString(),
        requestDurationMillis: stopwatch.elapsedMilliseconds,
        diagnosticTail: '${e.runtimeType}: $e',
      ));
    } finally {
      _busy = false;
      _diagnostics.trace(
          _logTag, 'refresh attempt $attempt complete (busy released)');
    }
  }

  Future<void> retry() async {
    _diagnostics.log(_logTag, 'retry requested');
    await refresh();
  }

  Future<List<RepositoryDto>> _fetchRepositoriesWithTimeout({
    required GitHub github,
    required String accountLogin,
  }) async {
    return _fetchRepositoriesPaginated(
      github: github,
      accountLogin: accountLogin,
    ).timeout(
      _fetchTimeout,
      onTimeout: () {
        throw TimeoutException(
            'GitHub /user/repos pagination did not complete in '
            '${_fetchTimeout.inSeconds}s');
      },
    );
  }

  Future<List<RepositoryDto>> _fetchRepositoriesPaginated({
    required GitHub github,
    required String accountLogin,
  }) async {
    final List<RepositoryDto> results = <RepositoryDto>[];
    final Map<String, Repository> nextCache = <String, Repository>{};
    int pageNumber = 1;
    int pagesCompleted = 0;

    while (pageNumber <= _maxPages) {
      _emit(value.copyWith(
        phase: 'requesting_page',
        pageNumber: pageNumber,
        endpoint: 'GET /user/repos?page=$pageNumber',
        diagnosticTail: 'Requesting page $pageNumber...',
      ));

      final Stopwatch pageStopwatch = Stopwatch()..start();
      final Map<String, dynamic> params = <String, dynamic>{
        'type': 'all',
        'sort': 'updated',
        'direction': 'desc',
        'per_page': 100,
        'page': pageNumber,
      };
      _diagnostics.trace(_logTag,
          'GET /user/repos page=$pageNumber per_page=100 sort=updated');

      final http.Response response;
      try {
        response =
            await github.request('GET', '/user/repos', params: params).timeout(
          _perPageTimeout,
          onTimeout: () {
            throw TimeoutException('page $pageNumber did not respond in '
                '${_perPageTimeout.inSeconds}s');
          },
        );
      } catch (e) {
        pageStopwatch.stop();
        _diagnostics.error(_logTag,
            'page $pageNumber request failed after ${pageStopwatch.elapsedMilliseconds}ms: $e');
        rethrow;
      }
      pageStopwatch.stop();
      final int pageDurationMillis = pageStopwatch.elapsedMilliseconds;

      final int rateLimitRemaining =
          int.tryParse(response.headers['x-ratelimit-remaining'] ?? '') ?? -1;
      final int rateLimitLimit =
          int.tryParse(response.headers['x-ratelimit-limit'] ?? '') ?? -1;
      final int rateLimitResetSec =
          int.tryParse(response.headers['x-ratelimit-reset'] ?? '') ?? 0;
      final int rateLimitResetMillis = rateLimitResetSec * 1000;
      final int contentLength = response.bodyBytes.length;
      final String linkHeader = response.headers['link'] ?? '';
      final bool hasNext = linkHeader.contains('rel="next"');

      _diagnostics.trace(
          _logTag,
          'page $pageNumber HTTP ${response.statusCode} in ${pageDurationMillis}ms '
          'bytes=$contentLength ratelimit=$rateLimitRemaining/$rateLimitLimit '
          'next=${hasNext ? 'yes' : 'no'}');

      if (response.statusCode != 200) {
        _diagnostics.error(_logTag,
            'page $pageNumber returned non-200 status: ${response.statusCode}');
        _emit(value.copyWith(
          phase: 'http_error',
          pageNumber: pageNumber,
          lastHttpStatus: response.statusCode,
          lastResponseBytes: contentLength,
          lastResponseDurationMillis: pageDurationMillis,
          rateLimitRemaining: rateLimitRemaining,
          rateLimitLimit: rateLimitLimit,
          rateLimitResetMillis: rateLimitResetMillis,
          diagnosticTail:
              'HTTP ${response.statusCode} on page $pageNumber: ${_extractMessage(response.body)}',
        ));
        throw GitHubError(
          github,
          'GitHub returned HTTP ${response.statusCode}: '
          '${_extractMessage(response.body)}',
        );
      }

      final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
      _diagnostics.trace(_logTag,
          'page $pageNumber decoded ${decoded.length} repository records');

      final List<RepositoryDto> pageDtos = <RepositoryDto>[];
      for (final dynamic record in decoded) {
        if (record is Map<String, dynamic>) {
          try {
            final Repository repository = Repository.fromJson(record);
            pageDtos.add(_toDto(repository));
            nextCache[repository.fullName.toLowerCase()] = repository;
          } catch (e) {
            _diagnostics.warn(_logTag,
                'skipped a malformed repository record on page $pageNumber: $e');
          }
        }
      }
      results.addAll(pageDtos);
      pagesCompleted += 1;

      _emit(value.copyWith(
        phase: 'page_complete',
        pageNumber: pageNumber,
        pagesCompleted: pagesCompleted,
        fetchedCount: results.length,
        lastHttpStatus: response.statusCode,
        lastResponseBytes: contentLength,
        lastResponseDurationMillis: pageDurationMillis,
        rateLimitRemaining: rateLimitRemaining,
        rateLimitLimit: rateLimitLimit,
        rateLimitResetMillis: rateLimitResetMillis,
        diagnosticTail: 'Page $pageNumber: +${pageDtos.length} repos '
            '(total ${results.length}) in ${pageDurationMillis}ms',
      ));

      if (!hasNext || decoded.isEmpty) {
        _diagnostics.trace(_logTag,
            'pagination complete after $pagesCompleted page(s) with ${results.length} total repos');
        break;
      }

      if (rateLimitRemaining == 0) {
        _diagnostics.warn(_logTag,
            'rate limit exhausted; stopping pagination with partial results');
        _emit(value.copyWith(
          phase: 'rate_limited',
          diagnosticTail:
              'Rate limit exhausted at ${results.length} repos. Retry after reset.',
        ));
        break;
      }

      pageNumber += 1;
    }

    if (pageNumber > _maxPages) {
      _diagnostics.warn(
          _logTag, 'reached page limit $_maxPages; returning partial results');
    }

    _repositoryCache
      ..clear()
      ..addAll(nextCache);

    return results;
  }

  String _extractMessage(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final Object? message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // body wasn't JSON; fall through to raw
    }
    if (body.length > 200) {
      return '${body.substring(0, 200)}...';
    }
    return body;
  }

  RepositoryDto _toDto(Repository repository) {
    final int updatedAtMillis =
        repository.updatedAt?.millisecondsSinceEpoch ?? 0;
    final String description = repository.description.trim();
    final String language = repository.language.trim();
    return RepositoryDto(
      fullName: repository.fullName,
      owner: repository.owner?.login ?? 'unknown',
      name: repository.name,
      description: description,
      defaultBranch: repository.defaultBranch,
      isPrivate: repository.isPrivate,
      isFork: repository.isFork,
      isArchived: repository.archived,
      htmlUrl: repository.htmlUrl,
      starCount: repository.stargazersCount,
      forkCount: repository.forksCount,
      language: language.isEmpty ? null : language,
      updatedAtMillis: updatedAtMillis,
    );
  }

  void _emit(RepositoryListState next) {
    _subject.add(next);
  }

  Future<void> close() async {
    await _subject.close();
  }
}
