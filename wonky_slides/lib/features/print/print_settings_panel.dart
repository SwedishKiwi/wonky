import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_slides_core/interfaces.dart';
import 'package:wonky_slides_core/pdf.dart';

import '../../l10n/slides_l10n.dart';
import 'print_controller.dart';

/// The settings column of the print preview (Slides 10 §12): every option
/// of 10 §11.1 — layout cards, handouts per page and order, range, paper,
/// orientation, margins, frames, skipped slides, build stages (M10), header
/// and footer, slide numbers, bookmarks, links, ink saver and image quality
/// — plus the page count and the warnings of the current PDF.
class PrintSettingsPanel extends StatefulWidget {
  const PrintSettingsPanel({
    super.key,
    required this.controller,
    this.canPrintBuilds = false,
    this.hasSelection = false,
  });

  final SlidesPrintController controller;

  /// Builds as pages arrive with the timeline (SL-33, M10).
  final bool canPrintBuilds;

  /// More than one slide is selected in the navigator.
  final bool hasSelection;

  @override
  State<PrintSettingsPanel> createState() => _PrintSettingsPanelState();
}

class _PrintSettingsPanelState extends State<PrintSettingsPanel> {
  late final TextEditingController _range = TextEditingController(
    text: widget.controller.customRange,
  );

  SlidesPrintController get c => widget.controller;

