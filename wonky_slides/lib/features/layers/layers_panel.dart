import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../config/panels/slides_panels.dart';
import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../selection/reading_order.dart';
import '../toolbar/command_ui.dart';
import 'element_names.dart';
import 'layers_controller.dart';

/// The Layers side panel (`slides.panel.layers`, 03 §8.1).
SidePanelSpec layersPanelSpec(
  BuildContext context,
  ShellServices services,
  DeckEditorController editor,
) => SidePanelSpec(
  id: SlidesPanels.layers,
  title: slidesL10n(context).layersPanelTitle,
  icon: LucideIcons.layers,
  builder: (context) => LayersPanel(services: services, editor: editor),
);

/// Stable widget keys of the Layers panel.
abstract final class LayersPanelKeys {
  static const panel = ValueKey<String>('slides.layers.panel');
  static const list = ValueKey<String>('slides.layers.list');
  static const tabLayers = ValueKey<String>('slides.layers.tab.layers');
  static const tabReadingOrder = ValueKey<String>(
    'slides.layers.tab.readingOrder',
  );
  static const fromLayout = ValueKey<String>('slides.layers.fromLayout');
  static const editLayout = ValueKey<String>('slides.layers.editLayout');
  static const resetOrder = ValueKey<String>('slides.layers.resetOrder');
  static const renameField = ValueKey<String>('slides.layers.renameField');

  static ValueKey<String> row(String id) =>
      ValueKey<String>('slides.layers.row.$id');
  static ValueKey<String> name(String id) =>
      ValueKey<String>('slides.layers.name.$id');
  static ValueKey<String> hide(String id) =>
      ValueKey<String>('slides.layers.hide.$id');
  static ValueKey<String> lock(String id) =>
      ValueKey<String>('slides.layers.lock.$id');
  static ValueKey<String> chevron(String id) =>
      ValueKey<String>('slides.layers.chevron.$id');
  static ValueKey<String> layoutRow(String id) =>
      ValueKey<String>('slides.layers.layoutRow.$id');
  static ValueKey<String> orderRow(String id) =>
      ValueKey<String>('slides.layers.order.$id');
  static ValueKey<String> orderUp(String id) =>
      ValueKey<String>('slides.layers.order.$id.up');
  static ValueKey<String> orderDown(String id) =>
      ValueKey<String>('slides.layers.order.$id.down');
}

/// Where a dragged row lands relative to a target row.
enum _Zone { above, into, below }

/// One visible row of the layers tree.
class _Row {
  const _Row(this.rec, this.depth, this.parentId);

  final SlideElementRec rec;
  final int depth;
  final String? parentId;

  String get id => rec.id;
}

/// The Layers panel (03 §8.1): the elements of the current slide — or, in
/// masters mode, of the edited layout or master (SL-28) — as a tree, front
/// most at the top. Each row shows the kind icon and the name (double
/// click or Enter renames, `slides.element.rename`), an eye
/// (`slides.element.hide`/`show`) and a lock (`slides.element.lock`/
/// `unlock`). Clicking selects (Shift extends, Mod toggles; locked and
/// hidden elements too), synced with the canvas selection. Rows drag to
/// reorder (`slides.arrange.setZ`, into and out of element groups, one
/// step); Alt+Shift+↑/↓ move the selection a row. *From layout* lists the
/// layout and master elements read-only with *Edit layout*. The *Reading
/// order* tab lists the slide's elements as read (03 §17.2), reordered by
/// drag or the arrow buttons (`slides.a11y.setReadingOrder`), with *Reset
/// to automatic*.
class LayersPanel extends StatefulWidget {
  const LayersPanel({super.key, required this.services, required this.editor});

  final ShellServices services;
  final DeckEditorController editor;

  @override
  State<LayersPanel> createState() => _LayersPanelState();
}

