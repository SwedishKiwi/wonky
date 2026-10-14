import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/model.dart';

import '../export/sheets_downloads.dart';
import '../import_export/progress_dialog.dart';
import '../import_export/sheets_io.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// State of the print route (11 §7): scope, settings (stored per sheet for
/// editors through `sheets.print.updateSettings`, local overrides for
/// viewers), the pagination of the job and break mode. Paginates on every
/// model change (debounced 250 ms).
class PrintController extends ChangeNotifier {
  PrintController(
    this.ed, {
    PrintScope scope = PrintScope.currentSheet,
    PdfFontProvider? fonts,
  }) : _scope = scope, // ignore: prefer_initializing_formals
       fonts = fonts ?? const BuiltInPdfFontProvider() {
    _sheetId = ed.activeSheetId;
    _selection = ed.activeRange;
    ed.model.addListener(_onBatch);
    current = this;
    repaginate();
  }

  /// The open print route (commands `sheets.print.*` act on it).
  static PrintController? current;

  final SheetEditorController ed;

  /// PDF fonts (the preview measures with them too).
  PdfFontProvider fonts;
  late CellTextMeasurer _measurer = PdfFontMeasurer(fonts);

  /// The PDF metrics (paginator auto-fit and preview layout).
  CellTextMeasurer get textMeasurer => _measurer;

  late String _sheetId;
  late ResolvedRange _selection;
  PrintScope _scope;
  bool _applyToAll = true;
  bool _breakMode = false;
  final Map<String, PrintSettings> _local = {};
  PaginationResult? _pagination;
  Timer? _debounce;
  bool _disposed = false;

  /// Bumped when the model changed (pages repaint).
  int contentVersion = 0;

  WorkbookModel get model => ed.model;
  PrintScope get scope => _scope;
  bool get applyToAll => _applyToAll;
  bool get breakMode => _breakMode;
  PaginationResult? get pagination => _pagination;
  List<PageSpec> get pages => _pagination?.pages ?? const [];
  String get sheetId => _sheetId;
  ResolvedRange get selection => _selection;

  /// Editors store settings; viewers keep them for this print job only.
  bool get persists => ed.canEdit;

  /// Switches to [f] once the bundled fonts loaded.
  void setFonts(PdfFontProvider f) {
    fonts = f;
    _measurer = PdfFontMeasurer(f);
    repaginate(immediate: true);
  }

  /// The settings of [sheetId] (default: the current sheet).
  PrintSettings settingsFor([String? sheetId]) {
    final id = sheetId ?? _sheetId;
    final local = _local[id];
    if (local != null) return local;
    final s = model.sheet(id);
    return PrintSettings.parse(
      s?.record?.printSettingsJson,
      locale: model.spreadsheet.locale,
    );
  }

  PrintSettings get settings => settingsFor();

  /// Sheets an edit applies to.
  List<String> get targetSheets => _scope == PrintScope.workbook && _applyToAll
      ? [for (final s in model.visibleSheets) s.id]
      : [_sheetId];

  set scope(PrintScope v) {
    if (v == _scope) return;
    _scope = v;
    notifyListeners();
    repaginate();
  }

  set applyToAll(bool v) {
    _applyToAll = v;
    notifyListeners();
  }

  set breakMode(bool v) {
    if (v == _breakMode) return;
    _breakMode = v;
    notifyListeners();
  }

  /// The print job of the current state.
  PrintJob get job => PrintJob(
    scope: _scope,
    sheetId: _sheetId,
    selection: _scope == PrintScope.selection ? _selection : null,
    settingsBySheet: Map.of(_local),
  );

  /// Applies a JSON merge patch to the settings (11 §7.2): editors through
  /// `sheets.print.updateSettings` (one undo step), viewers locally.
  Future<bool> update(Map<String, Object?> patch) async {
    if (persists) {
      final ok = await ed.invokeCommand('sheets.print.updateSettings', {
        'sheetIds': targetSheets,
        'patch': patch,
      });
      repaginate(immediate: true);
      return ok;
    }
    for (final id in targetSheets) {
      _local[id] = settingsFor(
        id,
      ).mergePatch(patch, locale: model.spreadsheet.locale);
    }
    notifyListeners();
    repaginate(immediate: true);
    return true;
  }

  /// Resets the settings to the defaults.
  Future<bool> reset() async {
    if (persists) {
      final ok = await ed.invokeCommand('sheets.print.resetSettings', {
        'sheetIds': targetSheets,
      });
      repaginate(immediate: true);
      return ok;
    }
    for (final id in targetSheets) {
      _local.remove(id);
    }
    repaginate(immediate: true);
    return true;
  }

  void _onBatch(WorkbookChangeBatch b) {
    contentVersion++;
    repaginate();
  }

  /// Re-runs the paginator (debounced unless [immediate]).
  void repaginate({bool immediate = false}) {
    _debounce?.cancel();
    if (immediate) {
      _paginate();
    } else {
      _debounce = Timer(const Duration(milliseconds: 250), _paginate);
    }
  }

  void _paginate() {
    if (_disposed) return;
    if (model.sheet(_sheetId) == null) {
      _sheetId = ed.activeSheetId;
    }
    try {
      _pagination = Paginator.paginate(
        model,
        job,
        source: ed.engine,
        measurer: textMeasurer,
      );
    } catch (e) {
      debugPrint('Pagination failed: $e');
      _pagination = const PaginationResult([], [], requestedPages: 0);
    }
    contentVersion++;
    notifyListeners();
  }

  /// The PDF of the job.
  Future<Uint8List> buildPdf({IoProgress? progress}) async {
    final l = ed.l10n;
    _paginate();
    var images = const <String, Uint8List>{};
    if (SheetsWorkbookExporter.imageFiles(model).isNotEmpty) {
      await progress?.step(l.exportPhaseImages);
      images = await fetchImageBytes(ed.services, model);
    }
    await progress?.step(l.printPhaseRendering(pages.length));
    final me = ed.services.me;
    return SheetsWorkbookExporter.pdf(
      model,
      ed.engine,
      _pagination!,
      now: clock.now(),
      author: me?.displayName,
      title: exportTitle(ed),
      imageBytes: (u) => images[u],
      conditional: ed.cells.conditional,
      fonts: fonts,
    );
  }

  /// `<title>.pdf`, or `<title> - <sheet>.pdf` for one sheet.
  String get pdfFileName => SheetsWorkbookExporter.fileNameFor(
    exportTitle(ed),
    SheetsExportFormat.pdf,
    sheetName: _scope == PrintScope.workbook
        ? null
        : model.sheet(_sheetId)?.name,
  );

  /// Whether the user may print/export.
  bool get canExport => canDownload(ed) || ed.itemRole >= Role.editor;

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    ed.model.removeListener(_onBatch);
    if (identical(current, this)) current = null;
    super.dispose();
  }
}
