enum RepositoryTileAction {
  details,
  openFinder,
  settings,
  viewGithub,
  issues,
  pullRequests,
  newIssue,
  newPullRequest,
  pull,
  archive,
  deleteRepository,
  activate,
  updateArchive,
  deleteArchive,
  clone,
  archiveFromCloud,
  fork,
  enrollArchiveMaster,
  unenrollArchiveMaster,
  refreshArchiveMaster,
  promoteArchiveMaster,
  changeAuth,
}

abstract class RepositoryTileActionOperations {
  Future<void> showDetails();

  Future<void> openInFinder();

  Future<void> openSettings();

  Future<void> openExternalUrl(String url);

  Future<void> pull();

  Future<void> archive();

  Future<void> deleteRepository();

  Future<void> activate();

  Future<void> updateArchive();

  Future<void> deleteArchive();

  Future<void> cloneRepository();

  Future<void> archiveFromCloud();

  Future<void> forkAndClone();

  Future<void> enrollArchiveMaster();

  Future<void> unenrollArchiveMaster();

  Future<void> refreshArchiveMaster();

  Future<void> promoteArchiveMaster();

  Future<void> changeAuth();

  Future<bool> confirmDeleteRepository();

  Future<bool> confirmDeleteArchive();

  Future<bool> confirmUnenrollArchiveMaster();
}

class RepositoryTileActionDispatcher {
  const RepositoryTileActionDispatcher();

  Future<void> dispatch({
    required RepositoryTileAction action,
    required RepositoryTileActionOperations operations,
    required String baseUrl,
  }) {
    return switch (action) {
      RepositoryTileAction.details => operations.showDetails(),
      RepositoryTileAction.openFinder => operations.openInFinder(),
      RepositoryTileAction.settings => operations.openSettings(),
      RepositoryTileAction.viewGithub => operations.openExternalUrl(baseUrl),
      RepositoryTileAction.issues =>
        operations.openExternalUrl('$baseUrl/issues'),
      RepositoryTileAction.pullRequests =>
        operations.openExternalUrl('$baseUrl/pulls'),
      RepositoryTileAction.newIssue =>
        operations.openExternalUrl('$baseUrl/issues/new'),
      RepositoryTileAction.newPullRequest =>
        operations.openExternalUrl('$baseUrl/compare'),
      RepositoryTileAction.pull => operations.pull(),
      RepositoryTileAction.archive => operations.archive(),
      RepositoryTileAction.deleteRepository =>
        _dispatchDeleteRepository(operations),
      RepositoryTileAction.activate => operations.activate(),
      RepositoryTileAction.updateArchive => operations.updateArchive(),
      RepositoryTileAction.deleteArchive => _dispatchDeleteArchive(operations),
      RepositoryTileAction.clone => operations.cloneRepository(),
      RepositoryTileAction.archiveFromCloud => operations.archiveFromCloud(),
      RepositoryTileAction.fork => operations.forkAndClone(),
      RepositoryTileAction.enrollArchiveMaster =>
        operations.enrollArchiveMaster(),
      RepositoryTileAction.unenrollArchiveMaster =>
        _dispatchUnenrollArchiveMaster(operations),
      RepositoryTileAction.refreshArchiveMaster =>
        operations.refreshArchiveMaster(),
      RepositoryTileAction.promoteArchiveMaster =>
        operations.promoteArchiveMaster(),
      RepositoryTileAction.changeAuth => operations.changeAuth(),
    };
  }

  Future<void> _dispatchDeleteRepository(
    RepositoryTileActionOperations operations,
  ) async {
    bool confirmed = await operations.confirmDeleteRepository();
    if (!confirmed) {
      return;
    }
    await operations.deleteRepository();
  }

  Future<void> _dispatchDeleteArchive(
    RepositoryTileActionOperations operations,
  ) async {
    bool confirmed = await operations.confirmDeleteArchive();
    if (!confirmed) {
      return;
    }
    await operations.deleteArchive();
  }

  Future<void> _dispatchUnenrollArchiveMaster(
    RepositoryTileActionOperations operations,
  ) async {
    bool confirmed = await operations.confirmUnenrollArchiveMaster();
    if (!confirmed) {
      return;
    }
    await operations.unenrollArchiveMaster();
  }
}
