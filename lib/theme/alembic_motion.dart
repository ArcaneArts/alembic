import 'package:flutter/cupertino.dart';

class AlembicMotion {
  static const Duration tabSwitch = Duration(milliseconds: 340);
  static const Duration chip = Duration(milliseconds: 220);
  static const Duration hover = Duration(milliseconds: 180);
  static const Duration panel = Duration(milliseconds: 320);
  static const Duration content = Duration(milliseconds: 260);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;
  static const Curve exit = Curves.easeInCubic;

  const AlembicMotion._();
}
