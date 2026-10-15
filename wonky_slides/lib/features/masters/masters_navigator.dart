import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/planner.dart' show OrderKeys;
import 'package:wonky_ui/wonky_ui.dart';

import '../../config/menus/context_menu_specs.dart' show SlidesContextMenuIds;
import '../../l10n/slides_l10n.dart';
import '../../theme/slides_tokens.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../navigator/deck_renderer.dart';
import '../navigator/nav_thumbnail.dart';
import '../navigator/slide_navigator.dart' show OpenContextMenu;
import '../stage/slide_renderer.dart';

/// One row of the masters navigator.
sealed class MastersRow {
  const MastersRow();
}

/// A theme section header.
final class MastersThemeRow extends MastersRow {
  const MastersThemeRow(
    this.theme, {
    required this.isDefault,
    required this.used,
  });

  final DeckThemeRec theme;
  final bool isDefault;

  /// Slides drawn with the theme's layouts.
  final int used;
}

/// A master.
final class MastersMasterRow extends MastersRow {
  const MastersMasterRow(this.master, {required this.dimmed});

  final SlideMasterRec master;
  final bool dimmed;
}

/// A layout of a master.
final class MastersLayoutRow extends MastersRow {
  const MastersLayoutRow(
    this.layout, {
    required this.used,
    required this.dimmed,
  });

  final SlideLayoutRec layout;
  final int used;
  final bool dimmed;
}

/// *New layout* at the end of a master's layouts.
final class MastersAddLayoutRow extends MastersRow {
  const MastersAddLayoutRow(this.master);

  final SlideMasterRec master;
}

/// The rows of the masters navigator of [model]: every theme (the default
/// first, unused themes dimmed), its masters and their layouts in order.
List<MastersRow> mastersRows(DeckModel model) {
  final ix = model.indexes.themes;
  final def = model.defaultTheme;
  final themes = [
    ?def,
    for (final t in model.themes)
      if (t.id != def?.id) t,
  ];
  final out = <MastersRow>[];
  for (final t in themes) {
    final used = ix.slidesUsingTheme(t.id);
    final dimmed = used == 0 && t.id != def?.id;
    out.add(MastersThemeRow(t, isDefault: t.id == def?.id, used: used));
    for (final m in model.mastersOf(t.id)) {
      out.add(MastersMasterRow(m, dimmed: dimmed));
      final layouts = OrderKeys.sorted([
        for (final l in model.layoutsOf(m.id)) (l.sortKey, l.id),
      ]);
      for (final (_, id) in layouts) {
        final l = model.layout(id)!;
        out.add(
          MastersLayoutRow(l, used: ix.slidesUsingLayout(l.id), dimmed: dimmed),
        );
      }
      out.add(MastersAddLayoutRow(m));
    }
  }
  return out;
}

/// The navigator of masters mode (Slides 05 §8.1; SL-28): the deck's
/// themes as sections, each master with its layouts below it, every one
/// with a live thumbnail; layouts show their usage ("Used by 12 slides")
/// and a hidden badge, unused themes are dimmed. A click edits the
/// master/layout (`slides.view.setMode {mode: masters, layoutId |
/// masterId}`); right-click or ⋮ opens its context menu. Keyboard:
/// Up/Down move between masters and layouts, Enter focuses the canvas,
/// F2 renames, Delete deletes the layout.
///
/// A list rather than `WonkyTreeView`: rows carry thumbnails (the tree's
/// rows are 30 px).
class MastersNavigator extends StatefulWidget {
  const MastersNavigator({
    super.key,
    required this.services,
    required this.editor,
    required this.width,
    required this.onContextMenu,
  });

  final ShellServices services;
  final DeckEditorController editor;
  final double width;
  final OpenContextMenu onContextMenu;

  @override
  State<MastersNavigator> createState() => _MastersNavigatorState();
}

