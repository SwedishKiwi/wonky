import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

/// One rasterized PDF page: PNG bytes and their pixel size.
class PdfPageImage {
  const PdfPageImage({
    required this.index,
    required this.width,
    required this.height,
    required this.png,
  });

  /// 0-based page index.
  final int index;
  final int width;
  final int height;
  final Uint8List png;
}

/// Thrown when a PDF needs a password (Drive 02 §6.3).
class PdfPasswordException implements Exception {
  const PdfPasswordException();
}

/// Rasterizes PDF pages (Drive 02 §6.3): no PDF JavaScript, forms or links
/// are ever run — the viewer only shows page images.
abstract class PdfRasterizer {
  /// Whether rasterizing works here (web: the self-hosted pdf.js is
  /// reachable).
  Future<bool> available();

  /// Rasterizes [pages] (0-based; null = every page, in order) of [pdf] at
  /// [dpi]. Throws [PdfPasswordException] for encrypted PDFs and other
  /// errors for broken ones.
  Stream<PdfPageImage> raster(Uint8List pdf, {List<int>? pages, double dpi});
}

/// `printing`'s `Printing.raster`: pdf.js on the web — **self-hosted** in
/// `web/pdfjs/` because the apps are cross-origin isolated (suite 13 §3;
/// `index.html` points `dartPdfJsBaseUrl` there) — and PDFium on desktop.
/// Spike S-D1 (Drive 05 §5) chose it over `pdfrx` (no new dependency, no
/// 4–5 MB PDFium WASM; pdf.js loads only when a PDF is opened).
class PrintingPdfRasterizer implements PdfRasterizer {
  PrintingPdfRasterizer({required this.pdfJsBaseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  /// Where `pdf.min.mjs` and `pdf.worker.min.mjs` are served (the app's
  /// base URL + `pdfjs/`).
  final String pdfJsBaseUrl;
  final http.Client _http;
  Future<bool>? _available;

  /// How long the first page may take before the viewer gives up.
  static const firstPageTimeout = Duration(seconds: 30);

  @override
  Future<bool> available() => _available ??= _probe();

  Future<bool> _probe() async {
    if (!kIsWeb) return true;
    // `printing` imports pdf.js lazily; a missing file would leave its
    // loader locked forever, so check that the module is served first.
    try {
      final res = await _http.head(Uri.parse('${pdfJsBaseUrl}pdf.min.mjs'));
      if (res.statusCode != 200) return false;
      final type = res.headers['content-type'] ?? '';
      if (!type.contains('javascript')) return false;
      final info = await Printing.info().timeout(firstPageTimeout);
      return info.canRaster;
    } on Object {
      return false;
    }
  }

  @override
  Stream<PdfPageImage> raster(
    Uint8List pdf, {
    List<int>? pages,
    double dpi = 72,
  }) async* {
    if (_looksEncrypted(pdf)) throw const PdfPasswordException();
    var i = 0;
    final order = pages;
    try {
      await for (final r in Printing.raster(
        pdf,
        pages: pages,
        dpi: dpi,
      ).timeout(firstPageTimeout)) {
        final index = order == null ? i : order[i];
        i++;
        yield PdfPageImage(
          index: index,
          width: r.width,
          height: r.height,
          png: await r.toPng(),
        );
      }
    } on Object catch (e) {
      if ('$e'.toLowerCase().contains('password')) {
        throw const PdfPasswordException();
      }
      rethrow;
    }
  }

  /// A trailer `/Encrypt` entry (checked in the last 4 KB, where trailers
  /// and cross-reference streams live).
  static bool _looksEncrypted(Uint8List pdf) {
    final start = pdf.length > 4096 ? pdf.length - 4096 : 0;
    final tail = String.fromCharCodes(pdf.sublist(start));
    return tail.contains('/Encrypt');
  }
}
