import 'dart:convert';
import 'dart:io';

import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;
  final String preRelease;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease = '',
  });

  factory AppVersion.parse(String value) {
    String trimmed = value.trim();
    if (trimmed.startsWith('v')) {
      trimmed = trimmed.substring(1);
    }
    String withoutBuild = trimmed.split('+').first;
    List<String> preReleaseSplit = withoutBuild.split('-');
    String core = preReleaseSplit.first;
    String preRelease =
        preReleaseSplit.length > 1 ? preReleaseSplit.sublist(1).join('-') : '';
    List<String> parts = core.split('.');
    return AppVersion(
      major: _part(parts, 0),
      minor: _part(parts, 1),
      patch: _part(parts, 2),
      preRelease: preRelease,
    );
  }

  static int _part(List<String> parts, int index) {
    if (index >= parts.length) {
      return 0;
    }
    return int.tryParse(parts[index]) ?? 0;
  }

  @override
  int compareTo(AppVersion other) {
    int majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) {
      return majorComparison;
    }
    int minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) {
      return minorComparison;
    }
    int patchComparison = patch.compareTo(other.patch);
    if (patchComparison != 0) {
      return patchComparison;
    }
    return _comparePreRelease(other);
  }

  int _comparePreRelease(AppVersion other) {
    if (preRelease.isEmpty && other.preRelease.isEmpty) {
      return 0;
    }
    if (preRelease.isEmpty) {
      return 1;
    }
    if (other.preRelease.isEmpty) {
      return -1;
    }

    List<String> left = preRelease.split('.');
    List<String> right = other.preRelease.split('.');
    int length = left.length > right.length ? left.length : right.length;
    for (int i = 0; i < length; i++) {
      if (i >= left.length) {
        return -1;
      }
      if (i >= right.length) {
        return 1;
      }
      int comparison = _comparePreReleasePart(left[i], right[i]);
      if (comparison != 0) {
        return comparison;
      }
    }
    return 0;
  }

  int _comparePreReleasePart(String left, String right) {
    int? leftNumber = int.tryParse(left);
    int? rightNumber = int.tryParse(right);
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }
    if (leftNumber != null) {
      return -1;
    }
    if (rightNumber != null) {
      return 1;
    }
    return left.compareTo(right);
  }
}

class UpdatePlatformAsset {
  final String platform;
  final String kind;
  final String name;
  final String url;
  final String sha256;
  final int size;
  final String manualName;
  final String manualUrl;

  const UpdatePlatformAsset({
    required this.platform,
    required this.kind,
    required this.name,
    required this.url,
    required this.sha256,
    required this.size,
    required this.manualName,
    required this.manualUrl,
  });

  factory UpdatePlatformAsset.fromJson(Map<String, dynamic> json) {
    String platform = _string(json, 'platform');
    String kind = _string(json, 'kind');
    String name = _string(json, 'name');
    String url = _string(json, 'url');
    String sha256 = _string(json, 'sha256');
    if (platform.isEmpty ||
        kind.isEmpty ||
        name.isEmpty ||
        url.isEmpty ||
        sha256.isEmpty) {
      throw const FormatException('Update asset is missing required fields');
    }
    return UpdatePlatformAsset(
      platform: platform,
      kind: kind,
      name: name,
      url: url,
      sha256: sha256,
      size: _int(json, 'size'),
      manualName: _string(json, 'manualName'),
      manualUrl: _string(json, 'manualUrl'),
    );
  }

  static String _string(Map<String, dynamic> json, String key) =>
      json[key]?.toString().trim() ?? '';

