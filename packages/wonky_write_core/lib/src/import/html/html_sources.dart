/// Source detection and source-specific rules for HTML imports (07 §3.5):
/// Google Docs, Microsoft Word HTML and Wonky's own HTML export.
library;

import 'package:html/dom.dart';

import 'css_styles.dart';

/// Where an HTML document comes from (selects normalizer rules).
enum HtmlSource {
  /// Any other HTML (web pages, other editors).
  generic,

  /// Google Docs clipboard HTML (`id="docs-internal-guid-…"`) or a Google
  /// Docs HTML export (`lst-kix_` list classes, `doc-content` body).
  googleDocs,

  /// Microsoft Word HTML (`xmlns:w`, `class=Mso…`, `mso-` styles).
  msWord,

  /// Wonky Write's own HTML export (`article.wonky-doc`, generator meta).
  wonky,
}

/// Detects the [HtmlSource] of raw [html].
HtmlSource detectHtmlSource(String html) {
  final head = html.length > 200000 ? html.substring(0, 200000) : html;
  if (RegExp(
        r'''<meta[^>]+name\s*=\s*["']?generator["']?[^>]+content\s*=\s*["']?Wonky Write''',
        caseSensitive: false,
      ).hasMatch(head) ||
      RegExp(r'''class\s*=\s*["'][^"']*\bwonky-doc\b''').hasMatch(head)) {
    return HtmlSource.wonky;
  }
  if (head.contains('docs-internal-guid-') ||
      head.contains('lst-kix_') ||
      RegExp(r'''class\s*=\s*["'][^"']*\bdoc-content\b''').hasMatch(head)) {
    return HtmlSource.googleDocs;
  }
  if (head.contains('urn:schemas-microsoft-com:office:word') ||
      RegExp(r'''class\s*=\s*["']?Mso''').hasMatch(head) ||
      RegExp(
        r'''<meta[^>]+content\s*=\s*["']?Microsoft Word''',
        caseSensitive: false,
      ).hasMatch(head) ||
      head.contains('mso-list:')) {
    return HtmlSource.msWord;
  }
  return HtmlSource.generic;
}

/// Microsoft Word HTML rules.
abstract final class MsWordHtml {
  static final _level = RegExp(r'level(\d+)', caseSensitive: false);
  static final _ordered = RegExp(
    r'^[\(\[]?(?:[0-9]+|[a-zA-Z]|[ivxlcdmIVXLCDM]{1,6})[.)\]]',
  );

  /// The list level (1-based) of a paragraph with `mso-list: lN levelM`, or
  /// `null` when the paragraph is not a list item.
  static int? listLevel(CssDeclarations style) {
    final v = style['mso-list'];
    if (v == null || v.toLowerCase().contains('ignore')) return null;
    final m = _level.firstMatch(v);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  /// Whether [e] is the `mso-list:Ignore` marker span (bullet/number text).
  static bool isListMarker(Element e) {
    final s = e.attributes['style'];
    return s != null &&
        RegExp(r'mso-list\s*:\s*ignore', caseSensitive: false).hasMatch(s);
  }

  /// Finds the marker text of a Word list paragraph.
  static String? markerText(Element paragraph) {
    for (final e in paragraph.querySelectorAll('span')) {
      if (isListMarker(e)) return e.text;
    }
    return null;
  }

  /// Whether a marker (e.g. `1.`, `a)`, `iv.`) denotes an ordered list.
  static bool isOrderedMarker(String? marker) {
    if (marker == null) return false;
    final t = marker.replaceAll(' ', ' ').trim();
    return _ordered.hasMatch(t);
  }

  /// The heading level for a Word paragraph class, or `null`.
  static int? headingLevel(Iterable<String> classes) {
    for (final c in classes) {
      final l = c.toLowerCase();
      if (l == 'msotitle') return 1;
      if (l == 'msosubtitle') return 2;
      final m = RegExp(r'^msoheading([1-6])$').firstMatch(l);
      if (m != null) return int.parse(m.group(1)!);
    }
    return null;
  }

  /// Whether a Word paragraph class denotes a quote.
  static bool isQuote(Iterable<String> classes) => classes.any((c) {
    final l = c.toLowerCase();
    return l == 'msoquote' || l == 'msointensequote' || l == 'msoblocktext';
  });
}

/// Google Docs rules.
abstract final class GoogleDocsHtml {
  static final _kix = RegExp(r'^lst-kix_\S*-(\d+)$');

  /// The nesting level of a Google Docs export list (`ul.lst-kix_…-N`), or
  /// `null`.
  static int? exportListLevel(Iterable<String> classes) {
    for (final c in classes) {
      final m = _kix.firstMatch(c);
      if (m != null) return int.tryParse(m.group(1)!);
    }
    return null;
  }

  /// The heading level for export paragraph classes `title`/`subtitle`.
  static int? headingLevel(Iterable<String> classes) {
    if (classes.contains('title')) return 1;
    if (classes.contains('subtitle')) return 2;
    return null;
  }
}

/// Rules for Wonky's own HTML (07 §5.3). The exporter contract:
///
/// - Content is inside `<article class="wonky-doc">`; whitespace is
///   preserved when the article has `style="white-space:pre-wrap"`.
/// - Empty paragraphs are `<p><br></p>`; a trailing soft break is written as
///   an extra `<br>`.
/// - Tasks are `<li>` starting with `<input type="checkbox" disabled
///   [checked]>`; mentions are `<a class="wonky-mention" href="mailto:…"
///   data-user-uuid="…">`; images are `<figure><img><figcaption>title
///   </figcaption></figure>`; code blocks `<pre><code class="language-x">`
///   ending with a newline.
/// - Elements with class `wonky-toc`, `wonky-heading-number` or
///   `aria-hidden="true"` are decoration and skipped.
abstract final class WonkyHtml {
  /// Classes of decorative elements skipped on import.
  static const decorationClasses = {
    'wonky-toc',
    'wonky-heading-number',
    'wonky-number',
  };

  /// Attributes that may carry a mention's user UUID.
  static const mentionAttributes = [
    'data-user-uuid',
    'data-user',
    'data-mention',
    'data-mention-uuid',
    'data-uuid',
  ];
}
