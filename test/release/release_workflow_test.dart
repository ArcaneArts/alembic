import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('desktop ci does not cache generated native build products', () async {
    String workflow = await File(
      p.join('.github', 'workflows', 'desktop-ci.yml'),
    ).readAsString();

    expect(workflow, isNot(contains('build/macos')));
    expect(workflow, isNot(contains('build/windows')));
    expect(workflow, isNot(contains('build/native_assets')));
  });

  test('desktop ci publishes main builds to the updater release', () async {
    String workflow = await File(
      p.join('.github', 'workflows', 'desktop-ci.yml'),
    ).readAsString();

    expect(workflow, contains('Publish latest updater release'));
    expect(workflow, contains('runs-on: windows-2022'));
    expect(workflow, isNot(contains('runs-on: windows-latest')));
    expect(workflow, contains('--tag latest'));
    expect(workflow, contains(r'--build-id "$GITHUB_SHA"'));
    expect(workflow, contains(r'gh release create "$tag"'));
    expect(workflow, contains(r'gh release edit "$tag"'));
  });

  test('macOS release script rebuilds native asset outputs from clean state',
      () async {
    String script = await File(
      p.join('scripts', 'release', 'build_macos.sh'),
    ).readAsString();

    expect(script, contains(r'rm -rf "$ROOT/build/macos"'));
    expect(script, contains(r'"$ROOT/build/native_assets/macos"'));
    expect(script, contains('--config-only --no-pub'));
    expect(script, contains('ALEMBIC_BUILD_ID'));
    expect(script, contains('Native assets after failed macOS build:'));
  });

  test('Windows release script packages installer with Inno Setup', () async {
    String script = await File(
      p.join('scripts', 'release', 'build_windows.ps1'),
    ).readAsString();

    expect(script, contains('Get-InnoSetupCompiler'));
    expect(script, contains('ISCC.exe'));
    expect(
        script, contains('DefaultDirName={localappdata}\\Programs\\Alembic'));
    expect(script, contains(r'OutputBaseFilename=$OutputBaseName'));
    expect(script, contains('AppId={{8A7D6F09-7F5C-4E41-8B39-A01A87E78D41}'));
    expect(script, isNot(contains('flutter_distributor')));
    expect(script, isNot(contains('make_config.yaml')));
  });

  test('local release shortcuts use shared release scripts', () async {
    String pubspec = await File('pubspec.yaml').readAsString();

    expect(pubspec, contains('distrib: bash scripts/release/build_macos.sh'));
    expect(
      pubspec,
      contains(
        'distrib_windows: powershell -NoProfile -ExecutionPolicy Bypass '
        '-File scripts/release/build_windows.ps1',
      ),
    );
    expect(pubspec, isNot(contains('flutter_distributor')));
  });

  test('Flutter release assets are explicitly listed', () async {
    String pubspec = await File('pubspec.yaml').readAsString();

    expect(
        pubspec, isNot(contains(RegExp(r'^    - assets/$', multiLine: true))));
    expect(pubspec, contains('    - assets/app_icon.ico'));
    expect(pubspec, contains('    - assets/icon.svg'));
    expect(pubspec, contains('    - assets/launcher.png'));
    expect(pubspec, contains('    - assets/login.svg'));
    expect(pubspec, contains('    - assets/tray.png'));
    expect(pubspec, isNot(contains('.pem')));
    expect(File('assets/alembictool.2024-08-06.private-key.pem').existsSync(),
        isFalse);
  });
}
