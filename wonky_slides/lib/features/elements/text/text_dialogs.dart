import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../../l10n/slides_l10n.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../editor_screen/slide_labels.dart';

/// Asks for one value (font size, line spacing, list start, color…): a
/// `WonkyDialogSpec` text field, MCP-operable through `ui.get_dialog` /
/// `ui.fill_dialog`. Returns the entered text or null when cancelled.
Future<String?> showTextValueDialog(
  BuildContext context, {
  required String dialogKey,
  required String title,
  required String label,
  String initial = '',
  String? Function(String value)? validator,
}) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: title,
      dialogKey: dialogKey,
      fields: [
        TextFieldSpec(
          id: 'value',
          label: label,
          initial: initial,
          validator: validator,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'apply', label: l.dialogApply, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'apply') return null;
  return r!.text('value').trim();
}

/// Asks for one of [options] (font family, list style…). Returns the
/// chosen key or null.
Future<String?> showTextChoiceDialog(
  BuildContext context, {
  required String dialogKey,
  required String title,
  required String label,
  required Map<String, String> options,
  required String initial,
}) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: title,
      dialogKey: dialogKey,
      fields: [
        SelectFieldSpec(
          id: 'value',
          label: label,
          options: options,
          initial: options.containsKey(initial) ? initial : options.keys.first,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'apply', label: l.dialogApply, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'apply') return null;
  final v = r!.text('value');
  return v.isEmpty ? null : v;
}

/// The answer of [showLinkDialog].
sealed class LinkChoice {
  const LinkChoice();
}

/// Link to a web address (or `mailto:`).
class UrlLink extends LinkChoice {
  const UrlLink(this.url);
  final String url;
}

/// Link to a slide of this deck.
class SlideLink extends LinkChoice {
  const SlideLink(this.slideId);
  final String slideId;
}

/// An element action (`next`, `previous`, `first`, `last`, `end`).
class ActionLink extends LinkChoice {
  const ActionLink(this.action);
  final String action;
}

/// *Remove link*.
class RemoveLink extends LinkChoice {
  const RemoveLink();
}

/// The link dialog (04 §13.5, as a `WonkyDialogSpec` so MCP can fill it):
/// *Link to* — a web address, a slide of this deck (with group names) or,
/// for elements ([actions]), next/previous/first/last slide and end show —
/// and the address. *Remove link* when [canRemove].
Future<LinkChoice?> showLinkDialog(
  BuildContext context,
  DeckEditorController ed, {
  String initialUrl = '',
  String? initialSlideId,
  bool actions = false,
  bool canRemove = false,
}) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final options = <String, String>{
    'url': l.linkTargetUrl,
    for (final e in ed.order.entries)
      'slide:${e.id}': SlideLabels.goToLabel(
        ed.model,
        e,
        untitled: l.slideUntitled,
      ),
    if (actions) ...{
      'action:next': l.linkActionNext,
      'action:previous': l.linkActionPrevious,
      'action:first': l.linkActionFirst,
      'action:last': l.linkActionLast,
      'action:end': l.linkActionEnd,
    },
  };
  final initialTarget = initialSlideId != null
      ? 'slide:$initialSlideId'
      : 'url';
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.linkDialogTitle,
      dialogKey: 'dialog.slides.link',
      fields: [
        SelectFieldSpec(
          id: 'target',
          label: l.linkTargetLabel,
          options: options,
          initial: options.containsKey(initialTarget) ? initialTarget : 'url',
        ),
        TextFieldSpec(
          id: 'url',
          label: l.linkUrlLabel,
          initial: initialUrl,
          placeholder: 'https://',
        ),
      ],
      buttons: [
        if (canRemove) DialogButtonSpec(id: 'remove', label: l.linkRemove),
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'apply', label: l.dialogApply, primary: true),
      ],
    ),
  );
  switch (r?.buttonId) {
    case 'remove':
      return const RemoveLink();
    case 'apply':
      final target = r!.text('target');
      if (target.startsWith('slide:')) return SlideLink(target.substring(6));
      if (target.startsWith('action:')) return ActionLink(target.substring(7));
      final url = r.text('url').trim();
      return url.isEmpty ? null : UrlLink(url);
    default:
      return null;
  }
}
