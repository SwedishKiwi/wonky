/// EPUB chapter splitting and chapter XHTML documents (07 §5.8).
library;

import '../../ir/anchors.dart';
import '../../ir/doc_tree.dart';
import '../export_api.dart';
import '../html/html_writer.dart';
import '../office/office_support.dart';

/// One chapter (`OEBPS/text/chapter-NNN.xhtml`) of an EPUB.
final class EpubChapter {
  /// Creates a chapter.
  const EpubChapter({
    required this.number,
    required this.title,
    required this.blocks,
    required this.counters,
    this.heading,
  });

  /// Chapter number (`0` for content before the first split heading).
  final int number;

  /// Chapter title (heading text or the document title).
  final String title;

  /// The blocks of the chapter.
  final List<DocBlock> blocks;

  /// The heading that starts the chapter (`null` for chapter 0 and for
  /// unsplit documents).
  final HeadingBlock? heading;

  /// Heading counters (levels 1–6) before the chapter's first block, so
  /// theme heading numbering continues across chapter files.
  final List<int> counters;

  /// File name relative to `OEBPS/text/` (`chapter-001.xhtml`).
  String get fileName => 'chapter-${number.toString().padLeft(3, '0')}.xhtml';

  /// Path relative to `OEBPS/` (`text/chapter-001.xhtml`).
  String get href => 'text/$fileName';

  /// Manifest id (`chapter-001`).
  String get id => 'chapter-${number.toString().padLeft(3, '0')}';
}

/// Splits a [DocTree] into [EpubChapter]s.
abstract final class EpubChapterSplitter {
  /// Splits [tree] per [mode]: at level-1 headings ([EpubChapterSplit.h1]),
  /// at level-1 and level-2 headings ([EpubChapterSplit.h2]) or not at all.
  ///
  /// Content before the first split heading becomes chapter 0 when it is
  /// not blank; otherwise numbering starts at 1. An unsplit (or empty)
  /// document is a single chapter 1 titled [documentTitle].
  static List<EpubChapter> split(
    DocTree tree,
    EpubChapterSplit mode, {
    required String documentTitle,
  }) {
    final maxLevel = switch (mode) {
      EpubChapterSplit.h1 => 1,
      EpubChapterSplit.h2 => 2,
      EpubChapterSplit.none => 0,
    };
    final chunks = <(HeadingBlock?, List<DocBlock>, List<int>)>[];
    final counters = List<int>.filled(6, 0);
    var current = <DocBlock>[];
    HeadingBlock? currentHeading;
    var currentCounters = List<int>.filled(6, 0);
    for (final block in tree.blocks) {
      if (block is HeadingBlock && block.level <= maxLevel) {
        chunks.add((currentHeading, current, currentCounters));
        current = <DocBlock>[];
        currentHeading = block;
        currentCounters = List<int>.of(counters);
      }
      if (block is HeadingBlock) {
        final l = block.level.clamp(1, 6);
        counters[l - 1]++;
        for (var i = l; i < 6; i++) {
          counters[i] = 0;
        }
      }
      current.add(block);
    }
    chunks.add((currentHeading, current, currentCounters));

    final out = <EpubChapter>[];
    final lead = chunks.first;
    if (!_isBlank(lead.$2) && chunks.length > 1) {
      out.add(
        EpubChapter(
          number: 0,
          title: documentTitle,
          blocks: lead.$2,
          counters: lead.$3,
        ),
      );
    }
    if (chunks.length == 1) {
      return [
        EpubChapter(
          number: 1,
          title: documentTitle,
          blocks: lead.$2,
          counters: lead.$3,
        ),
      ];
    }
    var n = 0;
    for (final (heading, blocks, start) in chunks.skip(1)) {
      n++;
      final text = runsPlainText(heading!.runs);
      out.add(
        EpubChapter(
          number: n,
          title: text.isEmpty ? documentTitle : text,
          blocks: blocks,
          counters: start,
          heading: heading,
        ),
      );
    }
    return out;
  }

  static bool _isBlank(List<DocBlock> blocks) => blocks.every(
    (b) => b is ParagraphBlock && InlineRun.plainText(b.runs).trim().isEmpty,
  );
}

/// Maps heading anchors to the chapter files that contain them and
/// rewrites internal `#anchor` links across chapters.
final class EpubAnchorMap {
  /// Builds the map for [chapters].
  EpubAnchorMap(List<EpubChapter> chapters)
    : firstFile = chapters.first.fileName {
    for (final c in chapters) {
      for (final b in c.blocks) {
        if (b is HeadingBlock) {
          _files[b.anchorId] = c.fileName;
          _bySlug.putIfAbsent(
            AnchorIdGenerator.slugify(InlineRun.plainText(b.runs)),
            () => b.anchorId,
          );
        }
      }
    }
  }

  final _files = <String, String>{};
  final _bySlug = <String, String>{};

  /// The first chapter's file name (target of unknown fragments).
  final String firstFile;

