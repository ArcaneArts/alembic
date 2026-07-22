import 'package:alembic/core/legacy_data_migrator.dart';

class BootContext {
  static final BootContext instance = BootContext._();

  String configPath = '';
  MigrationReport? migrationReport;
  int hiveEntries = 0;

  BootContext._();

  void reset() {
    configPath = '';
    migrationReport = null;
    hiveEntries = 0;
  }
}
