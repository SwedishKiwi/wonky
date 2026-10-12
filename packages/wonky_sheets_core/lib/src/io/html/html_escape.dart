/// Escaping helpers for generated HTML (clipboard, HTML export).
abstract final class HtmlText {
  /// Escapes text content (`&`, `<`, `>`, quotes). Control characters other
  /// than tab/newline are dropped.
  static String escape(String s) {
    StringBuffer? b;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      final String? rep = switch (c) {
        0x26 => '&amp;',
        0x3c => '&lt;',
        0x3e => '&gt;',
        0x22 => '&quot;',
        0x27 => '&#39;',
        _ => (c < 0x20 && c != 0x09 && c != 0x0a) || c == 0x7f ? '' : null,
      };
      if (rep != null) {
        b ??= StringBuffer(s.substring(0, i));
        b.write(rep);
      } else {
        b?.writeCharCode(c);
      }
    }
    return b?.toString() ?? s;
  }

  /// Escapes text and turns line breaks into `<br/>`.
  static String escapeMultiline(String s) {
    final e = escape(s.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
    return e.contains('\n') ? e.replaceAll('\n', '<br/>') : e;
  }

  /// Escapes an attribute value (to be wrapped in double quotes).
  static String attr(String s) => escape(s).replaceAll('\n', '&#10;').replaceAll('\t', '&#9;');

  /// A safe `href` for a cell link: `http(s)`/`mailto` URLs are kept, others
  /// (e.g. `javascript:`) return null. Internal links are handled by callers.
  static String? safeUrl(String? url) {
    if (url == null) return null;
    final u = url.trim();
    final lower = u.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://') || lower.startsWith('mailto:')) {
      return u;
    }
    if (lower.startsWith('www.')) return 'https://$u';
    return null;
  }

  /// A CSS font-family value: quoted family name (characters that could end
  /// the declaration are removed) followed by a generic fallback.
  static String cssFontFamily(String family, {String generic = 'sans-serif'}) {
    final clean = family.replaceAll(RegExp(r'''["'\\;<>{}\n\r]'''), '').trim();
    if (clean.isEmpty) return generic;
    return "'$clean',$generic";
  }

  /// A number for CSS output (no trailing zeros).
  static String num(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    var s = v.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }
}
