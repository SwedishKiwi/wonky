import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Whether [printPdf] opens a print dialog on this platform.
const bool canPrintPdf = true;

web.HTMLIFrameElement? _frame;
String? _url;

/// Prints [bytes] through the browser's print dialog from a hidden
/// `<iframe>` in this tab (11 §7.7; no new tab or window, suite 03 §1).
Future<bool> printPdf(Uint8List bytes, {required String title}) async {
  _frame?.remove();
  if (_url != null) web.URL.revokeObjectURL(_url!);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  _url = url;
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
  _frame = frame;
  web.document.body?.append(frame);
  return true;
}
