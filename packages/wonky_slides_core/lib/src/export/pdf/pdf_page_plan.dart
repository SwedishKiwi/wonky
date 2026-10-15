/// Page list resolution and page geometry of Slides PDFs (10 §11.2–§11.3
/// step 1): which slides (range, groups, explicit ids, skipped), which
/// frames per slide (print frame, final frame or one per build step), the
/// page size per layout and paper, and the slide boxes of slides, notes and
/// handout pages. Pure geometry in points with a top-left origin.
library;

import 'dart:math' as math;

import '../../interfaces/pdf.dart';
import '../../model/api/deck_model.dart';
import '../../model/index/deck_indexes.dart';
import '../../model/index/slide_order.dart';
import 'pdf_options_codec.dart';

/// A rectangle in points (top-left origin).
final class SlidesPdfRect {
  /// Creates a rectangle.
  const SlidesPdfRect(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;

  @override
  bool operator ==(Object other) =>
      other is SlidesPdfRect &&
      (other.x - x).abs() < 1e-6 &&
      (other.y - y).abs() < 1e-6 &&
      (other.width - width).abs() < 1e-6 &&
      (other.height - height).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(
    x.toStringAsFixed(4),
    y.toStringAsFixed(4),
    width.toStringAsFixed(4),
    height.toStringAsFixed(4),
  );

  @override
  String toString() =>
      'SlidesPdfRect(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, '
      '${width.toStringAsFixed(2)} × ${height.toStringAsFixed(2)})';
}

/// One slide picked for the export, with the frames to print.
final class SlidesPdfSlide {
  /// Creates an entry.
  const SlidesPdfSlide({required this.entry, required this.steps});

  /// The slide's order entry (position, group, number, skipped).
  final SlideOrderEntry entry;

  /// The timeline steps printed: `[null]` = one page (print or final
  /// frame); `[0, 1, …]` = one page per build step (06 §9.6) — the steps
  /// whose settled frame differs from the previous step's (SL-33).
  final List<int?> steps;

  String get slideId => entry.id;
}

/// The slides of an export and the warnings of the selection.
final class SlidesPdfSelection {
  /// Creates a selection.
  const SlidesPdfSelection(this.slides, this.warnings);

  final List<SlidesPdfSlide> slides;

  /// `range_unresolved` (`current`/`selection` without slide ids),
  /// `empty_selection`.
  final List<String> warnings;

  /// The ids of the exported slides.
  Set<String> get slideIds => {for (final s in slides) s.slideId};
}

/// Page geometry for one export (10 §11.2).
final class SlidesPdfGeometry {
  /// Computes the geometry of [options] for slides of [slideWidth] ×
  /// [slideHeight] su.
  factory SlidesPdfGeometry(
    SlidesPdfOptions options, {
    required double slideWidth,
    required double slideHeight,
  }) {
    final sw = slideWidth > 0 ? slideWidth : 1920.0;
    final sh = slideHeight > 0 ? slideHeight : 1080.0;
    final margin = switch (options.margins) {
      SlidesPdfMargins.none => 0.0,
      SlidesPdfMargins.narrow => 18.0,
      SlidesPdfMargins.normal => 36.0,
    };
    final wide = sw >= sh;
    double pw, ph;
    final paper =
        options.pageSize == SlidesPdfPageSize.slide &&
            options.layout != SlidesPdfLayout.slides
        ? SlidesPdfPageSize.letter
        : options.pageSize;
    if (paper == SlidesPdfPageSize.slide) {
      // Deck su / 2 = pt (02 §2.2), capped at 14,400 pt per side.
      final k = math.min(1.0, 14400 / math.max(sw / 2, sh / 2));
      pw = sw / 2 * k + 2 * margin;
      ph = sh / 2 * k + 2 * margin;
    } else {
      final (w, h) = slidesPaperSizes[paper]!;
      final landscape = switch (options.orientation) {
        SlidesPdfOrientation.landscape => true,
        SlidesPdfOrientation.portrait => false,
        // Slides follow the deck; notes and handouts are portrait.
        SlidesPdfOrientation.auto =>
          options.layout == SlidesPdfLayout.slides && wide,
      };
      pw = landscape ? h : w;
      ph = landscape ? w : h;
    }
    return SlidesPdfGeometry._(options, sw, sh, pw, ph, margin);
  }

  SlidesPdfGeometry._(
    this.options,
    this.slideWidth,
    this.slideHeight,
    this.pageWidth,
    this.pageHeight,
    this.margin,
  );

  final SlidesPdfOptions options;

  /// Slide size (su).
  final double slideWidth;
  final double slideHeight;

  /// Page size (pt).
  final double pageWidth;
  final double pageHeight;

  /// Page margin (pt).
  final double margin;

  /// Height of the header and footer bands of notes/handout pages (pt).
  static const bandHeight = 22.0;

  /// Height reserved under a handout slide for its number (pt).
  static const numberHeight = 14.0;

  /// The slide's aspect ratio (width / height).
  double get aspect => slideWidth / slideHeight;

  /// The content box inside the margins.
  SlidesPdfRect get content => SlidesPdfRect(
    margin,
    margin,
    pageWidth - 2 * margin,
    pageHeight - 2 * margin,
  );

  /// The content box minus the header/footer bands (notes, handouts).
  SlidesPdfRect get body {
    final c = content;
    final band = options.headerFooter ? bandHeight : 0.0;
    return SlidesPdfRect(c.x, c.y + band, c.width, c.height - 2 * band);
  }

