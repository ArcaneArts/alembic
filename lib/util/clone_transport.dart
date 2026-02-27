import 'package:alembic/main.dart';

const String cloneTransportModeKey = 'clone_transport_mode_v1';

enum CloneTransportMode {
  https,
  sshPreferred,
}

extension XCloneTransportMode on CloneTransportMode {
  String get storageValue => switch (this) {
        CloneTransportMode.https => 'https',
        CloneTransportMode.sshPreferred => 'ssh_preferred',
      };

  String get label => switch (this) {
        CloneTransportMode.https => 'HTTPS (PAT + Public Fallback)',
        CloneTransportMode.sshPreferred => 'SSH Preferred',
      };
}

CloneTransportMode loadCloneTransportMode() {
  final String raw =
      boxSettings.get(cloneTransportModeKey, defaultValue: 'https').toString();
  for (final CloneTransportMode mode in CloneTransportMode.values) {
    if (mode.storageValue == raw) {
      return mode;
    }
  }
  return CloneTransportMode.https;
}

Future<void> saveCloneTransportMode(CloneTransportMode mode) {
  return boxSettings.put(cloneTransportModeKey, mode.storageValue);
}