  static int _int(Map<String, dynamic> json, String key) {
    Object? value = json[key];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class UpdateManifest {
  final String version;
  final String publishedAt;
  final String buildId;
  final List<UpdatePlatformAsset> assets;

  const UpdateManifest({
    required this.version,
    required this.publishedAt,
    required this.buildId,
    required this.assets,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    String version = json['version']?.toString().trim() ?? '';
    if (version.isEmpty) {
      throw const FormatException('Update manifest is missing version');
    }
    return UpdateManifest(
      version: version,
      publishedAt: json['publishedAt']?.toString().trim() ?? '',
      buildId: json['buildId']?.toString().trim() ?? '',
      assets: _assets(json['assets']),
    );
  }

  UpdatePlatformAsset? assetFor(AlembicDesktopPlatform platform) {
    String platformName = switch (platform) {
      AlembicDesktopPlatform.macos => 'macos',
      AlembicDesktopPlatform.windows => 'windows',
      AlembicDesktopPlatform.other => 'desktop',
    };
    for (UpdatePlatformAsset asset in assets) {
      if (asset.platform == platformName && asset.kind == 'zip') {
        return asset;
      }
    }
    return null;
  }

  bool isNewerThan({
    required String currentVersion,
    required String currentBuildId,
  }) {
    int versionComparison =
        AppVersion.parse(version).compareTo(AppVersion.parse(currentVersion));
    if (versionComparison != 0) {
      return versionComparison > 0;
    }
    return buildId.isNotEmpty &&
        currentBuildId.isNotEmpty &&
        buildId != currentBuildId;
  }

  static List<UpdatePlatformAsset> _assets(Object? rawAssets) {
    if (rawAssets is! List) {
      throw const FormatException('Update manifest assets must be a list');
    }
    return <UpdatePlatformAsset>[
      for (Object? rawAsset in rawAssets)
        if (rawAsset is Map<String, dynamic>)
          UpdatePlatformAsset.fromJson(rawAsset)
        else if (rawAsset is Map)
          UpdatePlatformAsset.fromJson(Map<String, dynamic>.from(rawAsset))
        else
          throw const FormatException('Update manifest asset is invalid'),
    ];
  }
}

class UpdateCheckResult {
  final UpdateManifest manifest;
  final UpdatePlatformAsset asset;

  const UpdateCheckResult({
    required this.manifest,
    required this.asset,
  });
}

class AppUpdateService {
  static const String defaultManifestUrl =
      'https://github.com/ArcaneArts/alembic/releases/latest/download/update.json';

  final DesktopPlatformAdapter adapter;
  final String manifestUrl;
  final http.Client _client;
  final bool _ownsClient;

  AppUpdateService({
    http.Client? client,
    this.adapter = DesktopPlatformAdapter.instance,
    this.manifestUrl = defaultManifestUrl,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  Future<UpdateCheckResult?> checkForUpdate({
    required String currentVersion,
    String currentBuildId = AppBuild.currentBuildId,
    AlembicDesktopPlatform? platform,
  }) async {
    UpdateManifest manifest = await fetchManifest();
    if (!manifest.isNewerThan(
      currentVersion: currentVersion,
      currentBuildId: currentBuildId,
    )) {
      return null;
    }
    AlembicDesktopPlatform selectedPlatform =
        platform ?? adapter.currentPlatform;
    UpdatePlatformAsset? asset = manifest.assetFor(selectedPlatform);
    if (asset == null) {
      throw StateError('No update asset for ${selectedPlatform.name}');
    }
    return UpdateCheckResult(manifest: manifest, asset: asset);
  }

  Future<UpdateManifest> fetchManifest() async {
    http.Response response = await _client.get(Uri.parse(manifestUrl));
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to fetch update manifest: ${response.statusCode}',
        uri: Uri.parse(manifestUrl),
      );
    }
    Object? json = jsonDecode(response.body);
    if (json is Map<String, dynamic>) {
      return UpdateManifest.fromJson(json);
    }
    if (json is Map) {
      return UpdateManifest.fromJson(Map<String, dynamic>.from(json));
    }
    throw const FormatException('Update manifest root must be an object');
  }

  Future<File> downloadAsset({
    required UpdatePlatformAsset asset,
    required String temporaryDirectory,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    File file = File(p.join(temporaryDirectory, 'Alembic', asset.name));
    await file.parent.create(recursive: true);
    http.Request request = http.Request('GET', Uri.parse(asset.url));
    http.StreamedResponse response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to download update asset: ${response.statusCode}',
        uri: Uri.parse(asset.url),
      );
    }

    int receivedBytes = 0;
    int responseContentLength = response.contentLength ?? -1;
    int? totalBytes = responseContentLength >= 0 ? responseContentLength : null;
    IOSink sink = file.openWrite();
    try {
      await for (List<int> chunk in response.stream) {
        receivedBytes += chunk.length;
        sink.add(chunk);
        onProgress?.call(receivedBytes, totalBytes);
      }
    } finally {
      await sink.close();
    }

    await verifyChecksum(file: file, expectedSha256: asset.sha256);
    return file;
  }

  Future<void> verifyChecksum({
    required File file,
    required String expectedSha256,
  }) async {
    String actual = await sha256ForFile(file);
    if (actual.toLowerCase() != expectedSha256.toLowerCase()) {
      throw StateError('Update checksum mismatch for ${file.path}');
    }
  }

  Future<String> sha256ForFile(File file) async {
    Digest digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

class AppBuild {
  static const String currentBuildId =
      String.fromEnvironment('ALEMBIC_BUILD_ID');

  const AppBuild._();
}
