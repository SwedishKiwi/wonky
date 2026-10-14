import 'package:wonky_sheets_core/formula.dart'
    show FormulaLexer, FormulaToken, TokenKind;
import 'package:wonky_sheets_core/model.dart';

import 'pivot_ranges.dart';
import 'pivot_spec_edit.dart';

/// Converts calculated field formulas (07 §7.3) between the text the user
/// edits — source headers as names (`='Unit price' * Quantity`) — and the
/// stored form with field tokens `⟦F:<colId>⟧` and id-based references.
class PivotFormulaText {
  PivotFormulaText({
    required this.fields,
    this.hooks,
    required this.sheetId,
    this.row = 0,
    this.col = 0,
    this.locale = 'en_US',
  });

  final List<PivotSourceField> fields;
  final FormulaHooks? hooks;
  final String sheetId;
  final int row;
  final int col;
  final String locale;

  static String _placeholder(int i) => '__pf${i}_';
  static final RegExp _placeholderRe = RegExp(
    r'__pf(\d+)_',
    caseSensitive: false,
  );

  int? _fieldIndex(String name) {
    final n = name.toLowerCase();
    for (var i = 0; i < fields.length; i++) {
      if (fields[i].header.toLowerCase() == n) return i;
    }
    return null;
  }

  /// User text → stored form (with `=`).
  String toStored(String text) {
    final t = text.trim();
    final body = t.startsWith('=') ? t.substring(1) : t;
    final tokens = const FormulaLexer(storedForm: false).tokenize(body);
    final out = StringBuffer();
    for (var k = 0; k < tokens.length; k++) {
      var tok = tokens[k];
      while (_quoted(tok) &&
          k + 1 < tokens.length &&
          _quoted(tokens[k + 1]) &&
          tokens[k + 1].start == tok.end) {
        final next = tokens[++k];
        tok = FormulaToken(
          TokenKind.unknown,
          tok.start,
          next.end,
          tok.text + next.text,
          tok.depth,
        );
      }
      final nextText = k + 1 < tokens.length ? tokens[k + 1].text : '';
      int? i;
      if (tok.kind == TokenKind.name && nextText != '(') {
        i = _fieldIndex(tok.text);
      } else if (_quoted(tok) && !nextText.startsWith('!')) {
        i = _fieldIndex(
          tok.text.substring(1, tok.text.length - 1).replaceAll("''", "'"),
        );
      }
      out.write(i == null ? tok.text : _placeholder(i));
    }
    var stored = '=$out';
    final h = hooks;
    if (h != null) {
      stored = h.toStored(
        stored,
        sheetId: sheetId,
        row: row,
        col: col,
        locale: locale,
      );
    }
    return stored.replaceAllMapped(_placeholderRe, (m) {
      final i = int.parse(m.group(1)!);
      return i < fields.length
          ? PivotFormula.tokenOf(fields[i].colId)
          : m.group(0)!;
    });
  }

  /// Stored form → user text (with `=`). Fields that no longer exist read
  /// `#REF!`.
  String toA1(String stored) {
    final s = stored.startsWith('=') ? stored : '=$stored';
    var text = s.replaceAllMapped(PivotFormula.token, (m) {
      final id = m.group(1)!;
      final i = fields.indexWhere((f) => f.colId == id);
      if (i < 0) return '#REF!';
      return _placeholder(i);
    });
    final h = hooks;
    if (h != null) {
      text = h.toA1(text, sheetId: sheetId, row: row, col: col, locale: locale);
    }
    return text.replaceAllMapped(_placeholderRe, (m) {
      final i = int.parse(m.group(1)!);
      if (i >= fields.length) return m.group(0)!;
      return sheetNameInA1(fields[i].header);
    });
  }

  static bool _quoted(FormulaToken t) =>
      t.kind == TokenKind.unknown &&
      t.text.length >= 2 &&
      t.text.startsWith("'") &&
      t.text.endsWith("'");
}
