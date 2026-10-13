import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/write_l10n.dart';

/// Whether the platform shows PDFs inline (web: the browser's viewer).
const bool canPreviewPdfInline = false;

/// Shows [bytes] (desktop: a summary — the native viewer opens on Print).
class PdfView extends StatelessWidget {
  const PdfView({super.key, required this.bytes, this.pageCount});

  final Uint8List bytes;
  final int? pageCount;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = writeL10n(context);
    return Center(
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
          ),
          const SizedBox(height: 4),
          Text(l.printPdfDesktopHint, style: theme.textTheme.muted),
        ],
      ),
    );
  }
}

/// Prints [bytes] (desktop: not available; download instead).
Future<bool> printPdf(Uint8List bytes, {required String title}) async => false;
