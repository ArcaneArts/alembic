enum HomeTab {
  active,
  personal,
  organizations,
  archiveMaster,
}

enum OrganizationFilterKind {
  all,
  organization,
}

class OrganizationFilter {
  final OrganizationFilterKind kind;
  final String? organizationLogin;

  const OrganizationFilter.all()
      : kind = OrganizationFilterKind.all,
        organizationLogin = null;

  const OrganizationFilter.organization(String login)
      : kind = OrganizationFilterKind.organization,
        organizationLogin = login;

  bool get isAll => kind == OrganizationFilterKind.all;

  String get storageValue => organizationLogin ?? 'all';

  static OrganizationFilter fromStorageValue(String? value) {
    if (value == null || value == 'all' || value.trim().isEmpty) {
      return const OrganizationFilter.all();
    }
    return OrganizationFilter.organization(value);
  }
}

class HomeSelectionState {
  final HomeTab tab;
  final OrganizationFilter organizationFilter;

  const HomeSelectionState({
    required this.tab,
    required this.organizationFilter,
  });

  const HomeSelectionState.initial()
      : tab = HomeTab.active,
        organizationFilter = const OrganizationFilter.all();

  HomeSelectionState copyWith({
    HomeTab? tab,
    OrganizationFilter? organizationFilter,
  }) {
    return HomeSelectionState(
      tab: tab ?? this.tab,
      organizationFilter: organizationFilter ?? this.organizationFilter,
    );
  }
}
