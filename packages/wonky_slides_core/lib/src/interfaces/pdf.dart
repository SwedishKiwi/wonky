import 'package:wonky_fonts/wonky_fonts.dart' show FontProvider;

import '../model/api/deck_model.dart';
import '../scene/nodes/text_layout.dart';
import 'images.dart';

/// Page layouts of a PDF export (10 §11.1).
enum SlidesPdfLayout { slides, notes, handouts }

/// Page sizes of a PDF export (10 §11.1); `slide` = the slide aspect.
enum SlidesPdfPageSize { slide, letter, a4, legal, a3, tabloid }

/// Page orientation (10 §11.1).
enum SlidesPdfOrientation { auto, portrait, landscape }

/// Page margins (10 §11.1).
enum SlidesPdfMargins { none, narrow, normal }

/// The options of a Slides PDF export (10 §11.1; dialog, MCP and the
/// user's last-used defaults). Named `SlidesPdfOptions` (not 10's
/// `PdfExportOptions`) because Write exports a class of that name.
final class SlidesPdfOptions {
  /// Creates options (defaults of 10 §11.1).
  const SlidesPdfOptions({
    this.layout = SlidesPdfLayout.slides,
    this.handoutsPerPage = 6,
    this.handoutOrderVertical = false,
    this.includeBuilds = false,
    this.includeSkipped = false,
    this.range = 'all',
    this.groupIds,
    this.slideIds,
    this.pageSize = SlidesPdfPageSize.slide,
    this.orientation = SlidesPdfOrientation.auto,
    this.margins = SlidesPdfMargins.none,
    this.frameSlides = false,
    this.omitBackground = false,
    this.headerDate = true,
    this.headerTitle = true,
    this.pageNumbers = true,
    this.slideNumbers = true,
    this.bookmarks = true,
    this.links = true,
    this.compact = false,
    this.finalAnimationState = false,
    this.fileName,
  });

  final SlidesPdfLayout layout;

  /// 1, 2, 3, 4, 6 or 9.
  final int handoutsPerPage;
  final bool handoutOrderVertical;

  /// One page per build step (06 §9.6).
  final bool includeBuilds;
  final bool includeSkipped;

  /// `all`, `current`, `selection` or deck positions (`"1-3,7"`).
  final String range;

  /// Only these groups' slides (overrides [range]).
  final List<String>? groupIds;

  /// Only these slides, in deck order (overrides [range] and [groupIds]):
  /// `current`/`selection` resolved by the caller (SL-20, additive).
  final List<String>? slideIds;
  final SlidesPdfPageSize pageSize;
  final SlidesPdfOrientation orientation;
  final SlidesPdfMargins margins;
  final bool frameSlides;

  /// *Ink saver* (P1).
  final bool omitBackground;
  final bool headerDate;
  final bool headerTitle;
  final bool pageNumbers;
  final bool slideNumbers;
  final bool bookmarks;
  final bool links;

  /// `compact` quality (1× images, JPEG 80 %) instead of `high`.
  final bool compact;

  /// Use `finalFrame` instead of the print frame (P1).
  final bool finalAnimationState;

  /// Sanitized file name (null = the deck title).
  final String? fileName;
}

/// What the renderer reads besides the deck: fonts, images and (client
/// only) the line breaks Flutter laid out on screen, so client PDFs match
/// the screen exactly (10 §11.3).
final class SlidesExportResources {
  /// Creates resources.
  const SlidesExportResources({
    required this.fonts,
    required this.images,
    this.textLayout,
    this.lineBreakHints = const {},
    this.info = const SlidesPdfDocumentInfo(),
  });

  final FontProvider fonts;
  final SlideImageResolver images;

  /// The engine laying out text (null = the core `SlideTextLayout`).
  final TextLayoutEngine? textLayout;

  /// `<elementId>` or `<elementId>/<cellId>` → line-end offsets.
  ///
  /// Reserved: the layout engine contract carries no element ids, so the
  /// app passes its Flutter engine as [textLayout] instead (the PDF then
  /// uses the screen's own layout results, 10 §11.3 "As built (SL-20)").
  final Map<String, List<int>> lineBreakHints;

  /// Document metadata and header/footer values (SL-20, additive).
  final SlidesPdfDocumentInfo info;
}

/// Metadata of an exported document (10 §11.3 step 5) and the values of
/// notes/handout headers that the deck model doesn't hold (SL-20).
final class SlidesPdfDocumentInfo {
  /// Creates the info.
  const SlidesPdfDocumentInfo({
    this.title,
    this.author,
    this.subject,
    this.modified,
    this.dateLabel,
    this.revision,
  });

  /// Title (null = the deck title).
  final String? title;

  /// The owner's name.
  final String? author;

  /// The Drive description.
  final String? subject;

  /// The deck's modified time (creation/modification dates of the PDF,
  /// so equal inputs give equal bytes); null = a fixed epoch.
  final DateTime? modified;

  /// The localized date of headers (null = `modified` as `yyyy-mm-dd`).
  final String? dateLabel;

  /// The deck revision (part of the deterministic document id).
  final String? revision;
}

/// The result of a PDF export.
final class SlidesPdfResult {
  /// Creates a result.
  const SlidesPdfResult({
    required this.bytes,
    required this.pageCount,
    this.warnings = const [],
  });

  final List<int> bytes;
  final int pageCount;

  /// Warning codes (`font_fallback`, `image_missing`, `link_dropped`, …).
  final List<String> warnings;
}

/// Renders a deck to PDF (10 §11.3; pure Dart, client and server).
/// Implemented by SL-20 in `core/export/pdf/`.
abstract interface class SlidesPdfRenderer {
  /// Renders [deck] with [options].
  Future<SlidesPdfResult> render(
    DeckModel deck,
    SlidesPdfOptions options,
    SlidesExportResources resources,
  );
}
