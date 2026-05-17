import 'package:alembic/spike/legacy_data_migrator.dart';

class BootContext {
  BootContext._();

  static final BootContext instance = BootContext._();

  String configPath = '';
  MigrationReport? migrationReport;
  int hiveEntries = 0;

  void reset() {
    configPath = '';
    migrationReport = null;
    hiveEntries = 0;
  }
}
