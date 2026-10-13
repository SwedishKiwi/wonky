import 'package:xml/xml.dart';

import 'ooxml.dart';

/// XLSX print settings ⇄ the IR print map (11 §5.2 "Print settings",
/// §7.2 `PrintSettings` shape with index-based ranges).
abstract final class XlsxPrint {
  static const Map<int, String> _paper = {
    1: 'letter',
    3: 'tabloid',
    5: 'legal',
    6: 'statement',
    7: 'executive',
    8: 'a3',
    9: 'a4',
    11: 'a5',
    12: 'b4',
    13: 'b5',
    14: 'folio',
  };

  /// Reads print settings from worksheet elements. Returns null when the
  /// sheet has none.
  static Map<String, Object?>? read({
    XmlElement? pageSetup,
    XmlElement? margins,
    XmlElement? options,
    XmlElement? headerFooter,
    XmlElement? rowBreaks,
    XmlElement? colBreaks,
    bool fitToPage = false,
  }) {
    final out = <String, Object?>{};
    if (pageSetup != null) {
      final paper = _paper[pageSetup.intAttr('paperSize') ?? 1];
      if (paper != null && pageSetup.attr('paperSize') != null) {
        out['paper'] = paper;
      }
      final o = pageSetup.attr('orientation');
      if (o == 'landscape' || o == 'portrait') out['orientation'] = o;
      if (fitToPage) {
        final w = pageSetup.intAttr('fitToWidth') ?? 1;
        final h = pageSetup.intAttr('fitToHeight') ?? 1;
        out['scale'] = {
          'mode': w >= 1 && h >= 1
              ? 'fitPage'
              : (w >= 1 ? 'fitWidth' : (h >= 1 ? 'fitHeight' : 'normal')),
        };
      } else {
        final s = pageSetup.intAttr('scale');
        if (s != null && s != 100) {
          out['scale'] = {'mode': 'custom', 'percent': s.clamp(10, 400)};
        }
      }
    }
    if (margins != null) {
      final t = margins.doubleAttr('top') ?? 0.75,
          b = margins.doubleAttr('bottom') ?? 0.75;
      final l = margins.doubleAttr('left') ?? 0.7,
          r = margins.doubleAttr('right') ?? 0.7;
      Map<String, Object?> m;
      if (t == 0.75 && b == 0.75 && l == 0.7 && r == 0.7) {
        m = {'preset': 'normal'};
      } else if (t == 0.75 && b == 0.75 && l == 0.25 && r == 0.25 ||
          (t == 0.25 && b == 0.25 && l == 0.25 && r == 0.25)) {
        m = {'preset': 'narrow'};
      } else if (t == 1 && b == 1 && l == 1 && r == 1) {
        m = {'preset': 'wide'};
      } else {
        m = {
          'preset': 'custom',
          'top': t,
          'bottom': b,
          'left': l,
          'right': r,
          'unit': 'in',
        };
      }
      final h = margins.doubleAttr('header'), f = margins.doubleAttr('footer');
      if ((h != null && h != 0.3) || (f != null && f != 0.3)) {
        m['headerFooter'] = {'header': h ?? 0.3, 'footer': f ?? 0.3};
      }
      if (m['preset'] != 'normal' || m.length > 1) out['margins'] = m;
    }
    if (options != null) {
      if (options.boolAttr('gridLines') ?? false) out['gridlines'] = true;
      if (options.boolAttr('headings') ?? false) out['headings'] = true;
      final hc = options.boolAttr('horizontalCentered') ?? false;
      final vc = options.boolAttr('verticalCentered') ?? false;
      if (hc || vc) {
        out['align'] = {
          'h': hc ? 'center' : 'left',
          'v': vc ? 'middle' : 'top',
        };
      }
    }
    if (headerFooter != null) {
      final header = parseHeaderFooter(
        headerFooter.child('oddHeader')?.innerText ?? '',
      );
      final footer = parseHeaderFooter(
        headerFooter.child('oddFooter')?.innerText ?? '',
      );
      out['headerFooter'] = {
        'header': header,
        'footer': footer,
        'flags': {
          'pageNumbers': false,
          'title': false,
          'sheetName': false,
          'date': false,
          'time': false,
        },
      };
    }
    List<int> breaks(XmlElement? e) => [
      for (final b in e?.elems('brk') ?? const <XmlElement>[])
        if (b.intAttr('id') case final int id when id > 0) id,
    ]..sort();
    final rb = breaks(rowBreaks), cb = breaks(colBreaks);
    if (rb.isNotEmpty || cb.isNotEmpty) {
      out['pageBreaks'] = {'rows': rb, 'cols': cb};
    }
    return out.isEmpty ? null : out;
  }

