class SpikeChannels {
  static const String app = 'alembic.spike';
  static const String repositories = 'alembic.spike.repositories';
  static const String repositoryActions = 'alembic.spike.repositories.actions';
  static const String repositoryWork = 'alembic.spike.repositories.work';
  static const String accounts = 'alembic.spike.accounts';
  static const String settings = 'alembic.spike.settings';
  static const String diagnostics = 'alembic.spike.diagnostics';
  static const String workspace = 'alembic.spike.workspace';
}

class SpikeAppChannelMethods {
  static const String state = 'state';
  static const String echo = 'echo';
  static const String setStatus = 'setStatus';
  static const String shutdown = 'shutdown';
}

class SpikeRepositoryChannelMethods {
  static const String state = 'state';
  static const String refresh = 'refresh';
  static const String retry = 'retry';
  static const String selectAccount = 'selectAccount';
  static const String openInBrowser = 'openInBrowser';
  static const String signInWithToken = 'signInWithToken';
  static const String signOut = 'signOut';
}

class SpikeRepositoryActionMethods {
  static const String clone = 'clone';
  static const String pull = 'pull';
  static const String open = 'open';
  static const String openInFinder = 'openInFinder';
  static const String archive = 'archive';
  static const String unarchive = 'unarchive';
  static const String updateArchive = 'updateArchive';
  static const String archiveFromCloud = 'archiveFromCloud';
  static const String delete = 'delete';
  static const String deleteArchive = 'deleteArchive';
  static const String fork = 'fork';
  static const String enrollArchiveMaster = 'enrollArchiveMaster';
  static const String unenrollArchiveMaster = 'unenrollArchiveMaster';
  static const String refreshArchiveMaster = 'refreshArchiveMaster';
  static const String promoteArchiveMaster = 'promoteArchiveMaster';
  static const String getDetail = 'getDetail';
}

class SpikeRepositoryWorkMethods {
  static const String state = 'state';
  static const String getSnapshot = 'getSnapshot';
  static const String rescan = 'rescan';
}

class SpikeAccountChannelMethods {
  static const String state = 'state';
  static const String getAll = 'getAll';
  static const String add = 'add';
  static const String remove = 'remove';
  static const String rename = 'rename';
  static const String setPrimary = 'setPrimary';
  static const String reorder = 'reorder';
}

class SpikeSettingsChannelMethods {
  static const String state = 'state';
  static const String getAll = 'getAll';
  static const String setGeneral = 'setGeneral';
  static const String setWorkspace = 'setWorkspace';
  static const String setTools = 'setTools';
  static const String setArchiveMaster = 'setArchiveMaster';
  static const String setRepoConfig = 'setRepoConfig';
  static const String getRepoConfig = 'getRepoConfig';
  static const String revealDataFolder = 'revealDataFolder';
}

class SpikeRepositoryStatus {
  static const String idle = 'idle';
  static const String loading = 'loading';
  static const String ready = 'ready';
  static const String error = 'error';
  static const String empty = 'empty';
  static const String noAccount = 'noAccount';
}

class SpikeRepoStateValue {
  static const String active = 'active';
  static const String archived = 'archived';
  static const String cloud = 'cloud';
}

class SpikeDiagnosticsChannelMethods {
  static const String log = 'log';
  static const String snapshot = 'snapshot';
  static const String requestSnapshot = 'requestSnapshot';
}

class SpikeDiagnosticsLevel {
  static const String trace = 'trace';
  static const String info = 'info';
  static const String warn = 'warn';
  static const String error = 'error';
  static const String success = 'success';
}

class SpikeWorkspaceChannelMethods {
  static const String state = 'state';
  static const String getWorkspacePath = 'getWorkspacePath';
  static const String setWorkspacePath = 'setWorkspacePath';
  static const String scanDirectory = 'scanDirectory';
  static const String importDiscovered = 'importDiscovered';
  static const String scanProgress = 'scanProgress';
  static const String cloneFromUrl = 'cloneFromUrl';
}
