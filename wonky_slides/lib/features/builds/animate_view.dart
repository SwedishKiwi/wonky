import 'package:flutter/foundation.dart';
import 'package:wonky_slides_core/charts.dart' show SlideChartMotion;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

import '../../l10n/slides_l10n.dart';
import '../canvas/slide_canvas_controller.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../settings/slides_user_defaults.dart';
import 'animate_preview.dart';
import 'build_order.dart';

/// The Build tab's kind sub-tabs (06 §5.2): *In*, *Action* (emphasis and
/// motion) and *Out*.
enum BuildKindTab {
  buildIn,
  action,
  buildOut;

  /// The tab of builds of [kind].
  static BuildKindTab of(SlideBuildKind kind) => switch (kind) {
    SlideBuildKind.buildIn => buildIn,
    SlideBuildKind.buildOut => buildOut,
    _ => action,
  };

  /// The tab named [name] (`in`, `action`, `out` or a `BuildKind` name).
  static BuildKindTab? fromName(Object? name) => switch (name) {
    'in' || 'buildIn' => buildIn,
    'out' || 'buildOut' => buildOut,
    'action' || 'emphasis' || 'motion' => action,
    _ => null,
  };

  /// Whether builds of [kind] are listed on this tab.
  bool contains(SlideBuildKind kind) => of(kind) == this;

  /// The build kinds of the tab's effects (Action: emphasis, then motion).
  List<SlideBuildKind> get kinds => switch (this) {
    buildIn => const [SlideBuildKind.buildIn],
    buildOut => const [SlideBuildKind.buildOut],
    action => const [SlideBuildKind.emphasis, SlideBuildKind.motion],
  };
}

/// The Animate view state of an open deck (Slides 06 §5): per user, not
/// synced and not undoable.
///
/// - the **selected builds** (Order list rows; the Build tab edits them);
/// - the Build tab's kind sub-tab;
/// - the canvas toggles *Show build order* and *Show Magic Move matches*
///   and the ⚙ preview options (*Auto-preview changes*, *Include
///   transition in preview*, *Preview full motion*);
/// - the animation painter's copied builds (*Copy animation*);
/// - compiled timelines per slide (cached by the slide's revision);
/// - the running preview ([preview]).
///
/// Changes notify the editor, so the canvas, toolbar and inspector follow.
class AnimateView extends ChangeNotifier {
  AnimateView._(this.editor) {
    editor.session.model.addListener(_onBatch);
    preview = AnimatePreview(this);
    preview.addListener(_notify);
  }

  static final Expando<AnimateView> _registry = Expando('slidesAnimateView');

  /// The Animate view state of [ed].
  static AnimateView of(DeckEditorController ed) =>
      _registry[ed] ??= AnimateView._(ed);

  /// The view state of [ed] if it was ever created (no allocation).
  static AnimateView? maybeOf(DeckEditorController ed) => _registry[ed];

  final DeckEditorController editor;

  /// The canvas preview player (06 §5.5).
  late final AnimatePreview preview;

  DeckModel get model => editor.session.model;

  // ------------------------------------------------------------ selection

  final List<String> _selected = [];
  String? _anchor;

  /// The selected builds in sequence order (Order list rows).
  List<String> get selectedBuildIds => List.unmodifiable(_selected);

  /// The anchor of Shift-click range selection in the Order list.
  String? get anchor => _anchor;

  /// Selects [ids] (in the slide's sequence order); with [selectElements]
  /// their elements are selected on the canvas too (06 §5.4) and the Build
  /// tab shows the kind of the first build.
  void selectBuilds(
    Iterable<String> ids, {
    bool selectElements = true,
    String? anchor,
  }) {
    final set = ids.toSet();
    final ordered = <String>[];
    String? slideId;
    for (final id in set) {
      final b = model.build(id);
      if (b == null) continue;
      slideId ??= b.slideId;
    }
    if (slideId != null) {
      for (final b in model.buildsOf(slideId)) {
        if (set.contains(b.id)) ordered.add(b.id);
      }
    }
    _selected
      ..clear()
      ..addAll(ordered);
    _anchor = anchor ?? (ordered.isEmpty ? null : ordered.first);
    if (ordered.isNotEmpty) {
      final first = model.build(ordered.first)!;
      _kindTab = BuildKindTab.of(first.kind);
      if (selectElements) {
        final els = <String>[
          for (final id in ordered)
            if (model.build(id)?.elementId case final String e) e,
        ];
        final unique = els.toSet().toList();
        if (!_sameSet(editor.selectedElementIds, unique)) {
          final canvas = SlideCanvasController.of(editor);
          if (canvas != null) {
            canvas.selection.select(unique);
          } else {
            editor.selectElements(unique);
          }
        }
      }
    }
    _notify();
  }

