import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show ItemVersionView, UuidValue, VersionRestoreResult;
import 'package:wonky_core/wonky_core.dart' show UndoEntry;

import '../undo/server_change_undo.dart';
import 'slides_version_view.dart';

/// Slides' [VersionRenderer] (Slides 09 §4.2, §4.4): the version's deck
/// read-only with its changes ([SlidesVersionView]); a restore is one `slides.serverChange` undo step (undo =
/// `slides.revertChange` with the per-column skip rule, redo =
/// `slides.reapplyChange`).
class SlidesVersionRenderer extends VersionRenderer {
  SlidesVersionRenderer();

  @override
  Widget build(
    BuildContext context, {
    required UuidValue itemUuid,
    required ItemVersionView version,
    ItemVersionView? previous,
    required bool showChanges,
  }) => SlidesVersionView(
    key: ValueKey<String>('slides.version.${version.id}'),
    services: ShellScope.of(context),
    itemUuid: itemUuid,
    version: version,
    previous: previous,
    showChanges: showChanges,
  );

  @override
  UndoEntry? restoreUndoEntry(
    UuidValue itemUuid,
    int versionId,
    VersionRestoreResult result,
  ) => result.changeId == null
      ? null
      : SlidesServerChangeEntry(
          changeId: result.changeId!.uuid,
          label: 'Restore version',
        );
}
