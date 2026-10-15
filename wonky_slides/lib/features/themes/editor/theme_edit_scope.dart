import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource, JsonArgs;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/themes.dart';

import '../../../l10n/slides_l10n.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../masters/masters_targets.dart';
import '../../toolbar/command_ui.dart';

/// Per-editor view state of the theme editor (not persisted, not undone):
/// the scheme the color swatches edit and the expanded text styles.
class ThemeEditorState extends ChangeNotifier {
  ThemeEditorState._();

  static final Expando<ThemeEditorState> _of = Expando('slidesThemeEditor');

  /// The state of [editor]'s theme editor.
  static ThemeEditorState of(DeckEditorController editor) =>
      _of[editor] ??= ThemeEditorState._();

  SlideAppearance? _appearance;

  /// The scheme the Colors section edits (default: the deck appearance).
  SlideAppearance appearanceOf(DeckEditorController ed) =>
      _appearance ?? ed.model.deck?.appearance ?? SlideAppearance.light;

  set appearance(SlideAppearance a) {
    if (a == _appearance) return;
    _appearance = a;
    notifyListeners();
  }

  final Set<String> _expanded = {};

  /// Whether text style [key] shows its properties.
  bool expanded(String key) => _expanded.contains(key);

  void toggle(String key) {
    if (!_expanded.remove(key)) _expanded.add(key);
    notifyListeners();
  }
}

/// What one theme editor section works with (Slides 05 §8.4; SL-28): the
/// edited theme (the edited master's theme in masters mode), its data, the
/// theme resolved in both appearances and the write path — every
/// committed control replaces **one** JSON column through
/// `slides.theme.update` (one undo step, whole-value LWW, 02 §14).
class ThemeEditScope {
  ThemeEditScope(this.context, this.services, this.ed)
    : ui = SlidesCommandUi(context, services),
      l = slidesL10n(context),
      state = ThemeEditorState.of(ed),
      rec = MastersTargets.theme(ed, const JsonArgs()) {
    final r = rec;
    data = SlideResolver.themeDataOf(r);
    light = ed.resolver.resolveTheme(r, SlideAppearance.light);
    dark = ed.resolver.resolveTheme(r, SlideAppearance.dark);
  }

  final BuildContext context;
  final ShellServices services;
  final DeckEditorController ed;
  final SlidesCommandUi ui;
  final SlidesLocalizations l;
  final ThemeEditorState state;

  /// The edited theme row (null in a deck without themes).
  final DeckThemeRec? rec;

  /// Its data (the built-in default when [rec] is null).
  late final DeckThemeData data;

  /// Resolved in the light and the dark appearance.
  late final ResolvedTheme light;
  late final ResolvedTheme dark;

  /// The scheme the Colors section edits.
  SlideAppearance get appearance => state.appearanceOf(ed);

  /// [light] or [dark] for [appearance].
  ResolvedTheme get resolved =>
      appearance == SlideAppearance.dark ? dark : light;

  /// The theme in the deck's appearance (swatches of theme-color fields).
  ResolvedTheme get deckResolved =>
      (ed.model.deck?.appearance ?? SlideAppearance.light) ==
          SlideAppearance.dark
      ? dark
      : light;

  /// Whether the theme can be edited (role, Viewing mode, a theme).
  bool get enabled =>
      rec != null &&
      ui.state('slides.theme.update', {'themeId': rec!.id}).enabled;

  /// A deep copy of [column]'s JSON (absent optional columns: the
  /// effective defaults).
  JsonMap column(DeckThemeColumn column) {
    final raw =
        data.columnJson(column) ??
        switch (column) {
          DeckThemeColumn.shapeStyleJson => light.shapeStyles.toJson(),
          DeckThemeColumn.tableStyleJson => light.tableStyle.toJson(),
          DeckThemeColumn.codeStyleJson => light.codeStyle.toJson(),
          DeckThemeColumn.chartStyleJson => light.chartStyle.toJson(),
          _ => <String, Object?>{'v': 1},
        };
    return (jsonDecode(jsonEncode(raw)) as Map).cast<String, Object?>();
  }

  /// Replaces [column] (one undo step).
  void write(DeckThemeColumn column, JsonMap value) {
    final r = rec;
    if (r == null) return;
    ui.run('slides.theme.update', {
      'themeId': r.id,
      'columns': {column.name: value},
    }, InvocationSource.ui);
  }

  /// Edits a copy of [column] with [change] and writes it when it changed.
  void edit(DeckThemeColumn column, void Function(JsonMap json) change) {
    final json = this.column(column);
    final before = jsonEncode(json);
    change(json);
    if (jsonEncode(json) == before) return;
    write(column, json);
  }

  /// Sets the value at [path] in [json] (null removes it), creating
  /// intermediate objects.
  static void setPath(JsonMap json, List<String> path, Object? value) {
    var m = json;
    for (final k in path.take(path.length - 1)) {
      final next = m[k];
      if (next is Map<String, Object?>) {
        m = next;
      } else if (next is Map) {
        final copy = next.cast<String, Object?>();
        m[k] = copy;
        m = copy;
      } else {
        final created = <String, Object?>{};
        m[k] = created;
        m = created;
      }
    }
    if (value == null) {
      m.remove(path.last);
    } else {
      m[path.last] = value;
    }
  }

  /// The value at [path] of [json], or null.
  static Object? getPath(JsonMap json, List<String> path) {
    Object? v = json;
    for (final k in path) {
      if (v is! Map) return null;
      v = v[k];
    }
    return v;
  }

  /// Runs command [id] with [args].
  void run(String id, [Map<String, Object?> args = const {}]) =>
      ui.run(id, args, InvocationSource.ui);
}
