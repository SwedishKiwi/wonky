import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;

import '../banding/banding_controller.dart';
import '../conditional_format/cf_controller.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import '../theme/theme_controller.dart';
import '../model/memory_workbook_session.dart';
import 'cell_fonts.dart';
import 'rich_text_paint.dart';
import 'sheets_user_defaults.dart';

/// Panel ids of the formatting features (04 §10).
abstract final class FormattingPanels {
  static const conditionalFormatting = 'sheets.panel.conditionalFormatting';
  static const alternatingColors = 'sheets.panel.alternatingColors';
  static const theme = 'sheets.panel.theme';
}

/// The formatting features of one open spreadsheet (06 §13–15): conditional
/// formatting evaluation and preview, alternating-color and theme previews,
/// the range highlight layer and cell-font loading. Created by
/// [install] when the editor opens (or lazily by the first command that
/// needs it) and disposed with the editor screen.
class FormattingFeatures {
  FormattingFeatures._(this.editor) {
    cf = CfController(editor);
    banding = BandingController(editor);
    theme = ThemeController(
      editor,
      onPreviewChanged: cf.evaluator.invalidateAll,
    );
    _layer = RangeHighlightLayer(highlight);
    cf.highlight.addListener(_syncHighlight);
    banding.highlight.addListener(_syncHighlight);
    editor.layers.add(_layer);
    CellFonts.generation.addListener(_onFontLoaded);
    editor.services.prefs.addListener(_syncPrefs);
    _syncPrefs();
  }

  /// Custom fill lists (Settings › Sheets) for the planner's fill series.
  void _syncPrefs() {
    final s = editor.session;
    if (s is WorkbookSessionBase) {
      s.customLists = SheetsUserDefaults.of(editor.services).customFillLists;
    }
  }

  static final Expando<FormattingFeatures> _features = Expando(
    'FormattingFeatures',
  );

  /// The features of [editor], installing them on first use.
  static FormattingFeatures of(SheetEditorController editor) =>
      _features[editor] ??= FormattingFeatures._(editor);

  /// The installed features of [editor], or null.
  static FormattingFeatures? maybeOf(SheetEditorController editor) =>
      _features[editor];

  /// Installs the features on a new editor (grid hooks, layers).
  static FormattingFeatures install(SheetEditorController editor) => of(editor);

  final SheetEditorController editor;
  late final CfController cf;
  late final BandingController banding;
  late final ThemeController theme;
  late final RangeHighlightLayer _layer;

  /// Ranges outlined on the grid (hovered CF rule, banding range).
  final ValueNotifier<List<GridRect>?> highlight = ValueNotifier(null);

  void _syncHighlight() =>
      highlight.value = cf.highlight.value ?? banding.highlight.value;

  void _onFontLoaded() {
    editor.textCache.clear();
    richTextLayouts.clear();
    editor.contentSignal.fire();
  }

  /// Ends every preview (panels closed without *Done*).
  void endPreviews() {
    cf.setDraft(null);
    banding.setDraft(null);
    theme.preview(null);
    highlight.value = null;
  }

  void dispose() {
    editor.services.prefs.removeListener(_syncPrefs);
    CellFonts.generation.removeListener(_onFontLoaded);
    cf.highlight.removeListener(_syncHighlight);
    banding.highlight.removeListener(_syncHighlight);
    editor.layers.remove(_layer);
    cf.dispose();
    banding.dispose();
    theme.dispose();
    highlight.dispose();
    _features[editor] = null;
  }
}
