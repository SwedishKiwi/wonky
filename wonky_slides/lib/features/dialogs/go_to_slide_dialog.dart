import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../editor_screen/slide_labels.dart';

/// Go to slide (Slides 04 §13.10): a `slide` select listing every slide as
/// "4 · Our mission — Intro" (groups in the label), MCP-operable through
/// `ui.get_dialog` / `ui.fill_dialog` (a `WonkyDialogSpec`). Returns the
/// chosen slide id or null.
Future<String?> showGoToSlideDialog(
  BuildContext context,
  DeckEditorController ed,
) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final entries = ed.order.entries;
  if (entries.isEmpty) return null;
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.goToSlideTitle,
      dialogKey: 'dialog.slides.goToSlide',
      fields: [
        SelectFieldSpec(
          id: 'slide',
          label: l.goToSlideLabel,
          options: {
            for (final e in entries)
              e.id: SlideLabels.goToLabel(
                ed.model,
                e,
                untitled: l.slideUntitled,
              ),
          },
          initial: ed.currentSlideId ?? entries.first.id,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'go', label: l.goToSlideButton, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'go') return null;
  final id = r!.text('slide');
  return id.isEmpty ? null : id;
}
