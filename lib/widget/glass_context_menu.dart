import 'package:alembic/theme/alembic_tokens.dart';
import 'package:alembic/widget/glass_button.dart';
import 'package:alembic/widget/glass_modal_overlay.dart';
import 'package:alembic/widget/glass_panel.dart';
import 'package:flutter/cupertino.dart';

class GlassMenuAction<T> {
  final T value;
  final String title;
  final bool destructive;

  const GlassMenuAction({
    required this.value,
    required this.title,
    this.destructive = false,
  });
}

class GlassContextMenu {
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    String? message,
    required List<GlassMenuAction<T>> actions,
  }) {
    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (dialogContext, _, __) {
        AlembicTokens tokens = dialogContext.alembicTokens;
        return SafeArea(
          child: GlassModalOverlay(
            mode: GlassModalFocusMode.blurAndDim,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
              child: GlassPanel(
                role: GlassPanelRole.overlay,
                borderRadius: BorderRadius.circular(tokens.radiusLarge),
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (title != null || message != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (title != null)
                              Text(
                                title,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            if (message != null) const SizedBox(height: 4),
                            if (message != null)
                              Text(
                                message,
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: SingleChildScrollView(
                        child: Column(
                          children: actions.map((action) {
                            return _MenuActionTile(
                              title: action.title,
                              destructive: action.destructive,
                              onPressed: () {
                                Navigator.of(dialogContext).pop(action.value);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GlassButton(
                      label: 'Close',
                      onPressed: () => Navigator.of(dialogContext).pop(null),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        CurvedAnimation curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

Future<bool> showGlassConfirmDialog(
  BuildContext context, {
  required String title,
  required String description,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool destructive = false,
}) async {
  bool confirmed = false;

  await showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (dialogContext, _, __) {
      AlembicTokens tokens = dialogContext.alembicTokens;
      return SafeArea(
        child: GlassModalOverlay(
          mode: GlassModalFocusMode.blurAndDim,
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: GlassPanel(
              role: GlassPanelRole.overlay,
              borderRadius: BorderRadius.circular(tokens.radiusLarge),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: GlassButton(
                          label: cancelText,
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          kind: GlassButtonKind.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GlassButton(
                          label: confirmText,
                          kind: destructive
                              ? GlassButtonKind.destructive
                              : GlassButtonKind.primary,
                          onPressed: () {
                            confirmed = true;
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      CurvedAnimation curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );

  return confirmed;
}

Future<void> showGlassInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonText = 'OK',
}) async {
  await showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (dialogContext, _, __) {
      AlembicTokens tokens = dialogContext.alembicTokens;
      return SafeArea(
        child: GlassModalOverlay(
          mode: GlassModalFocusMode.blurAndDim,
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: GlassPanel(
              role: GlassPanelRole.overlay,
              borderRadius: BorderRadius.circular(tokens.radiusLarge),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassButton(
                    label: buttonText,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    kind: GlassButtonKind.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      CurvedAnimation curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

class _MenuActionTile extends StatefulWidget {
  final String title;
  final bool destructive;
  final VoidCallback onPressed;

  const _MenuActionTile({
    required this.title,
    required this.destructive,
    required this.onPressed,
  });

  @override
  State<_MenuActionTile> createState() => _MenuActionTileState();
}

class _MenuActionTileState extends State<_MenuActionTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    Color textColor = widget.destructive ? tokens.danger : tokens.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            setState(() => _pressed = false);
            widget.onPressed();
          },
          child: AnimatedScale(
            scale: _pressed ? 0.985 : (_hovered ? 1.006 : 1),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                color: _hovered
                    ? tokens.inlineFill
                        .withValues(alpha: tokens.inlineFillOpacity + 0.16)
                    : tokens.inlineFill
                        .withValues(alpha: tokens.inlineFillOpacity + 0.10),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 13,
                    color: textColor.withValues(alpha: 0.72),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