  /// The largest slide-aspect box inside [area], centered (top-aligned when
  /// [top]).
  SlidesPdfRect fit(SlidesPdfRect area, {bool top = false}) {
    var w = area.width;
    var h = w / aspect;
    if (h > area.height) {
      h = area.height;
      w = h * aspect;
    }
    final x = area.x + (area.width - w) / 2;
    final y = top ? area.y : area.y + (area.height - h) / 2;
    return SlidesPdfRect(x, y, w, h);
  }

  /// The slide box of a slides page.
  SlidesPdfRect get slideBox => fit(content);

  /// The slide box of a notes page (80 % of the content width, at the top).
  SlidesPdfRect get notesSlideBox {
    final b = body;
    final w = b.width * 0.8;
    final area = SlidesPdfRect(
      b.x + (b.width - w) / 2,
      b.y + 6,
      w,
      b.height / 2,
    );
    return fit(area, top: true);
  }

  /// The notes text area of a notes page (below the slide; the whole body
  /// on continuation pages).
  SlidesPdfRect notesTextArea({required bool continuation}) {
    final b = body;
    if (continuation) {
      return SlidesPdfRect(
        b.x + b.width * 0.1,
        b.y + 24,
        b.width * 0.8,
        b.height - 24,
      );
    }
    final s = notesSlideBox;
    final top = s.bottom + 18;
    return SlidesPdfRect(s.x, top, s.width, b.bottom - top);
  }

  /// The slide boxes (and the ruled-lines area for 1 and 3 per page) of a
  /// handout page with [count] slides, in [options]' order.
  List<(SlidesPdfRect slide, SlidesPdfRect? lines)> handoutCells() {
    final n = options.handoutsPerPage;
    final b = body;
    final numbers = options.slideNumbers ? numberHeight : 0.0;
    const gap = 18.0;
    switch (n) {
      case 1:
        final w = b.width * 0.8;
        final s = fit(
          SlidesPdfRect(b.x + (b.width - w) / 2, b.y + 6, w, b.height * 0.55),
          top: true,
        );
        final top = s.bottom + numbers + gap;
        return [(s, SlidesPdfRect(s.x, top, s.width, b.bottom - top))];
      case 3:
        final rowH = (b.height - 2 * gap) / 3;
        final colW = (b.width - gap) / 2;
        return [
          for (var r = 0; r < 3; r++)
            () {
              final cell = SlidesPdfRect(
                b.x,
                b.y + r * (rowH + gap),
                colW,
                rowH - numbers,
              );
              final s = fit(cell);
              return (s, SlidesPdfRect(b.x + colW + gap, s.y, colW, s.height));
            }(),
        ];
      default:
        final (cols, rows) = switch (n) {
          2 => (1, 2),
          4 => (2, 2),
          6 => (2, 3),
          9 => (3, 3),
          _ => (2, 3),
        };
        final cw = (b.width - (cols - 1) * gap) / cols;
        final ch = (b.height - (rows - 1) * gap) / rows;
        final cells = <(SlidesPdfRect, SlidesPdfRect?)>[];
        for (var i = 0; i < cols * rows; i++) {
          final (c, r) = options.handoutOrderVertical
              ? (i ~/ rows, i % rows)
              : (i % cols, i ~/ cols);
          final cell = SlidesPdfRect(
            b.x + c * (cw + gap),
            b.y + r * (ch + gap),
            cw,
            ch - numbers,
          );
          cells.add((fit(cell), null));
        }
        return cells;
    }
  }
}

/// Resolves the slides of an export (10 §11.2–§11.3 step 1).
abstract final class SlidesPdfPlanner {
  /// The slides of [deck] that [options] export, with their steps.
  /// [stepCounts] gives the number of build steps of a slide (the
  /// timeline's `stepCount`; null = no builds); [buildSteps], when given,
  /// the steps to print of a slide with builds as pages instead of every
  /// step `0…stepCount` (the exporter drops steps that look like the one
  /// before, 06 §9.6).
  static SlidesPdfSelection select(
    DeckModel deck,
    SlidesPdfOptions options, {
    int Function(String slideId)? stepCounts,
    List<int> Function(String slideId)? buildSteps,
  }) {
    final order = deck.indexes.order;
    final warnings = <String>[];
    Iterable<SlideOrderEntry> picked;
    var explicit = false;
    if (options.slideIds case final ids?) {
      final set = ids.toSet();
      picked = order.entries.where((e) => set.contains(e.id));
      explicit = true;
    } else if (options.groupIds case final groups?) {
      final set = groups.toSet();
      picked = order.entries.where((e) => set.contains(e.groupId));
    } else {
      final range = options.range.trim();
      final positions = SlidesPdfOptionsCodec.positions(range, order.length);
      if (positions != null) {
        picked = [for (final i in positions) order.entries[i]];
      } else {
        if (range == 'current' || range == 'selection') {
          warnings.add('range_unresolved');
        }
        picked = order.entries;
      }
    }
    final builds =
        options.includeBuilds && options.layout == SlidesPdfLayout.slides;
    final slides = [
      for (final e in picked)
        if (explicit || options.includeSkipped || !e.skipped)
          SlidesPdfSlide(
            entry: e,
            steps: !builds
                ? const [null]
                : buildSteps != null
                ? buildSteps(e.id)
                : [for (var i = 0; i <= (stepCounts?.call(e.id) ?? 0); i++) i],
          ),
    ];
    if (slides.isEmpty) warnings.add('empty_selection');
    return SlidesPdfSelection(slides, warnings);
  }
}
