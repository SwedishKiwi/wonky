import 'dart:convert';

import '../addressing/grid_geometry.dart';
import '../content/cell_content.dart';
import '../format/attributes.dart';
import '../model/grid_range.dart';

/// One copied cell (03 §12.2 item 3).
final class ClipCell {
  /// Creates a copied cell.
  ClipCell({
    required this.sourceRow,
    required this.sourceCol,
    this.content,
    this.value,
    this.formulaA1,
    CellFormat? format,
    this.note,
  }) : format = format ?? CellFormat.empty;

  /// Index of the source row / column on the source sheet (formulas are
  /// translated from here with `FormulaHooks.translate`).
  final int sourceRow;
  final int sourceCol;

  /// Encoded content (02 §2); formulas in stored-reference form.
  final String? content;

  /// The displayed value (formula results; used by *Paste values*).
  final CellValue? value;

  /// The formula as A1 text relative to its source cell (en_US separators),
  /// for pastes into another spreadsheet where stored ids don't resolve.
  final String? formulaA1;

  /// Effective explicit format (cell ▸ row ▸ column ▸ sheet), incl. `linkUrl`.
  final CellFormat format;
  final String? note;

  /// Whether the cell holds a formula.
  bool get isFormula => content != null && content!.startsWith('=');

  /// JSON map.
  Map<String, Object?> toJson() => {
    'r': sourceRow,
    'c': sourceCol,
    if (content != null) 'x': content,
    if (value != null && value is! EmptyValue)
      'v': CellContent.fromValue(value!)?.encode(),
    if (formulaA1 != null) 'a1': formulaA1,
    if (!format.isEmpty) 'f': format.toMap(),
    if (note != null) 'n': note,
  };

