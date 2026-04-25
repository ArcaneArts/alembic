import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/repository_auth.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/screen/home/home_actions.dart';
import 'package:alembic/screen/home/repository_auth_dialog.dart';
import 'package:alembic/screen/repository_settings.dart';
import 'package:alembic/util/archive_master.dart';
import 'package:alembic/util/window.dart';
import 'package:alembic/widget/repository_tile_actions.dart';
import 'package:flutter/widgets.dart';
import 'package:github/github.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomeRepositoryOperations implements RepositoryTileActionOperations {
  final BuildContext context;
  final Repository repository;
  final ArcaneRepository arcaneRepository;
  final GitHub github;
  final RepositoryRuntime runtime;
  final RepoState state;
  final List<String> work;
  final Future<void> Function() onChanged;

  const HomeRepositoryOperations({
    required this.context,
    required this.repository,
    required this.arcaneRepository,
    required this.github,
    required this.runtime,
    required this.state,
    required this.work,
    required this.onChanged,
  });

  @override
  Future<void> showDetails() async {
    String owner = repository.owner?.login ?? 'unknown';
    String workLabel = work.isEmpty ? 'None' : work.join(', ');
    List<String> lines = <String>[
      'State: ${state.label}',
      'Owner: $owner',
      'Work: $workLabel',
      'Workspace: ${arcaneRepository.repoPath}',
      'Archive: ${arcaneRepository.imagePath}',
    ];
    if (state == RepoState.active) {
      int daysUntilArchive = await arcaneRepository.daysUntilArchival;
      lines.add('Auto-archive in: $daysUntilArchive day(s)');
    }
    if (!context.mounted) {
      return;
    }
    await showAlembicInfoDialog(
      context,
      title: repository.fullName,
      message: lines.join('\n'),
    );
  }

  @override
  Future<void> openInFinder() async {
    await WindowUtil.hide();
    await arcaneRepository.openInFinder();
    runtime.notifyChanged();
    await onChanged();
  }

  @override
  Future<void> openSettings() =>
      showRepositorySettingsModal(context, repository);

  @override
  Future<void> openExternalUrl(String url) => launchUrlString(url);

  @override
  Future<void> pull() async {
    await arcaneRepository.ensureRepositoryUpdated(github);
    await onChanged();
  }

  @override
  Future<void> archive() async {
    await arcaneRepository.archive();
    await onChanged();
  }

  @override
  Future<void> deleteRepository() async {
    await arcaneRepository.deleteRepository();
    await onChanged();
  }

  @override
  Future<void> activate() async {
    await arcaneRepository.unarchive(github);
    await onChanged();
  }

  @override
  Future<void> updateArchive() async {
    await arcaneRepository.updateArchive(github);
    await onChanged();
  }

  @override
  Future<void> deleteArchive() async {
    await arcaneRepository.deleteArchive();
    await onChanged();
  }

  @override
  Future<void> cloneRepository() async {
    await arcaneRepository.ensureRepositoryActive(github);
    await onChanged();
  }

  @override
  Future<void> archiveFromCloud() async {
    await arcaneRepository.archiveFromCloud(github);
    await onChanged();
  }

  @override
  Future<void> forkAndClone() async {
    try {
      await arcaneRepository.forkAndClone(github);
      await onChanged();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      await showAlembicInfoDialog(
        context,
        title: 'Fork Failed',
        message: '$e',
      );
    }
  }

  @override
  Future<bool> confirmDeleteRepository() {
    return showAlembicConfirmDialog(
      context,
      title: 'Delete ${repository.fullName}?',
      description:
          'Delete this repository from local workspace. Unstaged or unpushed changes can be lost forever.',
      confirmText: 'Delete',
      destructive: true,
    );
  }

  @override
  Future<bool> confirmDeleteArchive() {
    return showAlembicConfirmDialog(
      context,
      title: 'Delete archive ${repository.fullName}?',
      description:
          'Delete this archived image from local storage. Any unsynced local changes inside the archive will be lost.',
      confirmText: 'Delete Archive',
      destructive: true,
    );
  }

  @override
  Future<void> enrollArchiveMaster() async {
    await addArchiveMasterRepository(
      owner: repository.owner?.login ?? '',
      repository: repository.name,
      accountId: arcaneRepository.accountId,
    );
    await arcaneRepository.ensureArchiveMaster(github);
    await onChanged();
  }

  @override
  Future<void> unenrollArchiveMaster() async {
    await removeArchiveMasterRepository(
      repository.owner?.login ?? '',
      repository.name,
    );
    await arcaneRepository.removeArchiveMaster();
    await onChanged();
  }

  @override
  Future<void> refreshArchiveMaster() async {
    try {
      await arcaneRepository.ensureArchiveMaster(github);
      await onChanged();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      await showAlembicInfoDialog(
        context,
        title: 'Archive Master Refresh Failed',
        message: '$e',
      );
    }
  }

  @override
  Future<void> promoteArchiveMaster() async {
    try {
      await arcaneRepository.promoteArchiveMaster(github);
      await onChanged();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      await showAlembicInfoDialog(
        context,
        title: 'Archive Master Promotion Failed',
        message: '$e',
      );
    }
  }

  @override
  Future<bool> confirmUnenrollArchiveMaster() {
    return showAlembicConfirmDialog(
      context,
      title: 'Remove ${repository.fullName} from Archive Master?',
      description:
          'This stops scheduled mirror updates and deletes the managed mirror clone. Active workspace and archives are unaffected.',
      confirmText: 'Remove',
      destructive: true,
    );
  }

  @override
  Future<void> changeAuth() async {
    const RepositoryAuthInspector inspector = RepositoryAuthInspector();
    final RepoAuthInfo current = await inspector.read(arcaneRepository);
    if (!context.mounted) {
      return;
    }
    final bool applied = await showRepositoryAuthDialog(
      context: context,
      repo: arcaneRepository,
      current: current,
    );
    if (applied) {
      await onChanged();
    }
  }
}
