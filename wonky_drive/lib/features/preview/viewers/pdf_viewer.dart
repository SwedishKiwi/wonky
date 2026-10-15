import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../l10n/drive_l10n.dart';
import '../file_preview_controller.dart';
import '../pdf_document.dart';

/// PDF viewer (Drive 02 §6.3): pages as images in a vertical continuous
/// scroll, white paper with a shadow in both themes, fit width by default
/// (zoom 25–400 %); visible pages ± 2 are rasterized at device pixel ratio
/// × zoom. No PDF JavaScript, forms or links ever run.
class PdfViewer extends StatefulWidget {
  const PdfViewer({super.key, required this.controller});

  final FilePreviewController controller;

  /// Logical pixels per PDF point at 100 % (1 pt = 4/3 CSS px).
  static const pxPerPoint = 4 / 3;

  static ValueKey<String> pageKey(int index) =>
      ValueKey<String>('drive.preview.pdf.page.$index');

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  final _v = ScrollController();
  final _h = ScrollController();
  StreamSubscription<int>? _jumps;
  List<double> _offsets = const [];
  double _scale = 1;
  double _dpr = 1;

  static const _pad = 24.0;
  static const _gap = 16.0;

  FilePreviewController get c => widget.controller;
  PdfDocumentState get doc => c.pdf!;

  @override
  void initState() {
    super.initState();
    _v.addListener(_onScroll);
    _jumps = c.pageJumps.listen(_jumpTo);
  }

  @override
  void dispose() {
    _jumps?.cancel();
    _v.dispose();
    _h.dispose();
    super.dispose();
  }

  void _jumpTo(int page) {
    if (!_v.hasClients || page >= _offsets.length) return;
    _v.jumpTo(_offsets[page].clamp(0, _v.position.maxScrollExtent).toDouble());
  }

  int _pageAt(double y) {
    var lo = 0;
    var hi = _offsets.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_offsets[mid] <= y) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return math.max(0, lo);
  }

  void _onScroll() => _request();

  /// Reports the current page and asks for sharp images of the visible
  /// pages ± 2.
  void _request() {
    if (_offsets.isEmpty) return;
    final top = _v.hasClients ? _v.offset : 0.0;
    final height = _v.hasClients ? _v.position.viewportDimension : 800.0;
    final first = _pageAt(top);
    final last = _pageAt(top + height);
    final mid = _pageAt(top + height / 3);
    c.reportPage(mid);
    doc.ensure([
      for (var p = first - 2; p <= last + 2; p++) p,
    ], 72 * PdfViewer.pxPerPoint * _scale * _dpr);
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final kb = HardwareKeyboard.instance;
    if (!kb.isControlPressed && !kb.isMetaPressed) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (_) {
      final factor = e.scrollDelta.dy > 0 ? 1 / 1.1 : 1.1;
      c.setZoom(c.effectiveZoom * factor);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = driveL10n(context);
    final sizes = doc.pageSizes;
    _dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return LayoutBuilder(
      builder: (context, box) {
        final maxW = sizes.isEmpty
            ? 612.0
            : sizes.map((s) => s.width).reduce(math.max);
        final avail = math.max(80.0, box.maxWidth - _pad * 2);
        final fit = avail / (maxW * PdfViewer.pxPerPoint);
        c.reportFitScale(fit);
        _scale = c.effectiveZoom * PdfViewer.pxPerPoint;
        var y = _pad;
        final offsets = <double>[];
        for (final s in sizes) {
          offsets.add(y - _pad);
          y += s.height * _scale + _gap;
        }
        _offsets = offsets;
        final contentW = math.max(box.maxWidth, maxW * _scale + _pad * 2);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _request();
        });
        return Listener(
          onPointerSignal: _onSignal,
          child: RawScrollbar(
            controller: _h,
            notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _h,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentW,
                height: box.maxHeight,
                child: RawScrollbar(
                  controller: _v,
                  child: ListView.builder(
                    controller: _v,
                    padding: const EdgeInsets.symmetric(vertical: _pad),
                    itemCount: sizes.length,
                    itemBuilder: (context, i) {
                      final s = sizes[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: _gap),
                        child: Center(
                          child: _PdfPage(
                            key: PdfViewer.pageKey(i),
                            image: doc.imageOf(i)?.png,
                            width: s.width * _scale,
                            height: s.height * _scale,
                            label: l.previewPdfPageSemantics(
                              i + 1,
                              sizes.length,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One page: white paper with a shadow (both themes), the page image.
class _PdfPage extends StatelessWidget {
  const _PdfPage({
    super.key,
    required this.image,
    required this.width,
    required this.height,
    required this.label,
  });

  final Uint8List? image;
  final double width;
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    final img = image;
    return Semantics(
      label: label,
      image: true,
      child: Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xffffffff),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: img == null
            ? null
            : Image.memory(
                img,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
      ),
    );
  }
}
