/// Page geometry of imported files → Wonky page setup (07 §3.6 "page
/// size/orientation/margins → page setup of the new document").
library;

import '../layout/page_setup.dart';
import 'import_api.dart';

/// Converts [ImportedPageSetup]s.
abstract final class ImportedPageSetups {
  /// The page setup for [imported]: a known paper size (either orientation,
  /// ±2 pt) or a custom size within 2–48 in; margins when all four are
  /// known and leave a content box of at least 2 × 2 in, else the theme's.
  /// `null` when the geometry is unusable.
  static PageSetup? toPageSetup(
    ImportedPageSetup imported, {
    PageSetup base = const PageSetup(),
  }) {
    final w = imported.widthPt;
    final h = imported.heightPt;
    if (!(w > 0 && h > 0)) return null;
    final landscape = w > h;
    final portraitW = landscape ? h : w;
    final portraitH = landscape ? w : h;
    var paper = PaperSize.custom;
    for (final p in PaperSize.values) {
      if (p == PaperSize.custom) continue;
      if ((p.widthPt - portraitW).abs() <= 2 &&
          (p.heightPt - portraitH).abs() <= 2) {
        paper = p;
        break;
      }
    }
    const minSide = 2 * 72.0, maxSide = 48 * 72.0;
    if (paper == PaperSize.custom &&
        (portraitW < minSide ||
            portraitH < minSide ||
            portraitW > maxSide ||
            portraitH > maxSide)) {
      return null;
    }
    PageMargins? margins;
    final t = imported.marginTopPt;
    final r = imported.marginRightPt;
    final b = imported.marginBottomPt;
    final l = imported.marginLeftPt;
    if (t != null && r != null && b != null && l != null) {
      final contentW = w - l - r;
      final contentH = h - t - b;
      if (contentW >= minSide && contentH >= minSide) {
        double round(double v) => (v * 100).round() / 100;
        margins = PageMargins(
          top: round(t),
          right: round(r),
          bottom: round(b),
          left: round(l),
        );
      }
    }
    final header = base.header;
    final footer = base.footer;
    HeaderFooterSpec fit(HeaderFooterSpec s, double? margin) {
      if (margin == null || s.distancePt < margin) return s;
      return HeaderFooterSpec(
        enabled: s.enabled,
        left: s.left,
        center: s.center,
        right: s.right,
        distancePt: margin / 2,
      );
    }

    return PageSetup(
      layout: base.layout,
      paper: paper,
      customWidthPt: paper == PaperSize.custom ? portraitW : base.customWidthPt,
      customHeightPt: paper == PaperSize.custom
          ? portraitH
          : base.customHeightPt,
      orientation: landscape
          ? PageOrientation.landscape
          : PageOrientation.portrait,
      margins: margins,
      header: fit(header, margins?.top),
      footer: fit(footer, margins?.bottom),
      differentFirstPage: base.differentFirstPage,
      firstPageHeader: base.firstPageHeader,
      firstPageFooter: base.firstPageFooter,
      pageNumberStart: base.pageNumberStart,
      pageNumberFormat: base.pageNumberFormat,
    );
  }
}
