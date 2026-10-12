import 'package:flutter/widgets.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../menus/menu_resolver.dart';
import '../shell/shell_services.dart';

/// Payload of a drive drag (rows and grid cards).
class DriveDragData {
  const DriveDragData(this.uuids);
  final List<String> uuids;
}

/// Context-menu / ⋮ entries for the selection (suite 05 §3.1).
List<WonkyMenuEntry> itemMenuEntries(
  BuildContext context,
  ShellServices s, {
  required bool trash,
}) {
  final r = MenuResolver(s);
  WonkyMenuItem? e(String id, [Map<String, Object?> args = const {}]) =>
      r.commandEntry(
        context,
        id,
        args: args,
        source: InvocationSource.contextMenu,
      );
  if (trash) {
    return [?e('shell.drive.restore'), ?e('shell.drive.deleteForever')];
  }
  return <WonkyMenuEntry>[
    ?e('shell.drive.open'),
    const WonkyMenuSeparator(),
    ?e('shell.sharing.open'),
    ?e('shell.sharing.copyLink'),
    const WonkyMenuSeparator(),
    ?e('shell.drive.rename'),
    ?e('shell.drive.move'),
    ?e('shell.drive.addShortcut'),
    ?e('shell.drive.setStarred'),
    ?e('shell.drive.togglePinnedOffline'),
    ?e('shell.drive.copy'),
    const WonkyMenuSeparator(),
    ?e('shell.file.details'),
    const WonkyMenuSeparator(),
    ?e('shell.drive.trash'),
  ].tidy();
}

/// Moves dragged items into [folderUuid] (undoable via the command).
Future<void> dropIntoFolder(
  ShellServices s,
  DriveDragData data,
  String? folderUuid,
) async {
  final ids = [
    for (final u in data.uuids)
      if (u != folderUuid) u,
  ];
  if (ids.isEmpty) return;
  await s.dispatcher.invoke(
    'shell.drive.move',
    args: {'uuids': ids, 'folderUuid': folderUuid},
    source: InvocationSource.ui,
  );
}
