import 'package:flutter/cupertino.dart';

class GlassShell extends StatelessWidget {
  final Widget child;
  final bool safeArea;
  final EdgeInsetsGeometry insetPadding;

  const GlassShell({
    super.key,
    required this.child,
    this.safeArea = true,
    this.insetPadding = const EdgeInsets.all(2),
  });

  @override
  Widget build(BuildContext context) {
    Widget content = safeArea ? SafeArea(child: child) : child;
    content = Padding(
      padding: insetPadding,
      child: content,
    );
    return content;
  }
}
