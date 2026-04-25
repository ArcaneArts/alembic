import 'package:alembic/core/repository_auth.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class RepositoryAuthBadge extends StatelessWidget {
  final RepoAuthInfo info;
  final VoidCallback? onTap;
  final bool compact;

  const RepositoryAuthBadge({
    super.key,
    required this.info,
    required this.onTap,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final IconData icon = _iconFor(info.transport);
    final String label = info.badgeLabel;
    final AlembicBadgeTone tone = _toneFor(info);
    final String tooltip = _tooltipFor(info);
    final Widget body = _BadgeBody(
      icon: icon,
      label: label,
      tone: tone,
      compact: compact,
      theme: theme,
    );
    final Widget interactive = m.Material(
      color: m.Colors.transparent,
      child: m.InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
        child: body,
      ),
    );
    return m.Tooltip(
      message: tooltip,
      child: interactive,
    );
  }

  IconData _iconFor(RepoAuthTransport transport) => switch (transport) {
        RepoAuthTransport.httpsToken => m.Icons.vpn_key_outlined,
        RepoAuthTransport.httpsPublic => m.Icons.public,
        RepoAuthTransport.ssh => m.Icons.terminal,
        RepoAuthTransport.unknown => m.Icons.help_outline,
      };

  AlembicBadgeTone _toneFor(RepoAuthInfo info) {
    if (info.transport == RepoAuthTransport.httpsToken &&
        !info.tokenMatchesAccount &&
        info.isCloned) {
      return AlembicBadgeTone.destructive;
    }
    if (info.transport == RepoAuthTransport.httpsPublic) {
      return AlembicBadgeTone.outline;
    }
    if (info.transport == RepoAuthTransport.unknown) {
      return AlembicBadgeTone.outline;
    }
    return AlembicBadgeTone.secondary;
  }

  String _tooltipFor(RepoAuthInfo info) {
    final List<String> parts = <String>[];
    parts.add(info.detailLabel);
    final String? login = (info.accountLogin ?? '').trim().isEmpty
        ? null
        : info.accountLogin;
    if (login != null) {
      parts.add('@$login');
    }
    final String? remote = info.remoteUrl;
    if (remote != null && remote.isNotEmpty) {
      parts.add(_redactRemote(remote));
    }
    if (info.transport == RepoAuthTransport.httpsToken &&
        !info.tokenMatchesAccount &&
        info.isCloned) {
      parts.add('Token does not match any saved account.');
    }
    parts.add('Click to change');
    return parts.join('\n');
  }

  String _redactRemote(String url) {
    return url.replaceAllMapped(
      RegExp(r'https://([^@/:]+)@'),
      (Match _) => 'https://***@',
    );
  }
}

class _BadgeBody extends StatelessWidget {
  final IconData icon;
  final String label;
  final AlembicBadgeTone tone;
  final bool compact;
  final ThemeData theme;

  const _BadgeBody({
    required this.icon,
    required this.label,
    required this.tone,
    required this.compact,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final Color background = _backgroundFor(theme, tone);
    final Color foreground = _foregroundFor(theme, tone);
    final Color border = _borderFor(theme, tone);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          m.Icon(icon, size: 11, color: foreground),
          const Gap(4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xSmall.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _backgroundFor(ThemeData theme, AlembicBadgeTone tone) =>
      switch (tone) {
        AlembicBadgeTone.primary => m.Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.card,
          ),
        AlembicBadgeTone.secondary => theme.colorScheme.secondary,
        AlembicBadgeTone.outline => theme.colorScheme.card,
        AlembicBadgeTone.destructive =>
          theme.colorScheme.destructive.withValues(alpha: 0.16),
      };

  Color _foregroundFor(ThemeData theme, AlembicBadgeTone tone) =>
      switch (tone) {
        AlembicBadgeTone.primary => theme.colorScheme.foreground,
        AlembicBadgeTone.secondary => theme.colorScheme.foreground,
        AlembicBadgeTone.outline => theme.colorScheme.mutedForeground,
        AlembicBadgeTone.destructive => theme.colorScheme.destructive,
      };

  Color _borderFor(ThemeData theme, AlembicBadgeTone tone) => switch (tone) {
        AlembicBadgeTone.primary =>
          theme.colorScheme.primary.withValues(alpha: 0.2),
        AlembicBadgeTone.secondary => theme.colorScheme.border,
        AlembicBadgeTone.outline => theme.colorScheme.border,
        AlembicBadgeTone.destructive =>
          theme.colorScheme.destructive.withValues(alpha: 0.32),
      };
}
