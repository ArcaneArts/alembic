import 'dart:io';

import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/core/app_update_service.dart';
import 'package:alembic/main.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:arcane/arcane.dart';
import 'package:fast_log/fast_log.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

class HomeUpdateChecker {
  static const String _settingsKey = 'achup';

  const HomeUpdateChecker();

  Future<bool> check({
    required BuildContext context,
    required bool force,
  }) async {
    if (!force && boxSettings.get(_settingsKey, defaultValue: true) != true) {
      return false;
    }
    AppUpdateService updateService = AppUpdateService();
    UpdateCheckResult? update;
    bool shouldNotifyFailure = force;
    try {
      String currentVersion = packageInfo.version.trim();
      update =
          await updateService.checkForUpdate(currentVersion: currentVersion);
      if (update == null) {
        info('The app is up to date (version: $currentVersion)');
        return false;
      }
      if (!context.mounted) {
        return true;
      }
      bool confirmed = await _confirmDownload(context, update);
      if (!confirmed) {
        return true;
      }
      shouldNotifyFailure = true;
      await _downloadAndApply(updateService, update);
      return true;
    } catch (e) {
      error('Error checking for updates: $e');
      if (shouldNotifyFailure && context.mounted) {
        await _showUpdateFailure(context, update, e);
      }
      return false;
    } finally {
      updateService.dispose();
    }
  }

  Future<bool> _confirmDownload(
    BuildContext context,
    UpdateCheckResult update,
  ) {
    DesktopPlatformAdapter adapter = DesktopPlatformAdapter.instance;
    return showAlembicConfirmDialog(
      context,
      title: 'Alembic ${update.manifest.version} Available',
      description:
          'A new ${adapter.updatePlatformName} release is available. Alembic will download it, replace this install, and relaunch.',
      confirmText: 'Update',
      cancelText: 'Later',
    );
  }

  Future<void> _showUpdateFailure(
    BuildContext context,
    UpdateCheckResult? update,
    Object failure,
  ) async {
    DesktopPlatformAdapter adapter = DesktopPlatformAdapter.instance;
    String manualInstallerUrl = _manualInstallerUrl(update);
    if (manualInstallerUrl.isEmpty) {
      await showAlembicInfoDialog(
        context,
        title: 'Update Failed',
        message:
            'Alembic could not complete the update check.\n\nDetails: $failure',
      );
      return;
    }

    bool openInstaller = await showAlembicConfirmDialog(
      context,
      title: 'Automatic Update Failed',
      description:
          'Alembic could not install the update automatically.\n\nDetails: $failure\n\nOpen the platform installer instead?',
      confirmText: 'Open Installer',
      cancelText: 'Close',
    );
    if (openInstaller) {
      await adapter.launchDownloadedUpdate(manualInstallerUrl);
    }
  }

  String _manualInstallerUrl(UpdateCheckResult? update) {
    if (update == null) {
      return '';
    }
    if (update.asset.manualUrl.isNotEmpty) {
      return update.asset.manualUrl;
    }
    return update.asset.url;
  }

  Future<void> _downloadAndApply(
    AppUpdateService updateService,
    UpdateCheckResult update,
  ) async {
    DesktopPlatformAdapter adapter = DesktopPlatformAdapter.instance;
    String temporaryDirectory = (await getTemporaryDirectory()).absolute.path;
    File payload = await updateService.downloadAsset(
      asset: update.asset,
      temporaryDirectory: temporaryDirectory,
    );
    String installTarget = adapter.currentInstallTarget();
    String manualInstallerUrl = _manualInstallerUrl(update);

    verbose('Launching updater for $installTarget from ${payload.path}');
    int launchExitCode = await adapter.launchSilentUpdateHelper(
      payloadPath: payload.path,
      installTarget: installTarget,
      manualInstallerUrl: manualInstallerUrl,
    );
    if (launchExitCode != 0) {
      throw Exception('Failed to launch silent update helper');
    }
    warn('Shutting down Alembic so the update can be installed');
    await windowManager.destroy();
    exit(0);
  }
}
