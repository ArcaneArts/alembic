import 'package:arcane/arcane.dart';

enum AlembicBadgeTone {
  primary,
  secondary,
  outline,
  destructive,
}

class AlembicActionItem<T> {
  final T value;
  final String label;
  final String? description;
  final IconData? icon;
  final bool prominent;
  final bool destructive;

  const AlembicActionItem({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.prominent = false,
    this.destructive = false,
  });
}

class AlembicDropdownOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool destructive;

  const AlembicDropdownOption({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
  });
}

class AlembicNavigationItem<T> {
  final T value;
  final String label;
  final IconData icon;
  final String? tooltip;

  const AlembicNavigationItem({
    required this.value,
    required this.label,
    required this.icon,
    this.tooltip,
  });
}

class AlembicSegmentedOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const AlembicSegmentedOption({
    required this.value,
    required this.label,
    this.icon,
  });
}