  @override
  void dispose() {
    _range.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final o = c.options;
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(t, style: theme.textTheme.small),
    );
    Widget check(
      String id,
      String text,
      bool value,
      SlidesPdfOptions Function(bool v) apply, {
      bool enabled = true,
    }) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ShadCheckbox(
        key: ValueKey<String>('slides.print.$id'),
        value: value,
        enabled: enabled,
        onChanged: (v) => c.setOptions(apply(v)),
        label: Text(text),
      ),
    );
    final notesOrHandouts = o.layout != SlidesPdfLayout.slides;
    final warnings = c.warningTexts(l);
    return ListView(
      key: const ValueKey<String>('slides.print.settings'),
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          header: true,
          child: Text(l.printSettings, style: theme.textTheme.large),
        ),
        if (c.pageCount != null) ...[
          const SizedBox(height: 4),
          Text(
            l.printPageCount(c.pageCount!),
            key: const ValueKey<String>('slides.print.pages'),
            style: theme.textTheme.muted,
          ),
        ],
        label(l.printLayout),
        _layoutCards(context, l, o),
        if (o.layout == SlidesPdfLayout.handouts) ...[
          label(l.printPerPage),
          _select<int>(
            id: 'slides.print.perPage',
            value: o.handoutsPerPage,
            values: slidesHandoutCounts,
            text: (n) => '$n',
            onChanged: (n) => c.setOptions(o.copyWith(handoutsPerPage: n)),
          ),
          label(l.printOrder),
          _select<bool>(
            id: 'slides.print.order',
            value: o.handoutOrderVertical,
            values: const [false, true],
            text: (v) => v ? l.printOrderVertical : l.printOrderHorizontal,
            onChanged: (v) => c.setOptions(o.copyWith(handoutOrderVertical: v)),
          ),
        ],
        label(l.printRange),
        _select<PrintRangeChoice>(
          id: 'slides.print.range',
          value: c.range,
          values: [
            PrintRangeChoice.all,
            PrintRangeChoice.current,
            if (widget.hasSelection) PrintRangeChoice.selection,
            PrintRangeChoice.custom,
          ],
          text: (r) => switch (r) {
            PrintRangeChoice.all => l.printRangeAll,
            PrintRangeChoice.current => l.printRangeCurrent,
            PrintRangeChoice.selection => l.printRangeSelection,
            PrintRangeChoice.custom => l.printRangeCustom,
          },
          onChanged: (r) => c.setRange(r),
        ),
        if (c.range == PrintRangeChoice.custom) ...[
          const SizedBox(height: 8),
          ShadInput(
            key: const ValueKey<String>('slides.print.customRange'),
            controller: _range,
            placeholder: Text(l.printRangeHint),
            onChanged: (v) => c.setRange(PrintRangeChoice.custom, custom: v),
          ),
          if (!c.customRangeValid)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.printRangeInvalid,
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.destructive,
                ),
              ),
            ),
        ],
        label(l.printPaper),
        _select<SlidesPdfPageSize>(
          id: 'slides.print.paper',
          value: o.pageSize,
          values: [
            if (o.layout == SlidesPdfLayout.slides) SlidesPdfPageSize.slide,
            SlidesPdfPageSize.letter,
            SlidesPdfPageSize.a4,
            SlidesPdfPageSize.legal,
            SlidesPdfPageSize.a3,
            SlidesPdfPageSize.tabloid,
          ],
          text: (p) => switch (p) {
            SlidesPdfPageSize.slide => l.printPaperSlide,
            SlidesPdfPageSize.letter => l.printPaperLetter,
            SlidesPdfPageSize.a4 => 'A4',
            SlidesPdfPageSize.legal => l.printPaperLegal,
            SlidesPdfPageSize.a3 => 'A3',
            SlidesPdfPageSize.tabloid => l.printPaperTabloid,
          },
          onChanged: (p) => c.setOptions(
            o.copyWith(
              pageSize: p,
              margins: p == SlidesPdfPageSize.slide
                  ? SlidesPdfMargins.none
                  : (o.margins == SlidesPdfMargins.none
                        ? SlidesPdfMargins.normal
                        : o.margins),
            ),
          ),
        ),
        if (o.pageSize != SlidesPdfPageSize.slide ||
            o.layout != SlidesPdfLayout.slides) ...[
          label(l.printOrientation),
          _select<SlidesPdfOrientation>(
            id: 'slides.print.orientation',
            value: o.orientation,
            values: SlidesPdfOrientation.values,
            text: (v) => switch (v) {
              SlidesPdfOrientation.auto => l.printOrientationAuto,
              SlidesPdfOrientation.portrait => l.printOrientationPortrait,
              SlidesPdfOrientation.landscape => l.printOrientationLandscape,
            },
            onChanged: (v) => c.setOptions(o.copyWith(orientation: v)),
          ),
        ],
        label(l.printMargins),
        _select<SlidesPdfMargins>(
          id: 'slides.print.margins',
          value: o.margins,
          values: SlidesPdfMargins.values,
          text: (v) => switch (v) {
            SlidesPdfMargins.none => l.printMarginsNone,
            SlidesPdfMargins.narrow => l.printMarginsNarrow,
            SlidesPdfMargins.normal => l.printMarginsNormal,
          },
          onChanged: (v) => c.setOptions(o.copyWith(margins: v)),
        ),
        const SizedBox(height: 6),
        check(
          'builds',
          l.printBuilds,
          o.includeBuilds,
          (v) => o.copyWith(includeBuilds: v),
          enabled: widget.canPrintBuilds && o.layout == SlidesPdfLayout.slides,
        ),
        check(
          'skipped',
          l.printSkipped,
          o.includeSkipped,
          (v) => o.copyWith(includeSkipped: v),
        ),
        check(
          'frame',
          l.printFrame,
          o.frameSlides,
          (v) => o.copyWith(frameSlides: v),
        ),
        if (notesOrHandouts)
          check(
            'headerFooter',
            l.printHeaderFooter,
            o.headerFooter,
            (v) => o.copyWith(headerDate: v, headerTitle: v, pageNumbers: v),
          ),
        if (o.layout == SlidesPdfLayout.handouts)
          check(
            'slideNumbers',
            l.printSlideNumbers,
            o.slideNumbers,
            (v) => o.copyWith(slideNumbers: v),
          ),
        check(
          'bookmarks',
          l.printBookmarks,
          o.bookmarks,
          (v) => o.copyWith(bookmarks: v),
        ),
        check('links', l.printLinks, o.links, (v) => o.copyWith(links: v)),
        check(
          'inkSaver',
          l.printInkSaver,
          o.omitBackground,
          (v) => o.copyWith(omitBackground: v),
        ),
        label(l.printQuality),
        _select<bool>(
          id: 'slides.print.quality',
          value: o.compact,
          values: const [false, true],
          text: (v) => v ? l.printQualityCompact : l.printQualityHigh,
          onChanged: (v) => c.setOptions(o.copyWith(compact: v)),
        ),
        if (warnings.isNotEmpty) ...[
          label(l.printWarnings),
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 6),
                    child: Icon(
                      LucideIcons.triangleAlert,
                      size: 14,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                  Expanded(child: Text(w, style: theme.textTheme.muted)),
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// The layout choice (Slides, Notes pages, Handouts) as radios: keyboard
  /// operable, and they fit a 300 px column at any text scale.
  Widget _layoutCards(
    BuildContext context,
    SlidesLocalizations l,
    SlidesPdfOptions o,
  ) => ShadRadioGroup<SlidesPdfLayout>(
    key: ValueKey<String>('slides.print.layout.${o.layout.name}.group'),
    initialValue: o.layout,
    onChanged: (v) {
      if (v != null && v != o.layout) c.setLayout(v);
    },
    items: [
      for (final (layout, text) in [
        (SlidesPdfLayout.slides, l.printLayoutSlides),
        (SlidesPdfLayout.notes, l.printLayoutNotes),
        (SlidesPdfLayout.handouts, l.printLayoutHandouts),
      ])
        ShadRadio<SlidesPdfLayout>(
          key: ValueKey<String>('slides.print.layout.${layout.name}'),
          value: layout,
          label: Text(text),
        ),
    ],
  );

  Widget _select<T>({
    required String id,
    required T value,
    required List<T> values,
    required String Function(T) text,
    required void Function(T) onChanged,
  }) => ShadSelect<T>(
    key: ValueKey<String>('$id.$value'),
    initialValue: values.contains(value) ? value : values.first,
    minWidth: 240,
    options: [
      for (final v in values)
        ShadOption<T>(
          key: ValueKey<String>('$id.option.$v'),
          value: v,
          child: Text(text(v)),
        ),
    ],
    selectedOptionBuilder: (context, v) =>
        Text(text(v), overflow: TextOverflow.ellipsis),
    onChanged: (v) {
      if (v != null && v != value) onChanged(v);
    },
  );
}
