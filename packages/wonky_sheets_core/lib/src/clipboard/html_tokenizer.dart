/// A token of [HtmlTokenizer].
sealed class HtmlToken {
  const HtmlToken();
}

/// `<name attr=…>`; names are lower case.
final class HtmlStartTag extends HtmlToken {
  /// Creates a start tag.
  const HtmlStartTag(this.name, this.attributes, {this.selfClosing = false});

  final String name;

  /// Attributes (lower-case names, entity-decoded values; a bare attribute
  /// has the empty string as value).
  final Map<String, String> attributes;
  final bool selfClosing;

  @override
  String toString() => '<$name $attributes${selfClosing ? '/' : ''}>';
}

/// `</name>`.
final class HtmlEndTag extends HtmlToken {
  /// Creates an end tag.
  const HtmlEndTag(this.name);

  final String name;

  @override
  String toString() => '</$name>';
}

/// Character data (entities decoded; raw for `<style>`/`<script>` bodies).
final class HtmlTextToken extends HtmlToken {
  /// Creates text.
  const HtmlTextToken(this.text, {this.raw = false});

  final String text;

  /// Whether this is the raw body of a `<style>`, `<script>`, `<title>` or
  /// `<textarea>` element.
  final bool raw;

  @override
  String toString() => 'Text(${text.length > 40 ? '${text.substring(0, 40)}…' : text})';
}

/// `<!-- … -->`.
final class HtmlComment extends HtmlToken {
  /// Creates a comment.
  const HtmlComment(this.text);

  final String text;
}

/// A small, tolerant HTML tokenizer for clipboard HTML (03 §12.5): never
/// throws; unknown constructs (`<!DOCTYPE>`, `<?xml?>`, `<![if …]>`, CDATA)
/// are skipped; unterminated tags/comments end at the end of input.
abstract final class HtmlTokenizer {
  static const _rawTextElements = {'style', 'script', 'title', 'textarea', 'xmp'};

  /// Tokenizes [html].
  static List<HtmlToken> tokenize(String html) {
    final out = <HtmlToken>[];
    final n = html.length;
    var i = 0;
    final text = StringBuffer();

    void flushText() {
      if (text.isEmpty) return;
      out.add(HtmlTextToken(decodeEntities(text.toString())));
      text.clear();
    }

    while (i < n) {
      final c = html.codeUnitAt(i);
      if (c != 0x3c) {
        final next = html.indexOf('<', i);
        final end = next < 0 ? n : next;
        text.write(html.substring(i, end));
        i = end;
        continue;
      }
      // '<'
      if (html.startsWith('<!--', i)) {
        flushText();
        final end = html.indexOf('-->', i + 4);
        out.add(HtmlComment(html.substring(i + 4, end < 0 ? n : end)));
        i = end < 0 ? n : end + 3;
        continue;
      }
      if (html.startsWith('<![CDATA[', i)) {
        flushText();
        final end = html.indexOf(']]>', i);
        final body = html.substring(i + 9, end < 0 ? n : end);
        out.add(HtmlTextToken(body));
        i = end < 0 ? n : end + 3;
        continue;
      }
      if (i + 1 < n && (html.codeUnitAt(i + 1) == 0x21 || html.codeUnitAt(i + 1) == 0x3f)) {
        // <!DOCTYPE …>, <![if …]>, <?xml …?>
        flushText();
        final end = html.indexOf('>', i);
        i = end < 0 ? n : end + 1;
        continue;
      }
      if (i + 1 < n && html.codeUnitAt(i + 1) == 0x2f) {
        // End tag.
        var j = i + 2;
        final start = j;
        while (j < n && _isNameChar(html.codeUnitAt(j))) {
          j++;
        }
        if (j == start) {
          text.write('</');
          i += 2;
          continue;
        }
        flushText();
        final name = html.substring(start, j).toLowerCase();
        final end = html.indexOf('>', j);
        out.add(HtmlEndTag(name));
        i = end < 0 ? n : end + 1;
        continue;
      }
      if (i + 1 < n && _isNameStart(html.codeUnitAt(i + 1))) {
        flushText();
        final (tag, end) = _startTag(html, i + 1);
        out.add(tag);
        i = end;
        if (!tag.selfClosing && _rawTextElements.contains(tag.name)) {
          final close = _indexOfIgnoreCase(html, '</${tag.name}', i);
          final bodyEnd = close < 0 ? n : close;
          final body = html.substring(i, bodyEnd);
          if (body.isNotEmpty) {
            out.add(
              HtmlTextToken(tag.name == 'title' || tag.name == 'textarea' ? decodeEntities(body) : body, raw: true),
            );
          }
          if (close < 0) {
            i = n;
          } else {
            final gt = html.indexOf('>', close);
            out.add(HtmlEndTag(tag.name));
            i = gt < 0 ? n : gt + 1;
          }
        }
        continue;
      }
      // Stray '<'.
      text.write('<');
      i++;
    }
    flushText();
    return out;
  }

