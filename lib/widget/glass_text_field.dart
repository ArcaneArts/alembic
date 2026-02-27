import 'package:alembic/theme/alembic_tokens.dart';
import 'package:alembic/widget/glass_panel.dart';
import 'package:flutter/cupertino.dart';

class GlassTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final int? maxLength;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.keyboardType,
    this.prefix,
    this.maxLength,
  });

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    BorderRadius borderRadius = BorderRadius.circular(tokens.radiusSmall);

    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: GlassPanel(
        role: GlassPanelRole.inline,
        borderRadius: borderRadius,
        fillColor: tokens.inlineFill.withValues(
          alpha: _focused
              ? tokens.inlineFillOpacity + 0.03
              : tokens.inlineFillOpacity,
        ),
        child: CupertinoTextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          placeholder: widget.placeholder,
          placeholderStyle: TextStyle(
            color: tokens.textSecondary.withValues(alpha: 0.74),
            fontSize: 13,
          ),
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          prefix: widget.prefix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 10, right: 8),
                  child: widget.prefix,
                ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: const BoxDecoration(
            color: CupertinoColors.transparent,
          ),
          maxLength: widget.maxLength,
        ),
      ),
    );
  }
}
