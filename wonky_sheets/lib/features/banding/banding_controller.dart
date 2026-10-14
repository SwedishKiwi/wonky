import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../sheet_editor/sheet_editor_controller.dart';

/// The alternating colors being edited in the panel (06 §14.2): previewed on
/// the grid, committed by *Done*.
@immutable
class BandingDraft {
  const BandingDraft({
    required this.sheetId,
    required this.range,
    required this.style,
    this.bandingId,
  });

  final String sheetId;

  /// The banding being edited (null = a new one).
  final String? bandingId;

  /// The range (null while the range input is invalid).
  final GridRect? range;
  final BandingStyle style;

  BandingDraft copyWith({GridRect? range, BandingStyle? style}) => BandingDraft(
    sheetId: sheetId,
    bandingId: bandingId,
    range: range ?? this.range,
    style: style ?? this.style,
  );
}

/// Alternating colors of an open spreadsheet: lookups for the panel and the
/// live preview of the draft through `WorkbookModel.bandingPreview`.
class BandingController extends ChangeNotifier {
  BandingController(this.editor);

  final SheetEditorController editor;
  BandingDraft? _draft;

  BandingDraft? get draft => _draft;

  /// The draft's range, outlined on the grid while the panel edits it.
  final ValueNotifier<List<GridRect>?> highlight = ValueNotifier(null);

  WorkbookModel get model => editor.model;

  /// Previews [d] (null ends the preview).
  void setDraft(BandingDraft? d) {
    _draft = d;
    final r = d?.range;
    highlight.value = r == null ? null : [r];
    model.bandingPreview = d == null ? null : _preview;
    editor.cells.invalidate();
    editor.contentSignal.fire();
    notifyListeners();
  }

  (String?, bool)? _preview(SheetModel s, int row, int col) {
    final d = _draft;
    if (d == null || s.id != d.sheetId) return null;
    final r = d.range;
    if (r != null && r.contains(row, col)) {
      return d.style.contributionIn(
        r,
        row,
        col,
        rows: s.rows,
        columns: s.columns,
      );
    }
    // The edited banding and bandings the draft will replace show nothing.
    for (final id in s.rulesAt(RuleKind.banding, row, col)) {
      if (id == d.bandingId) return (null, false);
      if (r != null &&
          s.ruleRects(RuleKind.banding, id).any((x) => x.intersects(r))) {
        return (null, false);
      }
    }
    return null;
  }

  /// The banding of [sheetId] intersecting [rect] (the panel edits it), or
  /// null.
  BandingRecord? bandingAt(String sheetId, GridRect rect) {
    final s = model.sheet(sheetId);
    if (s == null) return null;
    final ids = s.rulesIntersecting(RuleKind.banding, rect);
    return ids.isEmpty ? null : s.bandings[ids.first];
  }

  /// The resolved range of a banding.
  GridRect? rangeOf(String sheetId, String bandingId) {
    final s = model.sheet(sheetId);
    if (s == null) return null;
    final rects = s.ruleRects(RuleKind.banding, bandingId);
    return rects.isEmpty ? null : rects.first;
  }

  /// Custom styles used by bandings of this spreadsheet (06 §14.2 "saved
  /// custom styles"), excluding the theme presets.
  List<BandingStyle> customStyles() {
    final presets = BandingStyle.presets(model.theme).toSet();
    final out = <BandingStyle>{};
    for (final s in model.sheets) {
      for (final b in s.bandings.values) {
        final st = BandingStyle.parse(b.styleJson);
        final norm = BandingStyle(
          header: st.header,
          firstBand: st.firstBand,
          secondBand: st.secondBand,
          footer: st.footer,
        );
        if (!presets.contains(norm)) out.add(norm);
      }
    }
    return out.toList();
  }

  @override
  void dispose() {
    if (_draft != null) model.bandingPreview = null;
    highlight.dispose();
    super.dispose();
  }
}
