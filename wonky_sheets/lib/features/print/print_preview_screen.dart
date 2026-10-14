import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../commands/sheets_command.dart' show editorOfServices;
import '../../l10n/sheets_l10n.dart';
import '../export/sheets_downloads.dart';
import '../import_export/sheets_io.dart';
import '../model/workbook_session.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'page_break_canvas.dart';
import 'print_controller.dart';
import 'print_fonts.dart';
import 'print_page_painter.dart';
import 'print_settings_panel.dart';

/// The print / PDF route `/s/:uuid/print` (11 §7, 04 §1): live page preview
/// (painted with the PDF's layout and fonts, always light paper), page
/// thumbnails, zoom and page navigation, the settings panel, *Export PDF*
/// and *Print*. A child route of the editor: the open spreadsheet stays
/// loaded underneath; Esc / Back returns to the grid.
class SheetsPrintPreviewScreen extends StatefulWidget {
  const SheetsPrintPreviewScreen({
    super.key,
    required this.services,
    required this.itemUuid,
    this.scope,
    this.exportMode = false,
  });

  final ShellServices services;
  final String itemUuid;

  /// `?scope=workbook|selection|currentSheet`.
  final String? scope;

  /// `?export=1`: opened by *Download ▸ PDF* (Export preselected).
  final bool exportMode;

  @override
  State<SheetsPrintPreviewScreen> createState() =>
      _SheetsPrintPreviewScreenState();
}

class _SheetsPrintPreviewScreenState extends State<SheetsPrintPreviewScreen> {
  PrintController? _c;
  PrintPaintContext? _paint;
  int _paintVersion = -1;
  final _scroll = ScrollController();
  final _thumbs = ScrollController();
  final _focus = FocusNode(debugLabel: 'print');

