/// EPUB 3 exporter (07 §5.8).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

import '../../fonts/font_provider.dart';
import '../../ir/anchors.dart';
import '../../ir/doc_tree.dart';
import '../../theme/mappers/css_writer.dart';
import '../../theme/model/values.dart';
import '../../theme/resolve/resolved_theme.dart';
import '../../theme/resolve/theme_resolver.dart';
import '../export_api.dart';
import '../markdown_file_exporter.dart';
import '../office/office_support.dart';
import '../zip.dart';
import 'epub_chapters.dart';
import 'epub_cover.dart';
import 'epub_package.dart';

/// Exports a document as an EPUB 3 book (with an EPUB 2 NCX for older
/// readers):
///
/// ```text
/// mimetype                      stored, first
/// META-INF/container.xml
/// OEBPS/content.opf             metadata, manifest, spine
/// OEBPS/nav.xhtml               toc (H1–H3) + landmarks
/// OEBPS/toc.ncx
/// OEBPS/cover.xhtml             cover ≠ none
/// OEBPS/text/chapter-NNN.xhtml  split per EpubExportOptions.chapterSplit
/// OEBPS/styles/theme.css        ThemeCssWriter (target: epub)
/// OEBPS/fonts/*.ttf             embedFonts (+ LICENSE-OFL.txt)
/// OEBPS/images/*
/// ```
///
/// Output is deterministic: identical input gives identical bytes.
final class EpubExporter implements DocumentExporter<EpubExportOptions> {
  /// Creates the exporter.
  const EpubExporter();

  @override
  ExportFormat get format => ExportFormat.epub;

  static const _xhtml = 'application/xhtml+xml';

