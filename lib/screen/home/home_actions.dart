import 'package:alembic/core/arcane_repository.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart';

enum HomeBulkAction {
  pullActive,
  archiveActive,
  updateArchives,
  activateArchives,
  activateEverything,
}

enum HomeTopMenuAction {
  workspaceFolder,
  archivesFolder,
  bulkActions,
  checkUpdates,
  restart,
  logout,
}

extension HomeBulkActionMeta on HomeBulkAction {
  String get label => switch (this) {
        HomeBulkAction.pullActive => 'Pull active repositories',
        HomeBulkAction.archiveActive => 'Archive active repositories',
        HomeBulkAction.updateArchives => 'Refresh archived snapshots',
        HomeBulkAction.activateArchives => 'Reactivate archived repositories',
        HomeBulkAction.activateEverything => 'Activate every repository',
      };

  String get description => switch (this) {
        HomeBulkAction.pullActive =>
          'Run `git pull` across every currently active repository.',
        HomeBulkAction.archiveActive =>
          'Archive every active repository into local Alembic storage.',
        HomeBulkAction.updateArchives =>
          'Unarchive, pull, and re-compress every archived repository.',
        HomeBulkAction.activateArchives =>
          'Restore archived repositories back into the workspace.',
        HomeBulkAction.activateEverything =>
          'Clone or restore every visible repository into the workspace.',
      };

  bool get prominent =>
      this == HomeBulkAction.pullActive ||
      this == HomeBulkAction.activateEverything;
}

extension HomeTopMenuActionMeta on HomeTopMenuAction {
  String get label => switch (this) {
        HomeTopMenuAction.workspaceFolder => 'Open workspace folder',
        HomeTopMenuAction.archivesFolder => 'Open archives folder',
        HomeTopMenuAction.bulkActions => 'Bulk actions',
        HomeTopMenuAction.checkUpdates => 'Check for updates',
        HomeTopMenuAction.restart => 'Restart app',
        HomeTopMenuAction.logout => 'Log out',
      };

  IconData get icon => switch (this) {
        HomeTopMenuAction.workspaceFolder => m.Icons.folder_open,
        HomeTopMenuAction.archivesFolder => m.Icons.archive_outlined,
        HomeTopMenuAction.bulkActions =>
          m.Icons.playlist_add_check_circle_outlined,
        HomeTopMenuAction.checkUpdates => m.Icons.system_update_alt,
        HomeTopMenuAction.restart => m.Icons.restart_alt,
        HomeTopMenuAction.logout => m.Icons.logout,
      };
}

extension RepoStateMeta on RepoState {
  String get label => switch (this) {
        RepoState.active => 'Local',
        RepoState.archived => 'Archived',
        RepoState.cloud => 'Remote',
      };

  String get primaryActionLabel => switch (this) {
        RepoState.active => 'Open',
        RepoState.archived => 'Activate',
        RepoState.cloud => 'Clone',
      };

  IconData get primaryActionIcon => switch (this) {
        RepoState.active => m.Icons.folder_open,
        RepoState.archived => m.Icons.unarchive_outlined,
        RepoState.cloud => m.Icons.add_link,
      };
}
