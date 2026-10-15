import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/slides_l10n.dart';

/// Whether the platform shows PDFs inline (web: the browser's viewer).
const bool canPreviewPdfInline = false;

/// Desktop and tests: a summary of the generated PDF (v2 is web only; the
/// rasterized desktop preview of 10 §12 comes with desktop work).
class PdfView extends StatelessWidget {
  const PdfView({super.key, required this.bytes, this.pageCount, this.page});

  final Uint8List bytes;
  final int? pageCount;
  final int? page;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.fileText,
              size: 40,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 12),
            Text(
              pageCount == null
                  ? l.printPdfReady
                  : l.printPdfReadyPages(pageCount!),
              style: theme.textTheme.large,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l.printPdfDesktopHint,
              style: theme.textTheme.muted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Prints [bytes] (desktop: not available yet; download instead).
Future<bool> printPdf(Uint8List bytes, {required String title}) async => false;
