import 'package:alembic/widget/repository_tile_actions.dart';

class RepositoryActionModel {
  final RepositoryTileAction action;
  final String label;
  final String description;
  final bool prominent;
  final bool destructive;

  const RepositoryActionModel({
    required this.action,
    required this.label,
    required this.description,
    this.prominent = false,
    this.destructive = false,
  });
}
