import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';

/// Paste special modes of the menu and the dialog (03 §12.4).
enum PasteSpecialMode {
  valuesOnly('values', PasteMode.valuesOnly),
  format('format', PasteMode.format),
  formulas('formulas', PasteMode.formulas),
  conditionalFormatting(
    'conditionalFormatting',
    PasteMode.conditionalFormatting,
  ),
  dataValidation('dataValidation', PasteMode.dataValidation),
  columnWidths('columnWidths', PasteMode.columnWidths),
  transposed('transposed', PasteMode.transposed),
  allExceptBorders('allExceptBorders', PasteMode.allExceptBorders);

  const PasteSpecialMode(this.id, this.mode);

  final String id;
  final PasteMode mode;

  static PasteSpecialMode? tryParse(String? id) =>
      values.where((m) => m.id == id).firstOrNull;

  String label(SheetsLocalizations l) => switch (this) {
    valuesOnly => l.pasteValuesOnly,
    format => l.pasteFormatOnly,
    formulas => l.pasteFormulasOnly,
    conditionalFormatting => l.pasteConditionalFormattingOnly,
    dataValidation => l.pasteDataValidationOnly,
    columnWidths => l.pasteColumnWidthsOnly,
    transposed => l.pasteTransposed,
    allExceptBorders => l.pasteAllExceptBorders,
  };
}

/// Paste special… (04 §11.6).
Future<PasteSpecialMode?> showPasteSpecialDialog(BuildContext context) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.dialogPasteSpecialTitle,
      dialogKey: 'dialog.pasteSpecial',
      fields: [
        SelectFieldSpec(
          id: 'mode',
          label: l.dialogPasteSpecialMode,
          options: {for (final m in PasteSpecialMode.values) m.id: m.label(l)},
          initial: PasteSpecialMode.values.first.id,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'ok', label: l.dialogPaste, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'ok') return null;
  return PasteSpecialMode.tryParse(r!.text('mode'));
}

/// Note editor (03 §14.5). Returns the new text ('' deletes).
Future<String?> showNoteDialog(
  BuildContext context, {
  String initial = '',
}) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.dialogNoteTitle,
      dialogKey: 'dialog.note',
      fields: [
        TextFieldSpec(
          id: 'text',
          label: l.dialogNoteLabel,
          initial: initial,
          multiline: true,
          maxLength: 50000,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'ok', label: l.dialogSave, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'ok') return null;
  return r!.text('text');
}

/// Insert link (03 §14.4). Returns (text, url); empty url removes.
Future<(String, String)?> showLinkDialog(
  BuildContext context, {
  String text = '',
  String url = '',
}) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.dialogLinkTitle,
      dialogKey: 'dialog.link',
      fields: [
        TextFieldSpec(id: 'text', label: l.dialogLinkText, initial: text),
        TextFieldSpec(
          id: 'url',
          label: l.dialogLinkUrl,
          initial: url,
          placeholder: 'https://',
          validator: (v) => null,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'ok', label: l.dialogApply, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'ok') return null;
  return (r!.text('text'), r.text('url').trim());
}

/// Merge warning (04 §11.11).
Future<bool> confirmMergeDialog(BuildContext context, MergeMode mode) {
  final l = sheetsL10n(context);
  return confirmDialog(
    context,
    title: l.dialogMergeTitle,
    description: switch (mode) {
      MergeMode.horizontal => l.dialogMergeHorizontal,
      MergeMode.vertical => l.dialogMergeVertical,
      MergeMode.all => l.dialogMergeAll,
    },
    confirmLabel: l.dialogOk,
  );
}

/// "There's already data here" (03 §11).
Future<bool> confirmReplaceDataDialog(BuildContext context) {
  final l = sheetsL10n(context);
  return confirmDialog(
    context,
    title: l.dialogReplaceDataTitle,
    description: l.dialogReplaceDataBody,
    confirmLabel: l.dialogOk,
  );
}

