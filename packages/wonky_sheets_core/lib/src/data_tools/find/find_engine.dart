import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../content/rich_text.dart';
import '../../engine_bridge/formula_hooks.dart';
import '../../format/attributes.dart';
import '../../formula/parser/formula_locale.dart';
import '../../formula/values/format_hint.dart';
import '../../formula/values/numeric.dart';
import '../../model/records.dart';
import '../../model/sheet_model.dart';
import '../../model/workbook_model.dart';
import '../../rules/conditions/display_text.dart';
import 'find_query.dart';

/// What part of a cell matched.
enum FindMatchKind {
  /// The display text (non-formula cells, formula results, overlays).
  value,

  /// The A1 formula text (*Also search within formulas*).
  formula,

  /// The cell link or a link run (*Also search within links*).
  link,
}

/// One match.
final class FindMatch {
  /// Creates a match.
  const FindMatch(
    this.sheetId,
    this.row,
    this.col,
    this.kind, {
    this.isOverlay = false,
    this.inHiddenRow = false,
  });

  final String sheetId;
  final int row;
  final int col;
  final FindMatchKind kind;

  /// A spill/pivot output cell (found, never replaced).
  final bool isOverlay;

  /// The row is hidden (filter, group, user).
  final bool inHiddenRow;

  @override
  bool operator ==(Object other) =>
      other is FindMatch &&
      other.sheetId == sheetId &&
      other.row == row &&
      other.col == col &&
      other.kind == kind &&
      other.isOverlay == isOverlay;

  @override
  int get hashCode => Object.hash(sheetId, row, col, kind, isOverlay);

  @override
  String toString() => 'FindMatch($sheetId!${CellPos(row, col).a1}, ${kind.name})';
}

/// Result of [FindEngine.find].
final class FindResult {
  /// Creates a result.
  const FindResult(this.matches, {this.capped = false});

  /// Matches in navigation order.
  final List<FindMatch> matches;

  /// Whether the 100,000 cap was reached ("100,000+ matches").
  final bool capped;

  /// Matches in hidden rows.
  int get hiddenRowCount => matches.where((m) => m.inHiddenRow).length;
}

/// Scans sheets for matches (07 §11.3–11.4).
final class FindEngine {
  /// Creates the engine. [overlayCells] lists spill/pivot output cells of a
  /// sheet (from the engine's overlay index); without it overlays are not searched.
  FindEngine(
    this.model,
    this.reader, {
    this.hooks,
    String? locale,
    this.overlayCells,
  }) : locale = locale ?? model.spreadsheet.locale;

  final WorkbookModel model;
  final CellTextReader reader;
  final FormulaHooks? hooks;
  final String locale;
  final Iterable<CellPos> Function(String sheetId)? overlayCells;

  /// Maximum number of matches.
  static const int maxMatches = 100000;

  /// The A1 text of a formula cell (stored text when no hooks are given).
  String formulaText(String sheetId, int row, int col, String stored) =>
      hooks?.toA1(stored, sheetId: sheetId, row: row, col: col, locale: locale) ?? stored;

  /// The kind of the first match in the cell, or null.
  FindMatchKind? matchCell(FindMatcher m, FindQuery q, SheetModel sheet, int row, int col, CellRecord? cell) {
    final content = cell?.decoded;
    if (content is FormulaContent && q.searchFormulas) {
      if (m.matches(formulaText(sheet.id, row, col, content.text))) return FindMatchKind.formula;
    }
    final v = reader.valueAt(sheet.id, row, col);
    if (!v.isBlank()) {
      final t = reader.display.displayText(v, reader.numberFormatAt(sheet.id, row, col));
      if (m.matches(t)) return FindMatchKind.value;
    }
    if (q.searchLinks && cell != null) {
      final link = cell.format[FormatAttr.linkUrl] as String?;
      if (link != null && m.matches(link)) return FindMatchKind.link;
      if (content is RichTextContent && content.rich.links.any(m.matches)) return FindMatchKind.link;
    }
    return null;
  }

  List<SheetModel> _sheets(FindQuery q, String? startSheetId) {
    if (q.scope == FindScope.allSheets) {
      final all = model.visibleSheets;
      final i = all.indexWhere((s) => s.id == startSheetId);
      if (i <= 0) return all;
      return [...all.sublist(i), ...all.sublist(0, i)];
    }
    final s = model.sheet(q.sheetId ?? startSheetId ?? '');
    return s == null ? const [] : [s];
  }

