import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';

/// The values of *Slide numbers and footer* (`slides.deck.setNumbering`).
class NumberingChoice {
  const NumberingChoice({
    required this.showSlideNumbers,
    required this.firstSlideNumber,
    required this.hideNumberOnTitle,
    required this.footerText,
  });

  final bool showSlideNumbers;
  final int firstSlideNumber;
  final bool hideNumberOnTitle;

  /// Empty = no footer.
  final String footerText;
}

/// Slide numbers and footer (Slides 04 §13.3, 05 §5.5): `showSlideNumbers`,
/// `firstSlideNumber`, `hideNumberOnTitle`, `footerText` (empty = hidden).
/// A `WonkyDialogSpec` (MCP-operable). Returns the values or null.
Future<NumberingChoice?> showNumberingDialog(
  BuildContext context,
  DeckEditorController ed,
) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final d = ed.model.deck;
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.numberingTitle,
      dialogKey: 'dialog.slides.numbering',
      fields: [
        CheckboxFieldSpec(
          id: 'showSlideNumbers',
          label: l.numberingShow,
          initial: d?.showSlideNumbers ?? false,
        ),
        TextFieldSpec(
          id: 'firstSlideNumber',
          label: l.numberingFirst,
          initial: '${d?.firstSlideNumber ?? 1}',
          validator: (v) {
            final n = int.tryParse(v.trim());
            return n == null || n < 0 || n > 9999
                ? l.numberingFirstInvalid
                : null;
          },
        ),
        CheckboxFieldSpec(
          id: 'hideNumberOnTitle',
          label: l.numberingHideOnTitle,
          initial: d?.hideNumberOnTitle ?? false,
        ),
        TextFieldSpec(
          id: 'footerText',
          label: l.numberingFooter,
          initial: d?.footerText ?? '',
          placeholder: l.numberingFooterHint,
          maxLength: 200,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'apply', label: l.pageSetupApply, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'apply') return null;
  return NumberingChoice(
    showSlideNumbers: r!.flag('showSlideNumbers'),
    firstSlideNumber: int.tryParse(r.text('firstSlideNumber').trim()) ?? 1,
    hideNumberOnTitle: r.flag('hideNumberOnTitle'),
    footerText: r.text('footerText').trim(),
  );
}
