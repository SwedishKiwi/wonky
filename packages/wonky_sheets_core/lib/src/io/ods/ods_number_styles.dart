import 'package:xml/xml.dart';

import '../numfmt/excel_number_formats.dart';
import '../xlsx/ooxml.dart';

/// Namespace of Wonky's foreign ODF attributes (ignored by other readers).
const kWonkyOdfNamespace = 'urn:wonky:sheets:odf';

/// ODF number styles (`number:number-style`, `date-style`, …) ⇄ Wonky
/// patterns (11 §5.5, §6.4).
abstract final class OdsNumberStyles {
  // ---------------------------------------------------------------------------
  // Import.

  /// The pattern of a data style element; [byName] resolves `style:map`
  /// targets. Wonky's own `wonky:pattern` attribute wins when present.
  static String? toPattern(XmlElement style, XmlElement? Function(String name) byName, [int depth = 0]) {
    final own = style.attr('pattern');
    if (own != null && own.isNotEmpty) return own;
    final kind = style.localName;
    if (kind == 'boolean-style') return null;
    if (kind == 'text-style') return '@';
    final sections = <String>[];
    if (depth < 4) {
      for (final m in style.elems('map')) {
        final target = byName(m.attr('apply-style-name') ?? '');
        if (target == null) continue;
        final p = toPattern(target, byName, depth + 1);
        if (p != null) sections.add(p);
      }
    }
    final b = StringBuffer();
    final color = style.child('text-properties')?.attr('color');
    if (color != null) {
      final named = _colorNames[color.toUpperCase()];
      if (named != null) b.write('[$named]');
    }
    final isTime = kind == 'time-style';
    final elapsed = style.attr('truncate-on-overflow') == 'false';
    var afterHours = false;
    for (final e in style.childElements) {
      final long = e.attr('style') == 'long';
      switch (e.localName) {
        case 'number':
          b.write(_number(e));
        case 'scientific-number':
          b
            ..write(_number(e))
            ..write('E+${'0' * (e.intAttr('min-exponent-digits') ?? 2)}');
        case 'fraction':
          final ip = e.intAttr('min-integer-digits') ?? 0;
          b.write('${ip > 0 ? '# ' : ''}${'?' * (e.intAttr('min-numerator-digits') ?? 1)}/${e.attr('denominator-value') ?? '?' * (e.intAttr('min-denominator-digits') ?? 1)}');
        case 'text':
          b.write(_literal(e.innerText, percent: kind == 'percentage-style'));
        case 'currency-symbol':
          final sym = e.innerText;
          b.write(sym.isEmpty ? '' : '[\$$sym]');
        case 'day':
          b.write(long ? 'dd' : 'd');
        case 'month':
          final textual = e.boolAttr('textual') ?? false;
          b.write(textual ? (long ? 'mmmm' : 'mmm') : (long ? 'mm' : 'm'));
        case 'year':
          b.write(long ? 'yyyy' : 'yy');
        case 'day-of-week':
          b.write(long ? 'dddd' : 'ddd');
        case 'hours':
          final h = long ? 'hh' : 'h';
          b.write(isTime && elapsed ? '[$h]' : h);
          afterHours = true;
        case 'minutes':
          b.write(long || afterHours ? 'mm' : 'm');
        case 'seconds':
          b.write(long ? 'ss' : 's');
          final dp = e.intAttr('decimal-places') ?? 0;
          if (dp > 0) b.write('.${'0' * dp}');
        case 'am-pm':
          b.write('AM/PM');
        case 'text-content':
          b.write('@');
      }
    }
    final own2 = b.toString();
    if (sections.isEmpty) return own2.isEmpty ? null : own2;
    return [...sections, own2].join(';');
  }

  static const Map<String, String> _colorNames = {
    '#FF0000': 'Red',
    '#0000FF': 'Blue',
    '#00FF00': 'Green',
    '#FFFF00': 'Yellow',
    '#FF00FF': 'Magenta',
    '#00FFFF': 'Cyan',
    '#000000': 'Black',
    '#FFFFFF': 'White',
  };

  static String _number(XmlElement e) {
    final dp = e.intAttr('decimal-places') ?? 0;
    final minDp = e.intAttr('min-decimal-places') ?? dp;
    final ip = e.intAttr('min-integer-digits') ?? 1;
    final grouping = e.boolAttr('grouping') ?? false;
    var integer = '0' * ip;
    if (grouping) integer = ip >= 4 ? integer : '#,${'#' * (3 - ip)}$integer'.replaceFirst('#,', '#,');
    if (grouping && ip < 4) integer = '#,${'#' * (3 - ip)}${'0' * ip}';
    if (integer.isEmpty) integer = '#';
    final dec = dp > 0 ? '.${'0' * minDp}${'#' * (dp - minDp)}' : '';
    return '$integer$dec';
  }

  static String _literal(String t, {required bool percent}) {
    if (t.isEmpty) return '';
    if (RegExp(r'^[\s\-/:.,()%$€£¥]+$').hasMatch(t)) return t;
    return '"${t.replaceAll('"', r'\"')}"';
  }

  // ---------------------------------------------------------------------------
  // Export.

  /// Data style XML elements (`<number:…-style style:name="N…">`) for
  /// [pattern]; the main style is named [name], map targets `${name}P0`, ….
  static String toXml(String pattern, String name, {String locale = 'en_US'}) {
    final p = pattern.startsWith('preset:') ? ExcelNumberFormats.presetPattern(pattern, locale) : pattern;
    final sections = _splitSections(p);
    final out = StringBuffer();
    final conditions = sections.length == 2
        ? const ['value()>=0']
        : sections.length >= 3
        ? const ['value()>0', 'value()<0']
        : const <String>[];
    final mains = sections.length <= 1 ? sections : sections.sublist(0, conditions.length);
    final last = sections.length <= 1 ? (sections.isEmpty ? '' : sections.first) : sections[conditions.length];
    if (sections.length > 1) {
      for (var i = 0; i < mains.length; i++) {
        out.write(_section(mains[i], '${name}P$i', null, const []));
      }
    }
    out.write(_section(last, name, sections.length > 1 ? pattern : pattern, [
      if (sections.length > 1)
        for (var i = 0; i < mains.length; i++) (conditions[i], '${name}P$i'),
    ]));
    return out.toString();
  }

  static List<String> _splitSections(String p) {
    final out = <String>[];
    final b = StringBuffer();
    var q = false;
    for (var i = 0; i < p.length; i++) {
      final c = p[i];
      if (c == '"') q = !q;
      if (c == r'\' && i + 1 < p.length) {
        b.write(p.substring(i, i + 2));
        i++;
        continue;
      }
      if (c == ';' && !q) {
        out.add(b.toString());
        b.clear();
        continue;
      }
      b.write(c);
    }
    out.add(b.toString());
    return out;
  }

  static String _section(String s, String name, String? fullPattern, List<(String, String)> maps) {
    final lower = _unquoted(s).toLowerCase();
    final hasDate = RegExp('[yd]').hasMatch(lower) || (lower.contains('m') && !RegExp('[hs]').hasMatch(lower));
    final hasTime = RegExp('[hs]').hasMatch(lower) || lower.contains('am/pm');
    final kind = s.contains('@')
        ? 'text-style'
        : hasDate
        ? 'date-style'
        : hasTime
        ? 'time-style'
        : lower.contains('%')
        ? 'percentage-style'
        : (s.contains(r'[$') || RegExp(r'"[$€£¥]"').hasMatch(s))
        ? 'currency-style'
        : 'number-style';
    final attrs = StringBuffer('style:name="$name"');
    if (fullPattern != null) attrs.write(' wonky:pattern="${Ooxml.attr(fullPattern)}"');
    if (kind == 'time-style' && s.contains('[h')) attrs.write(' number:truncate-on-overflow="false"');
    final body = StringBuffer();
    final color = RegExp(r'\[(Red|Blue|Green|Yellow|Magenta|Cyan|Black|White)\]', caseSensitive: false).firstMatch(s);
    if (color != null) {
      final hex = _colorNames.entries.firstWhere((e) => e.value.toLowerCase() == color.group(1)!.toLowerCase()).key;
      body.write('<style:text-properties fo:color="${hex.toLowerCase()}"/>');
    }
    body.write(kind == 'date-style' || kind == 'time-style' ? _dateElements(s) : _numberElements(s, kind));
    for (final (cond, target) in maps) {
      body.write('<style:map style:condition="${Ooxml.attr(cond)}" style:apply-style-name="$target"/>');
    }
    return '<number:$kind $attrs>$body</number:$kind>';
  }

  static String _unquoted(String s) => s.replaceAll(RegExp(r'"[^"]*"|\\.|\[[^\]]*\]'), '');

  static String _text(String t) => t.isEmpty ? '' : '<number:text>${Ooxml.esc(t)}</number:text>';

  static String _numberElements(String s, String kind) {
    final out = StringBuffer();
    final lit = StringBuffer();
    var numberDone = false;
    var i = 0;
    void flushLit() {
      if (lit.isNotEmpty) out.write(_text(lit.toString()));
      lit.clear();
    }

    while (i < s.length) {
      final c = s[i];
      if (c == '"') {
        final end = s.indexOf('"', i + 1);
        final t = end < 0 ? s.substring(i + 1) : s.substring(i + 1, end);
        if (kind == 'currency-style' && RegExp(r'^[$€£¥]$').hasMatch(t)) {
          flushLit();
          out.write('<number:currency-symbol>${Ooxml.esc(t)}</number:currency-symbol>');
        } else {
          lit.write(t);
        }
        i = end < 0 ? s.length : end + 1;
        continue;
      }
      if (c == r'\' && i + 1 < s.length) {
        lit.write(s[i + 1]);
        i += 2;
        continue;
      }
      if (c == '_' || c == '*') {
        if (c == '_') lit.write(' ');
        i += 2;
        continue;
      }
      if (c == '[') {
        final end = s.indexOf(']', i);
        final inner = end < 0 ? '' : s.substring(i + 1, end);
        if (inner.startsWith(r'$')) {
          final dash = inner.indexOf('-');
          final sym = dash < 0 ? inner.substring(1) : inner.substring(1, dash);
          flushLit();
          out.write('<number:currency-symbol>${Ooxml.esc(sym)}</number:currency-symbol>');
        }
        i = end < 0 ? s.length : end + 1;
        continue;
      }
      if (c == '@') {
        flushLit();
        out.write('<number:text-content/>');
        i++;
        continue;
      }
      if ('0#?,.'.contains(c) && !numberDone) {
        var j = i;
        while (j < s.length && '0#?,.Ee+-/ '.contains(s[j])) {
          if ((s[j] == '-' || s[j] == '+') && !(j > 0 && (s[j - 1] == 'E' || s[j - 1] == 'e'))) break;
          if (s[j] == ' ' && !(j + 1 < s.length && '?#0'.contains(s[j + 1]))) break;
          j++;
        }
        final num = s.substring(i, j);
        flushLit();
        out.write(_numberElement(num));
        numberDone = true;
        i = j;
        continue;
      }
      lit.write(c);
      i++;
    }
    flushLit();
    return out.toString();
  }

  static String _numberElement(String num) {
    if (num.contains('/')) {
      final parts = num.trim().split(RegExp(r'\s+'));
      final frac = parts.last.split('/');
      final whole = parts.length > 1 ? ' number:min-integer-digits="1"' : ' number:min-integer-digits="0"';
      final den = frac.length > 1 ? frac[1] : '?';
      final denAttr = RegExp(r'^\d+$').hasMatch(den)
          ? ' number:denominator-value="$den"'
          : ' number:min-denominator-digits="${den.length}"';
      return '<number:fraction$whole number:min-numerator-digits="${frac.first.length}"$denAttr/>';
    }
    final e = num.toUpperCase().indexOf('E');
    final mant = e < 0 ? num : num.substring(0, e);
    final dot = mant.indexOf('.');
    final intPart = dot < 0 ? mant : mant.substring(0, dot);
    final decPart = dot < 0 ? '' : mant.substring(dot + 1);
    final grouping = intPart.contains(',');
    final minInt = intPart.replaceAll(RegExp('[^0]'), '').length;
    final minDec = decPart.replaceAll(RegExp('[^0]'), '').length;
    final dec = decPart.replaceAll(RegExp('[^0#?]'), '').length;
    final attrs = ' number:decimal-places="$dec" number:min-decimal-places="$minDec" number:min-integer-digits="$minInt"'
        '${grouping ? ' number:grouping="true"' : ''}';
    if (e >= 0) {
      final expDigits = num.substring(e + 1).replaceAll(RegExp('[^0#]'), '').length;
      return '<number:scientific-number$attrs number:min-exponent-digits="$expDigits"/>';
    }
    return '<number:number$attrs/>';
  }

  static String _dateElements(String s) {
    final out = StringBuffer();
    final lit = StringBuffer();
    void flush() {
      if (lit.isNotEmpty) out.write(_text(lit.toString()));
      lit.clear();
    }

    final lower = s.toLowerCase();
    var i = 0;
    var lastWasHour = false;
    while (i < s.length) {
      final c = lower[i];
      if (s[i] == '"') {
        final end = s.indexOf('"', i + 1);
        lit.write(end < 0 ? s.substring(i + 1) : s.substring(i + 1, end));
        i = end < 0 ? s.length : end + 1;
        continue;
      }
      if (s[i] == r'\' && i + 1 < s.length) {
        lit.write(s[i + 1]);
        i += 2;
        continue;
      }
      if (c == '[') {
        final end = s.indexOf(']', i);
        final inner = end < 0 ? '' : lower.substring(i + 1, end);
        if (RegExp(r'^h+$').hasMatch(inner)) {
          flush();
          out.write('<number:hours${inner.length > 1 ? ' number:style="long"' : ''}/>');
          lastWasHour = true;
        } else if (RegExp(r'^m+$').hasMatch(inner)) {
          flush();
          out.write('<number:minutes number:style="long"/>');
        }
        i = end < 0 ? s.length : end + 1;
        continue;
      }
      if (lower.startsWith('am/pm', i) || lower.startsWith('a/p', i)) {
        flush();
        out.write('<number:am-pm/>');
        i += lower.startsWith('am/pm', i) ? 5 : 3;
        continue;
      }
      if ('ymdhs'.contains(c)) {
        var j = i;
        while (j < s.length && lower[j] == c) {
          j++;
        }
        final n = j - i;
        flush();
        switch (c) {
          case 'y':
            out.write('<number:year${n > 2 ? ' number:style="long"' : ''}/>');
          case 'd':
            out.write(n >= 3
                ? '<number:day-of-week${n > 3 ? ' number:style="long"' : ''}/>'
                : '<number:day${n > 1 ? ' number:style="long"' : ''}/>');
          case 'h':
            out.write('<number:hours${n > 1 ? ' number:style="long"' : ''}/>');
            lastWasHour = true;
          case 's':
            var dp = 0;
            if (j < s.length && s[j] == '.') {
              var k = j + 1;
              while (k < s.length && s[k] == '0') {
                k++;
              }
              dp = k - j - 1;
              j = k;
            }
            out.write('<number:seconds${n > 1 ? ' number:style="long"' : ''}${dp > 0 ? ' number:decimal-places="$dp"' : ''}/>');
          case 'm':
            final rest = lower.substring(j);
            final minute = lastWasHour || RegExp(r'^[^a-z]*s').hasMatch(rest) && n <= 2;
            if (minute && n <= 2) {
              out.write('<number:minutes${n > 1 ? ' number:style="long"' : ''}/>');
            } else if (n >= 3) {
              out.write('<number:month number:textual="true"${n > 3 ? ' number:style="long"' : ''}/>');
            } else {
              out.write('<number:month${n > 1 ? ' number:style="long"' : ''}/>');
            }
        }
        if (c != 'h' && c != 'm') lastWasHour = c == 'h';
        if (c == 'm') lastWasHour = false;
        i = j;
        continue;
      }
      lit.write(s[i]);
      i++;
    }
    flush();
    return out.toString();
  }
}
