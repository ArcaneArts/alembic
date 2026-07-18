class RepositoryListStatus {
  static const String idle = 'idle';
  static const String loading = 'loading';
  static const String ready = 'ready';
  static const String error = 'error';
  static const String empty = 'empty';
  static const String noAccount = 'noAccount';

  const RepositoryListStatus._();
}

class RepoStateValue {
  static const String active = 'active';
  static const String archived = 'archived';
  static const String cloud = 'cloud';

  const RepoStateValue._();
}
