import 'package:flutter/cupertino.dart';

class AlembicThemeBuilder {
  static const String sansFamily = 'PlusJakartaSans';

  static CupertinoThemeData light() {
    return const CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: Color(0xFF111111),
      barBackgroundColor: Color(0x00000000),
      scaffoldBackgroundColor: Color(0x00000000),
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          fontFamily: sansFamily,
          fontSize: 14,
          color: Color(0xFF111111),
        ),
      ),
    );
  }

  static CupertinoThemeData dark() {
    return const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: Color(0xFFF4F4F4),
      barBackgroundColor: Color(0x00000000),
      scaffoldBackgroundColor: Color(0x00000000),
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          fontFamily: sansFamily,
          fontSize: 14,
          color: Color(0xFFF4F4F4),
        ),
      ),
    );
  }
}