  /// The chapter file (`chapter-002.xhtml`) that defines [anchorId].
  String? fileOf(String anchorId) => _files[anchorId];

  /// The href of [anchorId] from a chapter file named [fromFile] (`#id`
  /// within the same chapter, `chapter-00N.xhtml#id` otherwise).
  String hrefFrom(String fromFile, String anchorId) {
    final file = _files[anchorId];
    if (file == null) return firstFile;
    return file == fromFile ? '#$anchorId' : '$file#$anchorId';
  }

  /// Rewrites a fragment-only [href] (`#anchor` or `#slug`) for a link in
  /// [fromFile]; other hrefs are returned unchanged. Fragments that match
  /// no heading point at the start of the book.
  String rewrite(String fromFile, String href) {
    if (!href.startsWith('#')) return href;
    var frag = href.substring(1);
    try {
      frag = Uri.decodeComponent(frag);
    } on ArgumentError {
      // Keep the raw fragment.
    }
    final id = _files.containsKey(frag)
        ? frag
        : _bySlug[AnchorIdGenerator.slugify(frag)];
    return id == null ? firstFile : hrefFrom(fromFile, id);
  }
}

/// A [LinkResolver] that applies the document's resolver and then rewrites
/// internal anchors for one chapter.
final class EpubChapterLinkResolver implements LinkResolver {
  /// Creates a resolver for links in [fileName].
  const EpubChapterLinkResolver(this.inner, this.anchors, this.fileName);

  /// The export's link resolver.
  final LinkResolver inner;

  /// Anchor → chapter map.
  final EpubAnchorMap anchors;

  /// The chapter file containing the links.
  final String fileName;

  @override
  String resolve(String link) => anchors.rewrite(fileName, inner.resolve(link));
}

/// Writes the XHTML document of an [EpubChapter].
final class EpubChapterWriter {
  /// Creates a writer.
  const EpubChapterWriter({
    required this.language,
    required this.links,
    required this.anchors,
    required this.imageSource,
    this.numbering = false,
  });

  /// `xml:lang` / `lang`.
  final String language;

  /// The export's link resolver.
  final LinkResolver links;

  /// Anchor → chapter map.
  final EpubAnchorMap anchors;

  /// Image `src` relative to `OEBPS/text/` (`null` → placeholder).
  final String? Function(ImageBlock image) imageSource;

  /// Whether the theme numbers headings (CSS counters are continued with a
  /// `counter-reset` on the chapter's article).
  final bool numbering;

  /// The chapter document.
  String write(EpubChapter chapter) {
    final writer = HtmlBodyWriter(
      options: HtmlBodyOptions(
        xhtml: true,
        imageSource: imageSource,
        links: EpubChapterLinkResolver(links, anchors, chapter.fileName),
        anchorHref: (id) => anchors.hrefFrom(chapter.fileName, id),
      ),
    );
    final style = numbering && chapter.counters.any((c) => c > 0)
        ? ' style="counter-reset: ${[for (var l = 1; l <= 6; l++) 'wk-h$l ${chapter.counters[l - 1]}'].join(' ')}"'
        : '';
    final body = xmlSafeMarkup(writer.blocks(chapter.blocks));
    return epubXhtmlDocument(
      language: language,
      title: chapter.title,
      head:
          '<link rel="stylesheet" type="text/css" href="../styles/theme.css"/>',
      body: '<article class="wonky-doc"$style>\n$body</article>',
    );
  }
}

/// A complete XHTML5 content document for EPUB.
String epubXhtmlDocument({
  required String language,
  required String title,
  required String body,
  String head = '',
  String bodyAttributes = '',
}) {
  final lang = xmlAttr(language);
  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<!DOCTYPE html>\n'
      '<html xmlns="http://www.w3.org/1999/xhtml" '
      'xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="$lang" lang="$lang">\n'
      '<head>\n<meta charset="UTF-8"/>\n<title>${xmlText(title)}</title>\n'
      '${head.isEmpty ? '' : '$head\n'}'
      '</head>\n<body$bodyAttributes>\n$body\n</body>\n</html>\n';
}

/// Removes characters that are not allowed in XML 1.0 from generated
/// markup (C0 controls other than tab/LF/CR, lone surrogates, U+FFFE/F).
String xmlSafeMarkup(String s) {
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final u = s.codeUnitAt(i);
    if (u >= 0xD800 && u <= 0xDBFF) {
      if (i + 1 < s.length) {
        final n = s.codeUnitAt(i + 1);
        if (n >= 0xDC00 && n <= 0xDFFF) {
          b
            ..writeCharCode(u)
            ..writeCharCode(n);
          i++;
          continue;
        }
      }
      b.write('�');
    } else if (u >= 0xDC00 && u <= 0xDFFF) {
      b.write('�');
    } else if ((u < 0x20 && u != 0x09 && u != 0x0A && u != 0x0D) ||
        u == 0xFFFE ||
        u == 0xFFFF) {
      continue;
    } else {
      b.writeCharCode(u);
    }
  }
  return b.toString();
}