/// Delete sheet confirm (04 §11.14).
Future<bool> confirmDeleteSheetDialog(BuildContext context, String name) {
  final l = sheetsL10n(context);
  return confirmDialog(
    context,
    title: l.dialogDeleteSheetTitle(name),
    description: l.dialogDeleteSheetBody,
    confirmLabel: l.dialogDelete,
    destructive: true,
  );
}

/// Resize rows/columns (04 §11.10).
Future<({bool fit, double size})?> showResizeDialog(
  BuildContext context, {
  required String title,
  required bool rows,
  required double current,
}) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: title,
      dialogKey: 'dialog.resize',
      fields: [
        SelectFieldSpec(
          id: 'mode',
          label: l.dialogResizeMode,
          options: {
            'size': rows
                ? l.dialogResizeSpecifyRow
                : l.dialogResizeSpecifyColumn,
            'fit': l.cmdFitToData,
          },
          initial: 'size',
        ),
        TextFieldSpec(
          id: 'size',
          label: l.dialogResizeSize,
          initial: current.round().toString(),
          validator: (t) {
            final n = double.tryParse(t.trim());
            return n == null || n < 2 || n > 5000
                ? l.dialogResizeInvalid
                : null;
          },
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'ok', label: l.dialogOk, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'ok') return null;
  return (
    fit: r!.text('mode') == 'fit',
    size: double.tryParse(r.text('size').trim()) ?? current,
  );
}

/// Insert rows/columns… (04 §11.8).
Future<({int count, bool after})?> showInsertDimensionDialog(
  BuildContext context, {
  required bool rows,
}) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: rows ? l.cmdRowsInsertDialog : l.cmdColsInsertDialog,
      dialogKey: 'dialog.insertDimension',
      fields: [
        TextFieldSpec(
          id: 'count',
          label: l.dialogInsertCount,
          initial: '1',
          validator: (t) {
            final n = int.tryParse(t.trim());
            return n == null || n < 1 || n > 10000
                ? l.dialogInsertInvalid
                : null;
          },
        ),
        SelectFieldSpec(
          id: 'position',
          label: l.dialogInsertPosition,
          options: rows
              ? {'before': l.dialogInsertAbove, 'after': l.dialogInsertBelow}
              : {'before': l.dialogInsertLeft, 'after': l.dialogInsertRight},
          initial: 'before',
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'ok', label: l.dialogInsert, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'ok') return null;
  return (
    count: int.tryParse(r!.text('count').trim()) ?? 1,
    after: r.text('position') == 'after',
  );
}

/// Insert/Delete cells (04 §11.8–11.9). Returns the command id to run.
Future<String?> showShiftCellsDialog(
  BuildContext context, {
  required bool insert,
}) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final options = insert
      ? {
          'sheets.cells.insertShiftRight': l.cmdCellsInsertShiftRight,
          'sheets.cells.insertShiftDown': l.cmdCellsInsertShiftDown,
          'sheets.rows.insertAbove': l.dialogEntireRow,
          'sheets.cols.insertLeft': l.dialogEntireColumn,
        }
      : {
          'sheets.cells.deleteShiftLeft': l.cmdCellsDeleteShiftLeft,
          'sheets.cells.deleteShiftUp': l.cmdCellsDeleteShiftUp,
          'sheets.rows.delete': l.dialogEntireRow,
          'sheets.cols.delete': l.dialogEntireColumn,
        };
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: insert ? l.dialogInsertCellsTitle : l.dialogDeleteCellsTitle,
      dialogKey: 'dialog.shiftCells',
      fields: [
        SelectFieldSpec(
          id: 'command',
          label: l.dialogShiftMode,
          options: options,
          initial: options.keys.first,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(
          id: 'ok',
          label: insert ? l.dialogInsert : l.dialogDelete,
          primary: true,
        ),
      ],
    ),
  );
  if (r?.buttonId != 'ok') return null;
  return r!.text('command');
}