  /// Finds all matches in navigation order: row-major starting after the
  /// start cell ([includeStart] includes it), wrapping; *All sheets* continues
  /// in sheet order (hidden sheets skipped). [skipHidden] omits hidden rows
  /// (find navigation); replace-all keeps them.
  FindResult find(
    FindQuery q, {
    String? startSheetId,
    int startRow = 0,
    int startCol = -1,
    bool includeStart = false,
    bool skipHidden = false,
    int cap = maxMatches,
    bool Function()? isCancelled,
  }) {
    final m = q.compile();
    final sheets = _sheets(q, startSheetId);
    final before = <FindMatch>[];
    final after = <FindMatch>[];
    var total = 0;
    var capped = false;
    outer:
    for (final sheet in sheets) {
      final grid = sheet.gridRect;
      if (grid == null) continue;
      final rect = q.scope == FindScope.range && q.range != null ? q.range!.intersection(grid) : grid;
      if (rect == null) continue;
      final overlay = <CellPos>{
        for (final p in overlayCells?.call(sheet.id) ?? const <CellPos>[])
          if (rect.contains(p.row, p.col)) p,
      };
      final positions = <(int, int, CellRecord?)>[
        for (final (r, c, cell) in sheet.cellsIn(rect, contentOnly: !q.searchLinks)) (r, c, cell),
      ];
      if (overlay.isNotEmpty) {
        final have = {for (final p in positions) CellPos(p.$1, p.$2)};
        for (final p in overlay) {
          if (!have.contains(p)) positions.add((p.row, p.col, null));
        }
        positions.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
      }
      final isStart = sheet.id == startSheetId;
      for (final (r, c, cell) in positions) {
        if ((total & 0x3ff) == 0 && (isCancelled?.call() ?? false)) break outer;
        final hidden = sheet.rows.isHidden(r);
        if (skipHidden && hidden) continue;
        final kind = matchCell(m, q, sheet, r, c, cell);
        if (kind == null) continue;
        final match = FindMatch(sheet.id, r, c, kind, isOverlay: overlay.contains(CellPos(r, c)), inHiddenRow: hidden);
        final isBefore =
            isStart && (r < startRow || (r == startRow && (includeStart ? c < startCol : c <= startCol)));
        (isBefore ? before : after).add(match);
        total++;
        if (total >= cap) {
          capped = true;
          break outer;
        }
      }
    }
    return FindResult([...after, ...before], capped: capped);
  }
}

/// Why a matched cell is not replaced.
enum ReplaceSkipReason {
  /// Spill/pivot output.
  overlay,

  /// The match exists only in the display text (e.g. `$` of a currency format).
  displayOnly,

  /// The user can't edit the cell.
  protected,
}

/// A planned replacement (the planner turns it into writes).
final class CellReplacement {
  /// Creates a replacement.
  const CellReplacement(
    this.sheetId,
    this.row,
    this.col, {
    this.newEditText,
    this.newFormulaA1,
    this.newRichText,
    this.newLinkUrl,
    this.instances = 1,
  });

  final String sheetId;
  final int row;
  final int col;

  /// For values: the new edit text, to be parsed like typed input (03 §8.6).
  final String? newEditText;

  /// For formulas: the new A1 formula (with `=`), to be stored via `FormulaHooks.toStored`.
  final String? newFormulaA1;

  /// For rich text cells: the new rich text (runs re-offset); store as is.
  final RichText? newRichText;

  /// For link matches: the new `linkUrl`.
  final String? newLinkUrl;

  /// Replaced occurrences.
  final int instances;

  @override
  String toString() =>
      'CellReplacement(${CellPos(row, col).a1}, ${newEditText ?? newFormulaA1 ?? newRichText?.text ?? newLinkUrl})';
}

/// A skipped cell.
final class SkippedCell {
  /// Creates a skipped entry.
  const SkippedCell(this.sheetId, this.row, this.col, this.reason);

  final String sheetId;
  final int row;
  final int col;
  final ReplaceSkipReason reason;
}

/// Result of [ReplaceEngine.plan].
final class ReplacePlan {
  /// Creates a plan.
  const ReplacePlan(this.replacements, this.skipped, {this.hiddenRowCount = 0});

  final List<CellReplacement> replacements;
  final List<SkippedCell> skipped;

  /// Replaced cells in hidden rows (toast "(including 3 in hidden rows)").
  final int hiddenRowCount;

  /// Total replaced occurrences ("Replaced 12 instances of …").
  int get instanceCount => replacements.fold(0, (s, r) => s + r.instances);

  /// Number of protected skips ("12 cells were skipped because they are protected").
  int get protectedCount => skipped.where((s) => s.reason == ReplaceSkipReason.protected).length;
}

