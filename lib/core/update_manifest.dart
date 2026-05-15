import 'package:alembic/platform/desktop_platform_adapter.dart';

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
