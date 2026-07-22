import 'package:alembic/screen/home/home_view_filters.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;
import 'package:window_manager/window_manager.dart';

class HomeWindowDragSurface extends StatelessWidget {
  final Widget child;

  const HomeWindowDragSurface({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        child: child,
      );
}

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
              HomeWindowDragSurface(
                child: SizedBox(
                  height: 34,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: _SearchField(
                          searchController: searchController,
                          onSearchChanged: onSearchChanged,
                        ),
                      ),
                      const Gap(AlembicShadcnTokens.gapSm),
                      _SortSelect(
                        filters: filters,
                        archiveEnabled: archiveEnabled,
                        onSortSelected: onSortSelected,
                      ),
                      if (owners.length > 1) ...<Widget>[
                        const Gap(AlembicShadcnTokens.gapSm),
                        _OwnerSelect(
                          filters: filters,
                          owners: owners,
                          onOwnerSelected: onOwnerSelected,
                        ),
                      ],
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
              const Gap(10),
              HomeStatLine(
                filters: filters,
                stats: stats,
                archiveEnabled: archiveEnabled,
                onStateFilterSelected: onStateFilterSelected,
                onSortSelected: onSortSelected,
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

class _SearchField extends StatelessWidget {
  final m.TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  const _SearchField({
    required this.searchController,
    required this.onSearchChanged,
  });

  void _clearSearch() {
    searchController.clear();
    onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) =>
      m.ValueListenableBuilder<m.TextEditingValue>(
        valueListenable: searchController,
        builder: (context, value, _) => _CompactSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
          showClear: value.text.isNotEmpty,
          onClear: _clearSearch,
        ),
      );
}

class _SortSelect extends StatelessWidget {
  final HomeFilterState filters;
  final bool archiveEnabled;
  final ValueChanged<HomeSortMode> onSortSelected;

  const _SortSelect({
    required this.filters,
    required this.archiveEnabled,
    required this.onSortSelected,
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

  @override
  Widget build(BuildContext context) => AlembicSelect<HomeSortMode>(
        value: archiveEnabled || filters.sortMode != HomeSortMode.archiveSoon
            ? filters.sortMode
            : HomeSortMode.attention,
        options: _sortOptions,
        onChanged: onSortSelected,
        leadingIcon: m.Icons.sort,
        compact: true,
      );
}

class _OwnerSelect extends StatelessWidget {
  static const String allOwnersValue = '__all__';

  final HomeFilterState filters;
  final List<String> owners;
  final ValueChanged<String?> onOwnerSelected;

  const _OwnerSelect({
    required this.filters,
    required this.owners,
    required this.onOwnerSelected,
  });

  List<AlembicDropdownOption<String>> get _ownerOptions =>
      <AlembicDropdownOption<String>>[
        const AlembicDropdownOption<String>(
          value: allOwnersValue,
          label: 'All owners',
        ),
        for (String owner in owners)
          AlembicDropdownOption<String>(value: owner, label: owner),
      ];

  @override
  Widget build(BuildContext context) {
    String? ownerFilter = filters.ownerFilter;
    String value = ownerFilter != null && owners.contains(ownerFilter)
        ? ownerFilter
        : allOwnersValue;
    return AlembicSelect<String>(
      value: value,
      options: _ownerOptions,
      onChanged: (selected) =>
          onOwnerSelected(selected == allOwnersValue ? null : selected),
      leadingIcon: m.Icons.apartment_outlined,
      compact: true,
    );
  }
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
            leadingIcon: m.Icons.refresh,
            busy: refreshing,
            iconOnly: true,
            compact: true,
            tooltip: 'Refresh repositories',
            onPressed: refreshing ? null : onRefresh,
          ),
          const Gap(AlembicShadcnTokens.gapSm),
          AlembicToolbarButton(
            label: 'Clone',
            leadingIcon: m.Icons.add_link,
            onPressed: onCloneLink,
            prominent: true,
            compact: true,
            iconOnly: collapseToIcons,
            tooltip: 'Clone a repository from a link',
          ),
          const Gap(AlembicShadcnTokens.gapSm),
          AlembicToolbarButton(
            label: 'Import',
            leadingIcon: m.Icons.download_outlined,
            onPressed: onImport,
            compact: true,
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
            compact: true,
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

class HomeStatLine extends StatelessWidget {
  static const m.Color activeColor = m.Color(0xFF16A34A);
  static const m.Color archivedColor = m.Color(0xFF2563EB);
  static const m.Color syncingColor = m.Color(0xFFE8930C);
  static const m.Color privateColor = m.Color(0xFF9333EA);
  static const m.Color dueSoonColor = m.Color(0xFFE8930C);

  final HomeFilterState filters;
  final HomeStats stats;
  final bool archiveEnabled;
  final ValueChanged<HomeStateFilter> onStateFilterSelected;
  final ValueChanged<HomeSortMode> onSortSelected;

  const HomeStatLine({
    super.key,
    required this.filters,
    required this.stats,
    required this.archiveEnabled,
    required this.onStateFilterSelected,
    required this.onSortSelected,
  });

  bool _selected(HomeStateFilter filter) => filters.stateFilter == filter;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 22,
      child: Center(
        child: m.SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _StatSegment(
                label: 'All',
                value: stats.total,
                color: theme.colorScheme.primary,
                tooltip: 'All repositories across your accounts',
                selected: _selected(HomeStateFilter.all),
                onPressed: () => onStateFilterSelected(HomeStateFilter.all),
              ),
              const _StatSeparator(),
              _StatSegment(
                label: 'Active',
                value: stats.active,
                color: activeColor,
                tooltip: 'Cloned into the local workspace',
                selected: _selected(HomeStateFilter.active),
                onPressed: () => onStateFilterSelected(HomeStateFilter.active),
              ),
              const _StatSeparator(),
              _StatSegment(
                label: 'Archived',
                value: stats.archived,
                color: archivedColor,
                tooltip: 'Compressed into Alembic archive storage',
                selected: _selected(HomeStateFilter.archived),
                onPressed: () =>
                    onStateFilterSelected(HomeStateFilter.archived),
              ),
              const _StatSeparator(),
              _StatSegment(
                label: 'Cloud',
                value: stats.cloud,
                color: theme.colorScheme.mutedForeground,
                tooltip: 'On GitHub only, not on this device',
                selected: _selected(HomeStateFilter.cloud),
                onPressed: () => onStateFilterSelected(HomeStateFilter.cloud),
              ),
              const _StatSeparator(),
              _StatSegment(
                label: 'Syncing',
                value: stats.syncing,
                color: syncingColor,
                tooltip:
                    stats.syncing > 0 ? 'Jobs in flight' : 'No active jobs',
                selected: _selected(HomeStateFilter.syncing),
                onPressed: () => onStateFilterSelected(HomeStateFilter.syncing),
              ),
              const _StatSeparator(),
              _StatSegment(
                label: 'Private (${stats.forks} forks)',
                value: stats.private,
                color: privateColor,
                tooltip:
                    '${stats.private} private repositories, ${stats.forks} forks',
                selected: false,
                onPressed: null,
              ),
              if (!archiveEnabled) ...<Widget>[
                const _StatSeparator(),
                const _StatTextSegment(
                  label: 'Archive off',
                  tooltip: 'Automatic archiving is disabled',
                ),
              ] else if (stats.archiveDueSoon > 0) ...<Widget>[
                const _StatSeparator(),
                _StatSegment(
                  label: 'due soon',
                  value: stats.archiveDueSoon,
                  color: dueSoonColor,
                  tooltip:
                      'Archiving within ${HomeStats.archiveDueSoonDays} days - click to sort',
                  selected: false,
                  onPressed: () => onSortSelected(HomeSortMode.archiveSoon),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatSeparator extends StatelessWidget {
  const _StatSeparator();

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: theme.typography.xSmall.copyWith(
          color: m.Color.alphaBlend(
            theme.colorScheme.mutedForeground.withValues(alpha: 0.45),
            theme.colorScheme.background,
          ),
        ),
      ),
    );
  }
}

class _StatTextSegment extends StatelessWidget {
  final String label;
  final String tooltip;

  const _StatTextSegment({
    required this.label,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color dimColor = m.Color.alphaBlend(
      theme.colorScheme.mutedForeground.withValues(alpha: 0.55),
      theme.colorScheme.background,
    );
    return m.Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: theme.typography.xSmall.copyWith(
                color: dimColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Gap(2),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _StatSegment extends StatefulWidget {
  final String label;
  final int value;
  final Color color;
  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;

  const _StatSegment({
    required this.label,
    required this.value,
    required this.color,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  @override
  State<_StatSegment> createState() => _StatSegmentState();
}

class _StatSegmentState extends State<_StatSegment> {
  bool _hovered = false;

  Color _dimColor(ThemeData theme) => m.Color.alphaBlend(
        theme.colorScheme.mutedForeground.withValues(alpha: 0.55),
        theme.colorScheme.background,
      );

  Color _countColor(ThemeData theme) =>
      widget.value == 0 ? _dimColor(theme) : widget.color;

  Color _labelColor(ThemeData theme) {
    if (widget.selected) {
      return theme.colorScheme.foreground;
    }
    if (_hovered && widget.onPressed != null) {
      return theme.colorScheme.foreground;
    }
    return widget.value == 0
        ? _dimColor(theme)
        : theme.colorScheme.mutedForeground;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '${widget.value}',
                        style: theme.typography.xSmall.copyWith(
                          color: _countColor(theme),
                          fontWeight: FontWeight.w700,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      const Gap(3),
                      Text(
                        widget.label,
                        style: theme.typography.xSmall.copyWith(
                          color: _labelColor(theme),
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Gap(2),
                  SizedBox(
                    height: 2,
                    child: widget.selected
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.foreground,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactSearchField extends StatelessWidget {
  final m.TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool showClear;
  final VoidCallback onClear;

  const _CompactSearchField({
    required this.controller,
    required this.onChanged,
    required this.showClear,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    m.OutlineInputBorder border = m.OutlineInputBorder(
      borderRadius: m.BorderRadius.circular(AlembicShadcnTokens.controlRadius),
      borderSide: m.BorderSide(color: theme.colorScheme.border),
      gapPadding: 0,
    );
    m.OutlineInputBorder activeBorder = m.OutlineInputBorder(
      borderRadius: m.BorderRadius.circular(AlembicShadcnTokens.controlRadius),
      borderSide: m.BorderSide(color: theme.colorScheme.ring),
      gapPadding: 0,
    );
    return SizedBox(
      height: 32,
      child: m.TextField(
        key: const m.ValueKey<String>('home-search-field'),
        controller: controller,
        maxLines: 1,
        onChanged: onChanged,
        onSubmitted: onChanged,
        style: theme.typography.small.copyWith(
          color: theme.colorScheme.foreground,
        ),
        cursorColor: theme.colorScheme.foreground,
        textAlignVertical: m.TextAlignVertical.center,
        decoration: m.InputDecoration(
          hintText: 'Search repositories...',
          hintStyle: theme.typography.small.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
          filled: true,
          fillColor: theme.colorScheme.card,
          isDense: true,
          contentPadding: const m.EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          suffixIcon: showClear
              ? _SearchClearButton(onPressed: onClear)
              : m.Icon(
                  m.Icons.search,
                  size: 14,
                  color: theme.colorScheme.mutedForeground,
                ),
          suffixIconConstraints: const m.BoxConstraints(
            minWidth: 30,
            minHeight: 32,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: activeBorder,
          disabledBorder: border,
          errorBorder: border,
          focusedErrorBorder: activeBorder,
        ),
      ),
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
            child: m.Icon(
              m.Icons.close,
              size: 14,
              color: Theme.of(context).colorScheme.mutedForeground,
            ),
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
            padding: const EdgeInsets.only(top: AlembicShadcnTokens.gapSm),
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
