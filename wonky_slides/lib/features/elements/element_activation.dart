import 'dart:async';

import 'package:wonky_app/wonky_app.dart' show CommandContext;
import 'package:wonky_core/wonky_core.dart' show CommandResult, JsonArgs;

import '../editor_screen/deck_editor_controller.dart';

/// What `slides.element.activate` (double-click / Enter, 03 §3.4) does for
/// an element kind: [applies] says whether the selection is this kind's,
/// [run] activates it (images: crop mode or *Insert image* for an empty
/// picture placeholder; tables: edit the clicked or first cell — SL-15).
class ElementActivation {
  const ElementActivation({required this.applies, required this.run});

  final bool Function(DeckEditorController ed, JsonArgs args) applies;
  final FutureOr<CommandResult> Function(
    CommandContext ctx,
    DeckEditorController ed,
    JsonArgs args,
  )
  run;
}

/// The registry of [ElementActivation]s (element work packages register
/// theirs with their commands).
abstract final class ElementActivations {
  static final List<ElementActivation> _all = [];

  /// Registers [a] (idempotent per instance).
  static void register(ElementActivation a) {
    if (!_all.contains(a)) _all.add(a);
  }

  /// The activation that applies to [ed]'s selection, or null.
  static ElementActivation? of(DeckEditorController ed, JsonArgs args) {
    for (final a in _all) {
      if (a.applies(ed, args)) return a;
    }
    return null;
  }
}
