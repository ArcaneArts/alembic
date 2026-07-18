import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/presentation/repository_action_model.dart';
import 'package:alembic/widget/repository_tile_actions.dart';
import 'package:flutter/material.dart' as m;

class RepositoryActionCatalog {
  const RepositoryActionCatalog._();

  static List<RepositoryActionModel> stateActions(RepoState state) =>
      switch (state) {
        RepoState.active => <RepositoryActionModel>[
            const RepositoryActionModel(
              action: RepositoryTileAction.pull,
              label: 'Pull latest changes',
              description: 'Run `git pull` in the active workspace repository.',
              icon: m.Icons.sync,
              prominent: true,
            ),
            const RepositoryActionModel(
              action: RepositoryTileAction.archive,
              label: 'Archive repository',
              description:
                  'Compress the local repository into Alembic archive storage.',
              icon: m.Icons.archive_outlined,
            ),
            const RepositoryActionModel(
              action: RepositoryTileAction.deleteRepository,
              label: 'Delete local repository',
              description: 'Remove the cloned workspace copy from this device.',
              icon: m.Icons.delete_outline,
              destructive: true,
            ),
          ],
        RepoState.archived => <RepositoryActionModel>[
            const RepositoryActionModel(
              action: RepositoryTileAction.activate,
              label: 'Activate archive',
              description:
                  'Restore this archived repository into the workspace.',
              icon: m.Icons.unarchive_outlined,
              prominent: true,
            ),
            const RepositoryActionModel(
              action: RepositoryTileAction.updateArchive,
              label: 'Refresh archive',
              description:
                  'Restore, pull, and recompress the archive snapshot.',
              icon: m.Icons.sync,
            ),
            const RepositoryActionModel(
              action: RepositoryTileAction.deleteArchive,
              label: 'Delete archive',
              description:
                  'Remove the stored archive snapshot from local storage.',
              icon: m.Icons.delete_outline,
              destructive: true,
            ),
          ],
        RepoState.cloud => <RepositoryActionModel>[
            const RepositoryActionModel(
              action: RepositoryTileAction.clone,
              label: 'Clone repository',
              description:
                  'Clone this repository into the configured workspace.',
              icon: m.Icons.add_link,
              prominent: true,
            ),
            const RepositoryActionModel(
              action: RepositoryTileAction.archiveFromCloud,
              label: 'Archive from cloud',
              description:
                  'Clone the repository, then archive it without keeping a working copy.',
              icon: m.Icons.archive_outlined,
            ),
          ],
      };

  static List<RepositoryActionModel> linkActions({
    required bool canFork,
    required String explorerName,
    required bool includeExplorer,
  }) =>
      <RepositoryActionModel>[
        const RepositoryActionModel(
          action: RepositoryTileAction.details,
          label: 'Repository details',
          description: 'Open the repository detail summary dialog.',
          icon: m.Icons.info_outline,
        ),
        const RepositoryActionModel(
          action: RepositoryTileAction.changeAuth,
          label: 'Change authentication',
          description:
              'Pick the GitHub account, public HTTPS, or SSH key for this repository.',
          icon: m.Icons.vpn_key_outlined,
        ),
        if (includeExplorer)
          RepositoryActionModel(
            action: RepositoryTileAction.openFinder,
            label: 'Open in $explorerName',
            description:
                'Reveal the active working copy in the system file browser.',
            icon: m.Icons.folder_open,
          ),
        const RepositoryActionModel(
          action: RepositoryTileAction.settings,
          label: 'Repository settings',
          description:
              'Configure repository-specific editor, Git client, and path overrides.',
          icon: m.Icons.tune,
        ),
        const RepositoryActionModel(
          action: RepositoryTileAction.viewGithub,
          label: 'View on GitHub',
          description: 'Open the main repository page in the browser.',
          icon: m.Icons.open_in_new,
        ),
        const RepositoryActionModel(
          action: RepositoryTileAction.issues,
          label: 'Issues',
          description: 'Open the issues list for this repository.',
          icon: m.Icons.report_problem_outlined,
        ),
        const RepositoryActionModel(
          action: RepositoryTileAction.pullRequests,
          label: 'Pull requests',
          description: 'Open the pull request list for this repository.',
          icon: m.Icons.account_tree_outlined,
        ),
        const RepositoryActionModel(
          action: RepositoryTileAction.newIssue,
          label: 'New issue',
          description: 'Open the GitHub new issue flow.',
          icon: m.Icons.add_circle_outline,
        ),
        const RepositoryActionModel(
          action: RepositoryTileAction.newPullRequest,
          label: 'New pull request',
          description: 'Open the GitHub compare view to start a pull request.',
          icon: m.Icons.add_task,
        ),
        if (canFork)
          const RepositoryActionModel(
            action: RepositoryTileAction.fork,
            label: 'Fork and clone',
            description:
                'Create a fork in your account and clone it into the workspace.',
            icon: m.Icons.call_split,
          ),
      ];