  /// From JSON.
  static ClipCell fromJson(Map<String, Object?> m) {
    final v = m['v'];
    final f = m['f'];
    return ClipCell(
      sourceRow: (m['r'] as num?)?.toInt() ?? 0,
      sourceCol: (m['c'] as num?)?.toInt() ?? 0,
      content: m['x'] as String?,
      value: v is String ? CellContent.decode(v)?.literalValue : null,
      formulaA1: m['a1'] as String?,
      format: f is Map
          ? CellFormat.fromMap(f.cast<String, Object?>())
          : CellFormat.empty,
      note: m['n'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ClipCell &&
      other.sourceRow == sourceRow &&
      other.sourceCol == sourceCol &&
      other.content == content &&
      other.value == value &&
      other.formulaA1 == formulaA1 &&
      other.format == format &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
    sourceRow,
    sourceCol,
    content,
    value,
    formulaA1,
    format,
    note,
  );

  @override
  String toString() => 'ClipCell(${toJson()})';
}

/// Kind of a copied range rule.
enum ClipRuleKind { dataValidation, conditionalFormat }

/// A DV or CF rule intersecting the copied range: its record columns (minus
/// ids and ranges), the intersecting rectangles relative to the payload grid,
/// and the anchor its formulas are relative to (06 §15.3, 07 §6.1).
final class ClipRule {
  /// Creates a rule.
  const ClipRule({
    required this.kind,
    required this.columns,
    required this.rects,
    required this.anchorRow,
    required this.anchorCol,
    this.sourceRuleId,
  });

  final ClipRuleKind kind;

  /// Record columns, e.g. `criteriaJson`, `strict`, `displayStyle`,
  /// `helpText` (DV) or `ruleJson`, `enabled`, `sortKey` (CF).
  final Map<String, Object?> columns;

  /// Rectangles in payload coordinates (0-based, copied rows/columns only).
  final List<GridRect> rects;

  /// Source sheet indices of the rule's formula anchor (top-left of its
  /// first range).
  final int anchorRow;
  final int anchorCol;
  final String? sourceRuleId;

  /// JSON map.
  Map<String, Object?> toJson() => {
    'k': kind.name,
    'cols': columns,
    'rects': [for (final r in rects) _rect(r)],
    'ar': anchorRow,
    'ac': anchorCol,
    if (sourceRuleId != null) 'id': sourceRuleId,
  };

  /// From JSON.
  static ClipRule fromJson(Map<String, Object?> m) => ClipRule(
    kind: ClipRuleKind.values.firstWhere(
      (k) => k.name == m['k'],
      orElse: () => ClipRuleKind.dataValidation,
    ),
    columns: (m['cols'] as Map?)?.cast<String, Object?>() ?? const {},
    rects: [
      for (final r in (m['rects'] as List? ?? const []))
        if (_parseRect(r) case final GridRect g) g,
    ],
    anchorRow: (m['ar'] as num?)?.toInt() ?? 0,
    anchorCol: (m['ac'] as num?)?.toInt() ?? 0,
    sourceRuleId: m['id'] as String?,
  );
}

List<int> _rect(GridRect r) => [r.top, r.left, r.bottom, r.right];

GridRect? _parseRect(Object? o) {
  if (o is! List || o.length != 4 || o.any((e) => e is! num)) return null;
  final v = [for (final e in o) (e as num).toInt()];
  return GridRect(v[0], v[1], v[2], v[3]);
}

/// The full internal clipboard payload (03 §12.2 item 3): copied cells
/// (visible rows/columns only), merges, DV/CF rules, sizes and the source.
final class SheetsClipboardPayload {
  /// Creates a payload.
  const SheetsClipboardPayload({
    required this.clipId,
    required this.spreadsheetId,
    required this.sheetId,
    required this.sourceRect,
    required this.sourceRange,
    required this.rowIndices,
    required this.colIndices,
    required this.cells,
    this.sheetName,
    this.locale = 'en_US',
    this.merges = const [],
    this.rules = const [],
    this.columnWidths = const [],
    this.rowHeights = const [],
    this.isCut = false,
  });

  /// Schema version.
  static const int version = 1;

  /// Id matching `data-wonky-clip` of the HTML representation.
  final String clipId;
  final String spreadsheetId;
  final String sheetId;
  final String? sheetName;
  final String locale;

  /// The copied range as indices (including hidden rows/columns in between).
  final GridRect sourceRect;

  /// The copied range by ids.
  final GridRange sourceRange;

  /// Source indices of the copied (visible) rows / columns, in order; payload
  /// row `i` is source row `rowIndices[i]`.
  final List<int> rowIndices;
  final List<int> colIndices;

  /// `rowCount × colCount` cells (null = empty).
  final List<List<ClipCell?>> cells;

  /// Merges, in payload coordinates.
  final List<GridRect> merges;
  final List<ClipRule> rules;

  /// Explicit widths (px) of the copied columns / heights of the rows
  /// (null = default).
  final List<double?> columnWidths;
  final List<double?> rowHeights;

  /// Whether this came from a cut (paste = move, 03 §12.6).
  final bool isCut;

  /// Number of copied rows.
  int get rowCount => rowIndices.length;

  /// Number of copied columns.
  int get colCount => colIndices.length;

  /// The cell at payload coordinates.
  ClipCell? cellAt(int row, int col) =>
      row < cells.length && col < cells[row].length ? cells[row][col] : null;

  /// Rules of [kind].
  Iterable<ClipRule> rulesOf(ClipRuleKind kind) =>
      rules.where((r) => r.kind == kind);

  /// A copy marked as cut / not cut.
  SheetsClipboardPayload withCut(bool cut) => SheetsClipboardPayload(
    clipId: clipId,
    spreadsheetId: spreadsheetId,
    sheetId: sheetId,
    sheetName: sheetName,
    locale: locale,
    sourceRect: sourceRect,
    sourceRange: sourceRange,
    rowIndices: rowIndices,
    colIndices: colIndices,
    cells: cells,
    merges: merges,
    rules: rules,
    columnWidths: columnWidths,
    rowHeights: rowHeights,
    isCut: cut,
  );

  /// JSON map (cells sparse: `[row, col, cell]`).
  Map<String, Object?> toJson() => {
    'v': version,
    'clip': clipId,
    'ss': spreadsheetId,
    's': sheetId,
    if (sheetName != null) 'sn': sheetName,
    'loc': locale,
    'rect': _rect(sourceRect),
    'range': sourceRange.toJson(),
    'ri': rowIndices,
    'ci': colIndices,
    'cells': [
      for (var r = 0; r < cells.length; r++)
        for (var c = 0; c < cells[r].length; c++)
          if (cells[r][c] != null) [r, c, cells[r][c]!.toJson()],
    ],
    if (merges.isNotEmpty) 'merges': [for (final m in merges) _rect(m)],
    if (rules.isNotEmpty) 'rules': [for (final r in rules) r.toJson()],
    if (columnWidths.any((w) => w != null)) 'cw': columnWidths,
    if (rowHeights.any((h) => h != null)) 'rh': rowHeights,
    if (isCut) 'cut': true,
  };

  /// JSON text.
  String encodeJson() => jsonEncode(toJson());

  /// Base64 of the UTF-8 JSON (the `<!--wonky:…-->` comment body).
  String encodeBase64() => base64Encode(utf8.encode(encodeJson()));

  /// Parses a JSON map; throws [FormatException] when malformed.
  static SheetsClipboardPayload fromJson(Map<String, Object?> m) {
    final v = m['v'];
    if (v is! num || v.toInt() > version) {
      throw const FormatException('Unsupported clipboard payload version');
    }
    final range = GridRange.tryParse(m['range']);
    final rect = _parseRect(m['rect']);
    if (range == null || rect == null) {
      throw const FormatException('Missing range');
    }
    List<int> ints(Object? o) => [
      for (final e in (o as List? ?? const [])) (e as num).toInt(),
    ];
    final rowIndices = ints(m['ri']);
    final colIndices = ints(m['ci']);
    final cells = List.generate(
      rowIndices.length,
      (_) => List<ClipCell?>.filled(colIndices.length, null),
    );
    for (final e in (m['cells'] as List? ?? const [])) {
      if (e is! List || e.length != 3) continue;
      final r = (e[0] as num).toInt();
      final c = (e[1] as num).toInt();
      if (r < 0 || c < 0 || r >= rowIndices.length || c >= colIndices.length) {
        continue;
      }
      cells[r][c] = ClipCell.fromJson((e[2] as Map).cast<String, Object?>());
    }
    List<double?> sizes(Object? o, int n) {
      final l = o as List?;
      return [
        for (var i = 0; i < n; i++)
          l != null && i < l.length && l[i] is num
              ? (l[i] as num).toDouble()
              : null,
      ];
    }

    return SheetsClipboardPayload(
      clipId: m['clip'] as String? ?? '',
      spreadsheetId: m['ss'] as String? ?? '',
      sheetId: m['s'] as String? ?? range.sheetId,
      sheetName: m['sn'] as String?,
      locale: m['loc'] as String? ?? 'en_US',
      sourceRect: rect,
      sourceRange: range,
      rowIndices: rowIndices,
      colIndices: colIndices,
      cells: cells,
      merges: [
        for (final r in (m['merges'] as List? ?? const []))
          if (_parseRect(r) case final GridRect g) g,
      ],
      rules: [
        for (final r in (m['rules'] as List? ?? const []))
          if (r is Map) ClipRule.fromJson(r.cast<String, Object?>()),
      ],
      columnWidths: sizes(m['cw'], colIndices.length),
      rowHeights: sizes(m['rh'], rowIndices.length),
      isCut: m['cut'] == true,
    );
  }

  /// Parses JSON text.
  static SheetsClipboardPayload decodeJson(String json) {
    final m = jsonDecode(json);
    if (m is! Map) throw const FormatException('Payload is not an object');
    return fromJson(m.cast<String, Object?>());
  }

  /// Parses a base64 comment body.
  static SheetsClipboardPayload decodeBase64(String b64) =>
      decodeJson(utf8.decode(base64Decode(b64.trim())));

  /// [decodeBase64], or null for malformed input.
  static SheetsClipboardPayload? tryDecodeBase64(String b64) {
    try {
      return decodeBase64(b64);
    } on Object {
      return null;
    }
  }
}
