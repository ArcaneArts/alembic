import 'package:alembic/main.dart';
import 'package:alembic/screen/home/home_view_filters.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;
import 'package:window_manager/window_manager.dart';

class HomeTopBar extends StatelessWidget {
  final HomeFilterState filters;
  final HomeStats stats;
  final List<String> owners;
  final bool archiveEnabled;
  final bool refreshing;
  final bool updateAvailable;
  final BehaviorSubject<double?> progress;
  final BehaviorSubject<String?> progressLabel;
  final m.TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<HomeStateFilter> onStateFilterSelected;
  final ValueChanged<HomeSortMode> onSortSelected;
  final ValueChanged<String?> onOwnerSelected;
  final VoidCallback onRefresh;
  final VoidCallback onCloneLink;
  final VoidCallback onImport;
  final VoidCallback onOpenSettings;

  const HomeTopBar({
    super.key,
    required this.filters,
    required this.stats,
    required this.owners,
    required this.archiveEnabled,
    required this.refreshing,
    required this.updateAvailable,
    required this.progress,
    required this.progressLabel,
    required this.searchController,
    required this.onSearchChanged,
    required this.onStateFilterSelected,
    required this.onSortSelected,
    required this.onOwnerSelected,
    required this.onRefresh,
    required this.onCloneLink,
    required this.onImport,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          bool collapseToIcons = constraints.maxWidth < 640;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DragToMoveArea(
                child: SizedBox(
                  height: 56,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const Expanded(child: _BrandLockup()),
                      const Gap(AlembicShadcnTokens.gapMd),
                      _TopBarActions(
                        collapseToIcons: collapseToIcons,
                        refreshing: refreshing,
                        updateAvailable: updateAvailable,
                        onRefresh: onRefresh,
                        onCloneLink: onCloneLink,
                        onImport: onImport,
                        onOpenSettings: onOpenSettings,
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(AlembicShadcnTokens.gapLg),
              _SearchAndSortRow(
                filters: filters,
                owners: owners,
                archiveEnabled: archiveEnabled,
                narrow: collapseToIcons,
                searchController: searchController,
                onSearchChanged: onSearchChanged,
                onSortSelected: onSortSelected,
                onOwnerSelected: onOwnerSelected,
              ),
              const Gap(AlembicShadcnTokens.gapLg),
              HomeStatFilterRow(
                filters: filters,
                stats: stats,
                onStateFilterSelected: onStateFilterSelected,
              ),
              _HomeTopBarProgress(
                progress: progress,
                progressLabel: progressLabel,
              ),
            ],
          );
        },
      );
}

class _TopBarActions extends StatelessWidget {
  final bool collapseToIcons;
  final bool refreshing;
  final bool updateAvailable;
  final VoidCallback onRefresh;
  final VoidCallback onCloneLink;
  final VoidCallback onImport;
  final VoidCallback onOpenSettings;

  const _TopBarActions({
    required this.collapseToIcons,
    required this.refreshing,
    required this.updateAvailable,
    required this.onRefresh,
    required this.onCloneLink,
    required this.onImport,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          AlembicToolbarButton(
            label: 'Refresh',
            leadingIcon: refreshing ? null : m.Icons.refresh,
            busy: refreshing,
            iconOnly: true,
            tooltip: 'Refresh repositories',
            onPressed: refreshing ? null : onRefresh,
          ),
          const Gap(AlembicShadcnTokens.gapSm),
          AlembicToolbarButton(
            label: 'Clone',
            leadingIcon: m.Icons.add_link,
            onPressed: onCloneLink,
            prominent: true,
            iconOnly: collapseToIcons,
            tooltip: 'Clone repository link',
          ),
          const Gap(AlembicShadcnTokens.gapSm),
          AlembicToolbarButton(
            label: 'Import',
            leadingIcon: m.Icons.download_outlined,
            onPressed: onImport,
            iconOnly: collapseToIcons,
            tooltip: 'Import repositories from disk',
          ),
          const Gap(AlembicShadcnTokens.gapSm),
          _SettingsButton(
            collapseToIcons: collapseToIcons,
            updateAvailable: updateAvailable,
            onOpenSettings: onOpenSettings,
          ),
        ],
      );
}

class _SettingsButton extends StatelessWidget {
  static const m.Color updateDotColor = m.Color(0xFFF5C421);

  final bool collapseToIcons;
  final bool updateAvailable;
  final VoidCallback onOpenSettings;

