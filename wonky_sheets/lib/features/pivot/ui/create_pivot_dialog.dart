import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../../l10n/sheets_l10n.dart';

/// Where *Create pivot table* puts the pivot (07 §7.2).
enum PivotDestination {
  newSheet('newSheet'),
  existingSheet('existingSheet');

  const PivotDestination(this.id);
  final String id;

  static PivotDestination byId(String? id) =>
      id == existingSheet.id ? existingSheet : newSheet;
}

/// The choices of [showCreatePivotDialog].
typedef CreatePivotChoice = ({
  String range,
  PivotDestination destination,
  String location,
});

/// *Create pivot table* (07 §7.2, a `WonkyDialogSpec` so MCP can fill it):
/// `range`, `destination` (new sheet / existing sheet) and `location` (a
/// single cell, used for *Existing sheet*).
Future<CreatePivotChoice?> showCreatePivotDialog(
  BuildContext context, {
  required WorkbookModel model,
  required String contextSheetId,
  required String range,
  String location = '',
}) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  String? validRange(String v) {
    try {
      final r = model.parseA1(v.trim(), contextSheetId: contextSheetId);
      return r.rect.rowCount < 1 ? l.dialogCreatePivotInvalidRange : null;
    } on InvalidRangeException {
      return l.dialogCreatePivotInvalidRange;
    }
  }

  String? validLocation(String v) {
    if (v.trim().isEmpty) return null;
    try {
      final r = model.parseA1(v.trim(), contextSheetId: contextSheetId);
      return r.rect.isSingleCell ? null : l.dialogCreatePivotInvalidLocation;
    } on InvalidRangeException {
      return l.dialogCreatePivotInvalidLocation;
    }
  }

  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.dialogCreatePivotTitle,
      dialogKey: 'dialog.createPivot',
      fields: [
        TextFieldSpec(
          id: 'range',
          label: l.dialogCreatePivotRange,
          initial: range,
          placeholder: 'Sheet1!A1:F100',
          validator: validRange,
        ),
        SelectFieldSpec(
          id: 'destination',
          label: l.dialogCreatePivotInsertTo,
          options: {
            PivotDestination.newSheet.id: l.dialogCreatePivotNewSheet,
            PivotDestination.existingSheet.id: l.dialogCreatePivotExistingSheet,
          },
          initial: PivotDestination.newSheet.id,
        ),
        TextFieldSpec(
          id: 'location',
          label: l.dialogCreatePivotLocation,
          initial: location,
          placeholder: 'Sheet1!H1',
          selectAll: false,
          validator: validLocation,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(
          id: 'create',
          label: l.dialogCreatePivotCreate,
          primary: true,
        ),
      ],
    ),
  );
  if (r?.buttonId != 'create') return null;
  return (
    range: r!.text('range').trim(),
    destination: PivotDestination.byId(r.text('destination')),
    location: r.text('location').trim(),
  );
}
