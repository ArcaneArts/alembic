import 'dart:convert';

import 'package:alembic/main.dart';

const String manualRepositoryCatalogKey = 'manual_repo_catalog_v1';

class RepositoryRef {
  final String owner;
  final String name;

  const RepositoryRef({
    required this.owner,
    required this.name,
  });

  String get fullName => '$owner/$name';

  @override
  bool operator ==(Object other) {
    return other is RepositoryRef &&
        other.fullName.toLowerCase() == fullName.toLowerCase();
  }

  @override
  int get hashCode => fullName.toLowerCase().hashCode;
}

RepositoryRef? parseRepositoryRef(String input) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final RegExp sshPattern = RegExp(r'^git@github\.com:([^/]+)/(.+?)(?:\.git)?$');
  final RegExpMatch? sshMatch = sshPattern.firstMatch(trimmed);
  if (sshMatch != null) {
    return _buildRepositoryRef(sshMatch.group(1), sshMatch.group(2));
  }

  final Uri? uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    if (uri.host.toLowerCase() != 'github.com') {
      return null;
    }
    final List<String> segments =
        uri.pathSegments.where((segment) => segment.trim().isNotEmpty).toList();
    if (segments.length < 2) {
      return null;
    }
    return _buildRepositoryRef(segments[0], segments[1]);
  }

  final RegExp slugPattern = RegExp(r'^([^/\s]+)/([^/\s]+)$');
  final RegExpMatch? slugMatch = slugPattern.firstMatch(trimmed);
  if (slugMatch == null) {
    return null;
  }
  return _buildRepositoryRef(slugMatch.group(1), slugMatch.group(2));
}

RepositoryRef? _buildRepositoryRef(String? owner, String? name) {
  if (owner == null || name == null) {
    return null;
  }
  String normalizedOwner = owner.trim();
  String normalizedName = name.trim();
  if (normalizedName.endsWith('.git')) {
    normalizedName =
        normalizedName.substring(0, normalizedName.length - '.git'.length);
  }
  if (normalizedOwner.isEmpty || normalizedName.isEmpty) {
    return null;
  }
  return RepositoryRef(owner: normalizedOwner, name: normalizedName);
}

List<RepositoryRef> loadManualRepoRefs() {
  final dynamic raw = boxSettings.get(
    manualRepositoryCatalogKey,
    defaultValue: '[]',
  );
  final List<RepositoryRef> refs = <RepositoryRef>[];

  try {
    final dynamic decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is List<dynamic>) {
      for (final dynamic entry in decoded) {
        RepositoryRef? ref;
        if (entry is String) {
          ref = parseRepositoryRef(entry);
        } else if (entry is Map<String, dynamic>) {
          ref = _buildRepositoryRef(
            entry['owner'] as String?,
            entry['name'] as String?,
          );
        } else if (entry is Map) {
          ref = _buildRepositoryRef(
            entry['owner'] as String?,
            entry['name'] as String?,
          );
        }
        if (ref != null) {
          refs.add(ref);
        }
      }
    }
  } catch (_) {
    return <RepositoryRef>[];
  }

  return _dedupeRepositoryRefs(refs);
}

Future<void> saveManualRepoRefs(List<RepositoryRef> refs) async {
  final List<String> serialized = _dedupeRepositoryRefs(refs)
      .map((RepositoryRef ref) => ref.fullName)
      .toList();
  await boxSettings.put(
    manualRepositoryCatalogKey,
    jsonEncode(serialized),
  );
}

Future<void> addManualRepoRef(RepositoryRef ref) async {
  final List<RepositoryRef> refs = loadManualRepoRefs();
  refs.add(ref);
  await saveManualRepoRefs(refs);
}

Future<void> removeManualRepoRef(RepositoryRef ref) async {
  final List<RepositoryRef> refs = loadManualRepoRefs();
  refs.removeWhere(
    (RepositoryRef item) =>
        item.fullName.toLowerCase() == ref.fullName.toLowerCase(),
  );
  await saveManualRepoRefs(refs);
}

List<RepositoryRef> _dedupeRepositoryRefs(List<RepositoryRef> refs) {
  final Map<String, RepositoryRef> byName = <String, RepositoryRef>{};
  for (final RepositoryRef ref in refs) {
    byName[ref.fullName.toLowerCase()] = ref;
  }
  final List<RepositoryRef> deduped = byName.values.toList();
  deduped.sort(
    (RepositoryRef a, RepositoryRef b) =>
        a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
  );
  return deduped;
}
