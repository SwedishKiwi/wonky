import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart' show WonkyTheme;

/// Creates the tap recognizer of a link to [url] (already checked with
/// [MarkdownInline.safeUrl]); null renders links styled but inert.
typedef MarkdownLinkRecognizer = GestureRecognizer? Function(String url);

/// Inline Markdown → spans (specs/16 §7.3): bold, italic, strike, code,
/// links, autolinks and backslash escapes. Images render as links (to the
/// image), raw HTML as text, and links whose scheme is not http(s) or
/// mailto as their source text.
abstract final class MarkdownInline {
  static final _inline = RegExp(
    // 1 escape
    r'\\([!-/:-@\[-`{-~])'
    // 2 ticks, 3 code
    r'|(`+)(?!`)([\s\S]+?)(?<!`)\2(?!`)'
    // image ![alt](src)
    r'|!\[(?<alt>[^\]\n]*)\]\((?:\s*<(?<src1>[^>\n]+)>|\s*(?<src2>[^)\s]+))(?:\s+"[^"\n]*")?\s*\)'
    // link [label](href)
    r'|\[(?<label>(?:[^\[\]\n]|\[[^\]\n]*\])+)\]\((?:\s*<(?<href1>[^>\n]+)>|\s*(?<href2>[^)\s]+))(?:\s+"[^"\n]*")?\s*\)'
    // autolink <https://…>
    r'|<(?<auto>(?:[A-Za-z][A-Za-z0-9+.\-]*):[^>\s]+)>'
    // bare http(s) URL
    r'|(?<bare>(?<![\w/])https?://[^\s<]*[^\s<.,:;"'
    "'"
    r')\]!?*_~])'
    // bold
    r'|\*\*(?=\S)(?<b1>[\s\S]+?)(?<=\S)\*\*'
    r'|(?<![A-Za-z0-9])__(?=\S)(?<b2>[\s\S]+?)(?<=\S)__(?![A-Za-z0-9])'
    // strike
    r'|~~(?=\S)(?<s>[\s\S]+?)(?<=\S)~~'
    // italic
    r'|\*(?=[^\s*])(?<i1>[\s\S]*?[^\s*]|[^\s*])\*'
    r'|(?<![A-Za-z0-9])_(?=[^\s_])(?<i2>[\s\S]*?[^\s_]|[^\s_])_(?![A-Za-z0-9])',
  );

  /// The URL of a link when it may be opened: http(s) with a host, or
  /// mailto. Null for every other scheme (`javascript:`, `data:`, `file:`,
  /// relative URLs …).
  static String? safeUrl(String raw) {
    final t = raw.trim();
    final uri = Uri.tryParse(t);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if ((scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty) {
      return t;
    }
    if (scheme == 'mailto' && uri.path.isNotEmpty) return t;
    return null;
  }

  /// [text] as a span in [base] (the root span carries [base]).
  static TextSpan spans(
    String text,
    TextStyle base,
    ShadColorScheme cs, {
    MarkdownLinkRecognizer? link,
  }) => TextSpan(
    style: base.copyWith(color: base.color ?? cs.foreground),
    children: _parse(text, base, cs, link),
  );

  static List<InlineSpan> _parse(
    String text,
    TextStyle base,
    ShadColorScheme cs,
    MarkdownLinkRecognizer? link,
  ) {
    final out = <InlineSpan>[];
    final plain = StringBuffer();
    void flush() {
      if (plain.isEmpty) return;
      out.add(TextSpan(text: plain.toString()));
      plain.clear();
    }

    var i = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > i) plain.write(text.substring(i, m.start));
      i = m.end;
      final escaped = m.group(1);
      if (escaped != null) {
        plain.write(escaped);
        continue;
      }
      final code = m.group(3);
      if (code != null) {
        flush();
        var c = code;
        if (c.length > 2 && c.startsWith(' ') && c.endsWith(' ')) {
          c = c.substring(1, c.length - 1);
        }
        out.add(
          TextSpan(
            text: c,
            style: TextStyle(
              fontFamily: WonkyTheme.monoFamily,
              fontSize: (base.fontSize ?? 14) - 1,
              backgroundColor: cs.muted,
            ),
          ),
        );
        continue;
      }
      final src = m.namedGroup('src1') ?? m.namedGroup('src2');
      if (src != null) {
        // Images are not rendered: a link to the image (16 §7.3).
        final url = safeUrl(src);
        if (url == null) {
          plain.write(m.group(0));
          continue;
        }
        flush();
        final alt = m.namedGroup('alt')!.trim();
        out.add(
          _link(url, [TextSpan(text: alt.isEmpty ? url : alt)], cs, link),
        );
        continue;
      }
      final href = m.namedGroup('href1') ?? m.namedGroup('href2');
      if (href != null) {
        final url = safeUrl(href);
        if (url == null) {
          // Other schemes are shown as text, never as a link.
          plain.write(m.group(0));
          continue;
        }
        flush();
        out.add(
          _link(url, _parse(m.namedGroup('label')!, base, cs, null), cs, link),
        );
        continue;
      }
      final auto = m.namedGroup('auto') ?? m.namedGroup('bare');
      if (auto != null) {
        final url = safeUrl(auto);
        if (url == null) {
          plain.write(m.group(0));
          continue;
        }
        flush();
        out.add(_link(url, [TextSpan(text: auto)], cs, link));
        continue;
      }
      flush();
      final bold = m.namedGroup('b1') ?? m.namedGroup('b2');
      if (bold != null) {
        out.add(
          TextSpan(
            style: const TextStyle(fontWeight: FontWeight.w600),
            children: _parse(bold, base, cs, link),
          ),
        );
        continue;
      }
      final strike = m.namedGroup('s');
      if (strike != null) {
        out.add(
          TextSpan(
            style: const TextStyle(decoration: TextDecoration.lineThrough),
            children: _parse(strike, base, cs, link),
          ),
        );
        continue;
      }
      out.add(
        TextSpan(
          style: const TextStyle(fontStyle: FontStyle.italic),
          children: _parse(
            m.namedGroup('i1') ?? m.namedGroup('i2')!,
            base,
            cs,
            link,
          ),
        ),
      );
    }
    if (i < text.length) plain.write(text.substring(i));
    flush();
    return out;
  }

  /// A link: [children] styled as a link, every leaf carrying the
  /// recognizer (hit testing only finds leaf spans).
  static InlineSpan _link(
    String url,
    List<InlineSpan> children,
    ShadColorScheme cs,
    MarkdownLinkRecognizer? link,
  ) {
    final recognizer = link?.call(url);
    InlineSpan leaf(InlineSpan s) {
      if (s is! TextSpan) return s;
      return TextSpan(
        text: s.text,
        style: s.style,
        children: s.children?.map(leaf).toList(),
        recognizer: recognizer,
        mouseCursor: recognizer == null ? null : SystemMouseCursors.click,
        semanticsLabel: s.semanticsLabel,
      );
    }

    return TextSpan(
      style: TextStyle(
        color: cs.primary,
        decoration: TextDecoration.underline,
        decorationColor: cs.primary,
      ),
      children: children.map(leaf).toList(),
      recognizer: recognizer,
      mouseCursor: recognizer == null ? null : SystemMouseCursors.click,
    );
  }
}
