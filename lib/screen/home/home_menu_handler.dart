import 'dart:io';

import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/main.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/screen/home/home_actions.dart';
import 'package:alembic/screen/home/home_bulk_actions.dart';
import 'package:alembic/screen/home/home_session.dart';
import 'package:alembic/screen/home/home_update_checker.dart';
import 'package:alembic/screen/splash.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class HomeTopMenuHandler {
  final HomeBulkActionsCoordinator bulkActions;
  final HomeSessionGuard session;
  final HomeUpdateChecker updateChecker;

  const HomeTopMenuHandler({
    required this.bulkActions,
    required this.session,
    required this.updateChecker,
  });

  List<HomeTopMenuAction> availableActions() {
    String workspacePath = expandPath(config.workspaceDirectory);
    String archivePath = _archivePath();
    return <HomeTopMenuAction>[
      if (Directory(workspacePath).existsSync())
        HomeTopMenuAction.workspaceFolder,
      if (Directory(archivePath).existsSync())
        HomeTopMenuAction.archivesFolder,
      HomeTopMenuAction.bulkActions,
      HomeTopMenuAction.checkUpdates,
      HomeTopMenuAction.restart,
      HomeTopMenuAction.logout,
    ];
  }

  Future<void> handle(BuildContext context, HomeTopMenuAction action) async {
    DesktopPlatformAdapter adapter = DesktopPlatformAdapter.instance;
    switch (action) {
      case HomeTopMenuAction.workspaceFolder:
        await adapter.openInFileExplorer(
          Directory(expandPath(config.workspaceDirectory)).absolute.path,
        );
        return;
      case HomeTopMenuAction.archivesFolder:
        await adapter.openInFileExplorer(
          Directory(_archivePath()).absolute.path,
        );
        return;
      case HomeTopMenuAction.bulkActions:
        await bulkActions.showActionsDialog(context);
        return;
      case HomeTopMenuAction.checkUpdates:
        await _checkForUpdatesNotifying(context);
        return;
      case HomeTopMenuAction.restart:
        if (!context.mounted) {
          return;
        }
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          m.MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
          (_) => false,
        );
        return;
      case HomeTopMenuAction.logout:
        await session.confirmLogout(context);
        return;
    }
  }

  Future<void> _checkForUpdatesNotifying(BuildContext context) async {
    bool updated = await updateChecker.check(context: context, force: true);
    if (updated || !context.mounted) {
      return;
    }
    await showAlembicInfoDialog(
      context,
      title: 'No Updates',
      message:
          'Alembic is already up to date. If a release is expected, try again later.',
    );
  }

  String _archivePath() =>
      '${expandPath(config.archiveDirectory)}/archives'.replaceAll('//', '/');
}
