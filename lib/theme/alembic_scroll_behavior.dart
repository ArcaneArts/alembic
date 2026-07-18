import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

class AlembicScrollBehavior extends CupertinoScrollBehavior {
  const AlembicScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };
}
