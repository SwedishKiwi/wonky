import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Whether the platform shows PDFs inline (web: the browser's viewer).
const bool canPreviewPdfInline = true;

int _nextId = 0;
web.HTMLIFrameElement? _current;

String _blobUrl(Uint8List bytes) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  return web.URL.createObjectURL(blob);
}

/// The PDF in the browser's built-in viewer (page thumbnails, zoom,
/// navigation), inside the app: an `<iframe>` platform view — no new tab or
/// window (suite 03 §1, Slides 10 §12). [page] (1-based) is kept when the
/// PDF is regenerated.
class PdfView extends StatefulWidget {
  const PdfView({super.key, required this.bytes, this.pageCount, this.page});

  final Uint8List bytes;
  final int? pageCount;
  final int? page;

  @override
  State<PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<PdfView> {
  late String _viewType;
  late String _url;

  @override
  void initState() {
    super.initState();
    _register();
  }

  void _register() {
    _url = _blobUrl(widget.bytes);
    _viewType = 'wonky-slides-pdf-view-${_nextId++}';
    final url = _url;
    final page = widget.page == null ? '' : '&page=${widget.page}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final frame = web.HTMLIFrameElement()
        ..src = '$url#toolbar=1&navpanes=1&view=Fit$page'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      _current = frame;
      return frame;
    });
  }

  @override
  void didUpdateWidget(PdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      web.URL.revokeObjectURL(_url);
      _register();
    }
  }

  @override
  void dispose() {
    web.URL.revokeObjectURL(_url);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      HtmlElementView(key: ValueKey<String>(_viewType), viewType: _viewType);
}

/// Prints [bytes] through the browser's print dialog: the shown viewer's
/// frame, else a hidden `<iframe>` in this tab.
Future<bool> printPdf(Uint8List bytes, {required String title}) async {
  final shown = _current;
  if (shown != null && shown.isConnected) {
    try {
      shown.contentWindow?.focus();
      shown.contentWindow?.print();
      return true;
    } catch (_) {
      // Fall back to a hidden frame.
    }
  }
  final url = _blobUrl(bytes);
  final frame = web.HTMLIFrameElement()
    ..title = title
    ..style.position = 'fixed'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.width = '0'
    ..style.height = '0'
    ..style.border = '0'
    ..src = url;
  frame.onload = ((web.Event _) {
    frame.contentWindow?.focus();
    frame.contentWindow?.print();
  }).toJS;
  web.document.body?.append(frame);
  return true;
}
