import 'dart:io';

import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/main.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:arcane/arcane.dart';
import 'package:fast_log/fast_log.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

class HomeUpdateChecker {
  static const String _settingsKey = 'achup';
  static const String _versionManifestUrl =
      'https://raw.githubusercontent.com/ArcaneArts/alembic/refs/heads/main/version';

  const HomeUpdateChecker();

  Future<bool> check({
    required BuildContext context,
    required bool force,
  }) async {
    if (!force && boxSettings.get(_settingsKey, defaultValue: true) != true) {
      return false;
    }
    try {
      String? liveVersion = await _fetchLiveVersion();
      if (liveVersion == null) {
        return false;
      }
      String currentVersion = packageInfo.version.trim();
      if (liveVersion == currentVersion) {
        info('The app is up to date (version: $currentVersion)');
        return false;
      }
      if (!context.mounted) {
        return true;
      }
      bool confirmed = await _confirmDownload(context, liveVersion);
      if (!confirmed) {
        return true;
      }
      await _downloadAndApply(liveVersion);
      return true;
    } catch (e) {
      error('Error checking for updates: $e');
      return false;
    }
  }

  Future<String?> _fetchLiveVersion() async {
    http.Response response = await http.get(Uri.parse(_versionManifestUrl));
    if (response.statusCode != 200) {
      error('Failed to fetch version file. Status: ${response.statusCode}');
      return null;
    }
    return response.body.trim();
  }

  Future<bool> _confirmDownload(BuildContext context, String liveVersion) {
    return showAlembicConfirmDialog(
      context,
      title: 'Alembic $liveVersion Available',
      description:
          'A new version is available for ${DesktopPlatformAdapter.instance.currentPlatform.name}. Download it now?',
      confirmText: 'Download',
      cancelText: 'Later',
    );
  }

  Future<void> _downloadAndApply(String liveVersion) async {
    DesktopPlatformAdapter adapter = DesktopPlatformAdapter.instance;
    String temporaryDirectory = (await getTemporaryDirectory()).absolute.path;
    String path = adapter.updateDownloadPath(
      temporaryDirectory: temporaryDirectory,
      version: liveVersion,
    );
    String url = adapter.updateDownloadUrl(liveVersion);

    await File(path).absolute.parent.create(recursive: true);
    verbose('Downloading $url to $path');

    http.Request request = http.Request('GET', Uri.parse(url));
    http.StreamedResponse streamedResponse = await http.Client().send(request);
    IOSink sink = File(path).openWrite();
    await streamedResponse.stream.pipe(sink);
    await sink.close();

    await adapter.launchDownloadedUpdate(path);
    warn('Shutting down Alembic so the update can be installed');
    await windowManager.destroy();
    exit(0);
  }
}