  /// Parses `&L…&C…&R…` into sections with Wonky tokens (`{page}`,
  /// `{pages}`, `{date}`, `{time}`, `{title}`, `{sheet}`); font/color codes
  /// are dropped.
  static Map<String, String> parseHeaderFooter(String code) {
    final sections = {
      'left': StringBuffer(),
      'center': StringBuffer(),
      'right': StringBuffer(),
    };
    var cur = 'center';
    var i = 0;
    while (i < code.length) {
      final ch = code[i];
      if (ch != '&' || i + 1 >= code.length) {
        sections[cur]!.write(ch);
        i++;
        continue;
      }
      final n = code[i + 1];
      i += 2;
      switch (n) {
        case 'L':
          cur = 'left';
        case 'C':
          cur = 'center';
        case 'R':
          cur = 'right';
        case 'P':
          sections[cur]!.write('{page}');
        case 'N':
          sections[cur]!.write('{pages}');
        case 'D':
          sections[cur]!.write('{date}');
        case 'T':
          sections[cur]!.write('{time}');
        case 'F':
          sections[cur]!.write('{title}');
        case 'A':
          sections[cur]!.write('{sheet}');
        case '&':
          sections[cur]!.write('&');
        case '"':
          final end = code.indexOf('"', i);
          i = end < 0 ? code.length : end + 1;
        case 'K':
          i += 6;
        default:
          // Font size digits, &B/&I/&U/&S/&X/&Y/&Z/&G codes.
          while (i < code.length &&
              RegExp(r'[0-9]').hasMatch(code[i]) &&
              RegExp(r'[0-9]').hasMatch(n)) {
            i++;
          }
      }
    }
    return {for (final e in sections.entries) e.key: e.value.toString()};
  }

  /// Formats header/footer sections as an Excel code string.
  static String formatHeaderFooter(Map<Object?, Object?>? sections) {
    if (sections == null) return '';
    String conv(String s) => s
        .replaceAll('&', '&&')
        .replaceAll('{page}', '&P')
        .replaceAll('{pages}', '&N')
        .replaceAll('{date}', '&D')
        .replaceAll('{time}', '&T')
        .replaceAll('{title}', '&F')
        .replaceAll('{sheet}', '&A');
    final b = StringBuffer();
    for (final (k, code) in const [
      ('left', '&L'),
      ('center', '&C'),
      ('right', '&R'),
    ]) {
      final s = sections[k]?.toString() ?? '';
      if (s.isNotEmpty) b.write('$code${conv(s)}');
    }
    return b.toString();
  }

