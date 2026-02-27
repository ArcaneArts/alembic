enum HomeTab {
  active,
  personal,
  organizations,
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
