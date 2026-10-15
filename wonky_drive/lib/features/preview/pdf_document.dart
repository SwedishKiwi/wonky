import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import 'pdf_rasterizer.dart';
import 'preview_content.dart';

/// The open PDF of a preview (Drive 02 §6.3): page sizes from a low-dpi
/// scan (which doubles as placeholders), and sharp page images rendered on
/// demand for the visible pages ± 2 at device pixel ratio × zoom (also
/// while the scan still runs, so the first page is sharp quickly).
class PdfDocumentState extends ChangeNotifier {
  PdfDocumentState(this.rasterizer, this.bytes);

  final PdfRasterizer rasterizer;
  final Uint8List bytes;

  /// The dpi of the size scan / placeholders.
  static const scanDpi = 12.0;

  /// Page sizes in points (1/72 in), in order; grows while scanning.
  final List<Size> pageSizes = [];

  /// Whether the size scan is still running.
  bool scanning = true;

  /// The PDF has more pages than [PreviewLimits.pdfPages].
  bool truncated = false;

  /// Set when the PDF can't be opened.
  Object? error;

  /// The PDF is password-protected.
  bool passwordProtected = false;

  final Map<int, PdfPageImage> _low = {};
  final Map<int, PdfPageImage> _sharp = {};
  final Map<int, double> _sharpDpi = {};
  final Set<int> _wanted = {};
  double _wantedDpi = 72;
  bool _rendering = false;
  bool _disposed = false;
  StreamSubscription<PdfPageImage>? _scan;

  int get pageCount => pageSizes.length;

  /// The best image of page [index] so far (sharp, else placeholder).
  PdfPageImage? imageOf(int index) => _sharp[index] ?? _low[index];

  /// Scans every page at [scanDpi] (stops after [PreviewLimits.pdfPages]).
  Future<void> open() {
    final done = Completer<void>();
    var lastNotify = 0;
    _scan = rasterizer
        .raster(bytes, dpi: scanDpi)
        .listen(
          (p) {
            if (pageSizes.length >= PreviewLimits.pdfPages) {
              truncated = true;
              _scan?.cancel();
              _finishScan(done);
              return;
            }
            pageSizes.add(
              Size(p.width * 72 / scanDpi, p.height * 72 / scanDpi),
            );
            _low[p.index] = p;
            // First page right away, then in batches.
            if (pageSizes.length == 1 || pageSizes.length - lastNotify >= 8) {
              lastNotify = pageSizes.length;
              _notify();
            }
          },
          onError: (Object e) {
            if (e is PdfPasswordException) {
              passwordProtected = true;
            } else if (pageSizes.isEmpty) {
              error = e;
            }
            // A failure after some pages keeps the pages read so far.
            _finishScan(done);
          },
          onDone: () => _finishScan(done),
          cancelOnError: true,
        );
    return done.future;
  }

  void _finishScan(Completer<void> done) {
    if (done.isCompleted) return;
    scanning = false;
    if (pageSizes.isEmpty && error == null && !passwordProtected) {
      error = StateError('The PDF has no pages');
    }
    _notify();
    done.complete();
    _pump();
  }

  /// Requests sharp images of [pages] at [dpi]; pages far from them drop
  /// their sharp images (memory).
  void ensure(Iterable<int> pages, double dpi) {
    _wanted
      ..clear()
      ..addAll(pages.where((p) => p >= 0 && p < pageCount));
    _wantedDpi = dpi.clamp(24, 600).toDouble();
    if (_wanted.isEmpty) return;
    final lo = _wanted.reduce((a, b) => a < b ? a : b) - 6;
    final hi = _wanted.reduce((a, b) => a > b ? a : b) + 6;
    _sharp.removeWhere((k, _) => k < lo || k > hi);
    _sharpDpi.removeWhere((k, _) => k < lo || k > hi);
    _pump();
  }

  Future<void> _pump() async {
    if (_rendering || _disposed) return;
    final need = [
      for (final p in _wanted.toList()..sort())
        if (p < pageCount && (_sharpDpi[p] ?? 0) < _wantedDpi * 0.9) p,
    ];
    if (need.isEmpty) return;
    _rendering = true;
    final dpi = _wantedDpi;
    try {
      await for (final img in rasterizer.raster(bytes, pages: need, dpi: dpi)) {
        if (_disposed) return;
        _sharp[img.index] = img;
        _sharpDpi[img.index] = dpi;
        _notify();
      }
    } on Object {
      // Keep the placeholders; the next request retries.
      for (final p in need) {
        _sharpDpi[p] = dpi;
      }
    } finally {
      _rendering = false;
    }
    if (!_disposed) unawaited(_pump());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scan?.cancel();
    super.dispose();
  }
}
