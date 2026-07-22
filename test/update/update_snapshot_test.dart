import 'package:alembic/core/update_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateSnapshot', () {
    test('idle is not an available update and serializes its core fields', () {
      final UpdateSnapshot snapshot = UpdateSnapshot.idle(
        autoCheckEnabled: true,
        currentVersion: '1.0.13',
      );

      expect(snapshot.status, UpdateStatus.idle);
      expect(snapshot.updateAvailable, isFalse);
      expect(snapshot.latestVersion, isNull);

      final Map<String, Object?> json = snapshot.toJson();
      expect(json['status'], 'idle');
      expect(json['autoCheckEnabled'], true);
      expect(json['updateAvailable'], false);
      expect(json['currentVersion'], '1.0.13');
      expect(json['releaseUrl'], UpdateSnapshot.defaultReleaseUrl);
    });

    test('available marks an update and carries the latest version', () {
      final UpdateSnapshot snapshot = UpdateSnapshot.available(
        autoCheckEnabled: true,
        currentVersion: '1.0.13',
        latestVersion: '1.0.14',
        lastCheckedMs: 1700,
      );

      expect(snapshot.status, UpdateStatus.updateAvailable);
      expect(snapshot.updateAvailable, isTrue);
      expect(snapshot.latestVersion, '1.0.14');

      final Map<String, Object?> json = snapshot.toJson();
      expect(json['status'], 'updateAvailable');
      expect(json['updateAvailable'], true);
      expect(json['latestVersion'], '1.0.14');
      expect(json['lastCheckedMs'], 1700);
    });

    test('upToDate clears the latest version and is not available', () {
      final UpdateSnapshot snapshot = UpdateSnapshot.upToDate(
        autoCheckEnabled: false,
        currentVersion: '1.0.13',
        lastCheckedMs: 42,
      );

      expect(snapshot.status, UpdateStatus.upToDate);
      expect(snapshot.updateAvailable, isFalse);
      expect(snapshot.latestVersion, isNull);
      expect(snapshot.toJson()['autoCheckEnabled'], false);
    });

    test('downloading keeps the update available and reports progress', () {
      final UpdateSnapshot snapshot = UpdateSnapshot.downloading(
        autoCheckEnabled: true,
        currentVersion: '1.0.13',
        latestVersion: '1.0.14',
        progress: 0.5,
      );

      expect(snapshot.status, UpdateStatus.downloading);
      expect(snapshot.updateAvailable, isTrue);
      expect(snapshot.downloadProgress, 0.5);
      expect(snapshot.toJson()['downloadProgress'], 0.5);
    });

    test('error carries the message and is not an available update', () {
      final UpdateSnapshot snapshot = UpdateSnapshot.error(
        autoCheckEnabled: true,
        currentVersion: '1.0.13',
        message: 'network unreachable',
      );

      expect(snapshot.status, UpdateStatus.error);
      expect(snapshot.updateAvailable, isFalse);
      expect(snapshot.errorMessage, 'network unreachable');
      expect(snapshot.toJson()['errorMessage'], 'network unreachable');
    });

    test('copyWith only overrides the requested field', () {
      final UpdateSnapshot original = UpdateSnapshot.available(
        autoCheckEnabled: true,
        currentVersion: '1.0.13',
        latestVersion: '1.0.14',
        lastCheckedMs: 99,
      );

      final UpdateSnapshot toggled = original.copyWith(autoCheckEnabled: false);

      expect(toggled.autoCheckEnabled, isFalse);
      expect(toggled.status, UpdateStatus.updateAvailable);
      expect(toggled.latestVersion, '1.0.14');
      expect(toggled.lastCheckedMs, 99);
    });
  });
}
