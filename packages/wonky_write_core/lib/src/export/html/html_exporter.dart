/// HTML and web-page zip exporters (07 §5.3).
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../fonts/font_provider.dart';
import '../../ir/anchors.dart';
import '../../ir/doc_tree.dart';
import '../../theme/mappers/css_writer.dart';
import '../../theme/model/values.dart';
import '../../theme/resolve/resolved_theme.dart';
import '../../theme/resolve/theme_resolver.dart';
import '../export_api.dart';
import '../markdown_file_exporter.dart';
import '../zip.dart';
import 'html_writer.dart';

/// Shared rendering for [HtmlExporter] and [HtmlZipExporter].
final class _HtmlBuild {
  _HtmlBuild(this.input, this.options);

  final ExportInput input;
  final HtmlExportOptions options;
  final warnings = <ExportWarning>[];

  late final DocTree tree = exportTree(input, options);
  late final ResolvedWriteTheme light = ThemeResolver.instance.resolve(
    input.theme,
    ThemeVariant.light,
  );
  late final ResolvedWriteTheme dark = ThemeResolver.instance.resolve(
    input.theme,
    ThemeVariant.dark,
  );

  /// The primary variant (dark when "Use dark theme").
  ResolvedWriteTheme get primary =>
      input.variant == ThemeVariant.dark ? dark : light;

  Future<Map<String, ResolvedImage>> images() async {
    final out = <String, ResolvedImage>{};
    for (final img in tree.images) {
      if (out.containsKey(img.src)) continue;
      input.cancel?.throwIfCancelled();
      final r = await input.images.resolve(img.src);
      if (r == null) {
        warnings.add(
          ExportWarning(
            'image_unavailable',
            'Image "${img.alt}" could not be loaded',
          ),
        );
      } else {
        out[img.src] = r;
      }
    }
    return out;
  }

  /// Font faces used by the theme (regular/bold/italic of each role).
  Future<List<FontFace>> fonts() async {
    final faces = <FontFace>[];
    final seen = <String>{};
    final t = primary;
    for (final (family, weights) in [
      (t.body.style.fontFamily, [400, 700]),
      (t.headings.first.style.fontFamily, [t.headings.first.style.fontWeight]),
      (t.codeBlock.style.fontFamily, [400]),
    ]) {
      for (final w in weights) {
        for (final italic in [false, true]) {
          if (italic && family == t.codeBlock.style.fontFamily) continue;
          try {
            final f = await input.fonts.load(family, weight: w, italic: italic);
            if (seen.add('${f.family}|${f.weight}|${f.italic}')) faces.add(f);
          } on FontUnavailableException {
            warnings.add(
              ExportWarning(
                'font_fallback',
                'Font "$family" is not available; using fallbacks',
              ),
            );
          }
        }
      }
    }
    return faces;
  }

  String css({List<CssFontFace> fontFaces = const []}) =>
      const ThemeCssWriter().write(
        primary,
        dark: options.includeDarkMode && input.variant == ThemeVariant.light
            ? dark
            : null,
        pageSize: (input.pageSetup.pageWidthPt, input.pageSetup.pageHeightPt),
        pageMargins: _margins(),
        fonts: fontFaces,
      );

  EdgesPt _margins() {
    final m = input.pageSetup.margins;
    if (m == null) return primary.page.defaultMargins;
    return EdgesPt(top: m.top, right: m.right, bottom: m.bottom, left: m.left);
  }

  String document({
    required String styleTag,
    required String? Function(ImageBlock) imageSrc,
  }) {
    final body = HtmlBodyWriter(
      options: HtmlBodyOptions(
        imageSource: imageSrc,
        links: input.links,
        includeToc: options.includeToc,
      ),
    ).article(tree);
    final lang = HtmlBodyWriter.attr(input.meta.language ?? 'en');
    final title = HtmlBodyWriter.escape(input.meta.title ?? 'Untitled');
    return '<!doctype html>\n<html lang="$lang">\n<head>\n'
        '<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        '<title>$title</title>\n<meta name="generator" content="Wonky Write">\n'
        '$styleTag\n</head>\n<body>\n$body\n</body>\n</html>\n';
  }
}

