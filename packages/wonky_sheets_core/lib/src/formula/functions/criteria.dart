import 'dart:collection';

import '../parser/formula_locale.dart';
import '../values/coercion.dart';
import '../values/compare.dart';
import '../values/errors.dart';
import '../values/fvalue.dart';
import '../values/numeric.dart';

enum _Op { eq, ne, lt, gt, le, ge }

/// A compiled criterion of the COUNTIF/SUMIF/AVERAGEIF/MAXIFS/D-function families
/// (05 §15.14). Compiled once per criterion string (`ParsedCriteria` cache).
final class Criterion {
  final _Op _op;

  /// Operand: number, text, bool, error or empty (`"="` / `"<>"`).
  final FValue _operand;
  final RegExp? _wildcard;

  /// Whether the operand came from text that also matches equal text ("5" ↔ 5).
  final String? _textForm;

  const Criterion._(this._op, this._operand, this._wildcard, this._textForm);

  static final LinkedHashMap<String, Criterion> _cache = LinkedHashMap();

  /// Compiles [criterion] (a scalar) in [locale].
  static Criterion of(FValue criterion, FormulaLocale locale) {
    if (criterion is FRich) criterion = criterion.scalar;
    switch (criterion) {
      case FNumber():
        return Criterion._(_Op.eq, criterion, null, null);
      case FBool():
        return Criterion._(_Op.eq, criterion, null, null);
      case FError():
        return Criterion._(_Op.eq, criterion, null, null);
      case FEmpty() || FOmitted():
        return const Criterion._(_Op.eq, FText.empty, null, '');
      case FText(:final v):
        final key = '${locale.id}\u0001$v';
        final c = _cache.remove(key);
        if (c != null) {
          _cache[key] = c;
          return c;
        }
        final parsed = _parse(v, locale);
        if (_cache.length > 4096) _cache.remove(_cache.keys.first);
        _cache[key] = parsed;
        return parsed;
      default:
        return const Criterion._(_Op.eq, FText.empty, null, '');
    }
  }

  static Criterion _parse(String s, FormulaLocale locale) {
    var op = _Op.eq;
    var rest = s;
    for (final (p, o) in const [
      ('<>', _Op.ne),
      ('<=', _Op.le),
      ('>=', _Op.ge),
      ('<', _Op.lt),
      ('>', _Op.gt),
      ('=', _Op.eq),
    ]) {
      if (s.startsWith(p)) {
        op = o;
        rest = s.substring(p.length);
        break;
      }
    }
    if (rest.isEmpty) {
      return Criterion._(op, FEmpty.instance, null, null);
    }
    final upper = rest.toUpperCase();
    if (upper == 'TRUE' || upper == 'FALSE') {
      return Criterion._(op, FBool(upper == 'TRUE'), null, rest);
    }
    final err = ErrorKind.fromLiteral(upper);
    if (err != null) return Criterion._(op, FError(err), null, rest);
    final n = TextNumberParser.parse(rest, locale);
    if (n != null) return Criterion._(op, FNumber(n.$1), null, rest);
    RegExp? wc;
    if ((op == _Op.eq || op == _Op.ne) && (rest.contains('*') || rest.contains('?'))) {
      wc = wildcardRegExp(rest);
    }
    return Criterion._(op, FText(rest), wc, rest);
  }

  /// `*` any run, `?` one character, `~` escapes; whole-string, case-insensitive.
  static RegExp wildcardRegExp(String pattern, {bool caseSensitive = false}) {
    final b = StringBuffer('^');
    for (var i = 0; i < pattern.length; i++) {
      final c = pattern[i];
      if (c == '~' && i + 1 < pattern.length) {
        b.write(RegExp.escape(pattern[i + 1]));
        i++;
      } else if (c == '*') {
        b.write('[\\s\\S]*');
      } else if (c == '?') {
        b.write('[\\s\\S]');
      } else {
        b.write(RegExp.escape(c));
      }
    }
    b.write(r'$');
    return RegExp(b.toString(), caseSensitive: caseSensitive);
  }

  /// Whether [v] (a cell value) satisfies the criterion.
  bool test(FValue v) {
    if (v is FRich) v = v.scalar;
    final o = _operand;
    // empty-operand forms: "=" matches blank, "<>" non-blank
    if (o is FEmpty) {
      final blank = v is FEmpty || (v is FText && v.v.isEmpty);
      return switch (_op) {
        _Op.eq => blank,
        _Op.ne => !blank,
        _ => false,
      };
    }
    if (v is FError) {
      if (o is FError) {
        final same = v.kind == o.kind;
        return _op == _Op.eq ? same : (_op == _Op.ne && !same);
      }
      return _op == _Op.ne;
    }
    if (o is FError) return _op == _Op.ne;
    if (o is FText && o.v.isEmpty) {
      // criterion "" → blank cells
      final blank = v is FEmpty || (v is FText && v.v.isEmpty);
      return _op == _Op.ne ? !blank : blank;
    }
    switch (o) {
      case FNumber(v: final x):
        double? y;
        if (v is FNumber) {
          y = v.v;
        } else if (v is FText && (_op == _Op.eq || _op == _Op.ne)) {
          // "5" criterion matches text "5"
          final tf = _textForm ?? Numeric.toText(x);
          final same = Compare.fold(v.v.trim()) == Compare.fold(tf);
          return _op == _Op.eq ? same : !same;
        }
        if (y == null) return _op == _Op.ne;
        final c = Numeric.compare(y, x);
        return _cmp(c);
      case FBool(v: final b):
        if (v is! FBool) return _op == _Op.ne;
        final c = v.v == b ? 0 : (v.v ? 1 : -1);
        return _cmp(c);
      case FText(v: final t):
        if (_wildcard != null) {
          final s = switch (v) {
            FText(:final v) => v,
            FNumber() => Numeric.toText(v.v),
            FBool(:final v) => v ? 'TRUE' : 'FALSE',
            _ => '',
          };
          final m = _wildcard.hasMatch(s);
          return _op == _Op.eq ? m : !m;
        }
        if (v is! FText) {
          if (v is FEmpty) {
            return _op == _Op.ne;
          }
          return _op == _Op.ne;
        }
        final c = Compare.fold(v.v).compareTo(Compare.fold(t)).sign;
        return _cmp(c);
      default:
        return false;
    }
  }

  bool _cmp(int c) => switch (_op) {
    _Op.eq => c == 0,
    _Op.ne => c != 0,
    _Op.lt => c < 0,
    _Op.gt => c > 0,
    _Op.le => c <= 0,
    _Op.ge => c >= 0,
  };
}
