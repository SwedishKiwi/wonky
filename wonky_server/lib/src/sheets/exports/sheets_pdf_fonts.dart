import 'dart:io';
import 'dart:typed_data';

import 'package:wonky_sheets_core/model.dart' as core;

import '../../write/export/server_fonts.dart';

/// PDF fonts of server-side spreadsheet PDFs (`drive.export pdf`, 11 §7.4):
/// the same bundled static TTFs as the app (`web/fonts/`, copied from
/// `wonky_sheets/assets/fonts/`) with the same family mapping
/// (`BundledPdfFonts`), so server and client PDFs embed the same faces.
/// Without the files the standard PDF fonts are used.
abstract final class SheetsPdfFonts {
  static Future<core.PdfFontProvider>? _instance;

  /// The process-wide provider (fonts are read once).
  static Future<core.PdfFontProvider> load({Directory? directory}) {
    if (directory != null) return _load(directory);
    return _instance ??= _load(FileSystemFontProvider.defaultDirectory());
  }

  static Future<core.PdfFontProvider> _load(Directory dir) =>
      core.BundledPdfFonts.load((file) async {
        final f = File('${dir.path}/$file');
        if (!await f.exists()) return null;
        final bytes = await f.readAsBytes();
        return ByteData.sublistView(bytes);
      });
}
