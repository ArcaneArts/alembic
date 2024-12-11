import 'package:arcane/arcane.dart';
import 'package:github/github.dart';

extension XBuildContextRepo on BuildContext {
  BehaviorSubject<String?> get search => pylon<BehaviorSubject<String?>>();

  GitHub get github => pylon<GitHub>();

  Repository get repository => pylon<Repository>();

  Organization get organization => pylon<Organization>();

  List<Repository> get repositories => pylon<List<Repository>>();

  Map<Organization, List<Repository>> get organizations =>
      pylon<Map<Organization, List<Repository>>>();
}

extension XSearchFilterRepo on List<Repository> {
  List<Repository> filterBy(String? query) => query == null || query.isEmpty
      ? this
      : where((i) => i.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
}