/// Computes replacements for find matches (07 §11.3).
final class ReplaceEngine {
  /// Creates the engine over a [FindEngine] (shares model, reader and hooks).
  const ReplaceEngine(this.find);

  final FindEngine find;

  /// The edit text of a value: what the cell editor shows (text; numbers in
  /// Automatic form with the locale decimal, dates/times as displayed;
  /// booleans; error literals).
  static String editText(CellValue v, String? numberFormat, String displayText, {String decimal = '.'}) =>
      switch (v) {
        EmptyValue() => '',
        TextValue(:final text) => text,
        NumberValue(:final number) =>
          numberFormat != null && FormatHint.looksLikeDatePattern(numberFormat)
              ? displayText
              : Numeric.toText(number, decimal: decimal),
        BoolValue(:final value) => value ? 'TRUE' : 'FALSE',
        ErrorValue(:final kind) => kind.literal,
      };

  /// Plans replacing [query] matches by [replacement] in [matches].
  /// [canEdit] reports whether the user may edit a cell (protection guard).
  ReplacePlan plan(
    FindQuery query,
    String replacement,
    Iterable<FindMatch> matches, {
    bool Function(String sheetId, int row, int col)? canEdit,
  }) {
    final m = query.compile();
    final out = <CellReplacement>[];
    final skipped = <SkippedCell>[];
    final seen = <(String, int, int)>{};
    var hidden = 0;
    final decimal = FormulaLocale.forId(find.locale).decimal;
    for (final match in matches) {
      if (!seen.add((match.sheetId, match.row, match.col))) continue;
      SkippedCell skip(ReplaceSkipReason r) => SkippedCell(match.sheetId, match.row, match.col, r);
      if (match.isOverlay) {
        skipped.add(skip(ReplaceSkipReason.overlay));
        continue;
      }
      if (canEdit != null && !canEdit(match.sheetId, match.row, match.col)) {
        skipped.add(skip(ReplaceSkipReason.protected));
        continue;
      }
      final sheet = find.model.sheet(match.sheetId);
      final cell = sheet?.cellAt(match.row, match.col);
      final content = cell?.decoded;
      CellReplacement? r;
      switch (match.kind) {
        case FindMatchKind.formula:
          if (content is FormulaContent) {
            final a1 = find.formulaText(match.sheetId, match.row, match.col, content.text);
            final (text, spans) = m.replaceAll(a1, replacement);
            if (spans.isNotEmpty) {
              r = CellReplacement(match.sheetId, match.row, match.col, newFormulaA1: text, instances: spans.length);
            }
          }
        case FindMatchKind.link:
          final link = cell?.format[FormatAttr.linkUrl] as String?;
          if (link != null && m.matches(link)) {
            final (text, spans) = m.replaceAll(link, replacement);
            r = CellReplacement(match.sheetId, match.row, match.col, newLinkUrl: text, instances: spans.length);
          }
        case FindMatchKind.value:
          if (content is FormulaContent || content == null) break;
          if (content is RichTextContent) {
            final (text, spans) = m.replaceAll(content.rich.text, replacement);
            if (spans.isNotEmpty) {
              r = CellReplacement(
                match.sheetId,
                match.row,
                match.col,
                newRichText: content.rich.remap(text, _offsetMap(spans)),
                instances: spans.length,
              );
            }
            break;
          }
          final v = content.literalValue;
          final fmt = find.reader.numberFormatAt(match.sheetId, match.row, match.col);
          final display = find.reader.display.displayText(v, fmt);
          final edit = editText(v, fmt, display, decimal: decimal);
          final (text, spans) = m.replaceAll(edit, replacement);
          if (spans.isNotEmpty) {
            r = CellReplacement(match.sheetId, match.row, match.col, newEditText: text, instances: spans.length);
          }
      }
      if (r == null) {
        skipped.add(skip(ReplaceSkipReason.displayOnly));
        continue;
      }
      if (match.inHiddenRow) hidden++;
      out.add(r);
    }
    return ReplacePlan(out, skipped, hiddenRowCount: hidden);
  }

  /// Maps old offsets to new ones given replaced spans (old start, old end,
  /// new start, new end): offsets inside a replaced span clamp into it.
  static int Function(int) _offsetMap(List<(int, int, int, int)> spans) => (o) {
    var delta = 0;
    for (final (os, oe, ns, ne) in spans) {
      if (o < os) break;
      if (o <= oe) {
        if (o == oe) return ne;
        final inside = o - os;
        return ns + (inside < ne - ns ? inside : ne - ns);
      }
      delta = ne - oe;
    }
    return o + delta;
  };
}
