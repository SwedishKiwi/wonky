import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:printing/printing.dart';

/// Whether [printPdf] opens a print dialog on this platform (desktop: the
/// native print dialog of the `printing` plugin, 11 §7.7).
const bool canPrintPdf = true;

/// Prints [bytes] with the native print dialog; returns false when printing
/// isn't available (no plugin, no printer support) so the caller offers
/// *Export PDF* instead.
Future<bool> printPdf(Uint8List bytes, {required String title}) async {
  try {
    final info = await Printing.info();
    if (!info.canPrint) return false;
    await Printing.layoutPdf(
      name: title,
      onLayout: (_) async => bytes,
      // Pages are already laid out; the dialog must not rescale them.
      usePrinterSettings: false,
    );
    return true;
  } on MissingPluginException {
    return false;
  } on PlatformException catch (e) {
    debugPrint('Printing failed: $e');
    return false;
  }
}
