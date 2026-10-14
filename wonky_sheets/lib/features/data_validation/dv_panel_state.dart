import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../common/range_input.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'dv_draft.dart';

/// Panel id (04 §10).
const dvPanelId = 'sheets.panel.dataValidation';

/// [DvFormulaCodec] through the editor's formula hooks (spreadsheet locale).
class EditorDvCodec implements DvFormulaCodec {
  const EditorDvCodec(this.editor);

  final SheetEditorController editor;

  @override
  String toStored(
    String a1, {
    required String sheetId,
    required int row,
    required int col,
  }) => editor.hooks.toStored(
    a1,
    sheetId: sheetId,
    row: row,
    col: col,
    locale: editor.locale,
  );

  @override
  String toA1(
    String stored, {
    required String sheetId,
    required int row,
    required int col,
  }) => editor.hooks.toA1(
    stored,
    sheetId: sheetId,
    row: row,
    col: col,
    locale: editor.locale,
  );
}

/// The data validation panel's state: the rule list, or a draft (07 §6.3).
class DvPanelState extends ChangeNotifier {
  DvPanelState._(this.editor);

  static DvPanelState of(SheetEditorController editor) =>
      editor.extension(DvPanelState, () {
        final s = DvPanelState._(editor);
        editor.onDispose(s.dispose);
        return s;
      });

  final SheetEditorController editor;

  DvDraft? _draft;
  DvDraft? get draft => _draft;

  /// Bumped when a new draft starts (resets the editor's fields).
  int generation = 0;

  /// Focus the first dropdown item when the editor opens (Insert ›
  /// Dropdown).
  bool focusFirstItem = false;

  set draft(DvDraft? d) {
    _draft = d;
    notifyListeners();
  }

  /// A1 text of [rects] on the draft's sheet (`A2:A500, C2:C9`).
  String rangesA1(String sheetId, List<GridRect> rects) {
    final model = editor.model;
    return rects
        .map(
          (r) => rangeToA1(
            model,
            ResolvedRange(sheetId, r),
            contextSheetId: editor.activeSheetId,
          ),
        )
        .join(', ');
  }

  /// Starts a new rule for [rangesText] (default: the selection).
  void startNew({String? rangesText, DvKind kind = DvKind.dropdown}) {
    generation++;
    focusFirstItem = false;
    draft = DvDraft(
      sheetId: editor.activeSheetId,
      rangesText: rangesText ?? _selectionA1(),
      kind: kind,
    );
  }

  /// Edits rule [ruleId] of [sheetId].
  bool edit(String sheetId, String ruleId, {bool focusFirstItem = false}) {
    final sheet = editor.model.sheet(sheetId);
    final record = sheet?.dvRules[ruleId];
    if (sheet == null || record == null) return false;
    generation++;
    this.focusFirstItem = focusFirstItem;
    draft = DvDraft.fromRule(
      record,
      sheet,
      rangesText: rangesA1(
        sheetId,
        sheet.ruleRects(RuleKind.dataValidation, ruleId),
      ),
      codec: EditorDvCodec(editor),
      rangeA1: (g) {
        final r = editor.model.resolve(g);
        return r == null
            ? ''
            : rangeToA1(editor.model, r, contextSheetId: editor.activeSheetId);
      },
    );
    return true;
  }

  String _selectionA1() => editor.selectedRanges
      .map(
        (r) => rangeToA1(
          editor.model,
          _clip(r),
          contextSheetId: editor.activeSheetId,
        ),
      )
      .join(', ');

  ResolvedRange _clip(ResolvedRange r) {
    final grid = editor.model.sheet(r.sheetId)?.gridRect;
    if (grid == null) return r;
    final rect = r.rect.intersection(grid) ?? r.rect;
    return ResolvedRange(
      r.sheetId,
      rect,
      wholeRows: r.wholeRows,
      wholeColumns: r.wholeColumns,
    );
  }

  /// Back to the list.
  void close() => draft = null;
}