/// Self-contained `.html` exporter (images as data URIs by default; fonts as
/// a CSS stack unless `embedFonts`).
final class HtmlExporter implements DocumentExporter<HtmlExportOptions> {
  /// Creates the exporter.
  const HtmlExporter();

  @override
  ExportFormat get format => ExportFormat.html;

  @override
  Future<ExportArtifact> export(
    ExportInput input,
    HtmlExportOptions options,
  ) async {
    final build = _HtmlBuild(input, options);
    input.progress?.call(ExportPhase.images, 0);
    final images = options.embedImages
        ? await build.images()
        : const <String, ResolvedImage>{};
    final faces = options.embedFonts == true
        ? await build.fonts()
        : const <FontFace>[];
    input.progress?.call(ExportPhase.packaging, 0.5);
    final css = build.css(
      fontFaces: [
        for (final f in faces)
          CssFontFace(
            family: f.family,
            weight: f.weight,
            italic: f.italic,
            url: 'data:font/ttf;base64,${base64Encode(f.bytes)}',
          ),
      ],
    );
    final html = build.document(
      styleTag: '<style>\n$css</style>',
      imageSrc: (img) {
        if (!options.embedImages) {
          return img.src.startsWith('wonky-file://') ? null : img.src;
        }
        final r = images[img.src];
        if (r == null) return null;
        return 'data:${r.mime};base64,${base64Encode(r.bytes)}';
      },
    );
    input.progress?.call(ExportPhase.packaging, 1);
    return ExportArtifact(
      fileName: ExportFileNames.fileName(
        options.fileName ?? input.meta.title,
        'html',
      ),
      mimeType: format.mimeType,
      bytes: Uint8List.fromList(utf8.encode(html)),
      warnings: build.warnings,
    );
  }
}

/// Web page `.zip`: `index.html` + `style.css` + `images/` + `fonts/`.
final class HtmlZipExporter implements DocumentExporter<HtmlExportOptions> {
  /// Creates the exporter.
  const HtmlZipExporter();

  @override
  ExportFormat get format => ExportFormat.htmlZip;

  @override
  Future<ExportArtifact> export(
    ExportInput input,
    HtmlExportOptions options,
  ) async {
    final build = _HtmlBuild(input, options);
    final images = await build.images();
    final faces = options.embedFonts != false
        ? await build.fonts()
        : const <FontFace>[];
    final entries = <ZipEntry>[];
    final paths = <String, String>{};
    var n = 0;
    for (final img in build.tree.images) {
      final r = images[img.src];
      if (r == null || paths.containsKey(img.src)) continue;
      n++;
      final path =
          'images/$n-${AnchorIdGenerator.slugify(img.alt.isEmpty ? 'image' : img.alt)}.${imageExtension(r.mime)}';
      paths[img.src] = path;
      entries.add(ZipEntry(path, r.bytes, store: true));
    }
    final cssFaces = <CssFontFace>[];
    for (final f in faces) {
      final path =
          'fonts/${AnchorIdGenerator.slugify(f.family)}-${f.weight}${f.italic ? '-italic' : ''}.ttf';
      entries.add(ZipEntry(path, f.bytes, store: true));
      cssFaces.add(
        CssFontFace(
          family: f.family,
          weight: f.weight,
          italic: f.italic,
          url: path,
        ),
      );
    }
    entries.add(ZipEntry.text('style.css', build.css(fontFaces: cssFaces)));
    entries.add(
      ZipEntry.text(
        'index.html',
        build.document(
          styleTag: '<link rel="stylesheet" href="style.css">',
          imageSrc: (img) => paths[img.src],
        ),
      ),
    );
    return ExportArtifact(
      fileName: ExportFileNames.fileName(
        options.fileName ?? input.meta.title,
        'zip',
      ),
      mimeType: format.mimeType,
      bytes: DeterministicZip.encode(
        entries,
        modified: input.meta.modifiedAt,
        first: const ['index.html'],
      ),
      warnings: build.warnings,
    );
  }
}
