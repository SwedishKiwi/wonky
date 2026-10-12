/// EPUB package documents: `container.xml`, `content.opf`, `nav.xhtml` and
/// `toc.ncx` (07 §5.8).
library;

import '../office/office_support.dart';
import 'epub_chapters.dart';

/// A file listed in the OPF manifest.
final class EpubManifestItem {
  /// Creates an item.
  const EpubManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    this.properties = const [],
  });

  /// Manifest id (an XML NCName).
  final String id;

  /// Path relative to `OEBPS/`.
  final String href;

  /// Media type.
  final String mediaType;

  /// Manifest properties (`nav`, `cover-image`, `svg`).
  final List<String> properties;
}

/// A table-of-contents entry (nav and NCX).
final class EpubNavEntry {
  /// Creates an entry.
  EpubNavEntry({required this.level, required this.label, required this.href});

  /// Heading level (1–3).
  final int level;

  /// Label text.
  final String label;

  /// Target relative to `OEBPS/` (`text/chapter-001.xhtml#h-intro-1`).
  final String href;

  /// Nested entries.
  final List<EpubNavEntry> children = [];

  /// Nests a flat, ordered list of [entries] by level: each entry becomes a
  /// child of the nearest preceding entry with a lower level.
  static List<EpubNavEntry> nest(List<EpubNavEntry> entries) {
    final roots = <EpubNavEntry>[];
    final stack = <EpubNavEntry>[];
    for (final e in entries) {
      while (stack.isNotEmpty && stack.last.level >= e.level) {
        stack.removeLast();
      }
      (stack.isEmpty ? roots : stack.last.children).add(e);
      stack.add(e);
    }
    return roots;
  }

  /// Depth of the deepest entry in [entries] (0 when empty).
  static int depth(List<EpubNavEntry> entries) {
    var d = 0;
    for (final e in entries) {
      final c = 1 + depth(e.children);
      if (c > d) d = c;
    }
    return d;
  }
}

/// Metadata of an EPUB package.
final class EpubMetadata {
  /// Creates metadata.
  const EpubMetadata({
    required this.identifier,
    required this.title,
    required this.language,
    required this.modified,
    this.creator,
    this.description,
  });

  /// `urn:uuid:…`.
  final String identifier;

  /// Title.
  final String title;

  /// BCP-47 language.
  final String language;

  /// `dcterms:modified` (`2026-10-01T12:00:00Z`).
  final String modified;

  /// Author.
  final String? creator;

  /// Description.
  final String? description;
}

/// Writes the package documents.
abstract final class EpubPackageWriter {
  /// `META-INF/container.xml`.
  static const containerXml =
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
      '  <rootfiles>\n'
      '    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>\n'
      '  </rootfiles>\n'
      '</container>\n';