  /// Null = fit width.
  double? _zoom;
  int _page = 0;
  bool _showSettings = false;
  Map<String, ui.Image> _images = const {};

  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    s.activeDocument.addListener(_attach);
    _scroll.addListener(_onScroll);
    _attach();
  }

  @override
  void dispose() {
    s.activeDocument.removeListener(_attach);
    _c?.removeListener(_changed);
    _c?.dispose();
    _scroll.dispose();
    _thumbs.dispose();
    _focus.dispose();
    for (final i in _images.values) {
      i.dispose();
    }
    super.dispose();
  }

  SheetEditorController? get _editor {
    final ed = editorOfServices(s);
    if (ed == null || ed.session.itemUuid.uuid != widget.itemUuid) {
      return null;
    }
    return ed.session.loadState.value is WorkbookReady ? ed : null;
  }

  void _attach() {
    if (_c != null) return;
    final ed = _editor;
    if (ed == null) {
      // The editor underneath is still opening; activeDocument notifies.
      Timer(const Duration(milliseconds: 300), () {
        if (mounted && _c == null) _attach();
      });
      return;
    }
    final scope = switch (widget.scope) {
      'workbook' => PrintScope.workbook,
      'selection' => PrintScope.selection,
      _ => PrintScope.currentSheet,
    };
    final c = PrintController(ed, scope: scope);
    c.addListener(_changed);
    setState(() => _c = c);
    unawaited(_loadAssets(c));
  }

  Future<void> _loadAssets(PrintController c) async {
    final fonts = await SheetsPdfFonts.load();
    if (!mounted || _c != c) return;
    c.setFonts(fonts);
    if (SheetsWorkbookExporter.imageFiles(c.model).isEmpty) return;
    final bytes = await fetchImageBytes(s, c.model);
    final out = <String, ui.Image>{};
    for (final e in bytes.entries) {
      try {
        final codec = await ui.instantiateImageCodec(e.value);
        out[e.key] = (await codec.getNextFrame()).image;
        codec.dispose();
      } catch (_) {
        // Unreadable image: placeholder.
      }
    }
    if (!mounted) return;
    setState(() {
      _images = out;
      _paintVersion = -1;
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
  }

  PrintPaintContext _paintContext(PrintController c) {
    if (_paint != null && _paintVersion == c.contentVersion) return _paint!;
    final model = c.model;
    final (date, time) = PrintDateTime.format(
      clock.now(),
      locale: model.spreadsheet.locale,
      timeZone: model.spreadsheet.timeZone,
    );
    ChartScene? Function(EmbeddedObjectRecord, double, double)? charts;
    try {
      charts = ChartPipeline.printSceneFor(model, c.ed.engine);
    } catch (_) {
      charts = null;
    }
    _paint = PrintPaintContext(
      model: model,
      source: c.ed.engine,
      resolver: CellDisplayResolver(
        model,
        c.ed.engine,
        conditional: c.ed.cells.conditional,
      ),
      measurer: c.textMeasurer,
      title: exportTitle(c.ed),
      date: date,
      time: time,
      chartScene: (o, w, h) {
        try {
          return charts?.call(o, w, h);
        } catch (_) {
          return null;
        }
      },
      images: _images,
    );
    _paintVersion = c.contentVersion;
    return _paint!;
  }

  void _back() => s.router.go('/s/${widget.itemUuid}');

  Future<void> _print() async {
    final ed = _c?.ed;
    if (ed == null || !(_c?.canExport ?? false)) return;
    await ed.invokeCommand('sheets.print.print');
  }

  Future<void> _export() async {
    final ed = _c?.ed;
    if (ed == null || !(_c?.canExport ?? false)) return;
    await ed.invokeCommand('sheets.print.exportPdf', {
      'darkTheme': _c?.darkTheme ?? false,
    });
  }

  // ------------------------------------------------------------ geometry

  static const _gap = 24.0;
  static const _labelH = 22.0;

  double _ppp(double width, List<PageSpec> pages) {
    final z = _zoom;
    if (z != null) return z * 4 / 3;
    final maxW = pages.isEmpty
        ? 612.0
        : pages.map((p) => p.pageWidth).reduce(math.max);
    return ((width - 2 * _gap) / maxW).clamp(0.2, 4.0);
  }

  double _lastPpp = 4 / 3;

  List<double> _offsets(List<PageSpec> pages, double ppp) {
    final out = <double>[];
    var y = _gap;
    for (final p in pages) {
      out.add(y);
      y += p.pageHeight * ppp + _labelH + _gap;
    }
    return out;
  }

  void _onScroll() {
    final c = _c;
    if (c == null || c.pages.isEmpty) return;
    final offs = _offsets(c.pages, _lastPpp);
    final y = _scroll.offset + 40;
    var i = 0;
    while (i + 1 < offs.length && offs[i + 1] <= y) {
      i++;
    }
    if (i != _page) setState(() => _page = i);
  }

  void _goTo(int page) {
    final c = _c;
    if (c == null || c.pages.isEmpty || !_scroll.hasClients) return;
    final p = page.clamp(0, c.pages.length - 1);
    final offs = _offsets(c.pages, _lastPpp);
    _scroll.animateTo(
      (offs[p] - _gap).clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    setState(() => _page = p);
  }

  void _zoomBy(int dir) {
    const steps = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final cur = _zoom ?? _lastPpp * 3 / 4;
    final next = dir > 0
        ? steps.firstWhere((z) => z > cur + 0.01, orElse: () => 2.0)
        : steps.lastWhere((z) => z < cur - 0.01, orElse: () => 0.5);
    setState(() => _zoom = next);
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_c?.breakMode ?? false) {
            _c!.breakMode = false;
          } else {
            _back();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true): _print,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): _print,
        const SingleActivator(LogicalKeyboardKey.pageDown): () =>
            _goTo(_page + 1),
        const SingleActivator(LogicalKeyboardKey.pageUp): () =>
            _goTo(_page - 1),
        const SingleActivator(LogicalKeyboardKey.home): () => _goTo(0),
        const SingleActivator(LogicalKeyboardKey.end): () =>
            _goTo((_c?.pages.length ?? 1) - 1),
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: ColoredBox(
          key: const ValueKey<String>('sheets.print'),
          color: cs.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              const ShadSeparator.horizontal(margin: EdgeInsets.zero),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = sheetsL10n(context);
    final c = _c;
    final title = c == null ? '' : exportTitle(c.ed);
    final enabled = c != null && c.canExport && c.pages.isNotEmpty;
    final narrow = MediaQuery.sizeOf(context).width < 640;
    final exportBtn = widget.exportMode
        ? ShadButton(
            key: const ValueKey<String>('print.export'),
            enabled: enabled,
            leading: const Icon(LucideIcons.fileDown, size: 16),
            onPressed: _export,
            child: Text(narrow ? 'PDF' : l.printExportPdf),
          )
        : ShadButton.outline(
            key: const ValueKey<String>('print.export'),
            enabled: enabled,
            leading: const Icon(LucideIcons.fileDown, size: 16),
            onPressed: _export,
            child: Text(narrow ? 'PDF' : l.printExportPdf),
          );
    final printBtn = widget.exportMode
        ? ShadButton.outline(
            key: const ValueKey<String>('print.print'),
            enabled: enabled,
            leading: const Icon(LucideIcons.printer, size: 16),
            onPressed: _print,
            child: narrow ? null : Text(l.printPrint),
          )
        : ShadButton(
            key: const ValueKey<String>('print.print'),
            enabled: enabled,
            leading: const Icon(LucideIcons.printer, size: 16),
            onPressed: _print,
            child: narrow ? null : Text(l.printPrint),
          );
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            ShadIconButton.ghost(
              key: const ValueKey<String>('print.back'),
              icon: const Icon(LucideIcons.arrowLeft, size: 18),
              onPressed: _back,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title.isEmpty ? l.printPrint : l.printTitle(title),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.large,
                ),
              ),
            ),
            if (MediaQuery.sizeOf(context).width < 760)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ShadIconButton.ghost(
                  key: const ValueKey<String>('print.toggleSettings'),
                  icon: Icon(
                    _showSettings
                        ? LucideIcons.fileText
                        : LucideIcons.settings2,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _showSettings = !_showSettings),
                ),
              ),
            exportBtn,
            const SizedBox(width: 8),
            printBtn,
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l = sheetsL10n(context);
    final cs = ShadTheme.of(context).colorScheme;
    final c = _c;
    if (c == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ShadSpinner(),
            const SizedBox(height: 12),
            Text(l.printLoading, style: ShadTheme.of(context).textTheme.muted),
          ],
        ),
      );
    }
    if (!c.canExport) {
      return WonkyEmptyState(
        illustration: EmptyIllustration.error,
        title: l.printDownloadsDisabledTitle,
        description: l.printDownloadsDisabledBody,
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 760;
        final settings = PrintSettingsPanel(
          key: const ValueKey<String>('print.settings'),
          controller: c,
        );
        final preview = c.breakMode
            ? ColoredBox(
                color: cs.canvas,
                child: PageBreakCanvas(controller: c),
              )
            : _previewArea(context, c);
        if (narrow) {
          return _showSettings ? settings : preview;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (box.maxWidth >= 1000) ...[
              SizedBox(width: 132, child: _thumbnails(context, c)),
              Container(width: 1, color: cs.border),
            ],
            Expanded(child: preview),
            Container(width: 1, color: cs.border),
            SizedBox(width: 360, child: settings),
          ],
        );
      },
    );
  }

  Widget _previewArea(BuildContext context, PrintController c) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final pages = c.pages;
    return ColoredBox(
      color: cs.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: pages.isEmpty
                ? (c.pagination == null
                      ? const Center(child: ShadSpinner())
                      : WonkyEmptyState(
                          illustration: EmptyIllustration.spreadsheets,
                          title: l.printNothing,
                          description: l.printNothingBody,
                        ))
                : LayoutBuilder(
                    builder: (context, box) {
                      final ppp = _ppp(box.maxWidth, pages);
                      _lastPpp = ppp;
                      final paint = _paintContext(c);
                      return Semantics(
                        label: l.printPageOf(_page + 1, pages.length),
                        container: true,
                        child: ListView.builder(
                          key: const ValueKey<String>('print.preview'),
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(vertical: _gap),
                          itemCount: pages.length,
                          itemBuilder: (context, i) {
                            final p = pages[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: _gap),
                              child: Column(
                                children: [
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: _gap,
                                      ),
                                      child: _PageCard(
                                        key: ValueKey<String>(
                                          'print.page.${i + 1}',
                                        ),
                                        paint: paint,
                                        spec: p,
                                        ppp: ppp,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: _labelH,
                                    child: Center(
                                      child: Text(
                                        l.printPageLabel(p.pageNumber),
                                        style: theme.textTheme.muted.copyWith(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
          _bottomBar(context, c),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context, PrintController c) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final n = c.pages.length;
    final zoomText = _zoom == null
        ? l.printZoomFit
        : '${(_zoom! * 100).round()}%';
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: cs.background,
        border: Border(top: BorderSide(color: cs.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          ShadIconButton.ghost(
            key: const ValueKey<String>('print.zoomOut'),
            icon: const Icon(LucideIcons.zoomOut, size: 16),
            onPressed: () => _zoomBy(-1),
          ),
          ShadButton.ghost(
            key: const ValueKey<String>('print.zoomFit'),
            size: ShadButtonSize.sm,
            onPressed: () => setState(() => _zoom = null),
            child: Text(zoomText),
          ),
          ShadIconButton.ghost(
            key: const ValueKey<String>('print.zoomIn'),
            icon: const Icon(LucideIcons.zoomIn, size: 16),
            onPressed: () => _zoomBy(1),
          ),
          const Expanded(child: SizedBox()),
          ShadIconButton.ghost(
            key: const ValueKey<String>('print.prev'),
            icon: const Icon(LucideIcons.chevronLeft, size: 16),
            enabled: _page > 0,
            onPressed: () => _goTo(_page - 1),
          ),
          Flexible(
            child: Text(
              n == 0 ? l.printPageCount(0) : l.printPageOf(_page + 1, n),
              key: const ValueKey<String>('print.pageOf'),
              style: theme.textTheme.small,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ShadIconButton.ghost(
            key: const ValueKey<String>('print.next'),
            icon: const Icon(LucideIcons.chevronRight, size: 16),
            enabled: _page + 1 < n,
            onPressed: () => _goTo(_page + 1),
          ),
        ],
      ),
    );
  }

  Widget _thumbnails(BuildContext context, PrintController c) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final pages = c.pages;
    if (pages.isEmpty) return const SizedBox.shrink();
    final paint = _paintContext(c);
    return ListView.builder(
      key: const ValueKey<String>('print.thumbnails'),
      controller: _thumbs,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: pages.length,
      itemBuilder: (context, i) {
        final p = pages[i];
        const w = 96.0;
        final ppp = w / p.pageWidth;
        final selected = i == _page;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: GestureDetector(
              onTap: () => _goTo(i),
              child: Semantics(
                button: true,
                selected: selected,
                label: sheetsL10n(context).printPageLabel(p.pageNumber),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected ? cs.ring : cs.border,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: _PageCard(
                        key: ValueKey<String>('print.thumb.${i + 1}'),
                        paint: paint,
                        spec: p,
                        ppp: ppp,
                        shadow: false,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p.pageNumber}',
                      style: theme.textTheme.muted.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One page of paper.
class _PageCard extends StatelessWidget {
  const _PageCard({
    super.key,
    required this.paint,
    required this.spec,
    required this.ppp,
    this.shadow = true,
  });

  final PrintPaintContext paint;
  final PageSpec spec;
  final double ppp;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final size = Size(spec.pageWidth * ppp, spec.pageHeight * ppp);
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: const Color(0xffffffff),
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: RepaintBoundary(
        child: CustomPaint(
          size: size,
          painter: PrintPagePainter(paint, spec, pixelsPerPoint: ppp),
        ),
      ),
    );
  }
}
