import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../history/server_change_undo.dart';
import 'sheets_ai_api.dart';

export '../history/server_change_undo.dart'
    show SheetsServerChangeEntry, SheetsServerChangeHandler;

/// The [SheetsAiApi] of each signed-in shell (tests install fakes).
abstract final class SheetsAiApis {
  static final Expando<SheetsAiApi> _apis = Expando('SheetsAiApi');

  /// The API of [services] (the server's, or the installed fake).
  static SheetsAiApi of(ShellServices services) {
    final installed = _apis[services];
    if (installed != null) return installed;
    final client = services.client;
    if (client == null) return const UnavailableSheetsAiApi();
    return _apis[services] = ServerSheetsAiApi(client);
  }

  /// Installs [api] for [services] (widget tests).
  static void install(ShellServices services, SheetsAiApi api) =>
      _apis[services] = api;
}

/// Pushes one undo step for the server change [changeId] (an AI run, Fill
/// with AI, an applied AI preview) on the open spreadsheet's stack,
/// labelled [label] ("AI: Fill B2:B20"). The `sheets.serverChange` domain
/// and its handler belong to the history feature (Sheets 10 A-10-5).
/// Returns the step id.
String pushServerChangeStep(
  ShellServices services, {
  required String changeId,
  required String label,
  InvocationSource source = InvocationSource.ai,
}) {
  final id = 'server-$changeId';
  services.undo.push(
    UndoStep(
      id: id,
      label: label,
      entries: [SheetsServerChangeEntry(changeId: changeId, label: label)],
      source: source,
    ),
  );
  return id;
}