  /// `OEBPS/content.opf` (EPUB 3.0 package). [spine] lists manifest ids in
  /// reading order; [coverImageId] adds the EPUB 2 `cover` meta.
  static String opf({
    required EpubMetadata meta,
    required List<EpubManifestItem> manifest,
    required List<String> spine,
    String? coverImageId,
  }) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8"?>\n')
      ..write(
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" '
        'unique-identifier="book-id" xml:lang="${xmlAttr(meta.language)}">\n',
      )
      ..write(
        '  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
        '    <dc:identifier id="book-id">${xmlText(meta.identifier)}</dc:identifier>\n'
        '    <dc:title>${xmlText(meta.title)}</dc:title>\n',
      );
    if (meta.creator != null && meta.creator!.trim().isNotEmpty) {
      b.write(
        '    <dc:creator id="creator">${xmlText(meta.creator!.trim())}</dc:creator>\n',
      );
    }
    b.write('    <dc:language>${xmlText(meta.language)}</dc:language>\n');
    if (meta.description != null && meta.description!.trim().isNotEmpty) {
      b.write(
        '    <dc:description>${xmlText(meta.description!.trim())}</dc:description>\n',
      );
    }
    b.write(
      '    <meta property="dcterms:modified">${xmlText(meta.modified)}</meta>\n',
    );
    if (coverImageId != null) {
      b.write('    <meta name="cover" content="${xmlAttr(coverImageId)}"/>\n');
    }
    b.write(
      '    <meta name="generator" content="Wonky Write"/>\n  </metadata>\n',
    );
    b.write('  <manifest>\n');
    for (final item in manifest) {
      b.write(
        '    <item id="${xmlAttr(item.id)}" href="${xmlAttr(item.href)}" '
        'media-type="${xmlAttr(item.mediaType)}"'
        '${item.properties.isEmpty ? '' : ' properties="${item.properties.join(' ')}"'}/>\n',
      );
    }
    b.write('  </manifest>\n  <spine toc="ncx">\n');
    for (final id in spine) {
      b.write('    <itemref idref="${xmlAttr(id)}"/>\n');
    }
    b.write('  </spine>\n</package>\n');
    return b.toString();
  }

  /// `OEBPS/nav.xhtml`: the `toc` nav of [entries] and a hidden `landmarks`
  /// nav ([coverHref] and the first chapter [bodyHref]).
  static String nav({
    required String language,
    required String title,
    required List<EpubNavEntry> entries,
    required String bodyHref,
    String? coverHref,
  }) {
    final b = StringBuffer()
      ..write('<nav epub:type="toc" id="toc" role="doc-toc">\n')
      ..write('<h1>${xmlText(title)}</h1>\n');
    void list(List<EpubNavEntry> items, String indent) {
      b.write('$indent<ol>\n');
      for (final e in items) {
        b.write(
          '$indent  <li><a href="${xmlAttr(e.href)}">${xmlText(e.label)}</a>',
        );
        if (e.children.isNotEmpty) {
          b.write('\n');
          list(e.children, '$indent    ');
          b.write('$indent  ');
        }
        b.write('</li>\n');
      }
      b.write('$indent</ol>\n');
    }

    list(entries, '');
    b
      ..write('</nav>\n')
      ..write('<nav epub:type="landmarks" id="landmarks" hidden="hidden">\n')
      ..write('<h2>Landmarks</h2>\n<ol>\n');
    if (coverHref != null) {
      b.write(
        '  <li><a epub:type="cover" href="${xmlAttr(coverHref)}">Cover</a></li>\n',
      );
    }
    b
      ..write(
        '  <li><a epub:type="bodymatter" href="${xmlAttr(bodyHref)}">Start of content</a></li>\n',
      )
      ..write('</ol>\n</nav>');
    return epubXhtmlDocument(
      language: language,
      title: title,
      body: b.toString(),
    );
  }

  /// `OEBPS/toc.ncx` (EPUB 2 compatibility); `dtb:uid` is [identifier].
  static String ncx({
    required String identifier,
    required String language,
    required String title,
    required List<EpubNavEntry> entries,
    String? author,
  }) {
    final depth = EpubNavEntry.depth(entries);
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8"?>\n')
      ..write(
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" '
        'xml:lang="${xmlAttr(language)}">\n',
      )
      ..write('  <head>\n')
      ..write('    <meta name="dtb:uid" content="${xmlAttr(identifier)}"/>\n')
      ..write(
        '    <meta name="dtb:depth" content="${depth < 1 ? 1 : depth}"/>\n',
      )
      ..write('    <meta name="dtb:totalPageCount" content="0"/>\n')
      ..write('    <meta name="dtb:maxPageNumber" content="0"/>\n')
      ..write('  </head>\n')
      ..write('  <docTitle><text>${xmlText(title)}</text></docTitle>\n');
    if (author != null && author.trim().isNotEmpty) {
      b.write(
        '  <docAuthor><text>${xmlText(author.trim())}</text></docAuthor>\n',
      );
    }
    b.write('  <navMap>\n');
    var order = 0;
    void points(List<EpubNavEntry> items, String indent) {
      for (final e in items) {
        order++;
        b
          ..write('$indent<navPoint id="navpoint-$order" playOrder="$order">\n')
          ..write(
            '$indent  <navLabel><text>${xmlText(e.label)}</text></navLabel>\n',
          )
          ..write('$indent  <content src="${xmlAttr(e.href)}"/>\n');
        points(e.children, '$indent  ');
        b.write('$indent</navPoint>\n');
      }
    }

    points(entries, '    ');
    b.write('  </navMap>\n</ncx>\n');
    return b.toString();
  }
}
