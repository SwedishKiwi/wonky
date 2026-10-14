import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../../l10n/sheets_l10n.dart';

/// *Create pivot group rule* (07 §7.3, histogram grouping): minimum,
/// maximum (optional) and interval size.
Future<PivotHistogramGrouping?> showPivotHistogramDialog(
  BuildContext context, {
  PivotHistogramGrouping? initial,
}) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  String fmt(double? v) => v == null
      ? ''
      : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
  String? optional(String v) =>
      v.trim().isEmpty || double.tryParse(v.trim()) != null
      ? null
      : l.pivotHistogramInvalidNumber;
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.pivotHistogramTitle,
      dialogKey: 'dialog.pivotHistogram',
      width: 360,
      fields: [
        TextFieldSpec(
          id: 'min',
          label: l.pivotHistogramMin,
          initial: fmt(initial?.min),
          validator: optional,
        ),
        TextFieldSpec(
          id: 'max',
          label: l.pivotHistogramMax,
          initial: fmt(initial?.max),
          validator: optional,
        ),
        TextFieldSpec(
          id: 'size',
          label: l.pivotHistogramSize,
          initial: fmt(initial?.size ?? 10),
          validator: (v) {
            final n = double.tryParse(v.trim());
            return n == null || n <= 0 ? l.pivotHistogramInvalidSize : null;
          },
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'ok', label: l.pivotApply, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'ok') return null;
  double? n(String id) => double.tryParse(r!.text(id).trim());
  return PivotHistogramGrouping(n('size')!, min: n('min'), max: n('max'));
}

/// *Rename…* of a value field.
Future<String?> showPivotRenameDialog(BuildContext context, String initial) {
  final l = sheetsL10n(context);
  return showTextInputDialog(
    context,
    title: l.pivotRenameTitle,
    label: l.pivotRenameLabel,
    confirmLabel: l.pivotApply,
    initial: initial,
    dialogKey: 'dialog.pivotRename',
  );
}