  @override
  Future<ExportArtifact> export(
    ExportInput input,
    EpubExportOptions options,
  ) async {
    input.cancel?.throwIfCancelled();
    input.progress?.call(ExportPhase.loading, 0);
    final warnings = <ExportWarning>[];
    final tree = exportTree(input, options);
    final theme = ThemeResolver.instance.resolve(
      input.theme,
      ThemeVariant.light,
    );
    final title = _title(input, tree);
    final author = options.author ?? exportAuthor(input);
    final language = _language(input.meta.language);
    final identifier = epubIdentifier(input);

    final entries = <ZipEntry>[
      ZipEntry.text('mimetype', 'application/epub+zip', store: true),
      ZipEntry.text('META-INF/container.xml', EpubPackageWriter.containerXml),
    ];
    final manifest = <EpubManifestItem>[];
    void add(EpubManifestItem item, Uint8List bytes, {bool store = false}) {
      manifest.add(item);
      entries.add(ZipEntry('OEBPS/${item.href}', bytes, store: store));
    }

    Uint8List text(String s) => Uint8List.fromList(utf8.encode(s));

    // Images (07 §4.4: PNG/JPEG, ≤ 2400 px).
    input.progress?.call(ExportPhase.images, 0);
    final images = await resolveOfficeImages(input, tree, warnings);
    final imageItems = <String, EpubManifestItem>{};
    final imageBytes = <String, Uint8List>{};
    for (final im in tree.images) {
      final r = images[im.src];
      if (r == null || imageItems.containsKey(im.src)) continue;
      final n = (imageItems.length + 1).toString().padLeft(3, '0');
      imageItems[im.src] = EpubManifestItem(
        id: 'img-$n',
        href: 'images/image-$n.${r.extension}',
        mediaType: r.mime,
      );
      imageBytes[im.src] = r.bytes;
    }

    // Cover.
    input.cancel?.throwIfCancelled();
    final cover = await _cover(input, options, tree, images, warnings);
    String? coverImageSrc;
    if (cover != null && cover.src != null) {
      coverImageSrc = cover.src;
      if (!imageItems.containsKey(cover.src)) {
        imageItems[cover.src!] = EpubManifestItem(
          id: 'img-cover',
          href: 'images/cover.${cover.image!.extension}',
          mediaType: cover.image!.mime,
        );
        imageBytes[cover.src!] = cover.image!.bytes;
      }
    }
    if (coverImageSrc != null) {
      final item = imageItems[coverImageSrc]!;
      imageItems[coverImageSrc] = EpubManifestItem(
        id: item.id,
        href: item.href,
        mediaType: item.mediaType,
        properties: const ['cover-image'],
      );
    }

    // Fonts.
    input.progress?.call(ExportPhase.fonts, 0);
    final fonts = options.embedFonts
        ? await _fonts(input, theme, warnings)
        : const <_EmbeddedFont>[];
    input.cancel?.throwIfCancelled();

    // Chapters.
    input.progress?.call(ExportPhase.packaging, 0);
    final chapters = EpubChapterSplitter.split(
      tree,
      options.chapterSplit,
      documentTitle: title,
    );
    final anchors = EpubAnchorMap(chapters);
    final chapterWriter = EpubChapterWriter(
      language: language,
      links: input.links,
      anchors: anchors,
      numbering: theme.headingNumbering.enabled,
      imageSource: (img) {
        final item = imageItems[img.src];
        return item == null ? null : '../${item.href}';
      },
    );

    // Navigation.
    final labels = headingLabels(tree, theme);
    final navEntries = <EpubNavEntry>[];
    if (chapters.first.number == 0) {
      navEntries.add(
        EpubNavEntry(level: 1, label: title, href: chapters.first.href),
      );
    }
    for (var i = 0; i < tree.blocks.length; i++) {
      final b = tree.blocks[i];
      if (b is! HeadingBlock || b.level > 3) continue;
      final file = anchors.fileOf(b.anchorId)!;
      final text = runsPlainText(b.runs);
      final label =
          '${labels[i] ?? ''}${text.isEmpty ? 'Untitled section' : text}'
              .trim();
      navEntries.add(
        EpubNavEntry(
          level: b.level,
          label: label,
          href: 'text/$file#${b.anchorId}',
        ),
      );
    }
    if (navEntries.isEmpty) {
      navEntries.add(
        EpubNavEntry(level: 1, label: title, href: chapters.first.href),
      );
    }
    final nav = EpubNavEntry.nest(navEntries);

    add(
      EpubManifestItem(
        id: 'nav',
        href: 'nav.xhtml',
        mediaType: _xhtml,
        properties: const ['nav'],
      ),
      text(
        EpubPackageWriter.nav(
          language: language,
          title: 'Contents',
          entries: nav,
          bodyHref: chapters.first.href,
          coverHref: cover == null ? null : 'cover.xhtml',
        ),
      ),
    );
    add(
      const EpubManifestItem(
        id: 'ncx',
        href: 'toc.ncx',
        mediaType: 'application/x-dtbncx+xml',
      ),
      text(
        EpubPackageWriter.ncx(
          identifier: identifier,
          language: language,
          title: title,
          author: author,
          entries: nav,
        ),
      ),
    );
    add(
      const EpubManifestItem(
        id: 'css',
        href: 'styles/theme.css',
        mediaType: 'text/css',
      ),
      text(
        const ThemeCssWriter().write(
          theme,
          target: CssTarget.epub,
          useColors: options.useThemeColors,
          fonts: [
            for (final f in fonts)
              CssFontFace(
                family: f.family,
                weight: f.weight,
                italic: f.italic,
                url: '../${f.href}',
              ),
          ],
        ),
      ),
    );
    if (cover != null) {
      final imageItem = coverImageSrc == null
          ? null
          : imageItems[coverImageSrc];
      add(
        EpubManifestItem(
          id: 'cover',
          href: 'cover.xhtml',
          mediaType: _xhtml,
          properties: imageItem == null ? const ['svg'] : const [],
        ),
        text(
          imageItem == null
              ? EpubCoverWriter.generated(
                  language: language,
                  title: title,
                  author: author,
                  theme: theme,
                )
              : EpubCoverWriter.image(
                  language: language,
                  title: title,
                  imageHref: imageItem.href,
                ),
        ),
      );
    }
    for (final c in chapters) {
      input.cancel?.throwIfCancelled();
      add(
        EpubManifestItem(id: c.id, href: c.href, mediaType: _xhtml),
        text(chapterWriter.write(c)),
      );
    }
    for (final e in imageItems.entries) {
      add(e.value, imageBytes[e.key]!, store: true);
    }
    for (final (i, f) in fonts.indexed) {
      if (fonts.indexWhere((o) => o.href == f.href) != i) continue;
      add(
        EpubManifestItem(
          id: 'font-${i + 1}',
          href: f.href,
          mediaType: 'font/ttf',
        ),
        f.bytes,
      );
    }
    if (fonts.isNotEmpty) {
      add(
        const EpubManifestItem(
          id: 'font-license',
          href: 'fonts/LICENSE-OFL.txt',
          mediaType: 'text/plain',
        ),
        text(_fontNotice(fonts)),
      );
    }

    final coverImage = coverImageSrc == null ? null : imageItems[coverImageSrc];
    final opf = EpubPackageWriter.opf(
      meta: EpubMetadata(
        identifier: identifier,
        title: title,
        language: language,
        modified: isoTimestamp(input.meta.modifiedAt),
        creator: author,
        description: input.meta.description,
      ),
      manifest: manifest,
      spine: [if (cover != null) 'cover', for (final c in chapters) c.id],
      coverImageId: coverImage?.id,
    );
    entries.add(ZipEntry.text('OEBPS/content.opf', opf));

    input.progress?.call(ExportPhase.packaging, 1);
    return ExportArtifact(
      fileName: ExportFileNames.fileName(
        options.fileName ?? input.meta.title,
        format.extension,
      ),
      mimeType: format.mimeType,
      bytes: DeterministicZip.encode(
        entries,
        modified: input.meta.modifiedAt,
        first: const ['mimetype'],
      ),
      warnings: warnings,
    );
  }

