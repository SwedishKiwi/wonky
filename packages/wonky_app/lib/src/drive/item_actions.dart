import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../menus/menu_resolver.dart';
import '../shell/shell_services.dart';

/// Payload of a drive drag (rows and grid cards).
class DriveDragData {
  const DriveDragData(this.uuids);
  final List<String> uuids;
}

/// Context-menu / ⋮ entries for the selection (suite 05 §3.1), without the
/// commands in [exclude] (those the selection bar already shows as icons).
List<WonkyMenuEntry> itemMenuEntries(
  BuildContext context,
  ShellServices s, {
  required bool trash,
  Set<String> exclude = const {},
}) {
  final r = MenuResolver(s);
  WonkyMenuItem? e(String id, [Map<String, Object?> args = const {}]) =>
      exclude.contains(id)
      ? null
      : r.commandEntry(
          context,
          id,
          args: args,
          source: InvocationSource.contextMenu,
        );
  if (trash) {
    return [?e('shell.drive.restore'), ?e('shell.drive.deleteForever')];
  }
  final extra = s.config.itemMenuCommands(context, s, s.driveSelection.value);
  return <WonkyMenuEntry>[
    if (!extra.hide.contains('shell.drive.open')) ?e('shell.drive.open'),
    for (final c in extra.commands)
      if (!exclude.contains(c.id))
        ?r.commandEntry(
          context,
          c.id,
          args: c.args,
          label: c.label,
          key: c.label == null ? null : '${c.id}.${c.label}',
          source: InvocationSource.contextMenu,
        ),
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

/// Marks a folder row or card as a target for files dragged from the OS
/// (Drive 04 §3.5); the home finds it by hit-testing the drag position
/// ([osDropFolderAt]).
class DriveOsDropFolder {
  const DriveOsDropFolder(this.item);
  final DriveItemView item;
}

/// The folder an OS file drag currently hovers (published by the home so
/// the row highlights).
class DriveOsDropScope extends InheritedNotifier<ValueNotifier<UuidValue?>> {
  const DriveOsDropScope({
    super.key,
    required ValueNotifier<UuidValue?> hovered,
    required super.child,
  }) : super(notifier: hovered);

  /// The hovered folder, or null (also outside a scope).
  static UuidValue? hoveredOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DriveOsDropScope>()
      ?.notifier
      ?.value;
}

/// Wraps a folder row/card so OS file drops can target it.
Widget osDropFolderTarget(DriveItemView item, Widget child) => MetaData(
  metaData: DriveOsDropFolder(item),
  behavior: HitTestBehavior.translucent,
  child: child,
);

/// The folder under [globalPosition] in [context]'s view, if any.
DriveItemView? osDropFolderAt(BuildContext context, Offset globalPosition) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(
    result,
    globalPosition,
    View.of(context).viewId,
  );
  for (final e in result.path) {
    final t = e.target;
    if (t is RenderMetaData && t.metaData is DriveOsDropFolder) {
      return (t.metaData as DriveOsDropFolder).item;
    }
  }
  return null;
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
