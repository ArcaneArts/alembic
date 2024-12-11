import 'package:arcane/arcane.dart';
import 'package:url_launcher/url_launcher_string.dart';

MenuItem linkMenu({
  required String text,
  required String url,
  required IconData icon,
  List<MenuItem>? subMenu,
}) =>
    MenuButton(
        leading: Icon(icon),
        subMenu: subMenu,
        onPressed: (context) => launchUrlString(url),
        child: Text(text));