  /// The book identifier: `urn:uuid:<documentUuid>`, else a UUID derived
  /// from a SHA-256 of title and revision (stable across exports).
  static String epubIdentifier(ExportInput input) {
    final uuid = input.meta.documentUuid?.trim();
    if (uuid != null && uuid.isNotEmpty) return 'urn:uuid:$uuid';
    final digest = sha256
        .convert(utf8.encode('${input.meta.title ?? ''}\n${input.revision}'))
        .bytes
        .sublist(0, 16);
    digest[6] = (digest[6] & 0x0F) | 0x50;
    digest[8] = (digest[8] & 0x3F) | 0x80;
    final hex = digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'urn:uuid:${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String _title(ExportInput input, DocTree tree) {
    final t = input.meta.title?.trim();
    if (t != null && t.isNotEmpty) return t;
    final h = tree.titleHeading;
    final ht = h == null ? '' : runsPlainText(h.runs);
    return ht.isEmpty ? 'Untitled' : ht;
  }

  static final _languageTag = RegExp(r'^[A-Za-z]{2,3}(-[A-Za-z0-9]{1,8})*$');

  static String _language(String? language) {
    final l = language?.trim().replaceAll('_', '-');
    return l != null && _languageTag.hasMatch(l) ? l : 'en';
  }

  Future<_Cover?> _cover(
    ExportInput input,
    EpubExportOptions options,
    DocTree tree,
    Map<String, OfficeImage> images,
    List<ExportWarning> warnings,
  ) async {
    final mode = options.cover.trim();
    if (mode == 'none') return null;
    if (mode == 'auto' || mode.isEmpty) {
      final first = tree.images
          .map((i) => i.src)
          .firstWhereOrNull(images.containsKey);
      return first == null
          ? const _Cover()
          : _Cover(src: first, image: images[first]);
    }
    final src = mode.startsWith('wonky-file://') ? mode : 'wonky-file://$mode';
    final known = images[src];
    if (known != null) return _Cover(src: src, image: known);
    final resolved = await input.images.resolve(src);
    final prepared = resolved == null ? null : prepareOfficeImage(resolved);
    if (prepared == null) {
      warnings.add(
        const ExportWarning(
          'image_unavailable',
          'The cover image could not be loaded; a generated cover was used',
        ),
      );
      return const _Cover();
    }
    return _Cover(src: src, image: prepared);
  }

  /// Loads the faces the theme uses ([ResolvedWriteTheme.usedFontFaces]),
  /// one file per distinct face.
  Future<List<_EmbeddedFont>> _fonts(
    ExportInput input,
    ResolvedWriteTheme theme,
    List<ExportWarning> warnings,
  ) async {
    final out = <_EmbeddedFont>[];
    final declared = <String>{};
    final files = <String, Uint8List>{};
    final warned = <String>{};
    for (final key in theme.usedFontFaces()) {
      input.cancel?.throwIfCancelled();
      FontFace face;
      try {
        face = await input.fonts.load(
          key.family,
          weight: key.weight,
          italic: key.italic,
        );
      } on Object {
        if (warned.add(key.family)) {
          warnings.add(
            ExportWarning(
              'font_fallback',
              'Font "${key.family}" is not available; the reader\'s fonts '
                  'are used instead',
            ),
          );
        }
        continue;
      }
      if (!declared.add('${key.family}|${face.weight}|${face.italic}')) {
        continue;
      }
      // One file per distinct face; identical bytes share a file.
      final base =
          'fonts/${AnchorIdGenerator.slugify(face.family)}-${face.weight}'
          '${face.italic ? '-italic' : ''}';
      var href = '$base.ttf';
      final same = files.entries.firstWhereOrNull(
        (e) => const ListEquality<int>().equals(e.value, face.bytes),
      );
      if (same != null) {
        href = same.key;
      } else {
        var n = 1;
        while (files.containsKey(href)) {
          n++;
          href = '$base-$n.ttf';
        }
        files[href] = face.bytes;
      }
      out.add(
        _EmbeddedFont(
          family: key.family,
          fileFamily: face.family,
          weight: face.weight,
          italic: face.italic,
          href: href,
          bytes: face.bytes,
        ),
      );
    }
    return out;
  }

  static String _fontNotice(List<_EmbeddedFont> fonts) {
    final families = {for (final f in fonts) f.fileFamily}.toList()..sort();
    return 'Embedded fonts\n'
        '==============\n\n'
        'The font files in this folder are licensed under the SIL Open Font '
        'License, Version 1.1\n(https://openfontlicense.org). They are '
        'embedded unmodified for rendering this publication\nand may not be '
        'sold by themselves.\n\n'
        'Families:\n'
        '${families.map((f) => '- $f\n').join()}';
  }
}

final class _Cover {
  const _Cover({this.src, this.image});

  /// Image source (`null` → generated SVG cover).
  final String? src;

  final OfficeImage? image;
}

final class _EmbeddedFont {
  const _EmbeddedFont({
    required this.family,
    required this.fileFamily,
    required this.weight,
    required this.italic,
    required this.href,
    required this.bytes,
  });

  /// CSS family (as the theme names it).
  final String family;

  /// Family of the loaded file (may differ when the provider substitutes).
  final String fileFamily;

  final int weight;
  final bool italic;

  /// Path relative to `OEBPS/`.
  final String href;

  final Uint8List bytes;
}
