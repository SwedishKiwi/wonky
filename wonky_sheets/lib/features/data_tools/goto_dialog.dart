import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/sheets_l10n.dart';

/// Go to range (04 §11.18): a `target` input (A1, ranges, `Sheet!A1`, named
/// ranges) validated by [isValid]; returns the target or null.
Future<String?> showGoToDialog(
  BuildContext context, {
  required bool Function(String target) isValid,
  String initial = '',
}) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.goToTitle,
      dialogKey: 'dialog.goTo',
      fields: [
        TextFieldSpec(
          id: 'target',
          label: l.goToLabel,
          initial: initial,
          placeholder: "A1, Sheet2!B5, Sales",
          selectAll: true,
          validator: (t) =>
              t.trim().isEmpty || !isValid(t.trim()) ? l.goToInvalid : null,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'go', label: l.goToButton, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'go') return null;
  return r!.text('target').trim();
}