class _MastersNavigatorState extends State<MastersNavigator> {
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'slides.masters.navigator');
  final Map<String, GlobalKey> _keys = {};
  late SlideRenderer _renderer;
  String? _shown;

  DeckEditorController get ed => widget.editor;

  @override
  void initState() {
    super.initState();
    _renderer = DeckThumbnails.acquire(ed);
    ed.addListener(_onEditor);
  }

  @override
  void didUpdateWidget(MastersNavigator old) {
    super.didUpdateWidget(old);
    if (!identical(old.editor, ed)) {
      old.editor.removeListener(_onEditor);
      DeckThumbnails.release(old.editor, _renderer);
      _renderer = DeckThumbnails.acquire(ed);
      ed.addListener(_onEditor);
    }
  }

  @override
  void dispose() {
    ed.removeListener(_onEditor);
    DeckThumbnails.release(ed, _renderer);
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Keeps the edited row in view.
  void _onEditor() {
    final id = ed.surfaceId;
    if (id == _shown) return;
    _shown = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _keys[id]?.currentContext;
      if (c != null && c.mounted) {
        Scrollable.ensureVisible(
          c,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
        if (c.mounted) {
          Scrollable.ensureVisible(
            c,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          );
        }
      }
    });
  }

  Future<void> _invoke(String id, [Map<String, Object?> args = const {}]) =>
      widget.services.dispatcher.invoke(
        id,
        args: args,
        source: InvocationSource.ui,
        context: context,
      );

  void _select(String id, {required bool layout}) {
    _invoke('slides.view.setMode', {
      'mode': 'masters',
      layout ? 'layoutId' : 'masterId': id,
    });
  }

  void _menu(String id, {required bool layout, required Offset global}) {
    _select(id, layout: layout);
    widget.onContextMenu(
      layout
          ? SlidesContextMenuIds.mastersLayout
          : SlidesContextMenuIds.mastersMaster,
      global,
    );
  }

  List<(String, bool)> _targets(List<MastersRow> rows) => [
    for (final r in rows)
      switch (r) {
        MastersMasterRow(:final master) => (master.id, false),
        MastersLayoutRow(:final layout) => (layout.id, true),
        _ => null,
      },
  ].nonNulls.toList();

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final targets = _targets(mastersRows(ed.model));
    final cur = targets.indexWhere((t) => t.$1 == ed.surfaceId);
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.arrowUp) {
      if (targets.isEmpty) return KeyEventResult.handled;
      final next =
          (cur < 0 ? 0 : cur + (k == LogicalKeyboardKey.arrowDown ? 1 : -1))
              .clamp(0, targets.length - 1);
      _select(targets[next].$1, layout: targets[next].$2);
      return KeyEventResult.handled;
    }
    if (e is KeyRepeatEvent) return KeyEventResult.ignored;
    final layout = cur >= 0 && targets[cur].$2;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      ed.canvasFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.f2 && cur >= 0) {
      _invoke(layout ? 'slides.layout.rename' : 'slides.master.rename');
      return KeyEventResult.handled;
    }
    if ((k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) &&
        cur >= 0) {
      _invoke(layout ? 'slides.layout.delete' : 'slides.master.delete');
      return KeyEventResult.handled;
    }
    if ((k == LogicalKeyboardKey.contextMenu ||
            (k == LogicalKeyboardKey.f10 &&
                HardwareKeyboard.instance.isShiftPressed)) &&
        cur >= 0) {
      final box = _keys[targets[cur].$1]?.currentContext?.findRenderObject();
      final at = box is RenderBox
          ? box.localToGlobal(box.size.center(Offset.zero))
          : Offset.zero;
      _menu(targets[cur].$1, layout: layout, global: at);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([ed, widget.services.registry]),
    builder: (context, _) {
      final l = slidesL10n(context);
      final theme = ShadTheme.of(context);
      final tokens = SlidesTokens.of(context);
      final rows = mastersRows(ed.model);
      return Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: Semantics(
          container: true,
          label: l.mastersNavigatorLabel,
          child: ColoredBox(
            key: const ValueKey<String>('slides.masters.navigator'),
            color: tokens.navigatorBackground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, l, theme),
                Container(height: 1, color: theme.colorScheme.border),
                Expanded(
                  child: WonkyScrollArea(
                    controller: _scroll,
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                      children: [
                        for (final r in rows)
                          _row(context, l, theme, tokens, r),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _header(
    BuildContext context,
    SlidesLocalizations l,
    ShadThemeData theme,
  ) {
    final st = widget.services.dispatcher.stateOf('slides.layout.add');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.mastersNavigatorLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ShadTooltip(
            builder: (_) => Text(st.disabledReason ?? l.cmdLayoutAdd),
            child: ShadIconButton.ghost(
              key: const ValueKey<String>('slides.masters.addLayout'),
              width: 28,
              height: 28,
              iconSize: 16,
              enabled: st.enabled,
              semanticLabel: l.cmdLayoutAdd,
              icon: const Icon(LucideIcons.plus),
              onPressed: () => _invoke('slides.layout.add'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    SlidesLocalizations l,
    ShadThemeData theme,
    SlidesTokens tokens,
    MastersRow r,
  ) {
    switch (r) {
      case MastersThemeRow(:final theme, :final isDefault, :final used):
        return _themeHeader(context, l, theme, isDefault, used);
      case MastersMasterRow(:final master, :final dimmed):
        return _target(
          context,
          l,
          id: master.id,
          layout: false,
          indent: 0,
          name: l.mastersMasterName(master.name),
          dimmed: dimmed,
          badges: const [],
        );
      case MastersLayoutRow(:final layout, :final used, :final dimmed):
        return _target(
          context,
          l,
          id: layout.id,
          layout: true,
          indent: 16,
          name: layout.name,
          dimmed: dimmed,
          used: used,
          badges: [
            if (layout.hidden)
              ShadTooltip(
                builder: (_) => Text(l.mastersHiddenInPicker),
                child: Icon(
                  LucideIcons.eyeOff,
                  size: 12,
                  color: ShadTheme.of(context).colorScheme.mutedForeground,
                ),
              ),
          ],
        );
      case MastersAddLayoutRow(:final master):
        final st = widget.services.dispatcher.stateOf('slides.layout.add', {
          'masterId': master.id,
        });
        return Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ShadButton.ghost(
              key: ValueKey<String>('slides.masters.addLayout.${master.id}'),
              size: ShadButtonSize.sm,
              enabled: st.enabled,
              leading: const Icon(LucideIcons.plus, size: 14),
              onPressed: () =>
                  _invoke('slides.layout.add', {'masterId': master.id}),
              child: Flexible(
                child: Text(
                  l.cmdLayoutAdd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
    }
  }

  Widget _themeHeader(
    BuildContext context,
    SlidesLocalizations l,
    DeckThemeRec t,
    bool isDefault,
    int used,
  ) {
    final theme = ShadTheme.of(context);
    final dimmed = used == 0 && !isDefault;
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Padding(
        key: ValueKey<String>('slides.masters.theme.${t.id}'),
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                t.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  fontSize: 11,
                ),
              ),
            ),
            if (isDefault)
              ShadBadge.secondary(child: Text(l.themesDefault))
            else if (dimmed)
              Text(
                l.themesUsedBy(0),
                style: theme.textTheme.muted.copyWith(fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  Widget _target(
    BuildContext context,
    SlidesLocalizations l, {
    required String id,
    required bool layout,
    required double indent,
    required String name,
    required bool dimmed,
    required List<Widget> badges,
    int? used,
  }) {
    final theme = ShadTheme.of(context);
    final current = ed.surfaceId == id;
    final width = (widget.width - 16 - indent - 8).clamp(48.0, 400.0);
    final key = _keys.putIfAbsent(id, GlobalKey.new);
    final usage = used == null ? null : l.themesUsedBy(used);
    return Padding(
      key: key,
      padding: EdgeInsets.only(left: indent, bottom: 8),
      child: Semantics(
        button: true,
        selected: current,
        label: [name, ?usage].join(', '),
        child: GestureDetector(
          key: ValueKey<String>('slides.masters.row.$id'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focus.requestFocus();
            _select(id, layout: layout);
          },
          onSecondaryTapUp: (d) =>
              _menu(id, layout: layout, global: d.globalPosition),
          child: Opacity(
            opacity: dimmed && !current ? 0.55 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NavThumbnail(
                  renderer: _renderer,
                  slideId: id,
                  width: width,
                  current: current,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(
                          fontSize: 12,
                          fontWeight: current
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    ...badges,
                    if (used != null && used > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: ShadTooltip(
                          builder: (_) => Text(usage!),
                          child: Text(
                            '$used',
                            key: ValueKey<String>('slides.masters.usage.$id'),
                            style: theme.textTheme.muted.copyWith(fontSize: 11),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: ShadIconButton.ghost(
                        key: ValueKey<String>('slides.masters.more.$id'),
                        width: 22,
                        height: 22,
                        iconSize: 14,
                        padding: EdgeInsets.zero,
                        semanticLabel: l.themesMore(name),
                        icon: const Icon(LucideIcons.ellipsisVertical),
                        onPressed: () {
                          final box = key.currentContext?.findRenderObject();
                          final at = box is RenderBox
                              ? box.localToGlobal(
                                  Offset(box.size.width, box.size.height),
                                )
                              : Offset.zero;
                          _menu(id, layout: layout, global: at);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
