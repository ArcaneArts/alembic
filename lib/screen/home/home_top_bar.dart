import 'package:alembic/main.dart';
import 'package:alembic/presentation/home_view_state.dart';
import 'package:alembic/screen/home/home_actions.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class HomeTopBar extends StatelessWidget {
  final HomeSelectionState selection;
  final BehaviorSubject<double?> progress;
  final m.TextEditingController searchController;
  final List<String> organizationLogins;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<HomeTab> onTabSelected;
  final ValueChanged<OrganizationFilter> onOrganizationFilterSelected;
  final VoidCallback onOpenSettings;
  final VoidCallback onImportRepository;
  final List<HomeTopMenuAction> topMenuActions;
  final ValueChanged<HomeTopMenuAction> onTopMenuSelected;

  const HomeTopBar({
    super.key,
    required this.selection,
    required this.progress,
    required this.searchController,
    required this.organizationLogins,
    required this.onSearchChanged,
    required this.onTabSelected,
    required this.onOrganizationFilterSelected,
    required this.onOpenSettings,
    required this.onImportRepository,
    required this.topMenuActions,
    required this.onTopMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    List<AlembicDropdownOption<HomeTopMenuAction>> menuOptions =
        _buildMenuOptions();
    List<AlembicDropdownOption<String>> organizationOptions =
        _buildOrganizationOptions();
    String selectedOrganization =
        selection.organizationFilter.organizationLogin ?? '__all__';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        bool collapseToIcons = constraints.maxWidth < 420;
        Widget navigation = _buildTabs(collapseToIcons);
        Widget actions = _buildActions(
          collapseToIcons: collapseToIcons,
          menuOptions: menuOptions,
        );
        Widget searchRow = _buildSearchRow(
          selectedOrganization: selectedOrganization,
          organizationOptions: organizationOptions,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const Expanded(
                  child: _RailBrand(compact: true),
                ),
                const Gap(AlembicShadcnTokens.gapMd),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actions,
                  ),
                ),
              ],
            ),
            const Gap(AlembicShadcnTokens.gapMd),
            Align(
              alignment: Alignment.center,
              child: navigation,
            ),
            const Gap(AlembicShadcnTokens.gapMd),
            searchRow,
            _HomeTopBarProgress(progress: progress),
          ],
        );
      },
    );
  }

  List<AlembicDropdownOption<HomeTopMenuAction>> _buildMenuOptions() =>
      <AlembicDropdownOption<HomeTopMenuAction>>[
        for (HomeTopMenuAction action in topMenuActions)
          AlembicDropdownOption<HomeTopMenuAction>(
            value: action,
            label: action.label,
            icon: action.icon,
          ),
      ];

  List<AlembicDropdownOption<String>> _buildOrganizationOptions() =>
      <AlembicDropdownOption<String>>[
        const AlembicDropdownOption<String>(
          value: '__all__',
          label: 'All organizations',
        ),
        for (String organization in organizationLogins)
          AlembicDropdownOption<String>(
            value: organization,
            label: organization,
          ),
      ];

  Widget _buildTabs(bool collapseToIcons) => AlembicTabs<HomeTab>(
        value: selection.tab,
        onChanged: onTabSelected,
        collapsed: collapseToIcons,
        items: const <AlembicNavigationItem<HomeTab>>[
          AlembicNavigationItem<HomeTab>(
            value: HomeTab.active,
            label: 'Local',
            icon: m.Icons.folder_open,
            tooltip: 'Local',
          ),
          AlembicNavigationItem<HomeTab>(
            value: HomeTab.personal,
            label: 'Personal',
            icon: m.Icons.person_outline,
            tooltip: 'Personal',
          ),
          AlembicNavigationItem<HomeTab>(
            value: HomeTab.organizations,
            label: 'Teams',
            icon: m.Icons.apartment_outlined,
            tooltip: 'Teams',
          ),
          AlembicNavigationItem<HomeTab>(
            value: HomeTab.archiveMaster,
            label: 'Archive',
            icon: m.Icons.cloud_sync_outlined,
            tooltip: 'Archive Master',
          ),
        ],
      );

  Widget _buildActions({
    required bool collapseToIcons,
    required List<AlembicDropdownOption<HomeTopMenuAction>> menuOptions,
  }) =>
      Wrap(
        spacing: AlembicShadcnTokens.gapSm,
        runSpacing: AlembicShadcnTokens.gapSm,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: collapseToIcons
                ? AlembicShadcnTokens.commandIconWidth
                : AlembicShadcnTokens.commandButtonWidth,
            child: AlembicToolbarButton(
              label: 'Clone',
              leadingIcon: m.Icons.add_link,
              onPressed: onImportRepository,
              prominent: true,
              iconOnly: collapseToIcons,
              tooltip: 'Clone repository',
            ),
          ),
          SizedBox(
            width: AlembicShadcnTokens.commandIconWidth,
            child: AlembicToolbarButton(
              label: 'Settings',
              leadingIcon: m.Icons.tune,
              onPressed: onOpenSettings,
              iconOnly: true,
              tooltip: 'Settings',
            ),
          ),
          SizedBox(
            width: AlembicShadcnTokens.commandIconWidth,
            child: AlembicOverflowMenu<HomeTopMenuAction>(
              label: 'More options',
              items: menuOptions,
              onSelected: onTopMenuSelected,
            ),
          ),
        ],
      );

  Widget _buildSearchRow({
    required String selectedOrganization,
    required List<AlembicDropdownOption<String>> organizationOptions,
  }) {
    Widget searchField = AlembicTextInput(
      controller: searchController,
      placeholder: 'Search repositories',
      leading: const m.Icon(m.Icons.search, size: 16),
      onChanged: onSearchChanged,
    );
    if (selection.tab != HomeTab.organizations) {
      return searchField;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        searchField,
        const Gap(AlembicShadcnTokens.gapSm),
        AlembicSelect<String>(
          value: selectedOrganization,
          options: organizationOptions,
          onChanged: (String value) {
            if (value == '__all__') {
              onOrganizationFilterSelected(const OrganizationFilter.all());
              return;
            }
            onOrganizationFilterSelected(
              OrganizationFilter.organization(value),
            );
          },
          leadingIcon: m.Icons.apartment_outlined,
          compact: false,
        ),
      ],
    );
  }
}

