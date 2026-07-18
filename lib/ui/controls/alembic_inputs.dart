import 'package:alembic/ui/alembic_tokens.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class AlembicLabeledField extends StatelessWidget {
  final String label;
  final String? supportingText;
  final Widget child;

  const AlembicLabeledField({
    super.key,
    required this.label,
    required this.child,
    this.supportingText,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.typography.small.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (supportingText != null) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapXs),
          Text(
            supportingText!,
            style: theme.typography.xSmall.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
        const Gap(AlembicShadcnTokens.gapSm),
        child,
      ],
    );
  }
}

class AlembicTextInput extends StatelessWidget {
  final m.TextEditingController? controller;
  final String placeholder;
  final bool obscureText;
  final int? maxLength;
  final m.TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;

  const AlembicTextInput({
    super.key,
    required this.placeholder,
    this.controller,
    this.obscureText = false,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.leading,
    this.trailing,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    m.OutlineInputBorder border = m.OutlineInputBorder(
      borderRadius: m.BorderRadius.circular(AlembicShadcnTokens.controlRadius),
      borderSide: m.BorderSide(color: theme.colorScheme.border),
      gapPadding: 0,
    );
    m.OutlineInputBorder activeBorder = m.OutlineInputBorder(
      borderRadius: m.BorderRadius.circular(AlembicShadcnTokens.controlRadius),
      borderSide: m.BorderSide(color: theme.colorScheme.ring),
      gapPadding: 0,
    );
    m.TextStyle textStyle = theme.typography.small.copyWith(
      color: enabled
          ? theme.colorScheme.foreground
          : theme.colorScheme.mutedForeground,
    );
    return m.TextField(
      controller: controller,
      obscureText: obscureText,
      maxLength: maxLength,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      style: textStyle,
      cursorColor: theme.colorScheme.foreground,
      textAlignVertical: m.TextAlignVertical.center,
      textInputAction: onSubmitted == null ? null : m.TextInputAction.done,
      decoration: m.InputDecoration(
        hintText: placeholder,
        hintStyle: theme.typography.small.copyWith(
          color: theme.colorScheme.mutedForeground,
        ),
        filled: true,
        fillColor: enabled ? theme.colorScheme.card : theme.colorScheme.muted,
        isDense: true,
        counterText: maxLength == null ? null : '',
        constraints: const m.BoxConstraints(
          minHeight: AlembicShadcnTokens.controlHeight,
        ),
        contentPadding: m.EdgeInsets.symmetric(
          horizontal: leading == null ? 12 : 0,
          vertical: 8,
        ),
        prefixIcon: leading == null
            ? null
            : _AlembicInputLeading(
                leading: leading!,
              ),
        prefixIconConstraints: const m.BoxConstraints(
          minWidth: 38,
          minHeight: AlembicShadcnTokens.controlHeight,
        ),
        suffixIcon: trailing == null
            ? null
            : _AlembicInputLeading(
                leading: trailing!,
              ),
        suffixIconConstraints: const m.BoxConstraints(
          minWidth: 38,
          minHeight: AlembicShadcnTokens.controlHeight,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: activeBorder,
        disabledBorder: border,
        errorBorder: border,
        focusedErrorBorder: activeBorder,
      ),
    );
  }
}

class _AlembicInputLeading extends StatelessWidget {
  final Widget leading;

  const _AlembicInputLeading({
    required this.leading,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Center(
      child: IconTheme.merge(
        data: m.IconThemeData(
          color: theme.colorScheme.mutedForeground,
          size: 16,
        ),
        child: leading,
      ),
    );
  }
}
