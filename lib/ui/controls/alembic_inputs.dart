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
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return TextField(
      controller: controller,
      placeholder: Text(
        placeholder,
        style: theme.typography.small.copyWith(
          color: theme.colorScheme.mutedForeground,
        ),
      ),
      obscureText: obscureText,
      maxLength: maxLength,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      features: <InputFeature>[
        if (leading != null) InputFeature.leading(leading!),
      ],
    );
  }
}