  static List<RepositoryActionModel> localActions({
    required bool includeExplorer,
    required String explorerName,
  }) =>
      <RepositoryActionModel>[
        const RepositoryActionModel(
          action: RepositoryTileAction.settings,
          label: 'Repository settings',
          description: '',
          icon: m.Icons.tune,
        ),
        const RepositoryActionModel(
          action: RepositoryTileAction.changeAuth,
          label: 'Change authentication',
          description: '',
          icon: m.Icons.vpn_key_outlined,
        ),
        const RepositoryActionModel(
          action: RepositoryTileAction.details,
          label: 'Repository details',
          description: '',
          icon: m.Icons.info_outline,
        ),
        if (includeExplorer)
          RepositoryActionModel(
            action: RepositoryTileAction.openFinder,
            label: 'Open in $explorerName',
            description: '',
            icon: m.Icons.folder_open,
          ),
      ];

  static List<RepositoryActionModel> githubActions() =>
      const <RepositoryActionModel>[
        RepositoryActionModel(
          action: RepositoryTileAction.viewGithub,
          label: 'View on GitHub',
          description: '',
          icon: m.Icons.open_in_new,
        ),
        RepositoryActionModel(
          action: RepositoryTileAction.pullRequests,
          label: 'Pull requests',
          description: '',
          icon: m.Icons.account_tree_outlined,
        ),
        RepositoryActionModel(
          action: RepositoryTileAction.issues,
          label: 'Issues',
          description: '',
          icon: m.Icons.report_problem_outlined,
        ),
      ];

  static List<RepositoryActionModel> archiveMasterActions({
    required bool enrolled,
    required bool hasMasterClone,
    required bool isActive,
  }) {
    final List<RepositoryActionModel> actions = <RepositoryActionModel>[];
    if (!enrolled) {
      actions.add(const RepositoryActionModel(
        action: RepositoryTileAction.enrollArchiveMaster,
        label: 'Enroll in Archive Master',
        description:
            'Maintain a managed mirror that pulls automatically on a schedule.',
        icon: m.Icons.cloud_sync_outlined,
      ));
    } else {
      actions.add(const RepositoryActionModel(
        action: RepositoryTileAction.refreshArchiveMaster,
        label: 'Refresh archive master',
        description:
            'Force a clone or pull of the managed archive master mirror.',
        icon: m.Icons.refresh,
      ));
      if (hasMasterClone && !isActive) {
        actions.add(const RepositoryActionModel(
          action: RepositoryTileAction.promoteArchiveMaster,
          label: 'Promote to workspace',
          description:
              'Move the managed mirror into the workspace as the active checkout.',
          icon: m.Icons.upgrade,
        ));
      }
      actions.add(const RepositoryActionModel(
        action: RepositoryTileAction.unenrollArchiveMaster,
        label: 'Remove from Archive Master',
        description:
            'Stop tracking this repository and delete the managed mirror.',
        icon: m.Icons.cancel_outlined,
        destructive: true,
      ));
    }
    return actions;
  }

  static RepositoryActionModel find(
    List<RepositoryActionModel> actions,
    RepositoryTileAction action,
  ) =>
      actions.firstWhere(
        (RepositoryActionModel model) => model.action == action,
      );
}
