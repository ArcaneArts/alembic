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
}
