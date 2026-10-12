import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../mapping/wonky_schema.dart';
import '../view/editor_view_state.dart';

/// Computes page breaks for the Pages layout (Write 04 §29.3): pages are
/// computed from the laid-out blocks' natural positions, never stored.
///
/// A block that doesn't fit on the current page (and isn't taller than a
/// page) is pushed to the next page by injecting extra top padding
/// ([PaginationStylePhase]); headings keep with the next block's first line;
/// oversized blocks overflow across the page seam.
class PaginationController extends ChangeNotifier {
  PaginationController();

  EditorPageSetup _setup = EditorPageSetup.a4;
  double _zoom = 1;

  /// Extra top padding per node id (scaled pixels).
  Map<String, double> _gaps = const {};
  int _pageCount = 1;

  Map<String, double> get gaps => _gaps;

  /// Number of pages after the last layout.
  int get pageCount => _pageCount;

  EditorPageSetup get setup => _setup;
  double get zoom => _zoom;

  /// Page height plus the gap between pages (scaled).
  double get pageStride => (_setup.size.height + _setup.pageGap) * _zoom;

  void configure(EditorPageSetup setup, double zoom) {
    if (setup == _setup && zoom == _zoom) return;
    _setup = setup;
    _zoom = zoom;
    _gaps = const {};
    notifyListeners();
  }

  /// Measures the laid-out [document] and recomputes the page breaks.
  /// Returns whether the injected gaps changed (the layout must be redone).
  bool measure(DocumentLayout layout, Document document) {
    final pageHeight = _setup.size.height * _zoom;
    final marginTop = _setup.margins.top * _zoom;
    final marginBottom = _setup.margins.bottom * _zoom;
    final contentHeight = pageHeight - marginTop - marginBottom;
    final stride = pageStride;

    final newGaps = <String, double>{};
    var previousShift = 0.0;
    var shift = 0.0;
    var page = 0;
    final nodes = document.toList();
    for (var i = 0; i < nodes.length; i += 1) {
      final node = nodes[i];
      final rect = layout.getRectForSelection(
        DocumentPosition(nodeId: node.id, nodePosition: node.beginningPosition),
        DocumentPosition(nodeId: node.id, nodePosition: node.endPosition),
      );
      if (rect == null) continue;
      previousShift += _gaps[node.id] ?? 0;
      final naturalTop = rect.top - previousShift;
      final height = rect.height;
      var top = naturalTop + shift;
      var bottom = top + height;

      while (top >= page * stride + pageHeight - marginBottom) {
        page += 1;
      }
      final contentTop = page * stride + marginTop;
      final contentBottom = contentTop + contentHeight;

      var needed = bottom;
      final isHeading =
          node is ParagraphNode &&
          headingLevelOf(node.getMetadataValue(NodeMetadata.blockType)) != null;
      if (isHeading && i + 1 < nodes.length) {
        // Keep with next: at least ~1.5 body lines of the next block.
        needed += 1.5 * 20 * _zoom;
      }
      if (needed > contentBottom &&
          height <= contentHeight &&
          top > contentTop + 0.5) {
        final nextContentTop = (page + 1) * stride + marginTop;
        final gap = nextContentTop - top;
        newGaps[node.id] = gap;
        shift += gap;
        page += 1;
        top += gap;
        bottom += gap;
      }
      while (bottom > page * stride + pageHeight - marginBottom &&
          height > contentHeight) {
        // Oversized block: it overflows across the seam.
        page += 1;
      }
    }

    final changed = !_sameGaps(newGaps, _gaps);
    _gaps = newGaps;
    final count = page + 1;
    if (changed || count != _pageCount) {
      _pageCount = count;
      notifyListeners();
    }
    return changed;
  }

  static bool _sameGaps(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || (other - entry.value).abs() > 0.5) return false;
    }
    return true;
  }
}

/// Injects the page-break gaps of a [PaginationController] as extra top
/// padding.
class PaginationStylePhase extends SingleColumnLayoutStylePhase {
  PaginationStylePhase(this.pagination) {
    pagination.addListener(markDirty);
  }

  final PaginationController pagination;

  @override
  void dispose() {
    pagination.removeListener(markDirty);
    super.dispose();
  }

  @override
  SingleColumnLayoutViewModel style(
    Document document,
    SingleColumnLayoutViewModel viewModel,
  ) {
    final gaps = pagination.gaps;
    if (gaps.isEmpty) return viewModel;
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final model in viewModel.componentViewModels)
          if (gaps[model.nodeId] case final gap?)
            (model.copy()
              ..padding = model.padding.add(EdgeInsets.only(top: gap)))
          else
            model,
      ],
    );
  }
}

/// Paints page cards, header/footer text and page numbers under the document
/// in the Pages layout (Write 04 §29.2).
class PageChromePainter extends CustomPainter {
  PageChromePainter({
    required this.pagination,
    required this.paperColor,
    required this.borderColor,
    required this.textStyle,
  }) : super(repaint: pagination);

  final PaginationController pagination;
  final Color paperColor;
  final Color borderColor;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final setup = pagination.setup;
    final zoom = pagination.zoom;
    final pageSize = setup.size * zoom;
    final stride = pagination.pageStride;
    final count = pagination.pageCount;
    final paper = Paint()..color = paperColor;
    final shadow = Paint()
      ..color = const Color(0x22000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < count; i += 1) {
      final rect = Offset(0, i * stride) & pageSize;
      canvas
        ..drawRect(rect.translate(0, 2), shadow)
        ..drawRect(rect, paper)
        ..drawRect(rect, border);
      _text(
        canvas,
        setup.headerText,
        i,
        count,
        Offset(
          rect.left + setup.margins.left * zoom,
          rect.top + setup.margins.top * zoom / 2 - 8,
        ),
      );
      _text(
        canvas,
        setup.footerText,
        i,
        count,
        Offset(
          rect.left + setup.margins.left * zoom,
          rect.bottom - setup.margins.bottom * zoom / 2 - 8,
        ),
      );
    }
  }

  void _text(Canvas canvas, String template, int page, int pages, Offset at) {
    if (template.isEmpty) return;
    final text = template
        .replaceAll('{page}', '${page + 1}')
        .replaceAll('{pages}', '$pages');
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(PageChromePainter oldDelegate) =>
      oldDelegate.paperColor != paperColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.pagination != pagination;
}