  static bool _sameSet(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  /// Clears the build selection.
  void clearBuildSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _anchor = null;
    _notify();
  }

  /// The builds the Build tab edits: the selected builds when they belong
  /// to the selected elements, else the first build of the kind tab on
  /// the (first) selected element.
  List<SlideBuildRec> editedBuilds() {
    final els = editor.selectedElementIds.toSet();
    final sel = [
      for (final id in _selected)
        if (model.build(id) case final SlideBuildRec b
            when els.isEmpty || els.contains(b.elementId))
          b,
    ];
    if (sel.isNotEmpty) return sel;
    final slideId = editor.currentSlideId;
    if (slideId == null || els.isEmpty) return const [];
    final out = <SlideBuildRec>[];
    final seen = <String>{};
    for (final b in model.buildsOf(slideId)) {
      if (els.contains(b.elementId) &&
          _kindTab.contains(b.kind) &&
          seen.add(b.elementId!)) {
        out.add(b);
      }
    }
    return out;
  }

  // ------------------------------------------------------------- kind tab

  BuildKindTab _kindTab = BuildKindTab.buildIn;

  /// The Build tab's kind sub-tab.
  BuildKindTab get kindTab => _kindTab;
  set kindTab(BuildKindTab t) {
    if (t == _kindTab) return;
    _kindTab = t;
    // The selection follows the sub-tab: the first build of that kind on
    // the selected element.
    _selected.clear();
    _notify();
  }

  // -------------------------------------------------------------- toggles

  bool _orderOverlay = false;
  bool _matches = false;

  /// View › Show › Build order (06 §5.5).
  bool get orderOverlay => _orderOverlay;

  /// View › Show › Magic Move matches (06 §8.3).
  bool get showMatches => _matches;

  void toggleOrderOverlay() {
    _orderOverlay = !_orderOverlay;
    _notify();
  }

  void toggleMatches() {
    _matches = !_matches;
    _notify();
  }

  /// Whether the canvas shows the build order badges: the toggle, or the
  /// Animate tab is open.
  bool get badgesVisible =>
      _orderOverlay ||
      (editor.inspectorVisible && editor.inspectorTab == InspectorTab.animate);

  /// Whether the canvas shows the Magic Move match badges: the slide's
  /// transition is Magic Move and the Transition tab is open, or the
  /// toggle is on.
  bool get matchBadgesVisible =>
      _matches ||
      (editor.inspectorVisible &&
          editor.inspectorTab == InspectorTab.animate &&
          editor.animateTab == 'transition');

  // ------------------------------------------------- ⚙ preview options

  /// The ⚙ options of the Order tab (06 §5.4).
  static const optionAutoPreview = 'autoPreview';
  static const optionIncludeTransition = 'includeTransition';
  static const optionFullMotion = 'fullMotion';

  final Map<String, bool> _options = {
    optionAutoPreview: true,
    optionIncludeTransition: false,
    optionFullMotion: false,
  };

  /// The value of ⚙ option [name].
  bool option(String name) => _options[name] ?? false;

  /// Flips ⚙ option [name]; false when it is unknown.
  bool toggleOption(String name) {
    final v = _options[name];
    if (v == null) return false;
    _options[name] = !v;
    if (name == optionFullMotion) _timelines.clear();
    _notify();
    return true;
  }

  // --------------------------------------------------- animation painter

  CopiedBuilds? _copied;

  /// The builds of *Copy animation* (06 §5.6), or null.
  CopiedBuilds? get copied => _copied;
  set copied(CopiedBuilds? c) {
    _copied = c;
    _notify();
  }

  // ------------------------------------------------------- reduced motion

  bool _systemReduced = false;