  const _SettingsButton({
    required this.collapseToIcons,
    required this.updateAvailable,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          AlembicToolbarButton(
            label: 'Settings',
            leadingIcon: m.Icons.tune,
            onPressed: onOpenSettings,
            iconOnly: collapseToIcons,
            tooltip: updateAvailable
                ? 'An update is available - open Settings'
                : 'Settings',
          ),
          if (updateAvailable)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: updateDotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      );
}

class HomeStatFilterRow extends StatelessWidget {
  static const m.Color activeColor = m.Color(0xFF16A34A);
  static const m.Color archivedColor = m.Color(0xFF2563EB);
  static const m.Color syncingColor = m.Color(0xFFE8930C);
  static const m.Color privateColor = m.Color(0xFF9333EA);

  final HomeFilterState filters;
  final HomeStats stats;
  final ValueChanged<HomeStateFilter> onStateFilterSelected;

  const HomeStatFilterRow({
    super.key,
    required this.filters,
    required this.stats,
    required this.onStateFilterSelected,
  });

  bool _selected(HomeStateFilter filter) => filters.stateFilter == filter;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 32,
      child: m.SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _StatFilterChip(
              label: 'All',
              value: stats.total,
              color: theme.colorScheme.primary,
              tooltip: 'All repositories across your accounts',
              selected: _selected(HomeStateFilter.all),
              onPressed: () => onStateFilterSelected(HomeStateFilter.all),
            ),
            const Gap(AlembicShadcnTokens.gapSm),
            _StatFilterChip(
              label: 'Active',
              value: stats.active,
              color: activeColor,
              tooltip: 'Cloned into the local workspace',
              selected: _selected(HomeStateFilter.active),
              onPressed: () => onStateFilterSelected(HomeStateFilter.active),
            ),
            const Gap(AlembicShadcnTokens.gapSm),
            _StatFilterChip(
              label: 'Archived',
              value: stats.archived,
              color: archivedColor,
              tooltip: 'Compressed into Alembic archive storage',
              selected: _selected(HomeStateFilter.archived),
              onPressed: () => onStateFilterSelected(HomeStateFilter.archived),
            ),
            const Gap(AlembicShadcnTokens.gapSm),
            _StatFilterChip(
              label: 'Cloud',
              value: stats.cloud,
              color: theme.colorScheme.mutedForeground,
              tooltip: 'On GitHub only, not on this device',
              selected: _selected(HomeStateFilter.cloud),
              onPressed: () => onStateFilterSelected(HomeStateFilter.cloud),
            ),
            const Gap(AlembicShadcnTokens.gapSm),
            _StatFilterChip(
              label: 'Syncing',
              value: stats.syncing,
              color: syncingColor,
              tooltip: stats.syncing > 0 ? 'Jobs in flight' : 'No active jobs',
              selected: _selected(HomeStateFilter.syncing),
              onPressed: () => onStateFilterSelected(HomeStateFilter.syncing),
            ),
            const Gap(AlembicShadcnTokens.gapSm),
            _StatFilterChip(
              label: 'Private',
              value: stats.private,
              color: privateColor,
              tooltip:
                  '${stats.private} private repositories, ${stats.forks} forks',
              selected: false,
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatFilterChip extends StatefulWidget {
  final String label;
  final int value;
  final Color color;
  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;

  const _StatFilterChip({
    required this.label,
    required this.value,
    required this.color,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  @override
  State<_StatFilterChip> createState() => _StatFilterChipState();
}

class _StatFilterChipState extends State<_StatFilterChip> {
  bool _hovered = false;

  Color _background(ThemeData theme) {
    if (widget.selected) {
      return theme.colorScheme.card;
    }
    if (_hovered && widget.onPressed != null) {
      return m.Color.alphaBlend(
        theme.colorScheme.secondary.withValues(alpha: 0.6),
        theme.colorScheme.background,
      );
    }
    return theme.colorScheme.background;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    bool dimmed = widget.value == 0;
    Color countColor =
        dimmed ? theme.colorScheme.mutedForeground : widget.color;
    Color labelColor = widget.selected
        ? theme.colorScheme.foreground
        : theme.colorScheme.mutedForeground;
    Color borderColor =
        widget.selected ? theme.colorScheme.ring : theme.colorScheme.border;
    return m.Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: widget.onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _background(theme),
              borderRadius:
                  BorderRadius.circular(AlembicShadcnTokens.controlRadius),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  '${widget.value}',
                  style: theme.typography.small.copyWith(
                    color: countColor,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const Gap(6),
                Text(
                  widget.label,
                  style: theme.typography.xSmall.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchAndSortRow extends StatelessWidget {
  static const String allOwnersValue = '__all__';

  final HomeFilterState filters;
  final List<String> owners;
  final bool archiveEnabled;
  final bool narrow;
  final m.TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<HomeSortMode> onSortSelected;
  final ValueChanged<String?> onOwnerSelected;

  const _SearchAndSortRow({
    required this.filters,
    required this.owners,
    required this.archiveEnabled,
    required this.narrow,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSortSelected,
    required this.onOwnerSelected,
  });

  List<AlembicDropdownOption<HomeSortMode>> get _sortOptions =>
      <AlembicDropdownOption<HomeSortMode>>[
        for (HomeSortMode mode in HomeSortMode.values)
          if (mode != HomeSortMode.archiveSoon || archiveEnabled)
            AlembicDropdownOption<HomeSortMode>(
              value: mode,
              label: mode.label,
            ),
      ];

  List<AlembicDropdownOption<String>> get _ownerOptions =>
      <AlembicDropdownOption<String>>[
        const AlembicDropdownOption<String>(
          value: allOwnersValue,
          label: 'All owners',
        ),
        for (String owner in owners)
          AlembicDropdownOption<String>(value: owner, label: owner),
      ];

  void _clearSearch() {
    searchController.clear();
    onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    Widget searchField = m.ValueListenableBuilder<m.TextEditingValue>(
      valueListenable: searchController,
      builder: (context, value, _) => AlembicTextInput(
        key: const m.ValueKey<String>('home-search-field'),
        controller: searchController,
        placeholder: 'Search repositories...',
        onChanged: onSearchChanged,
        onSubmitted: onSearchChanged,
        trailing: value.text.isEmpty
            ? null
            : _SearchClearButton(onPressed: _clearSearch),
      ),
    );
    Widget sortSelect = AlembicSelect<HomeSortMode>(
      value: archiveEnabled || filters.sortMode != HomeSortMode.archiveSoon
          ? filters.sortMode
          : HomeSortMode.attention,
      options: _sortOptions,
      onChanged: onSortSelected,
      leadingIcon: m.Icons.sort,
      compact: false,
    );
    Widget? ownerSelect = owners.length > 1
        ? AlembicSelect<String>(
            value: filters.ownerFilter ?? allOwnersValue,
            options: _ownerOptions,
            onChanged: (value) =>
                onOwnerSelected(value == allOwnersValue ? null : value),
            leadingIcon: m.Icons.apartment_outlined,
            compact: false,
          )
        : null;

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          searchField,
          const Gap(AlembicShadcnTokens.gapSm),
          sortSelect,
          if (ownerSelect != null) ...<Widget>[
            const Gap(AlembicShadcnTokens.gapSm),
            ownerSelect,
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(child: searchField),
        const Gap(AlembicShadcnTokens.gapSm),
        sortSelect,
        if (ownerSelect != null) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapSm),
          ownerSelect,
        ],
      ],
    );
  }
}

class _SearchClearButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SearchClearButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => m.Tooltip(
        message: 'Clear search',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: const m.Icon(m.Icons.close),
          ),
        ),
      );
}

class _HomeTopBarProgress extends StatelessWidget {
  final BehaviorSubject<double?> progress;
  final BehaviorSubject<String?> progressLabel;

  const _HomeTopBarProgress({
    required this.progress,
    required this.progressLabel,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<double?>(
        stream: progress.stream,
        initialData: progress.valueOrNull,
        builder: (context, snapshot) {
          double? value = snapshot.data;
          if (value == null) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: AlembicShadcnTokens.gapMd),
            child: _HomeHeaderProgressBar(
              value: value,
              label: progressLabel.valueOrNull ?? 'Working',
            ),
          );
        },
      );
}

class _HomeHeaderProgressBar extends StatelessWidget {
  final double value;
  final String label;

  const _HomeHeaderProgressBar({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    int percent = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value == 0 ? 'Working' : '$percent%',
              style: theme.typography.xSmall.copyWith(
                color: theme.colorScheme.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const Gap(AlembicShadcnTokens.gapXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
          child: AlembicProgressBar(
            value: value == 0 ? null : value,
            height: 3,
          ),
        ),
      ],
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const _BrandGlyph(),
        const Gap(AlembicShadcnTokens.gapMd),
        Flexible(
          child: Text(
            'Alembic',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.large.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Gap(AlembicShadcnTokens.gapSm),
        Text(
          'v${packageInfo.version}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.small.copyWith(
            color: theme.colorScheme.mutedForeground,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _BrandGlyph extends StatelessWidget {
  const _BrandGlyph();

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        border: Border.all(color: theme.colorScheme.border),
      ),
      alignment: Alignment.center,
      child: m.Icon(
        m.Icons.auto_awesome_motion_outlined,
        size: 15,
        color: theme.colorScheme.foreground,
      ),
    );
  }
}
