import 'dart:convert';

class RepositoryDto {
  const RepositoryDto({
    required this.fullName,
    required this.owner,
    required this.name,
    required this.description,
    required this.defaultBranch,
    required this.isPrivate,
    required this.isFork,
    required this.isArchived,
    required this.htmlUrl,
    required this.starCount,
    required this.forkCount,
    required this.language,
    required this.updatedAtMillis,
  });

  factory RepositoryDto.placeholder({
    required String owner,
    required String name,
    required String description,
  }) {
    return RepositoryDto(
      fullName: '$owner/$name',
      owner: owner,
      name: name,
      description: description,
      defaultBranch: 'main',
      isPrivate: false,
      isFork: false,
      isArchived: false,
      htmlUrl: 'https://github.com/$owner/$name',
      starCount: 0,
      forkCount: 0,
      language: null,
      updatedAtMillis: 0,
    );
  }

  final String fullName;
  final String owner;
  final String name;
  final String description;
  final String defaultBranch;
  final bool isPrivate;
  final bool isFork;
  final bool isArchived;
  final String htmlUrl;
  final int starCount;
  final int forkCount;
  final String? language;
  final int updatedAtMillis;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'fullName': fullName,
      'owner': owner,
      'name': name,
      'description': description,
      'defaultBranch': defaultBranch,
      'isPrivate': isPrivate,
      'isFork': isFork,
      'isArchived': isArchived,
      'htmlUrl': htmlUrl,
      'starCount': starCount,
      'forkCount': forkCount,
      'language': language,
      'updatedAtMillis': updatedAtMillis,
    };
  }

  String toEncoded() {
    return jsonEncode(toJson());
  }
}

class RepositoryListState {
  const RepositoryListState({
    required this.status,
    required this.accountLogin,
    required this.repositories,
    required this.errorMessage,
    required this.lastRefreshMillis,
    required this.phase,
    required this.fetchedCount,
    required this.attempt,
    required this.requestStartedMillis,
    required this.requestDurationMillis,
    required this.errorCode,
    required this.pageNumber,
    required this.pagesCompleted,
    required this.lastHttpStatus,
    required this.lastResponseBytes,
    required this.lastResponseDurationMillis,
    required this.rateLimitRemaining,
    required this.rateLimitLimit,
    required this.rateLimitResetMillis,
    required this.endpoint,
    required this.diagnosticTail,
  });

  factory RepositoryListState.initial() {
    return const RepositoryListState(
      status: 'idle',
      accountLogin: null,
      repositories: <RepositoryDto>[],
      errorMessage: null,
      lastRefreshMillis: 0,
      phase: 'awaiting_first_refresh',
      fetchedCount: 0,
      attempt: 0,
      requestStartedMillis: 0,
      requestDurationMillis: 0,
      errorCode: null,
      pageNumber: 0,
      pagesCompleted: 0,
      lastHttpStatus: 0,
      lastResponseBytes: 0,
      lastResponseDurationMillis: 0,
      rateLimitRemaining: -1,
      rateLimitLimit: -1,
      rateLimitResetMillis: 0,
      endpoint: '',
      diagnosticTail: '',
    );
  }

  final String status;
  final String? accountLogin;
  final List<RepositoryDto> repositories;
  final String? errorMessage;
  final int lastRefreshMillis;
  final String phase;
  final int fetchedCount;
  final int attempt;
  final int requestStartedMillis;
  final int requestDurationMillis;
  final String? errorCode;
  final int pageNumber;
  final int pagesCompleted;
  final int lastHttpStatus;
  final int lastResponseBytes;
  final int lastResponseDurationMillis;
  final int rateLimitRemaining;
  final int rateLimitLimit;
  final int rateLimitResetMillis;
  final String endpoint;
  final String diagnosticTail;

  RepositoryListState copyWith({
    String? status,
    String? accountLogin,
    List<RepositoryDto>? repositories,
    String? errorMessage,
    bool clearError = false,
    int? lastRefreshMillis,
    bool clearAccountLogin = false,
    String? phase,
    int? fetchedCount,
    int? attempt,
    int? requestStartedMillis,
    int? requestDurationMillis,
    String? errorCode,
    bool clearErrorCode = false,
    int? pageNumber,
    int? pagesCompleted,
    int? lastHttpStatus,
    int? lastResponseBytes,
    int? lastResponseDurationMillis,
    int? rateLimitRemaining,
    int? rateLimitLimit,
    int? rateLimitResetMillis,
    String? endpoint,
    String? diagnosticTail,
  }) {
    return RepositoryListState(
      status: status ?? this.status,
      accountLogin:
          clearAccountLogin ? null : (accountLogin ?? this.accountLogin),
      repositories: repositories ?? this.repositories,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastRefreshMillis: lastRefreshMillis ?? this.lastRefreshMillis,
      phase: phase ?? this.phase,
      fetchedCount: fetchedCount ?? this.fetchedCount,
      attempt: attempt ?? this.attempt,
      requestStartedMillis: requestStartedMillis ?? this.requestStartedMillis,
      requestDurationMillis:
          requestDurationMillis ?? this.requestDurationMillis,
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      pageNumber: pageNumber ?? this.pageNumber,
      pagesCompleted: pagesCompleted ?? this.pagesCompleted,
      lastHttpStatus: lastHttpStatus ?? this.lastHttpStatus,
      lastResponseBytes: lastResponseBytes ?? this.lastResponseBytes,
      lastResponseDurationMillis:
          lastResponseDurationMillis ?? this.lastResponseDurationMillis,
      rateLimitRemaining: rateLimitRemaining ?? this.rateLimitRemaining,
      rateLimitLimit: rateLimitLimit ?? this.rateLimitLimit,
      rateLimitResetMillis: rateLimitResetMillis ?? this.rateLimitResetMillis,
      endpoint: endpoint ?? this.endpoint,
      diagnosticTail: diagnosticTail ?? this.diagnosticTail,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'status': status,
      'accountLogin': accountLogin,
      'repositories': repositories
          .map((RepositoryDto repository) => repository.toJson())
          .toList(),
      'errorMessage': errorMessage,
      'lastRefreshMillis': lastRefreshMillis,
      'phase': phase,
      'fetchedCount': fetchedCount,
      'attempt': attempt,
      'requestStartedMillis': requestStartedMillis,
      'requestDurationMillis': requestDurationMillis,
      'errorCode': errorCode,
      'pageNumber': pageNumber,
      'pagesCompleted': pagesCompleted,
      'lastHttpStatus': lastHttpStatus,
      'lastResponseBytes': lastResponseBytes,
      'lastResponseDurationMillis': lastResponseDurationMillis,
      'rateLimitRemaining': rateLimitRemaining,
      'rateLimitLimit': rateLimitLimit,
      'rateLimitResetMillis': rateLimitResetMillis,
      'endpoint': endpoint,
      'diagnosticTail': diagnosticTail,
    };
  }
}
