import 'package:flutter/widgets.dart';

bool alembicIsFlutterTestEnvironment() {
  if (const bool.fromEnvironment('FLUTTER_TEST')) {
    return true;
  }

  final String bindingName = WidgetsBinding.instance.runtimeType.toString();
  return bindingName.contains('TestWidgetsFlutterBinding') ||
      bindingName.contains('AutomatedTestWidgetsFlutterBinding') ||
      bindingName.contains('LiveTestWidgetsFlutterBinding');
}
