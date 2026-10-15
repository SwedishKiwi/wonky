import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:wonky_fonts/wonky_fonts.dart';
import 'package:wonky_slides_core/interfaces.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/pdf.dart';

/// The bundled TTFs of `wonky_fonts` (the package's `fonts/` folder),
/// read from disk like the server reads `web/fonts/`.
abstract final class PdfFixture {
  static Directory? _dir;

  /// The `fonts/` folder of `wonky_fonts`.
  static Future<Directory> fontsDirectory() async {
    if (_dir != null) return _dir!;
    final lib = await Isolate.resolvePackageUri(
      Uri.parse('package:wonky_fonts/wonky_fonts.dart'),
    );
    return _dir = Directory.fromUri(
      lib!.resolve('../${BundledFonts.directory}/'),
    );
  }

  /// A provider over the bundled files.
  static Future<BundledFileFontProvider> fonts() async {
    final dir = await fontsDirectory();
    return BundledFileFontProvider((file) async {
      final f = File('${dir.path}$file');
      return await f.exists() ? f.readAsBytes() : null;
    });
  }

  /// Export resources with the bundled fonts and [images].
  static Future<SlidesExportResources> resources({
    Map<String, Uint8List>? images,
    SlidesPdfDocumentInfo info = const SlidesPdfDocumentInfo(),
  }) async => SlidesExportResources(
    fonts: await fonts(),
    images: MemorySlideImageResolver(images),
    info: info,
  );

  /// Renders [deck] uncompressed (inspectable PDF syntax).
  static Future<(SlidesPdfResult, String)> render(
    DeckModel deck,
    SlidesPdfOptions options, {
    SlidesExportResources? resources,
    SlidesPdfExporter? exporter,
  }) async {
    final r = await (exporter ?? SlidesPdfExporter(compress: false)).render(
      deck,
      options,
      resources ?? await PdfFixture.resources(),
    );
    return (r, latin1.decode(r.bytes));
  }

  /// The number of `/Type /Page` objects in [pdf] (not `/Pages`).
  static int pageObjects(String pdf) =>
      RegExp(r'/Type\s*/Page(?![a-zA-Z])').allMatches(pdf).length;

  /// The `/MediaBox` sizes in [pdf].
  static List<String> mediaBoxes(String pdf) => [
    for (final m in RegExp(r'/MediaBox\s*\[([^\]]*)\]').allMatches(pdf))
      m.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' '),
  ];

  /// Literal or hex PDF strings following `/Title` (outline items and the
  /// info dictionary), decoded.
  static List<String> titles(String pdf) => [
    for (final m in RegExp(
      r'/Title\s*(\((?:\\.|[^\\)])*\)|<[0-9A-Fa-f]*>)',
    ).allMatches(pdf))
      decodeString(m.group(1)!),
  ];

  /// Outline items: title → the title of its parent item (null for
  /// top-level items under `/Outlines`).
  static Map<String, String?> outlineParents(String pdf) {
    final objects = <String, String>{
      for (final m in RegExp(
        r'(\d+) 0 obj(.*?)endobj',
        dotAll: true,
      ).allMatches(pdf))
        m.group(1)!: m.group(2)!,
    };
    String? titleOf(String body) {
      final m = RegExp(
        r'/Title\s*(\((?:\\.|[^\\)])*\)|<[0-9A-Fa-f]*>)',
      ).firstMatch(body);
      return m == null ? null : decodeString(m.group(1)!);
    }

    final out = <String, String?>{};
    for (final body in objects.values) {
      if (!body.contains('/Parent') || !body.contains('/Title')) continue;
      final parent = RegExp(r'/Parent\s*(\d+) 0 R').firstMatch(body);
      final title = titleOf(body);
      if (parent == null || title == null) continue;
      final p = objects[parent.group(1)!];
      out[title] = p == null ? null : titleOf(p);
    }
    return out;
  }

  /// Decodes a PDF string token (`(...)` or `<FEFF...>`).
  static String decodeString(String token) {
    if (token.startsWith('<')) {
      final hex = token.substring(1, token.length - 1);
      final bytes = [
        for (var i = 0; i + 1 < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ];
      if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
        final units = [
          for (var i = 2; i + 1 < bytes.length; i += 2)
            (bytes[i] << 8) | bytes[i + 1],
        ];
        return String.fromCharCodes(units);
      }
      return latin1.decode(bytes);
    }
    final body = token.substring(1, token.length - 1);
    final raw = body.replaceAllMapped(
      RegExp(r'\\(.)'),
      (m) => switch (m.group(1)) {
        'n' => '\n',
        'r' => '\r',
        't' => '\t',
        _ => m.group(1)!,
      },
    );
    final units = latin1.encode(raw);
    if (units.length >= 2 && units[0] == 0xfe && units[1] == 0xff) {
      return String.fromCharCodes([
        for (var i = 2; i + 1 < units.length; i += 2)
          (units[i] << 8) | units[i + 1],
      ]);
    }
    return raw;
  }
}