  /// The OS/app *Reduce motion* setting (set by the Animate tab from
  /// `WonkyThemeScope`).
  bool get systemReducedMotion => _systemReduced;
  set systemReducedMotion(bool v) {
    if (v == _systemReduced) return;
    _systemReduced = v;
    _timelines.clear();
    // No notification: called during build.
  }

  /// Whether *Reduce motion* is on for the editor (06 §13): the system or
  /// app setting, or Slides settings › *Reduce motion in the editor*.
  bool get reduceMotionOn =>
      _systemReduced ||
      SlidesUserDefaults.of(
        editor.services,
      ).flag(SlidesUserDefaults.keyReduceEditorMotion);

  /// Whether previews play reduced (unless *Preview full motion*).
  bool get previewReduced => reduceMotionOn && !option(optionFullMotion);

  // ------------------------------------------------------------ timelines

  final Map<String, (String, SlideTimeline)> _timelines = {};

  /// The compiled timeline of [slideId] as the editor previews it (the
  /// authored clicks: `advance.autoBuilds` is ignored; reduced when
  /// [previewReduced]).
  SlideTimeline timelineOf(String slideId, {bool? reduced}) {
    final r = reduced ?? previewReduced;
    final rev = '${model.indexes.revision(slideId)}|$r';
    final key = '$slideId|$r';
    final hit = _timelines[key];
    if (hit != null && hit.$1 == rev) return hit.$2;
    final t = compile(slideId, reduced: r);
    _timelines[key] = (rev, t);
    if (_timelines.length > 24) _timelines.remove(_timelines.keys.first);
    return t;
  }

  /// Compiles [slideId] with [builds] instead of its own (previews of one
  /// build or of a hovered effect).
  SlideTimeline compile(
    String slideId, {
    bool reduced = false,
    List<SlideBuildRec>? builds,
  }) {
    if (model.slide(slideId) == null) return SlideTimeline(slideId: slideId);
    final canvas = SlideCanvasController.of(editor);
    final scene = canvas?.renderer.scene(slideId);
    var input = SlideMotionInput.fromDeck(
      model,
      slideId,
      resolved: editor.resolver.resolve(slideId),
      scene: scene,
      options: CompileOptions(reducedMotion: reduced, ignoreAutoBuilds: true),
      chartShapeOf: _chartShapes,
    );
    if (builds != null) {
      input = SlideMotionInput(
        slide: input.slide,
        builds: builds,
        elements: input.elements,
        transition: input.transition,
        slideWidth: input.slideWidth,
        slideHeight: input.slideHeight,
        options: input.options,
        resolveColor: input.resolveColor,
      );
    }
    return SlideTimelineCompiler.compile(input);
  }

  late final _chartShapes = SlideChartMotion.shapes(model);

  /// The Order list of [slideId] (06 §5.4).
  BuildOrder orderOf(String slideId) =>
      BuildOrder.of(model, slideId, timelineOf(slideId, reduced: false));

  // -------------------------------------------------------- slides around

  /// The slide shown before [slideId] when presenting in order (the
  /// previous non-skipped slide), or null.
  String? previousSlideOf(String slideId) {
    final entries = editor.order.entries;
    final i = entries.indexWhere((e) => e.id == slideId);
    for (var j = i - 1; j >= 0; j--) {
      if (!entries[j].skipped) return entries[j].id;
    }
    return null;
  }

  // ---------------------------------------------------------------- misc

  void _onBatch(DeckChangeBatch batch) {
    // 06 §11: a change of the previewed slide stops its preview; a
    // collaborator's change says so.
    if (preview.stopIfChanged() && batch.isRemote) {
      final l = slidesL10nOf(editor.services);
      editor.services.toasts.show(l.animatePreviewChanged);
    }
    final before = _selected.length;
    _selected.removeWhere((id) => model.build(id) == null);
    if (_selected.length != before) _notify();
  }

  void _notify() {
    notifyListeners();
    editor.notifyListeners();
    SlideCanvasController.of(editor)?.refresh();
  }

  @override
  void dispose() {
    editor.session.model.removeListener(_onBatch);
    preview
      ..removeListener(_notify)
      ..dispose();
    super.dispose();
  }
}
