import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/screen/home/home_actions.dart';
import 'package:alembic/screen/home/home_controller.dart';
import 'package:alembic/screen/home/home_tiles.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;
import 'package:github/github.dart';

class HomeBulkActionsCoordinator {
  final HomeController controller;
  final RepositoryRuntime runtime;
  final Future<List<Repository>> Function() getAllRepositories;
  final VoidCallback onChanged;

  const HomeBulkActionsCoordinator({
    required this.controller,
    required this.runtime,
    required this.getAllRepositories,
    required this.onChanged,
  });

  Future<void> executeOperation(
    Iterable<Repository> repositories,
    Future<void> Function(ArcaneRepository repository) operation, {
    String label = 'Working repositories',
  }) async {
    await controller.executeBulkOperation(
      repositories,
      operation,
      label: label,
    );
    onChanged();
  }

  Future<void> executeAction(HomeBulkAction action) async {
    List<Repository> active = runtime.activeRepositories;
    if (action == HomeBulkAction.pullActive) {
      await executeOperation(
        active,
        (ArcaneRepository repository) => repository.ensureRepositoryUpdated(
          controller.githubForRepository(repository.repository),
        ),
        label: HomeBulkAction.pullActive.label,
      );
      return;
    }
    if (action == HomeBulkAction.archiveActive) {
      await executeOperation(
        active,
        (ArcaneRepository repository) => repository.archive(),
        label: HomeBulkAction.archiveActive.label,
      );
      return;
    }

    List<Repository> repositories = await getAllRepositories();
    Iterable<Repository> archivedRepositories = repositories.where(
      (Repository repository) =>
          controller.repositoryFor(repository).isArchivedSync,
    );

    if (action == HomeBulkAction.updateArchives) {
      await executeOperation(
        archivedRepositories,
        (ArcaneRepository repository) => repository.updateArchive(
          controller.githubForRepository(repository.repository),
        ),
        label: HomeBulkAction.updateArchives.label,
      );
      return;
    }
    if (action == HomeBulkAction.activateArchives) {
      await executeOperation(
        archivedRepositories,
        (ArcaneRepository repository) => repository.unarchive(
          controller.githubForRepository(repository.repository),
          waitForPull: true,
        ),
        label: HomeBulkAction.activateArchives.label,
      );
      return;
    }

    await executeOperation(
      repositories,
      (ArcaneRepository repository) => repository.ensureRepositoryActive(
        controller.githubForRepository(repository.repository),
      ),
      label: HomeBulkAction.activateEverything.label,
    );
  }

  Future<void> showActionsDialog(BuildContext context) async {
    HomeBulkAction? selected = await _pickAction(context);
    if (selected == null) {
      return;
    }
    await executeAction(selected);
  }

  Future<HomeBulkAction?> _pickAction(BuildContext context) {
    List<HomeBulkAction> actions = _availableActions();
    return m.showDialog<HomeBulkAction>(
      context: context,
      builder: (BuildContext dialogContext) {
        return m.Dialog(
          child: AlembicPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AlembicSectionHeader(
                  title: 'Bulk Actions',
                  subtitle: 'Run repository operations across larger sets.',
                ),
                const Gap(AlembicShadcnTokens.gapLg),
                for (HomeBulkAction action in actions)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AlembicShadcnTokens.gapSm,
                    ),
                    child: HomeBulkActionTile(
                      action: action,
                      onPressed: () => Navigator.of(dialogContext).pop(action),
                    ),
                  ),
                const Gap(8),
                Align(
                  alignment: Alignment.centerRight,
                  child: AlembicToolbarButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    label: 'Close',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<HomeBulkAction> _availableActions() {
    List<HomeBulkAction> actions = <HomeBulkAction>[];
    if (runtime.activeRepositories.isNotEmpty) {
      actions.add(HomeBulkAction.pullActive);
      actions.add(HomeBulkAction.archiveActive);
    }
    actions.add(HomeBulkAction.updateArchives);
    actions.add(HomeBulkAction.activateArchives);
    actions.add(HomeBulkAction.activateEverything);
    return actions;
  }
}
