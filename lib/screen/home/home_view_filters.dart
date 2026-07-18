import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/domain/repository_dto.dart';
import 'package:github/github.dart';

enum HomeStateFilter {
  all,
  active,
  archived,
  cloud,
  syncing;

  static HomeStateFilter fromStorage(String? value) {
    for (HomeStateFilter filter in HomeStateFilter.values) {
      if (filter.name == value) {
        return filter;
      }
    }
    return HomeStateFilter.all;
  }
}

enum HomeSortMode {
  attention,
  archiveSoon,
  updated,
  state,
  name,
  owner,
}

extension HomeSortModeMeta on HomeSortMode {
  String get label => switch (this) {
        HomeSortMode.attention => 'Needs attention',
        HomeSortMode.archiveSoon => 'Archive soon',
        HomeSortMode.updated => 'Recently updated',
        HomeSortMode.state => 'State',
        HomeSortMode.name => 'Name',
        HomeSortMode.owner => 'Owner',
      };
}

class HomeRepositoryEntry {
  final RepositoryDto dto;
  final Repository repository;
  final RepoState repoState;
  final bool syncing;
  final int daysUntilArchive;

  const HomeRepositoryEntry({
    required this.dto,
    required this.repository,
    required this.repoState,
    required this.syncing,
    required this.daysUntilArchive,
  });

  String get fullName => dto.fullName;

  String get lowerKey => dto.fullName.toLowerCase();

  int get stateRank => syncing
      ? 0
      : switch (repoState) {
          RepoState.active => 1,
          RepoState.archived => 2,
          RepoState.cloud => 3,
        };
}

class HomeStats {
  final int total;
  final int active;
  final int archived;
  final int cloud;
  final int syncing;
  final int private;
  final int forks;

  const HomeStats({
    required this.total,
    required this.active,
    required this.archived,
    required this.cloud,
    required this.syncing,
    required this.private,
    required this.forks,
  });

  const HomeStats.empty()
      : total = 0,
        active = 0,
        archived = 0,
        cloud = 0,
        syncing = 0,
        private = 0,
        forks = 0;

  factory HomeStats.fromEntries(List<HomeRepositoryEntry> entries) {
    int active = 0;
    int archived = 0;
    int cloud = 0;
    int syncing = 0;
    int private = 0;
    int forks = 0;
    for (HomeRepositoryEntry entry in entries) {
      if (entry.repoState == RepoState.active) {
        active += 1;
      } else if (entry.repoState == RepoState.archived) {
        archived += 1;
      } else {
        cloud += 1;
      }
      if (entry.syncing) {
        syncing += 1;
      }
      if (entry.dto.isPrivate) {
        private += 1;
      }
      if (entry.dto.isFork) {
        forks += 1;
      }
    }
    return HomeStats(
      total: entries.length,
      active: active,
      archived: archived,
      cloud: cloud,
      syncing: syncing,
      private: private,
      forks: forks,
    );
  }
}

class HomeFilterState {
  final HomeStateFilter stateFilter;
  final HomeSortMode sortMode;
  final String? ownerFilter;
  final String? query;

  const HomeFilterState({
    required this.stateFilter,
    required this.sortMode,
    required this.ownerFilter,
    required this.query,
  });

  const HomeFilterState.initial()
      : stateFilter = HomeStateFilter.all,
        sortMode = HomeSortMode.attention,
        ownerFilter = null,
        query = null;

  bool get hasActiveFilters =>
      stateFilter != HomeStateFilter.all ||
      ownerFilter != null ||
      (query != null && query!.trim().isNotEmpty);

  HomeFilterState copyWith({
    HomeStateFilter? stateFilter,
    HomeSortMode? sortMode,
    String? ownerFilter,
    bool clearOwnerFilter = false,
    String? query,
    bool clearQuery = false,
  }) =>
      HomeFilterState(
        stateFilter: stateFilter ?? this.stateFilter,
        sortMode: sortMode ?? this.sortMode,
        ownerFilter:
            clearOwnerFilter ? null : (ownerFilter ?? this.ownerFilter),
        query: clearQuery ? null : (query ?? this.query),
      );
}
