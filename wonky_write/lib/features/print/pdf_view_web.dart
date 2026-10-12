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

/// The PDF in the browser's built-in viewer, inside the app (an `<iframe>`
/// platform view — no new tab or window, suite 03 §1).
class PdfView extends StatefulWidget {
  const PdfView({super.key, required this.bytes, this.pageCount});

  final Uint8List bytes;
  final int? pageCount;

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
    _viewType = 'wonky-pdf-view-${_nextId++}';
    final url = _url;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final frame = web.HTMLIFrameElement()
        ..src = '$url#toolbar=1&navpanes=0&view=FitH'
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

/// Prints [bytes] through the browser's print dialog using a hidden iframe
/// (same tab).
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