  static int _indexOfIgnoreCase(String s, String needle, int from) {
    final lower = needle.toLowerCase();
    var i = from;
    while (true) {
      final k = s.indexOf('<', i);
      if (k < 0 || k + lower.length > s.length) return -1;
      if (s.substring(k, k + lower.length).toLowerCase() == lower) return k;
      i = k + 1;
    }
  }

  static bool _isNameStart(int c) =>
      (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a);

  static bool _isNameChar(int c) =>
      _isNameStart(c) || (c >= 0x30 && c <= 0x39) || c == 0x2d || c == 0x3a || c == 0x5f || c == 0x2e;

  static bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d || c == 0x0c;

  static (HtmlStartTag, int) _startTag(String s, int i) {
    final n = s.length;
    var j = i;
    while (j < n && _isNameChar(s.codeUnitAt(j))) {
      j++;
    }
    final name = s.substring(i, j).toLowerCase();
    final attrs = <String, String>{};
    var selfClosing = false;
    while (j < n) {
      var c = s.codeUnitAt(j);
      if (_isSpace(c)) {
        j++;
        continue;
      }
      if (c == 0x3e) {
        j++;
        break;
      }
      if (c == 0x2f) {
        if (j + 1 < n && s.codeUnitAt(j + 1) == 0x3e) {
          selfClosing = true;
          j += 2;
          break;
        }
        j++;
        continue;
      }
      // Attribute name.
      final ns = j;
      while (j < n) {
        c = s.codeUnitAt(j);
        if (_isSpace(c) || c == 0x3d || c == 0x3e || (c == 0x2f && j + 1 < n && s.codeUnitAt(j + 1) == 0x3e)) {
          break;
        }
        j++;
      }
      final attrName = s.substring(ns, j).toLowerCase();
      if (attrName.isEmpty) {
        j++;
        continue;
      }
      while (j < n && _isSpace(s.codeUnitAt(j))) {
        j++;
      }
      var value = '';
      if (j < n && s.codeUnitAt(j) == 0x3d) {
        j++;
        while (j < n && _isSpace(s.codeUnitAt(j))) {
          j++;
        }
        if (j < n && (s.codeUnitAt(j) == 0x22 || s.codeUnitAt(j) == 0x27)) {
          final q = s.codeUnitAt(j);
          final end = s.indexOf(String.fromCharCode(q), j + 1);
          value = s.substring(j + 1, end < 0 ? n : end);
          j = end < 0 ? n : end + 1;
        } else {
          final vs = j;
          while (j < n && !_isSpace(s.codeUnitAt(j)) && s.codeUnitAt(j) != 0x3e) {
            j++;
          }
          value = s.substring(vs, j);
        }
      }
      attrs.putIfAbsent(attrName, () => decodeEntities(value));
    }
    const voidElements = {'br', 'col', 'img', 'meta', 'link', 'hr', 'input', 'wbr', 'base', 'area'};
    return (HtmlStartTag(name, attrs, selfClosing: selfClosing || voidElements.contains(name)), j);
  }

