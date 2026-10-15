import 'dart:convert';

import 'package:wonky_code_flutter/wonky_code_flutter.dart' show CodeLanguages;
import 'package:wonky_slides_core/code.dart';
import 'package:wonky_slides_core/model.dart' show ElementKind;

import '../../../l10n/slides_l10n.dart';
import '../../editor_screen/deck_editor_controller.dart';
import 'code_blocks.dart';

/// The toolbar's language button label (07 §3.5 language chip): the
/// language of the selected code block's edit state ("Dart", "Plain
/// text"), or null for the command title.
String? codeLanguageLabelOf(DeckEditorController ed) {
  final ids = ed.selectedElementIds;
  if (ids.length != 1) return null;
  final e = ed.model.element(ids.single);
  if (e == null || e.kind != ElementKind.code) return null;
  final state = CodeBlockView.of(ed).stateOf(e.id);
  final language =
      state?.language ??
      CodeElementData.fromJson(decodeCodeData(e.dataJson)).language;
  final normalized = CodeLanguages.normalize(language);
  return normalized.isEmpty
      ? slidesL10nOf(ed.services).codePlainText
      : CodeLanguages.displayName(normalized);
}

/// Decodes a code element's `dataJson` (null when absent or invalid).
Map<String, Object?>? decodeCodeData(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final v = jsonDecode(json);
    return v is Map ? v.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}
