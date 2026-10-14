import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/sheets_l10n.dart';

/// Alt text dialog (08 §14 `sheets.object.editAltText`): title and
/// description (2000 chars). [placeholder] shows the automatic chart
/// description. Returns (title, description) or null when cancelled.
Future<(String, String)?> showAltTextDialog(
  BuildContext context, {
  required String title,
  required String description,
  String? placeholder,
}) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.dialogAltTextTitle,
      description: l.dialogAltTextDescription,
      dialogKey: 'dialog.altText',
      width: 480,
      fields: [
        TextFieldSpec(
          id: 'title',
          label: l.dialogAltTextName,
          initial: title,
          maxLength: 255,
        ),
        TextFieldSpec(
          id: 'description',
          label: l.dialogAltTextBody,
          initial: description,
          placeholder: placeholder,
          multiline: true,
          maxLength: 2000,
          selectAll: false,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'ok', label: l.dialogSave, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'ok') return null;
  return (r!.text('title'), r.text('description'));
}