class _HomeTopBarProgress extends StatelessWidget {
  final BehaviorSubject<double?> progress;

  const _HomeTopBarProgress({required this.progress});

  @override
  Widget build(BuildContext context) => StreamBuilder<double?>(
        stream: progress.stream,
        initialData: progress.valueOrNull,
        builder: (BuildContext context, AsyncSnapshot<double?> snapshot) {
          double? value = snapshot.data;
          if (value == null) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: AlembicShadcnTokens.gapMd),
            child: _HomeHeaderProgressBar(value: value),
          );
        },
      );
}

class _HomeHeaderProgressBar extends StatelessWidget {
  final double value;

  const _HomeHeaderProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
      child: m.LinearProgressIndicator(
        minHeight: 3,
        value: value == 0 ? null : value,
        backgroundColor: theme.colorScheme.secondary,
        valueColor: AlwaysStoppedAnimation<Color>(
          theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  final bool compact;

  const _RailBrand({required this.compact});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Text title = Text(
      'Alembic',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.small.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
    );
    Text version = Text(
      'v${packageInfo.version}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.xSmall.copyWith(
        color: theme.colorScheme.mutedForeground,
        fontWeight: FontWeight.w600,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _RailBrandGlyph(compact: true),
          const Gap(AlembicShadcnTokens.gapSm),
          Flexible(child: title),
          const Gap(AlembicShadcnTokens.gapSm),
          version,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _RailBrandGlyph(compact: compact),
        const Gap(AlembicShadcnTokens.gapMd),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              title,
              const Gap(2),
              Text(
                'Desktop workspace',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const Gap(AlembicShadcnTokens.gapMd),
        version,
      ],
    );
  }
}

class _RailBrandGlyph extends StatelessWidget {
  final bool compact;

  const _RailBrandGlyph({required this.compact});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Container(
      width: compact ? 30 : 34,
      height: compact ? 30 : 34,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        border: Border.all(color: theme.colorScheme.border),
      ),
      alignment: Alignment.center,
      child: m.Icon(
        m.Icons.auto_awesome_motion_outlined,
        size: compact ? 15 : 18,
        color: theme.colorScheme.foreground,
      ),
    );
  }
}
