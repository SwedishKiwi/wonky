import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';

/// The answer of the *Delete group* dialog (04 §13.4).
enum DeleteGroupChoice { cancel, ungroupOnly, withSlides }

/// *Delete group* (Slides 04 §13.4): "Delete group ‘Intro’?" — [Cancel]
/// [Ungroup only] [Delete group and n slides] (destructive). A
/// `WonkyDialogSpec`, so MCP can describe and press it (04 AC-9).
Future<DeleteGroupChoice> showDeleteGroupDialog(
  BuildContext context,
  DeckEditorController ed,
  List<String> groupIds,
) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  var count = 0;
  for (final id in groupIds) {
    count += ed.order.range(id)?.length ?? 0;
  }
  final title = groupIds.length == 1
      ? l.deleteGroupTitle(_title(ed, groupIds.single, l))
      : l.deleteGroupsTitle(groupIds.length);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: title,
      description: l.deleteGroupBody(count),
      dialogKey: 'dialog.slides.deleteGroup',
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'ungroup', label: l.deleteGroupUngroupOnly),
        DialogButtonSpec(
          id: 'delete',
          label: l.deleteGroupWithSlides(count),
          primary: true,
          destructive: true,
        ),
      ],
    ),
  );
  return switch (r?.buttonId) {
    'ungroup' => DeleteGroupChoice.ungroupOnly,
    'delete' => DeleteGroupChoice.withSlides,
    _ => DeleteGroupChoice.cancel,
  };
}

/// *Add to group ▸ Choose a group…* (04 §5.6, P1): a select of the deck's
/// groups. Returns the chosen group id or null.
Future<String?> showChooseGroupDialog(
  BuildContext context,
  DeckEditorController ed,
) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final groups = ed.order.groups;
  if (groups.isEmpty) return null;
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.chooseGroupTitle,
      dialogKey: 'dialog.slides.chooseGroup',
      fields: [
        SelectFieldSpec(
          id: 'group',
          label: l.chooseGroupLabel,
          options: {
            for (final g in groups) g.group.id: _title(ed, g.group.id, l),
          },
          initial: ed.currentEntry?.groupId ?? groups.first.group.id,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'add', label: l.chooseGroupButton, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'add') return null;
  final id = r!.text('group');
  return id.isEmpty ? null : id;
}

String _title(DeckEditorController ed, String groupId, SlidesLocalizations l) {
  final t = ed.model.group(groupId)?.title ?? '';
  return t.isEmpty ? l.groupUntitled : t;
}
