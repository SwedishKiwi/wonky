import 'dart:convert';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../engine_bridge/stored_formula.dart';
import '../../format/attributes.dart';
import '../../input/input_parser.dart';
import '../../model/events.dart';
import '../../model/grid_range.dart';
import '../../model/schema.dart';
import '../operations.dart';
import '../plan_builder.dart';
import '../row_change.dart';
import 'helpers.dart';
import 'move.dart';
import 'rules.dart';

/// [PasteClipboard] (03 §12.3–§12.5).
MutationPlan planPaste(PlanBuilder b, PasteClipboard op) {
  final src = op.source;
  final s = b.sheetOf(op.target.sheetId);
  final h0 = src.rowCount;
  final w0 = src.colCount;
  if (h0 == 0 || w0 == 0) return b.build('Paste');
  final transposed = op.mode == PasteMode.transposed;
  final h = transposed ? w0 : h0;
  final w = transposed ? h0 : w0;
  final sameSpreadsheet =
      src.spreadsheetId == null || src.spreadsheetId == b.model.spreadsheetId;

  // Paste after cut within the spreadsheet = move. A cut whose copy skipped
  // hidden rows/columns moves only the copied (visible) cells (03 §12.6).
  if (src.isCut &&
      sameSpreadsheet &&
      src.sheetId != null &&
      op.mode == PasteMode.all) {
    final srcSheet = b.sheetOf(src.sheetId!);
    final top = op.target.rect.top;
    final left = op.target.rect.left;
    applyBlockMove(b, srcSheet, s, [
      for (final (sr, pr, rn) in _runs(h0, src.sourceRowOf))
        for (final (sc, pc, cn) in _runs(w0, src.sourceColOf))
          (
            GridRect(sr, sc, sr + rn - 1, sc + cn - 1),
            GridRect(
              top + pr,
              left + pc,
              top + pr + rn - 1,
              left + pc + cn - 1,
            ),
          ),
    ]);
    b.result['range'] = GridRect(top, left, top + h0 - 1, left + w0 - 1);
    b.result['cells'] = h0 * w0;
    return b.build('Paste', kinds: [ChangeKinds.values, ChangeKinds.format]);
  }

  // Target rectangle: tile when the selection is an exact multiple.
  final sel = op.target.rect;
  final tile =
      sel.rowCount % h == 0 &&
      sel.colCount % w == 0 &&
      (sel.rowCount > h || sel.colCount > w);
  final t = tile
      ? sel
      : GridRect(sel.top, sel.left, sel.top + h - 1, sel.left + w - 1);
  final cells = t.cellCount;
  b.result['range'] = t;
  final (rowIdAt, colIdAt) = ensureGridSize(b, s, t.bottom + 1, t.right + 1);
  if (t.bottom < s.rows.length && t.right < s.columns.length) {
    checkMergesNotSplit(s, t);
  }
  final hooks = b.ctx.formulas;

  PasteCell? sourceAt(int r, int c) {
    final rr = r % h;
    final cc = c % w;
    final (sr, sc) = transposed ? (cc, rr) : (rr, cc);
    final row = src.cells[sr];
    return sc < row.length ? row[sc] : null;
  }

  (int, int) sourcePos(int r, int c) {
    final rr = r % h;
    final cc = c % w;
    return transposed
        ? (src.sourceRow + cc, src.sourceCol + rr)
        : (src.sourceRow + rr, src.sourceCol + cc);
  }

  String? contentFor(
    PasteCell pc,
    int tr,
    int tc,
    int r,
    int c, {
    required bool valuesOnly,
  }) {
    if (valuesOnly) {
      if (pc.storedFormula != null || pc.formulaA1 != null) {
        return pc.value == null
            ? null
            : CellContent.fromValue(pc.value!)?.encode();
      }
    }
    if (pc.storedFormula != null &&
        sameSpreadsheet &&
        hooks != null &&
        src.sheetId != null) {
      final (sr, sc) = sourcePos(r, c);
      return hooks.translate(
        pc.storedFormula!,
        fromSheetId: src.sheetId!,
        fromRow: sr,
        fromCol: sc,
        toSheetId: s.id,
        toRow: tr,
        toCol: tc,
      );
    }
    if ((pc.formulaA1 != null || pc.storedFormula != null) && hooks != null) {
      final a1 = pc.formulaA1 ?? pc.storedFormula!;
      return hooks.toStored(
        a1,
        sheetId: s.id,
        row: tr,
        col: tc,
        locale: 'en_US',
      );
    }
    if (pc.content != null) return pc.content!.encode();
    if (pc.text != null) {
      final parsed = InputParser.instance.parse(
        pc.text!,
        locale: b.locale,
        today: b.ctx.now,
      );
      if (parsed.isFormula) {
        if (hooks == null) return TextContent(pc.text!).encode();
        return hooks.toStored(
          parsed.formulaA1!,
          sheetId: s.id,
          row: tr,
          col: tc,
          locale: b.locale,
        );
      }
      return parsed.content?.encode();
    }
    return pc.value == null ? null : CellContent.fromValue(pc.value!)?.encode();
  }

  final borderCols = {for (final a in FormatAttr.borders) a.column};
  for (var r = 0; r < t.rowCount; r++) {
    for (var c = 0; c < t.colCount; c++) {
      final tr = t.top + r;
      final tc = t.left + c;
      final rowId = rowIdAt(tr);
      final colId = colIdAt(tc);
      final pc = sourceAt(r, c);
      final writes = <String, Object?>{};
      final withContent =
          op.mode != PasteMode.format &&
          op.mode != PasteMode.columnWidths &&
          op.mode != PasteMode.conditionalFormatting &&
          op.mode != PasteMode.dataValidation;
      final withFormat =
          op.mode == PasteMode.all ||
          op.mode == PasteMode.format ||
          op.mode == PasteMode.transposed ||
          op.mode == PasteMode.allExceptBorders;
      if (withContent) {
        writes[CellCols.content] = pc == null
            ? null
            : contentFor(
                pc,
                tr,
                tc,
                r,
                c,
                valuesOnly: op.mode == PasteMode.valuesOnly,
              );
        if (op.mode != PasteMode.valuesOnly && op.mode != PasteMode.formulas) {
          writes[CellCols.note] = pc?.note;
        }
      }
      if (withFormat) {
        final f = pc?.format ?? CellFormat.empty;
        for (final a in FormatAttr.values) {
          if (op.mode == PasteMode.allExceptBorders &&
              borderCols.contains(a.column)) {
            continue;
          }
          writes[a.column] = a.toColumnValue(f[a]);
        }
      }
      if (writes.isEmpty) continue;
      b.writeCell(s.id, rowId, colId, writes);
    }
  }

  // Merges (tiled).
  if ((op.mode == PasteMode.all ||
          op.mode == PasteMode.format ||
          op.mode == PasteMode.transposed) &&
      t.bottom < s.rows.length &&
      t.right < s.columns.length) {
    for (final (id, m) in s.mergesIntersecting(t)) {
      if (t.containsRect(m)) b.delete(SheetsTables.mergedRange, id);
    }
  }
  if (op.mode == PasteMode.all ||
      op.mode == PasteMode.format ||
      op.mode == PasteMode.transposed) {
    for (var tr = 0; tr < t.rowCount; tr += h) {
      for (var tc = 0; tc < t.colCount; tc += w) {
        for (final m0 in src.merges) {
          final m = transposed
              ? GridRect(m0.left, m0.top, m0.right, m0.bottom)
              : m0;
          final g = GridRect(
            t.top + tr + m.top,
            t.left + tc + m.left,
            t.top + tr + m.bottom,
            t.left + tc + m.right,
          );
          if (g.bottom > t.bottom || g.right > t.right) continue;
          b.insert(SheetsTables.mergedRange, b.ctx.ids.newId(), {
            Cols.sheetId: s.id,
            Cols.rangeJson: GridRange(
              sheetId: s.id,
              r1: rowIdAt(g.top),
              r2: rowIdAt(g.bottom),
              c1: colIdAt(g.left),
              c2: colIdAt(g.right),
            ).encode(),
          });
        }
      }
    }
  }

  // Rule formulas are relative to the top-left of the rule's first range
  // (06 §15.3): re-anchor them from the source anchor to the new one, the
  // same translation pasted cell formulas get (per tile, since the new rule
  // spans all tiles from its first rectangle).
  final canTranslate = sameSpreadsheet && hooks != null && src.sheetId != null;
  (int, int) sourceOfTarget(int row, int col) {
    final pr = (row - t.top) % h;
    final pc = (col - t.left) % w;
    return (src.sourceRowOf(pr), src.sourceColOf(pc));
  }

  String reanchor(
    String json,
    (int, int)? anchor,
    List<GridRect> rules,
    GridRect first,
  ) {
    if (!canTranslate || rules.isEmpty || !json.contains('=')) return json;
    final a0 =
        anchor ??
        (src.sourceRowOf(rules.first.top), src.sourceColOf(rules.first.left));
    final (pr, pc) = sourceOfTarget(first.top, first.left);
    return _mapRuleFormulas(json, (f) {
      var out = f;
      if (a0 != (pr, pc)) {
        out = hooks.translate(
          out,
          fromSheetId: src.sheetId!,
          fromRow: a0.$1,
          fromCol: a0.$2,
          toSheetId: src.sheetId!,
          toRow: pr,
          toCol: pc,
        );
      }
      return hooks.translate(
        out,
        fromSheetId: src.sheetId!,
        fromRow: pr,
        fromCol: pc,
        toSheetId: s.id,
        toRow: first.top,
        toCol: first.left,
      );
    });
  }

  // Data validation.
  if ((op.mode == PasteMode.all || op.mode == PasteMode.dataValidation) &&
      src.internal) {
    if (t.bottom < s.rows.length && t.right < s.columns.length) {
      clearValidationIn(b, s, [t]);
    }
    for (var k = 0; k < src.dvRules.length; k++) {
      final rule = src.dvRules[k];
      final rects = <GridRange>[];
      GridRect? first;
      for (var tr = 0; tr < t.rowCount; tr += h) {
        for (var tc = 0; tc < t.colCount; tc += w) {
          for (final r0 in rule.rects) {
            final g = r0.shift(t.top + tr, t.left + tc);
            final cl = g.intersection(t);
            if (cl == null) continue;
            first ??= cl;
            rects.add(
              GridRange(
                sheetId: s.id,
                r1: rowIdAt(cl.top),
                r2: rowIdAt(cl.bottom),
                c1: colIdAt(cl.left),
                c2: colIdAt(cl.right),
              ),
            );
          }
        }
      }
      if (rects.isEmpty) continue;
      b.insert(SheetsTables.dataValidationRule, b.ctx.ids.newId(), {
        Cols.sheetId: s.id,
        Cols.rangesJson: GridRange.encodeList(rects),
        'criteriaJson': reanchor(
          rule.criteriaJson,
          k < src.dvAnchors.length ? src.dvAnchors[k] : null,
          rule.rects,
          first!,
        ),
        'strict': rule.strict,
        'showDropdown': rule.displayStyle != 'plainText',
        'displayStyle': rule.displayStyle,
        'helpText': rule.helpText,
      });
    }
  }

  // Conditional formatting (identical rules merge their ranges).
  if ((op.mode == PasteMode.all ||
          op.mode == PasteMode.conditionalFormatting) &&
      src.internal) {
    for (var k = 0; k < src.cfRules.length; k++) {
      final rule = src.cfRules[k];
      final rects = <GridRect>[];
      for (var tr = 0; tr < t.rowCount; tr += h) {
        for (var tc = 0; tc < t.colCount; tc += w) {
          for (final r0 in rule.rects) {
            final cl = r0.shift(t.top + tr, t.left + tc).intersection(t);
            if (cl != null) rects.add(cl);
          }
        }
      }
      if (rects.isEmpty ||
          t.bottom >= s.rows.length ||
          t.right >= s.columns.length) {
        continue;
      }
      final json = reanchor(
        rule.ruleJson,
        k < src.cfAnchors.length ? src.cfAnchors[k] : null,
        rule.rects,
        rects.first,
      );
      // An identical rule (formulas compared at its own anchor) absorbs the
      // pasted ranges.
      String atAnchorOf(GridRect anchor) =>
          !canTranslate || json == rule.ruleJson
          ? json
          : _mapRuleFormulas(
              json,
              (f) => hooks.translate(
                f,
                fromSheetId: s.id,
                fromRow: rects.first.top,
                fromCol: rects.first.left,
                toSheetId: s.id,
                toRow: anchor.top,
                toCol: anchor.left,
              ),
            );
      final existing = sameSpreadsheet
          ? s.cfRules.values.where((x) {
              final cur = s.ruleRects(RuleKind.conditionalFormat, x.id);
              return cur.isNotEmpty && x.ruleJson == atAnchorOf(cur.first);
            }).firstOrNull
          : null;
      if (existing != null) {
        final cur = s.ruleRects(RuleKind.conditionalFormat, existing.id);
        b.update(SheetsTables.conditionalFormatRule, existing.id, {
          Cols.rangesJson: b.rangesJson(s, [...cur, ...rects]),
        });
      } else {
        planAddCfRule(b, AddCfRule(s.id, rects, json));
      }
    }
  }

  // Column widths.
  if (op.mode == PasteMode.columnWidths) {
    for (var c = 0; c < t.colCount; c++) {
      final wpx = c % w < src.columnWidths.length
          ? src.columnWidths[c % w]
          : null;
      b.update(SheetsTables.sheetColumn, colIdAt(t.left + c), {
        DimCols.width: wpx,
      });
    }
  }

  if (t.bottom < s.rows.length && t.right < s.columns.length) {
    b.addResolvedRange(ResolvedRange(s.id, t));
  }
  b.result['cells'] = cells;
  final label = switch (op.mode) {
    PasteMode.all => 'Paste',
    PasteMode.valuesOnly => 'Paste values only',
    PasteMode.format => 'Paste format only',
    PasteMode.formulas => 'Paste formula only',
    PasteMode.conditionalFormatting => 'Paste conditional formatting only',
    PasteMode.dataValidation => 'Paste data validation only',
    PasteMode.columnWidths => 'Paste column widths only',
    PasteMode.transposed => 'Paste transposed',
    PasteMode.allExceptBorders => 'Paste all except borders',
  };
  return b.build(label, kinds: [ChangeKinds.values, ChangeKinds.format]);
}

/// Maximal runs of consecutive source indices among `0..n-1` mapped by
/// [sourceOf], as `(source start, payload start, length)`.
List<(int, int, int)> _runs(int n, int Function(int) sourceOf) {
  final out = <(int, int, int)>[];
  for (var i = 0; i < n; i++) {
    final si = sourceOf(i);
    if (out.isNotEmpty) {
      final (s0, p0, len) = out.last;
      if (s0 + len == si) {
        out[out.length - 1] = (s0, p0, len + 1);
        continue;
      }
    }
    out.add((si, i, 1));
  }
  return out;
}

/// Applies [f] to the formulas (`=…` strings) of a CF/DV JSON; the original
/// text when nothing changes or the JSON is invalid.
String _mapRuleFormulas(String json, String Function(String) f) {
  Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return json;
  }
  final (out, changed) = StoredFormula.mapJsonFormulas(decoded, f);
  return changed ? jsonEncode(out) : json;
}