class _LayersPanelState extends State<LayersPanel> {
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'slides.layers');
  final _rename = TextEditingController();
  final _renameFocus = FocusNode(debugLabel: 'slides.layers.rename');
  late final LayersController _layers = layersOf(widget.editor);
  String? _anchor;
  final Map<String, GlobalKey> _rowKeys = {};
  String? _lastTap;
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);
  (String, _Zone)? _drop;

  DeckEditorController get ed => widget.editor;

  @override
  void initState() {
    super.initState();
    _renameFocus.addListener(() {
      if (!_renameFocus.hasFocus && _layers.renaming != null) _commitRename();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    _rename.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  SlidesCommandUi _ui(BuildContext context) =>
      SlidesCommandUi(context, widget.services);

  void _run(String id, [Map<String, Object?> args = const {}]) =>
      _ui(context).run(id, args, InvocationSource.ui);

  /// The visible rows, front-most first.
  List<_Row> _rows(String owner) {
    final tree = ed.model.indexes.tree(owner);
    final out = <_Row>[];
    void walk(List<SlideElementRec> list, int depth, String? parent) {
      for (final e in list.reversed) {
        out.add(_Row(e, depth, parent));
        if (e.kind == ElementKind.group && !_layers.isCollapsed(e.id)) {
          walk(tree.childrenOf(e.id), depth + 1, e.id);
        }
      }
    }

    walk(tree.roots, 0, null);
    return out;
  }

  // ---------------------------------------------------------- selection

  void _click(_Row row, List<_Row> rows) {
    final keys = HardwareKeyboard.instance;
    final sel = ed.selectedElementIds;
    final siblings = [
      for (final r in rows)
        if (r.parentId == row.parentId) r.id,
    ];
    List<String> ids;
    if (keys.isShiftPressed && _anchor != null && siblings.contains(_anchor)) {
      final a = siblings.indexOf(_anchor!), b = siblings.indexOf(row.id);
      ids = siblings.sublist(a < b ? a : b, (a < b ? b : a) + 1);
    } else if (keys.isMetaPressed || keys.isControlPressed) {
      final same = sel.every(siblings.contains);
      ids = sel.contains(row.id)
          ? [
              for (final x in sel)
                if (x != row.id) x,
            ]
          : [if (same) ...sel, row.id];
      _anchor = row.id;
    } else {
      ids = [row.id];
      _anchor = row.id;
    }
    _run('slides.select.elements', {
      'ids': ids,
      'enteredGroupId': ?row.parentId,
    });
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, List<_Row> rows) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_layers.renaming != null || rows.isEmpty) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final sel = ed.selectedElementIds;
    final cur = sel.isEmpty ? -1 : rows.indexWhere((r) => r.id == sel.last);
    final k = event.logicalKey;
    final up = k == LogicalKeyboardKey.arrowUp;
    final down = k == LogicalKeyboardKey.arrowDown;
    if ((up || down) && keys.isAltPressed && keys.isShiftPressed) {
      _moveSelection(rows, up: up);
      return KeyEventResult.handled;
    }
    if (up || down) {
      final next = cur < 0
          ? (up ? rows.length - 1 : 0)
          : (cur + (up ? -1 : 1)).clamp(0, rows.length - 1);
      final row = rows[next];
      if (keys.isShiftPressed && _anchor != null) {
        _click(row, rows);
      } else {
        _anchor = row.id;
        _run('slides.select.elements', {
          'ids': [row.id],
          'enteredGroupId': ?row.parentId,
        });
      }
      return KeyEventResult.handled;
    }
    if (cur < 0) return KeyEventResult.ignored;
    final row = rows[cur];
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.f2) {
      _startRename(row.rec);
      return KeyEventResult.handled;
    }
    final isGroup = row.rec.kind == ElementKind.group;
    if (isGroup &&
        ((k == LogicalKeyboardKey.arrowLeft && !_layers.isCollapsed(row.id)) ||
            (k == LogicalKeyboardKey.arrowRight &&
                _layers.isCollapsed(row.id)))) {
      _layers.toggleCollapsed(row.id);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Alt+Shift+↑/↓: the selection one row up (in front of the sibling
  /// above) or down.
  void _moveSelection(List<_Row> rows, {required bool up}) {
    final sel = ed.selectedElementIds;
    if (sel.isEmpty) return;
    final first = rows.firstWhere((r) => r.id == sel.first);
    final siblings = [
      for (final r in rows)
        if (r.parentId == first.parentId && !sel.contains(r.id)) r.id,
    ];
    final idx = [
      for (final r in rows)
        if (r.parentId == first.parentId) r.id,
    ];
    final top = idx.indexWhere(sel.contains);
    final bottom = idx.lastIndexWhere(sel.contains);
    if (up) {
      // The visible sibling above the topmost selected row.
      final above = top > 0 ? idx[top - 1] : null;
      if (above == null || !siblings.contains(above)) return;
      _run('slides.arrange.setZ', {'ids': sel, 'aboveId': above});
    } else {
      final below = bottom < idx.length - 1 ? idx[bottom + 1] : null;
      if (below == null || !siblings.contains(below)) return;
      _run('slides.arrange.setZ', {'ids': sel, 'belowId': below});
    }
  }

  // ------------------------------------------------------------- rename

  void _startRename(SlideElementRec e) {
    if (!_ui(
      context,
    ).state('slides.element.rename', {'id': e.id, 'name': ''}).enabled) {
      return;
    }
    _rename.text = e.name ?? '';
    _rename.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _rename.text.length,
    );
    _layers.renaming = e.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _renameFocus.requestFocus();
    });
  }

  void _commitRename() {
    final id = _layers.renaming;
    if (id == null) return;
    _layers.renaming = null;
    final e = ed.model.element(id);
    if (e == null) return;
    final name = _rename.text.trim();
    if (name != (e.name ?? '')) {
      _run('slides.element.rename', {'id': id, 'name': name});
    }
    _focus.requestFocus();
  }

  void _cancelRename() {
    _layers.renaming = null;
    _focus.requestFocus();
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([ed, _layers, widget.services.registry]),
    builder: (context, _) {
      final l = slidesL10n(context);
      final theme = ShadTheme.of(context);
      final owner = ed.surfaceId;
      final body = owner == null
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l.navigatorEmpty, style: theme.textTheme.muted),
            )
          : _layers.tab == LayersTab.layers
          ? _layersTab(context, l, owner)
          : _readingOrderTab(context, l, owner);
      return Semantics(
        container: true,
        label: l.layersPanelTitle,
        child: KeyedSubtree(
          key: LayersPanelKeys.panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: _tabs(context, l),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    },
  );

  Widget _tabs(BuildContext context, SlidesLocalizations l) {
    Widget tab(LayersTab t, Key key, String label) {
      final on = _layers.tab == t;
      void select() => _run('slides.panel.layers', {'tab': t.name});
      return Expanded(
        child: Semantics(
          selected: on,
          child: on
              ? ShadButton.secondary(
                  key: key,
                  size: ShadButtonSize.sm,
                  onPressed: select,
                  child: Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              : ShadButton.ghost(
                  key: key,
                  size: ShadButtonSize.sm,
                  onPressed: select,
                  child: Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
        ),
      );
    }

    return Row(
      children: [
        tab(LayersTab.layers, LayersPanelKeys.tabLayers, l.layersTabLayers),
        const SizedBox(width: 4),
        tab(
          LayersTab.readingOrder,
          LayersPanelKeys.tabReadingOrder,
          l.layersTabReadingOrder,
        ),
      ],
    );
  }

  Widget _layersTab(BuildContext context, SlidesLocalizations l, String owner) {
    final theme = ShadTheme.of(context);
    final rows = _rows(owner);
    final children = <Widget>[
      if (rows.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            l.layersEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.muted,
          ),
        ),
      for (final r in rows) _row(context, l, r, rows),
      if (rows.isNotEmpty) _endTarget(owner),
      if (ed.surfaceKind == ElementOwnerKind.slide)
        ..._fromLayout(context, l, owner),
    ];
    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, event) => _onKey(node, event, rows),
      onFocusChange: (_) => setState(() {}),
      child: DecoratedBox(
        // The visible focus ring of the list (02 §6).
        decoration: BoxDecoration(
          border: Border.all(
            color: _focus.hasFocus
                ? theme.colorScheme.ring
                : const Color(0x00000000),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: WonkyScrollArea(
          controller: _scroll,
          child: ListView(
            key: LayersPanelKeys.list,
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            children: children,
          ),
        ),
      ),
    );
  }

  /// A drop target below the last row: the back of the top level.
  Widget _endTarget(String owner) => DragTarget<List<String>>(
    onWillAcceptWithDetails: (d) => d.data.isNotEmpty,
    onAcceptWithDetails: (d) {
      final roots = ed.model.indexes.tree(owner).roots;
      final back = roots.isEmpty ? null : roots.first.id;
      if (back == null || d.data.contains(back)) return;
      _run('slides.arrange.setZ', {'ids': d.data, 'belowId': back});
    },
    builder: (context, candidates, _) => SizedBox(
      height: 24,
      child: candidates.isEmpty
          ? null
          : Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 2,
                color: ShadTheme.of(context).colorScheme.ring,
              ),
            ),
    ),
  );

  Widget _row(
    BuildContext context,
    SlidesLocalizations l,
    _Row row,
    List<_Row> rows,
  ) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final e = row.rec;
    final selected = ed.selectedElementIds.contains(e.id);
    final isGroup = e.kind == ElementKind.group;
    final name = ElementNames.of(l, e);
    final ui = _ui(context);
    final drop = _drop?.$1 == e.id ? _drop!.$2 : null;
    final renaming = _layers.renaming == e.id;
    final dragIds = selected ? ed.selectedElementIds : [e.id];

    Widget toggle({
      required Key key,
      required IconData icon,
      required String label,
      required bool on,
      required String command,
      required bool active,
    }) => ShadTooltip(
      builder: (_) => Text(label),
      child: ShadIconButton.ghost(
        key: key,
        width: 24,
        height: 24,
        iconSize: 14,
        semanticLabel: label,
        enabled: on,
        icon: Icon(icon, color: active ? cs.foreground : cs.mutedForeground),
        onPressed: () => _run(command, {
          'ids': [e.id],
        }),
      ),
    );

    final hideCmd = e.hidden ? 'slides.element.show' : 'slides.element.hide';
    final lockCmd = e.locked ? 'slides.element.unlock' : 'slides.element.lock';
    final idArgs = {
      'ids': [e.id],
    };
    final content = Container(
      key: _rowKeys[e.id] ??= GlobalKey(),
      height: 30,
      decoration: BoxDecoration(
        color: selected ? cs.accent : null,
        borderRadius: BorderRadius.circular(4),
        border: drop == _Zone.into ? Border.all(color: cs.ring) : null,
      ),
      padding: EdgeInsets.only(left: 4 + 14.0 * row.depth, right: 2),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: isGroup
                ? GestureDetector(
                    key: LayersPanelKeys.chevron(e.id),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _layers.toggleCollapsed(e.id),
                    child: Icon(
                      _layers.isCollapsed(e.id)
                          ? LucideIcons.chevronRight
                          : LucideIcons.chevronDown,
                      size: 14,
                      color: cs.mutedForeground,
                    ),
                  )
                : null,
          ),
          Icon(ElementNames.icon(e), size: 14, color: cs.mutedForeground),
          const SizedBox(width: 6),
          Expanded(
            child: renaming
                ? _renameField(l)
                : Opacity(
                    opacity: e.hidden ? 0.5 : 1,
                    child: Text(
                      name,
                      key: LayersPanelKeys.name(e.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w400,
                        fontStyle: e.hidden ? FontStyle.italic : null,
                      ),
                    ),
                  ),
          ),
          toggle(
            key: LayersPanelKeys.hide(e.id),
            icon: e.hidden ? LucideIcons.eyeOff : LucideIcons.eye,
            label: e.hidden ? l.cmdElementShow : l.cmdElementHide,
            on: ui.state(hideCmd, idArgs).enabled,
            command: hideCmd,
            active: !e.hidden,
          ),
          toggle(
            key: LayersPanelKeys.lock(e.id),
            icon: e.locked ? LucideIcons.lock : LucideIcons.lockOpen,
            label: e.locked ? l.cmdElementUnlock : l.cmdElementLock,
            on: ui.state(lockCmd, idArgs).enabled,
            command: lockCmd,
            active: e.locked,
          ),
        ],
      ),
    );

    final line = Container(height: 2, color: cs.ring);
    final target = DragTarget<List<String>>(
      onWillAcceptWithDetails: (d) =>
          d.data.isNotEmpty && !d.data.contains(e.id),
      onMove: (d) {
        final box =
            _rowKeys[e.id]?.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final local = box.globalToLocal(d.offset);
        final h = 30.0;
        final y = local.dy.clamp(0, h);
        final zone = isGroup
            ? (y < h * 0.25
                  ? _Zone.above
                  : y > h * 0.75
                  ? _Zone.below
                  : _Zone.into)
            : (y < h / 2 ? _Zone.above : _Zone.below);
        if (_drop != (e.id, zone)) setState(() => _drop = (e.id, zone));
      },
      onLeave: (_) {
        if (_drop?.$1 == e.id) setState(() => _drop = null);
      },
      onAcceptWithDetails: (d) {
        final zone = _drop?.$1 == e.id ? _drop!.$2 : _Zone.above;
        setState(() => _drop = null);
        _run('slides.arrange.setZ', {
          'ids': d.data,
          switch (zone) {
            _Zone.above => 'aboveId',
            _Zone.below => 'belowId',
            _Zone.into => 'groupId',
          }: e.id,
        });
      },
      builder: (context, _, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (drop == _Zone.above) line else const SizedBox(height: 2),
          content,
          if (drop == _Zone.below) line else const SizedBox(height: 2),
        ],
      ),
    );

    final canDrag = ui.state('slides.arrange.setZ', {'ids': dragIds}).enabled;
    return Semantics(
      key: LayersPanelKeys.row(e.id),
      button: true,
      selected: selected,
      label: [
        name,
        if (e.hidden) l.layersHidden,
        if (e.locked) l.layersLocked,
      ].join(', '),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // A second click within the double-tap time renames (no
        // double-tap recognizer: single clicks select at once).
        onTap: () {
          final now = clock.now();
          final again =
              _lastTap == e.id &&
              now.difference(_lastTapAt) < kDoubleTapTimeout;
          _lastTap = e.id;
          _lastTapAt = now;
          if (again) {
            _startRename(e);
          } else {
            _click(row, rows);
          }
        },
        child: !canDrag || renaming
            ? target
            : Draggable<List<String>>(
                data: dragIds,
                axis: Axis.vertical,
                affinity: Axis.vertical,
                // The drop zones follow the pointer (not the feedback's
                // top-left).
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: _dragFeedback(context, name, dragIds.length),
                childWhenDragging: Opacity(opacity: 0.4, child: target),
                onDragEnd: (_) {
                  if (_drop != null) setState(() => _drop = null);
                },
                child: target,
              ),
      ),
    );
  }

  Widget _dragFeedback(BuildContext context, String name, int count) {
    final theme = ShadTheme.of(context);
    return IgnorePointer(
      child: Transform.translate(
        offset: const Offset(12, -14),
        child: _feedbackBox(theme, name, count, context),
      ),
    );
  }

  Widget _feedbackBox(
    ShadThemeData theme,
    String name,
    int count,
    BuildContext context,
  ) {
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.popover,
          border: Border.all(color: theme.colorScheme.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: DefaultTextStyle(
          style: theme.textTheme.small,
          child: Text(
            count > 1 ? slidesL10n(context).layersDragMany(count) : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _renameField(SlidesLocalizations l) => Focus(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        _cancelRename();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: ShadInput(
      key: LayersPanelKeys.renameField,
      controller: _rename,
      focusNode: _renameFocus,
      placeholder: Text(l.layersRenameHint),
      onSubmitted: (_) => _commitRename(),
    ),
  );

  List<Widget> _fromLayout(
    BuildContext context,
    SlidesLocalizations l,
    String slideId,
  ) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final resolved = ed.resolver.resolve(slideId);
    if (resolved == null) return const [];
    final inherited = [
      ...resolved.layoutElements.reversed,
      ...resolved.masterElements.reversed,
    ];
    final layoutId = resolved.layout?.id;
    final open = _layers.layoutOpen;
    return [
      const SizedBox(height: 8),
      Container(height: 1, color: cs.border),
      const SizedBox(height: 4),
      Semantics(
        button: true,
        expanded: open,
        child: GestureDetector(
          key: LayersPanelKeys.fromLayout,
          behavior: HitTestBehavior.opaque,
          onTap: () => _layers.layoutOpen = !open,
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                Icon(
                  open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 14,
                  color: cs.mutedForeground,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l.layersFromLayout(inherited.length),
                    style: theme.textTheme.small,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (open) ...[
        for (final e in inherited)
          Padding(
            key: LayersPanelKeys.layoutRow(e.id),
            padding: const EdgeInsets.only(left: 22),
            child: SizedBox(
              height: 26,
              child: Row(
                children: [
                  Icon(
                    ElementNames.icon(e.record),
                    size: 14,
                    color: cs.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ElementNames.of(l, e.record),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (layoutId != null &&
            _ui(context).state('slides.view.setMode', {
              'mode': 'masters',
              'layoutId': layoutId,
            }).enabled)
          Align(
            alignment: Alignment.centerLeft,
            child: ShadButton.link(
              key: LayersPanelKeys.editLayout,
              size: ShadButtonSize.sm,
              onPressed: () => _run('slides.view.setMode', {
                'mode': 'masters',
                'layoutId': layoutId,
              }),
              child: Text(l.layersEditLayout),
            ),
          ),
      ],
    ];
  }

  // ------------------------------------------------------ reading order

  Widget _readingOrderTab(
    BuildContext context,
    SlidesLocalizations l,
    String owner,
  ) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final ui = _ui(context);
    final slide = ed.resolver.resolve(owner);
    final order = slide == null
        ? const <ResolvedElement>[]
        : ReadingOrder.of(
            slide.elements,
            slideHeight: slide.bounds.height,
            includeDecorative: false,
          );
    final ids = [for (final e in order) e.id];
    final custom = slide?.elements.any((e) => e.record.readingKey != null);
    final canEdit = ui.state('slides.a11y.setReadingOrder', {
      'ids': ids,
    }).enabled;

    void move(int from, int to) {
      if (from == to || to < 0 || to >= ids.length) return;
      final next = [...ids];
      final id = next.removeAt(from);
      next.insert(to, id);
      _run('slides.a11y.setReadingOrder', {'ids': next});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(
            custom ?? false ? l.layersOrderCustom : l.layersOrderAutomatic,
            style: theme.textTheme.muted,
          ),
        ),
        Expanded(
          child: ids.isEmpty
              ? Text(
                  l.layersEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.muted,
                )
              : ReorderableList(
                  itemCount: order.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onReorderItem: (from, to) => move(from, to),
                  itemBuilder: (context, i) {
                    final e = order[i];
                    final name = ElementNames.of(l, e.record);
                    return Semantics(
                      key: LayersPanelKeys.orderRow(e.id),
                      label: l.accessibilityReadingOrder(i + 1, ids.length),
                      value: name,
                      child: Container(
                        height: 32,
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: ed.selectedElementIds.contains(e.id)
                              ? cs.accent
                              : null,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            if (canEdit)
                              ReorderableDragStartListener(
                                index: i,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      LucideIcons.gripVertical,
                                      size: 14,
                                      color: cs.mutedForeground,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 22),
                            SizedBox(
                              width: 22,
                              child: Text(
                                '${i + 1}',
                                style: theme.textTheme.muted,
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _run('slides.select.elements', {
                                  'ids': [e.id],
                                }),
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.small.copyWith(
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                            ShadIconButton.ghost(
                              key: LayersPanelKeys.orderUp(e.id),
                              width: 24,
                              height: 24,
                              iconSize: 14,
                              semanticLabel: l.layersOrderEarlier,
                              enabled: canEdit && i > 0,
                              icon: const Icon(LucideIcons.arrowUp),
                              onPressed: () => move(i, i - 1),
                            ),
                            ShadIconButton.ghost(
                              key: LayersPanelKeys.orderDown(e.id),
                              width: 24,
                              height: 24,
                              iconSize: 14,
                              semanticLabel: l.layersOrderLater,
                              enabled: canEdit && i < ids.length - 1,
                              icon: const Icon(LucideIcons.arrowDown),
                              onPressed: () => move(i, i + 1),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ShadButton.outline(
              key: LayersPanelKeys.resetOrder,
              size: ShadButtonSize.sm,
              enabled: ui.state('slides.a11y.resetReadingOrder').enabled,
              onPressed: () => _run('slides.a11y.resetReadingOrder'),
              child: Text(l.cmdA11yResetReadingOrder),
            ),
          ),
        ),
      ],
    );
  }
}
