import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/sheets_l10n.dart';

/// Answers of the save conflict dialog (09 §14.3).
enum ScriptConflictChoice { overwriteMine, discardMine, cancel }

/// "Someone saved a newer version of utils.dart" (09 §14.3, LWW per file):
/// *Overwrite with mine* / *Discard mine* / *Cancel*.
Future<ScriptConflictChoice> showScriptConflictDialog(
  BuildContext context, {
  required String fileName,
}) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.scriptConflictTitle,
      description: l.scriptConflictBody(fileName),
      dialogKey: 'dialog.scriptConflict',
      width: 460,
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(
          id: 'discard',
          label: l.scriptConflictDiscard,
          destructive: true,
        ),
        DialogButtonSpec(
          id: 'overwrite',
          label: l.scriptConflictOverwrite,
          primary: true,
        ),
      ],
    ),
  );
  return switch (r?.buttonId) {
    'overwrite' => ScriptConflictChoice.overwriteMine,
    'discard' => ScriptConflictChoice.discardMine,
    _ => ScriptConflictChoice.cancel,
  };
}
