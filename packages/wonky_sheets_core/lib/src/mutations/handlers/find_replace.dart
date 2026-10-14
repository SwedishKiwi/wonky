import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../data_tools/find/find_engine.dart';
import '../../data_tools/find/find_query.dart';
import '../../data_tools/protection/protection_guard.dart';
import '../../model/schema.dart';
import '../../rules/conditions/display_text.dart';
import '../operations.dart';
import '../plan_builder.dart';
import '../row_change.dart';
import 'helpers.dart';
import 'row_tools.dart';
import 'values.dart';

/// [FindReplace] (07 §11.3): *Replace all* over the scope (a range, the
/// given sheets, or all visible sheets in order) or a single *Replace* in
/// [FindReplace.onlyCell]. Values are replaced in their edit text and parsed
/// like typed input; formulas in their A1 text (*search within formulas*) and
/// stored again; rich text keeps its runs; links (*search within links*) are
/// rewritten. Spill/pivot output and display-only matches are skipped. Cells
/// the user can't edit are skipped (a single *Replace* on one is refused with
/// `protected_range`). Invalid regular expressions → `invalid_argument`.
///
/// Result: `replaced` (instances), `cells`, `skipped`, `skippedProtected`,
/// `hiddenRows` (replaced cells in hidden rows) and the toast `message`.
MutationPlan planFindReplace(PlanBuilder b, FindReplace op) {
  final single = op.onlyCell != null;
  final label = single ? 'Replace' : 'Replace all';
  final values = planValues(b);
  final engine = FindEngine(
    b.model,
    CellTextReader(values, FormatterDisplayText(locale: b.locale)),
    hooks: b.ctx.formulas,
    locale: b.locale,
  );
  final queries = _queries(b, op);
  final matches = <FindMatch>[];
  try {
    _query(op, FindScope.allSheets).compile();
    for (final q in queries) {
      matches.addAll(engine.find(q, cap: 1 << 30).matches);
    }
  } on FindPatternException catch (e) {
    throw PlanException('invalid_argument', e.message);
  }
  final guard = ProtectionGuard(b.model);
  bool canEdit(String sheetId, int row, int col) {
    final s = b.model.sheet(sheetId);
    if (s == null || s.protections.isEmpty) return true;
    return !guard
        .check(
          CellWrites(sheetId, [GridRect(row, col, row, col)]),
          b.ctx.userId,
          isOwner: b.ctx.isOwner,
        )
        .isBlocked;
  }

  final plan = ReplaceEngine(engine).plan(
    _query(op, FindScope.allSheets),
    op.replacement,
    matches,
    canEdit: canEdit,
  );
  if (single && plan.protectedCount > 0) {
    throw const PlanException('protected_range', GuardResult.blockedMessage);
  }
  for (final r in plan.replacements) {
    final s = b.sheetOf(r.sheetId);
    final rowId = s.rows.idAt(r.row);
    final colId = s.columns.idAt(r.col);
    final Map<String, Object?> writes;
    if (r.newFormulaA1 != null) {
      final stored = b.formulas.toStored(
        r.newFormulaA1!,
        sheetId: s.id,
        row: r.row,
        col: r.col,
        locale: b.locale,
      );
      writes = {CellCols.content: stored.startsWith('=') ? stored : '=$stored'};
    } else if (r.newRichText != null) {
      final n = r.newRichText!.normalize();
      writes = {
        CellCols.content: n.rich == null
            ? TextContent(r.newRichText!.text).encode()
            : RichTextContent(n.rich!).encode(),
      };
    } else if (r.newLinkUrl != null) {
      writes = {CellCols.linkUrl: r.newLinkUrl!.isEmpty ? null : r.newLinkUrl};
    } else {
      writes = inputColumns(
        b,
        s,
        rowId,
        colId,
        r.row,
        r.col,
        CellInput.user(r.newEditText ?? ''),
      );
    }
    b.writeCell(s.id, rowId, colId, writes);
    b.summary.sheets.add(s.id);
  }
  final count = plan.instanceCount;
  b.result['replaced'] = count;
  b.result['cells'] = plan.replacements.length;
  b.result['skipped'] = plan.skipped.length;
  b.result['skippedProtected'] = plan.protectedCount;
  b.result['hiddenRows'] = plan.hiddenRowCount;
  final hidden = plan.hiddenRowCount > 0
      ? ' (including ${plan.hiddenRowCount} in hidden rows)'
      : '';
  b.result['message'] = count == 0
      ? "No instances of '${op.find}' were replaced."
      : "Replaced $count instance${count == 1 ? '' : 's'} of '${op.find}' "
            "with '${op.replacement}'$hidden.";
  if (plan.protectedCount > 0) {
    final n = plan.protectedCount;
    b.warnings.add(
      '$n cell${n == 1 ? ' was' : 's were'} skipped because '
      '${n == 1 ? 'it is' : 'they are'} protected.',
    );
  }
  return b.build(label, kinds: [ChangeKinds.values]);
}

FindQuery _query(
  FindReplace op,
  FindScope scope, {
  String? sheetId,
  GridRect? range,
}) => FindQuery(
  op.find,
  matchCase: op.matchCase,
  entireCell: op.matchEntireCell,
  regex: op.useRegex,
  searchFormulas: op.searchFormulas,
  searchLinks: op.searchLinks,
  scope: scope,
  sheetId: sheetId,
  range: range,
);

List<FindQuery> _queries(PlanBuilder b, FindReplace op) {
  FindQuery q(FindScope scope, {String? sheetId, GridRect? range}) =>
      _query(op, scope, sheetId: sheetId, range: range);
  final only = op.onlyCell;
  if (only != null) {
    final (sheetId, row, col) = only;
    final s = b.sheetOf(sheetId);
    final rect = GridRect(row, col, row, col);
    b.checkRect(s, rect);
    return [q(FindScope.range, sheetId: sheetId, range: rect)];
  }
  final range = op.range;
  if (range != null) {
    b.checkRect(b.sheetOf(range.sheetId), range.rect);
    b.addResolvedRange(range);
    return [q(FindScope.range, sheetId: range.sheetId, range: range.rect)];
  }
  final ids = op.sheetIds;
  if (ids == null) return [q(FindScope.allSheets)];
  return [for (final id in ids) q(FindScope.sheet, sheetId: b.sheetOf(id).id)];
}
