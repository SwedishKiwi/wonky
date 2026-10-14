import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../../l10n/sheets_l10n.dart';

/// What a scope allows, in the user's words (09 §11.1).
String scriptScopeLabel(SheetsLocalizations l, String scope) => switch (scope) {
  ScriptScopes.externalRequest => l.scriptScopeExternalRequest,
  ScriptScopes.userEmail => l.scriptScopeUserEmail,
  ScriptScopes.triggers => l.scriptScopeTriggers,
  _ => scope,
};

/// The authorization dialog (09 §11.2): "Project wants to: • …" with
/// *Allow* / *Cancel*. A `WonkyDialogSpec`, so agents can read it (MCP
/// `ui.get_dialog`) — granting stays a human decision in practice since the
/// dialog only opens for runs started in the app.
Future<bool> showScriptAuthorizationDialog(
  BuildContext context, {
  required String projectName,
  required Set<String> scopes,
}) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final list = [
    for (final s in ScriptScopes.authorizable)
      if (scopes.contains(s)) '• ${scriptScopeLabel(l, s)}',
    for (final s in scopes)
      if (!ScriptScopes.authorizable.contains(s)) '• $s',
  ].join('\n');
  final name = projectName.trim().isEmpty
      ? l.scriptDefaultProjectName
      : projectName;
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.scriptAuthorizeTitle,
      description: '${l.scriptAuthorizeBody(name)}\n$list',
      dialogKey: 'dialog.scriptAuthorize',
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(
          id: 'allow',
          label: l.scriptAuthorizeAllow,
          primary: true,
        ),
      ],
    ),
  );
  return r?.buttonId == 'allow';
}
