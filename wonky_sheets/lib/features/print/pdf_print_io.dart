import 'dart:typed_data';

/// Whether [printPdf] opens a print dialog on this platform (desktop: no
/// native print integration yet; *Export PDF* saves the file instead).
const bool canPrintPdf = false;

/// Prints [bytes]; returns false when printing isn't available.
Future<bool> printPdf(Uint8List bytes, {required String title}) async => false;
