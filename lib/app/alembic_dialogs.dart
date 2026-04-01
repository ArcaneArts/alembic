import 'package:arcane/arcane.dart';
import 'package:alembic/app/alembic_widgets.dart';
import 'package:flutter/material.dart' as m;

Future<void> showAlembicInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return m.showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return m.Dialog(
        child: AlembicPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AlembicSectionHeader(
                title: title,
                subtitle: message,
              ),
              const Gap(18),
              Align(
                alignment: Alignment.centerRight,
                child: PrimaryButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> showAlembicConfirmDialog(
  BuildContext context, {
  required String title,
  required String description,
  String confirmText = 'Continue',
  String cancelText = 'Cancel',
  bool destructive = false,
}) async {
  final bool? result = await m.showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return m.Dialog(
        child: AlembicPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AlembicSectionHeader(
                title: title,
                subtitle: description,
              ),
              const Gap(18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  OutlineButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(cancelText),
                  ),
                  const Gap(10),
                  destructive
                      ? SecondaryButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(confirmText),
                        )
                      : PrimaryButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(confirmText),
                        ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

Future<String?> showAlembicInputDialog(
  BuildContext context, {
  required String title,
  required String description,
  required String placeholder,
  String confirmText = 'Save',
}) async {
  final m.TextEditingController controller = m.TextEditingController();
  final String? result = await m.showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      return m.Dialog(
        child: AlembicPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AlembicSectionHeader(
                title: title,
                subtitle: description,
              ),
              const Gap(16),
              AlembicTextInput(
                controller: controller,
                placeholder: placeholder,
                onSubmitted: (String value) {
                  Navigator.of(dialogContext).pop(value.trim());
                },
              ),
              const Gap(18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  OutlineButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Gap(10),
                  PrimaryButton(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(controller.text.trim()),
                    child: Text(confirmText),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  controller.dispose();
  return result;
}
