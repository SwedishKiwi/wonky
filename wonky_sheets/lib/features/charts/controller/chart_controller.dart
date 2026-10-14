import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../sheet_editor/sheet_editor_controller.dart';
import '../render/chart_painter.dart';

/// The editor's chart colors (08 §6.4): automatic background, text and
/// lines follow the app's `card`, `foreground` and `border` tokens.
ChartUiTokens chartUiTokensOf(BuildContext context) {
  final c = ShadTheme.of(context).colorScheme;
  return ChartUiTokens(
    card: c.card.toARGB32(),
    foreground: c.foreground.toARGB32(),
    border: c.border.toARGB32(),
  );
}

/// The theme brightness of [context].
bool chartDarkOf(BuildContext context) =>
    ShadTheme.of(context).brightness == Brightness.dark;

/// One laid-out scene and the inputs it was laid out for.
@immutable
class _SceneKey {
  const _SceneKey(
    this.width,
    this.height,
    this.dark,
    this.card,
    this.foreground,
    this.border,
    this.highlight,
    this.page,
  );

  final double width;
  final double height;
  final bool dark;
  final int card;
  final int foreground;
  final int border;
  final String? highlight;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is _SceneKey &&
      other.width == width &&
      other.height == height &&
      other.dark == dark &&
      other.card == card &&
      other.foreground == foreground &&
      other.border == border &&
      other.highlight == highlight &&
      other.page == page;

  @override
  int get hashCode => Object.hash(
    width,
    height,
    dark,
    card,
    foreground,
    border,
    highlight,
    page,
  );
}

/// Per-chart state of the editor (08 §4.3, §6.2 `ChartController`): the
/// parsed spec, the resolved data (re-resolved when the source cells
/// change) and the laid-out scene cached per (size, theme, highlight).
///
/// Scenes are laid out at the chart's logical size (100 % zoom) and painted
/// scaled, so text scales with zoom and stays crisp.
class ChartController extends ChangeNotifier {
  ChartController(this.editor, this.objectId, String specJson) {
    _setSpec(specJson);
  }

  final SheetEditorController editor;
  final String objectId;

  String _specJson = '';
  late ChartSpec _spec;
  ChartData? _data;
  List<ChartWarning> _layoutWarnings = const [];
  bool _dirty = true;
  _SceneKey? _sceneKey;
  ChartScene? _scene;

  /// Series highlighted from the legend (not persisted, 08 §6.5).
  String? _highlight;

  /// Page of a paged table chart.
  int tablePage = 0;

  ChartSpec get spec => _spec;
  String get specJson => _specJson;

  String? get highlight => _highlight;
  set highlight(String? key) {
    if (key == _highlight) return;
    _highlight = key;
    _scene = null;
    notifyListeners();
  }

  void _setSpec(String json) {
    _specJson = json;
    _spec = ChartSpec.fromJson(json);
    _dirty = true;
    _scene = null;
  }

  /// The stored spec changed (local edit, undo or a collaborator).
  void updateSpec(String json) {
    if (json == _specJson) return;
    _setSpec(json);
    notifyListeners();
  }

  /// Source cells may have changed: re-resolve on the next paint.
  void invalidateData() {
    _dirty = true;
    notifyListeners();
  }

  /// Sheet ids the chart reads from.
  Set<String> get sourceSheets => {
    for (final r in _spec.data.ranges) r.sheetId,
  };

  /// The resolved data (re-resolved when stale).
  ChartData get data {
    if (_dirty || _data == null) {
      final before = _data?.dataVersion;
      try {
        _data = ChartPipeline.resolve(_spec, editor.model, editor.engine);
      } catch (e) {
        debugPrint('Chart $objectId: resolving data failed: $e');
        _data = ChartData.empty(
          warnings: const [
            ChartWarning(
              ChartWarningCode.rangeNotFound,
              'Data range not found',
            ),
          ],
        );
      }
      _dirty = false;
      if (before == null || before != _data!.dataVersion) _scene = null;
    }
    return _data!;
  }

  /// Data and layout warnings (for the chart editor).
  List<ChartWarning> get warnings => [...data.warnings, ..._layoutWarnings];

  /// The automatic description (08 §14).
  String get autoDescription {
    try {
      return ChartDescriber.describe(_spec, data);
    } catch (_) {
      return '${_spec.type.displayName} chart';
    }
  }

  /// The scene at [width] × [height] (logical px) for the theme [tokens].
  ChartScene sceneFor(
    double width,
    double height, {
    required bool dark,
    required ChartUiTokens tokens,
    bool export = false,
  }) {
    final d = data;
    final key = _SceneKey(
      width,
      height,
      dark,
      export ? -1 : tokens.card,
      tokens.foreground,
      tokens.border,
      export ? null : _highlight,
      tablePage,
    );
    if (!export && _scene != null && key == _sceneKey) return _scene!;
    final theme = ChartTheme.from(
      editor.model.theme,
      dark: dark,
      export: export,
      tokens: tokens,
    );
    try {
      final layout = ChartPipeline.layout(
        _spec,
        d,
        size: ChartSize(width, height),
        theme: theme,
        measurer: FlutterTextMeasurer.instance,
        locale: editor.locale,
        options: ChartLayoutOptions(
          highlightSeriesKey: export ? null : _highlight,
          tablePage: tablePage,
        ),
      );
      if (export) return layout.scene;
      _layoutWarnings = layout.warnings;
      _scene = layout.scene;
    } catch (e) {
      debugPrint('Chart $objectId: layout failed: $e');
      final empty = ChartScene(
        width: width,
        height: height,
        background: theme.background,
        primitives: const [],
      );
      if (export) return empty;
      _layoutWarnings = const [];
      _scene = ChartScene(
        width: width,
        height: height,
        background: theme.background,
        primitives: const [],
      );
    }
    _sceneKey = key;
    return _scene!;
  }
}