  /// Worksheet XML fragments for [print]: `printOptions`, `pageMargins`,
  /// `pageSetup`, `headerFooter`, `rowBreaks`, `colBreaks` (ECMA order)
  /// and whether `sheetPr/pageSetUpPr fitToPage` is needed.
  static ({
    String printOptions,
    String margins,
    String pageSetup,
    String headerFooter,
    String breaks,
    bool fitToPage,
  })
  write(Map<String, Object?>? print) {
    final p = print ?? const {};
    final align = p['align'] as Map?;
    final po = StringBuffer();
    if (p['gridlines'] == true) po.write(' gridLines="1"');
    if (p['headings'] == true) po.write(' headings="1"');
    if (align?['h'] == 'center') po.write(' horizontalCentered="1"');
    if (align?['v'] == 'middle') po.write(' verticalCentered="1"');
    final printOptions = po.isEmpty ? '' : '<printOptions$po/>';
    final m = p['margins'] as Map?;
    var t = 0.75, b = 0.75, l = 0.7, r = 0.7;
    switch (m?['preset']) {
      case 'narrow':
        t = 0.75;
        b = 0.75;
        l = 0.25;
        r = 0.25;
      case 'wide':
        t = b = l = r = 1;
      case 'custom':
        double v(String k, double d) => (m?[k] as num?)?.toDouble() ?? d;
        final cm = m?['unit'] == 'cm';
        double u(double x) => cm ? x / 2.54 : x;
        t = u(v('top', 0.75));
        b = u(v('bottom', 0.75));
        l = u(v('left', 0.7));
        r = u(v('right', 0.7));
    }
    final hf = m?['headerFooter'] as Map?;
    final margins =
        '<pageMargins left="${_n(l)}" right="${_n(r)}" top="${_n(t)}" bottom="${_n(b)}" '
        'header="${_n((hf?['header'] as num?)?.toDouble() ?? 0.3)}" footer="${_n((hf?['footer'] as num?)?.toDouble() ?? 0.3)}"/>';
    final ps = StringBuffer();
    final paper = p['paper'];
    if (paper != null) {
      for (final e in _paper.entries) {
        if (e.value == paper) ps.write(' paperSize="${e.key}"');
      }
    }
    final scale = p['scale'] as Map?;
    var fit = false;
    switch (scale?['mode']) {
      case 'custom':
        ps.write(' scale="${scale?['percent']}"');
      case 'fitWidth':
        fit = true;
        ps.write(' fitToWidth="1" fitToHeight="0"');
      case 'fitHeight':
        fit = true;
        ps.write(' fitToWidth="0" fitToHeight="1"');
      case 'fitPage':
        fit = true;
        ps.write(' fitToWidth="1" fitToHeight="1"');
    }
    if (p['orientation'] != null) {
      ps.write(' orientation="${p['orientation']}"');
    }
    final pageSetup = ps.isEmpty ? '' : '<pageSetup$ps/>';
    final hfm = p['headerFooter'] as Map?;
    var headerFooter = '';
    if (hfm != null) {
      final h = formatHeaderFooter(hfm['header'] as Map?);
      final f = formatHeaderFooter(hfm['footer'] as Map?);
      if (h.isNotEmpty || f.isNotEmpty) {
        headerFooter =
            '<headerFooter>${h.isEmpty ? '' : '<oddHeader>${Ooxml.esc(h)}</oddHeader>'}'
            '${f.isEmpty ? '' : '<oddFooter>${Ooxml.esc(f)}</oddFooter>'}</headerFooter>';
      }
    }
    final br = p['pageBreaks'] as Map?;
    final breaks = StringBuffer();
    for (final (k, el, max) in const [
      ('rows', 'rowBreaks', 16383),
      ('cols', 'colBreaks', 1048575),
    ]) {
      final ids = [
        for (final x in (br?[k] as List?) ?? const [])
          if (x is num) x.toInt(),
      ];
      if (ids.isEmpty) continue;
      breaks.write(
        '<$el count="${ids.length}" manualBreakCount="${ids.length}">',
      );
      for (final id in ids) {
        breaks.write('<brk id="$id" max="$max" man="1"/>');
      }
      breaks.write('</$el>');
    }
    return (
      printOptions: printOptions,
      margins: margins,
      pageSetup: pageSetup,
      headerFooter: headerFooter,
      breaks: breaks.toString(),
      fitToPage: fit,
    );
  }

  static String _n(double d) =>
      d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
}
