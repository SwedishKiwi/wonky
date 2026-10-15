import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../../l10n/slides_l10n.dart';

/// The alt text dialog (Slides 04 §13.7, 03 §17.1): a multi-line
/// description and *Decorative*. MCP-operable (`WonkyDialogSpec`). Returns
/// `(altText, decorative)` or null when cancelled.
Future<(String, bool)?> showAltTextDialog(
  BuildContext context, {
  String altText = '',
  bool decorative = false,
}) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.altTextDialogTitle,
      dialogKey: 'dialog.slides.altText',
      fields: [
        TextFieldSpec(
          id: 'altText',
          label: l.accessibilityAltText,
          initial: altText,
          placeholder: l.accessibilityAltTextHint,
          multiline: true,
          maxLength: 2000,
        ),
        CheckboxFieldSpec(
          id: 'decorative',
          label: l.altTextDialogDecorative,
          initial: decorative,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'save', label: l.dialogSave, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'save') return null;
  return (r!.text('altText').trim(), r.flag('decorative'));
}
