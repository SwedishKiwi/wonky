import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart';

import '../../formatting/sheets_user_defaults.dart';
import '../../sheet_editor/sheet_editor_controller.dart';

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
    this.azimuth,
    this.elevation,
    this.transition,
    this.pattern,
    this.hover,
  );

  final double width;
  final double height;
  final bool dark;
  final int card;
  final int foreground;
  final int border;
  final String? highlight;
  final int page;
  final double? azimuth;
  final double? elevation;
  final double transition;
  final bool pattern;
  final SceneTag? hover;

  @override
  bool operator ==(Object other) =>
      other is _SceneKey &&
      other.pattern == pattern &&
      other.hover == hover &&
      other.width == width &&
      other.height == height &&
      other.dark == dark &&
      other.card == card &&
      other.foreground == foreground &&
      other.border == border &&
      other.highlight == highlight &&
      other.page == page &&
      other.azimuth == azimuth &&
      other.elevation == elevation &&
      other.transition == transition;

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
    azimuth,
    elevation,
    transition,
    pattern,
    hover,
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
    _pattern = _patternPref;
    editor.services.prefs.addListener(_onPrefs);
  }

  /// Settings › Sheets › *Distinguish chart series by pattern* (08 §14).
  bool _pattern = false;

  bool get _patternPref =>
      SheetsUserDefaults.of(editor.services).chartSeriesByPattern;

  void _onPrefs() {
    final p = _patternPref;
    if (p == _pattern) return;
    _pattern = p;
    _scene = null;
    notifyListeners();
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

  /// The 3D item under the pointer (drawn lighter, 08 §23.6).
  SceneTag? _hover3D;

  SceneTag? get hover3D => _hover3D;

  set hover3D(SceneTag? tag) {
    if (tag == _hover3D) return;
    _hover3D = tag;
    notifyListeners();
  }

  /// Page of a paged table chart.
  int tablePage = 0;

  // 3D (08 §23.6): the view angles while the user orbits, and the animated
  // transition between two data states.
  double? _orbitAzimuth;
  double? _orbitElevation;
  bool _orbitCommitted = false;
  Chart3DModel? _settled3D;
  Chart3DModel? _displayed3D;
  Chart3DModel? _from3D;
  double _t3D = 1;

  /// Whether data changes of 3D charts animate (off with reduced motion).
  bool animate3D = true;

  /// Incremented when a 3D transition starts; the view animates
  /// [transition3D] from 0 to 1.
  final ValueNotifier<int> transitionRequests = ValueNotifier(0);

  /// The orbit angles shown instead of the spec's (null = the spec's).
  (double, double)? get orbit =>
      _orbitAzimuth == null ? null : (_orbitAzimuth!, _orbitElevation!);

  /// Shows the chart from [azimuth]/[elevation] until [endOrbit].
  void setOrbit(double azimuth, double elevation) {
    final a = ChartThreeD.normalizeAzimuth(azimuth);
    final e = elevation.clamp(
      ChartThreeD.minElevation,
      ChartThreeD.maxElevation,
    );
    if (a == _orbitAzimuth && e == _orbitElevation) return;
    _orbitAzimuth = a;
    _orbitElevation = e;
    _orbitCommitted = false;
    _scene = null;
    notifyListeners();
  }

  /// Ends an orbit. With [committed], the override stays until the spec
  /// with the committed angles arrives (no flicker), else it is dropped.
  void endOrbit({bool committed = false}) {
    if (_orbitAzimuth == null) return;
    if (committed) {
      _orbitCommitted = true;
      return;
    }
    _orbitAzimuth = null;
    _orbitElevation = null;
    _scene = null;
    notifyListeners();
  }

  @override
  void dispose() {
    editor.services.prefs.removeListener(_onPrefs);
    transitionRequests.dispose();
    Chart3DBackends.gpu.value?.release(this);
    super.dispose();
  }

  /// Progress of the running 3D transition (0..1).
  double get transition3D => _t3D;
  set transition3D(double t) {
    final v = t.clamp(0.0, 1.0);
    if (v == _t3D) return;
    _t3D = v;
    if (v >= 1) _from3D = null;
    _scene = null;
    notifyListeners();
  }

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
    if (_orbitCommitted) {
      _orbitCommitted = false;
      _orbitAzimuth = null;
      _orbitElevation = null;
    }
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
    for (final r in _spec.data.gridRanges) r.sheetId,
  };

  /// The resolved data (re-resolved when stale).
  ChartData get data {
    if (_dirty || _data == null) {
      final before = _data?.dataVersion;
      try {
        _data = SheetsChartPipeline.resolve(_spec, editor.model, editor.engine);
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
      export ? null : _orbitAzimuth,
      export ? null : _orbitElevation,
      export ? 1 : _t3D,
      !export && _pattern,
      export ? null : _hover3D,
    );
    if (!export && _scene != null && key == _sceneKey) return _scene!;
    final theme = ChartTheme.from(
      editor.model.theme,
      dark: dark,
      export: export,
      tokens: tokens,
    );
    try {
      ChartLayout run({Chart3DModel? from, double t = 1}) =>
          ChartPipeline.layout(
            _spec,
            d,
            size: ChartSize(width, height),
            theme: theme,
            measurer: FlutterTextMeasurer.instance,
            locale: editor.locale,
            options: ChartLayoutOptions(
              highlightSeriesKey: export ? null : _highlight,
              tablePage: tablePage,
              distinguishByPattern: !export && _pattern,
              hover3D: export ? null : _hover3D,
              azimuth3D: export ? null : _orbitAzimuth,
              elevation3D: export ? null : _orbitElevation,
              transitionFrom3D: from,
              transition3D: t,
            ),
          );
      var layout = run();
      if (export) return layout.scene;
      final target = layout.scene.threeD?.model;
      if (target != null) {
        final settled = _settled3D;
        if (animate3D &&
            _orbitAzimuth == null &&
            settled != null &&
            settled.kind == target.kind &&
            settled.contentHash != target.contentHash) {
          // Animate from what is on screen now (08 §23.6).
          _from3D = _displayed3D ?? settled;
          _t3D = 0;
          transitionRequests.value++;
        }
        _settled3D = target;
        final from = _from3D;
        if (from != null && _t3D < 1) {
          layout = run(from: from, t: Curves.easeOutCubic.transform(_t3D));
        }
        _displayed3D = layout.scene.threeD?.model;
      } else {
        _settled3D = _displayed3D = _from3D = null;
        _t3D = 1;
      }
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
