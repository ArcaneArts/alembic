import 'package:alembic/main.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_svg/flutter_svg.dart';

Future<void> showAboutAlembicDialog(BuildContext context) {
  return m.showDialog<void>(
    context: context,
    builder: (dialogContext) => AlembicDialogCard(
      title: 'Alembic',
      description: 'GitHub repository manager for your desktop.',
      actions: <Widget>[
        AlembicToolbarButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          label: 'Close',
          prominent: true,
        ),
      ],
      children: const <Widget>[
        _AboutAlembicContent(),
      ],
    ),
  );
}

class _AboutAlembicContent extends StatelessWidget {
  const _AboutAlembicContent();

  String get _versionLine {
    String build = packageInfo.buildNumber.trim();
    if (build.isEmpty) {
      return 'Version ${packageInfo.version}';
    }
    return 'Version ${packageInfo.version} (build $build)';
  }

  String get _copyrightLine =>
      'Copyright ${DateTime.now().year} Arcane Arts. All rights reserved.';

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SvgPicture.asset(
          'assets/icon.svg',
          width: 48,
          height: 48,
        ),
        const Gap(AlembicShadcnTokens.gapLg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _versionLine,
                style: theme.typography.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(AlembicShadcnTokens.gapXs),
              Text(
                _copyrightLine,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