  static const Map<String, int> _entities = {
    'amp': 0x26, 'lt': 0x3c, 'gt': 0x3e, 'quot': 0x22, 'apos': 0x27, 'nbsp': 0xa0, //
    'iexcl': 0xa1, 'cent': 0xa2, 'pound': 0xa3, 'curren': 0xa4, 'yen': 0xa5, 'brvbar': 0xa6,
    'sect': 0xa7, 'uml': 0xa8, 'copy': 0xa9, 'ordf': 0xaa, 'laquo': 0xab, 'not': 0xac,
    'shy': 0xad, 'reg': 0xae, 'macr': 0xaf, 'deg': 0xb0, 'plusmn': 0xb1, 'sup2': 0xb2,
    'sup3': 0xb3, 'acute': 0xb4, 'micro': 0xb5, 'para': 0xb6, 'middot': 0xb7, 'cedil': 0xb8,
    'sup1': 0xb9, 'ordm': 0xba, 'raquo': 0xbb, 'frac14': 0xbc, 'frac12': 0xbd, 'frac34': 0xbe,
    'iquest': 0xbf, 'times': 0xd7, 'divide': 0xf7, 'szlig': 0xdf, 'agrave': 0xe0, 'aacute': 0xe1,
    'acirc': 0xe2, 'atilde': 0xe3, 'auml': 0xe4, 'aring': 0xe5, 'aelig': 0xe6, 'ccedil': 0xe7,
    'egrave': 0xe8, 'eacute': 0xe9, 'ecirc': 0xea, 'euml': 0xeb, 'igrave': 0xec, 'iacute': 0xed,
    'icirc': 0xee, 'iuml': 0xef, 'eth': 0xf0, 'ntilde': 0xf1, 'ograve': 0xf2, 'oacute': 0xf3,
    'ocirc': 0xf4, 'otilde': 0xf5, 'ouml': 0xf6, 'oslash': 0xf8, 'ugrave': 0xf9, 'uacute': 0xfa,
    'ucirc': 0xfb, 'uuml': 0xfc, 'yacute': 0xfd, 'thorn': 0xfe, 'yuml': 0xff, 'Agrave': 0xc0,
    'Aacute': 0xc1, 'Acirc': 0xc2, 'Atilde': 0xc3, 'Auml': 0xc4, 'Aring': 0xc5, 'AElig': 0xc6,
    'Ccedil': 0xc7, 'Egrave': 0xc8, 'Eacute': 0xc9, 'Ecirc': 0xca, 'Euml': 0xcb, 'Igrave': 0xcc,
    'Iacute': 0xcd, 'Icirc': 0xce, 'Iuml': 0xcf, 'ETH': 0xd0, 'Ntilde': 0xd1, 'Ograve': 0xd2,
    'Oacute': 0xd3, 'Ocirc': 0xd4, 'Otilde': 0xd5, 'Ouml': 0xd6, 'Oslash': 0xd8, 'Ugrave': 0xd9,
    'Uacute': 0xda, 'Ucirc': 0xdb, 'Uuml': 0xdc, 'Yacute': 0xdd, 'THORN': 0xde, 'euro': 0x20ac,
    'ndash': 0x2013, 'mdash': 0x2014, 'lsquo': 0x2018, 'rsquo': 0x2019, 'sbquo': 0x201a,
    'ldquo': 0x201c, 'rdquo': 0x201d, 'bdquo': 0x201e, 'dagger': 0x2020, 'Dagger': 0x2021,
    'bull': 0x2022, 'hellip': 0x2026, 'permil': 0x2030, 'prime': 0x2032, 'lsaquo': 0x2039,
    'rsaquo': 0x203a, 'trade': 0x2122, 'larr': 0x2190, 'uarr': 0x2191, 'rarr': 0x2192,
    'darr': 0x2193, 'minus': 0x2212, 'le': 0x2264, 'ge': 0x2265, 'ne': 0x2260, 'infin': 0x221e,
    'ensp': 0x2002, 'emsp': 0x2003, 'thinsp': 0x2009, 'zwnj': 0x200c, 'zwj': 0x200d,
    'OElig': 0x152, 'oelig': 0x153, 'Scaron': 0x160, 'scaron': 0x161, 'Yuml': 0x178,
    'fnof': 0x192, 'circ': 0x2c6, 'tilde': 0x2dc, 'alpha': 0x3b1, 'beta': 0x3b2, 'pi': 0x3c0,
    'sigma': 0x3c3, 'mu': 0x3bc, 'Omega': 0x3a9, 'check': 0x2713,
  };

  /// Decodes character references (`&amp;`, `&#65;`, `&#x41;`, common named
  /// entities; unknown references are kept verbatim).
  static String decodeEntities(String s) {
    if (!s.contains('&')) return s;
    final b = StringBuffer();
    var i = 0;
    while (i < s.length) {
      final amp = s.indexOf('&', i);
      if (amp < 0) {
        b.write(s.substring(i));
        break;
      }
      b.write(s.substring(i, amp));
      var j = amp + 1;
      if (j < s.length && s.codeUnitAt(j) == 0x23) {
        j++;
        final hex = j < s.length && (s.codeUnitAt(j) | 0x20) == 0x78;
        if (hex) j++;
        final ds = j;
        while (j < s.length && j - ds < 8 && _isDigitIn(s.codeUnitAt(j), hex)) {
          j++;
        }
        if (j > ds) {
          final v = int.tryParse(s.substring(ds, j), radix: hex ? 16 : 10);
          if (j < s.length && s.codeUnitAt(j) == 0x3b) j++;
          if (v != null && v > 0 && v <= 0x10ffff && (v < 0xd800 || v > 0xdfff)) {
            b.writeCharCode(v == 0xa0 ? 0xa0 : v);
          } else {
            b.writeCharCode(0xfffd);
          }
          i = j;
          continue;
        }
        b.write('&');
        i = amp + 1;
        continue;
      }
      final ns = j;
      while (j < s.length && j - ns < 10 && _isAlnum(s.codeUnitAt(j))) {
        j++;
      }
      final name = s.substring(ns, j);
      final cp = _entities[name] ?? _entities[name.toLowerCase()];
      if (cp != null) {
        if (j < s.length && s.codeUnitAt(j) == 0x3b) j++;
        b.writeCharCode(cp);
        i = j;
      } else {
        b.write('&');
        i = amp + 1;
      }
    }
    return b.toString();
  }

  static bool _isAlnum(int c) =>
      (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a);

  static bool _isDigitIn(int c, bool hex) =>
      (c >= 0x30 && c <= 0x39) || (hex && ((c | 0x20) >= 0x61 && (c | 0x20) <= 0x66));
}
