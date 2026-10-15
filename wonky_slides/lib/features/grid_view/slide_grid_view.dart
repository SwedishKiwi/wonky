import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../collab/presence_widgets.dart' show SlidePresenceDots;
import '../../commands/navigator_commands.dart' show navMoveTo;
import '../../commands/slides_command.dart' show SlidesKeyScopes;
import '../../config/menus/context_menu_specs.dart';
import '../../l10n/slides_l10n.dart';
import '../../theme/slides_tokens.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../editor_screen/slide_labels.dart';
import '../navigator/deck_renderer.dart';
import '../navigator/nav_thumbnail.dart';
import '../navigator/navigator_controller.dart';
import '../navigator/navigator_model.dart';
import '../navigator/slide_navigator.dart'
    show DashedBorderBox, OpenContextMenu;
import '../stage/slide_renderer.dart';
import 'grid_layout.dart';

/// The grid view — the light table (Slides 04 §9): a responsive grid of
/// thumbnails (size slider 120–480 px, device pref) with groups as section
/// headers (chevron, color, title, count, ⋮) sharing the navigator's
/// collapse state, selection model, keyboard (arrows move in 2D, ⌘ arrows
/// move slides, Enter / double-click opens the slide in Normal view),
/// drag and drop (a vertical bar between thumbnails; a section header
/// appends to its group; groups drag as sections), context menus and
/// commands. Skipped slides are dimmed; numbers sit under the thumbnails.
class SlideGridView extends StatefulWidget {
  const SlideGridView({
    super.key,
    required this.services,
    required this.editor,
    required this.onContextMenu,
  });

  final ShellServices services;
  final DeckEditorController editor;
  final OpenContextMenu onContextMenu;

  @override
  State<SlideGridView> createState() => _SlideGridViewState();
}

class _SlideGridViewState extends State<SlideGridView> {
  final _scroll = ScrollController();
  final _areaKey = GlobalKey();
  late SlideRenderer _renderer;
  late NavigatorController _nav;
  late final ShadSliderController _size;
  GridLayout? _layout;
  GridDrop? _drop;
  Offset? _downGlobal;
  GridItem? _downItem;
  bool _suppressTap = false;
  bool _dragCancelled = false;
  Offset _pointerLocal = Offset.zero;
  String? _lastTapKey;
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);

  DeckEditorController get ed => widget.editor;

  @override
  void initState() {
    super.initState();
    _nav = navigatorOf(ed);
    _renderer = DeckThumbnails.acquire(ed);
    _size = ShadSliderController(initialValue: _nav.gridThumbSize);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ed.navigatorFocus.hasFocus) {
        ed.navigatorFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    if (_nav.drag != null) _nav.endDrag();
    DeckThumbnails.release(ed, _renderer);
    _size.dispose();
    _scroll.dispose();
    super.dispose();
  }

  double get _aspect {
    final s = _renderer.slideSize;
    return s.width <= 0 ? 9 / 16 : s.height / s.width;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SlidesTokens.of(context);
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: KeymapScope(
        scope: SlidesKeyScopes.navigator,
        keymap: widget.services.keymap,
        focusNode: ed.navigatorFocus,
        child: ColoredBox(
          key: const ValueKey<String>('slides.view.grid'),
          color: tokens.canvasSurround,
          child: ListenableBuilder(
            listenable: _nav,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topBar(context, l, theme),
                Container(height: 1, color: theme.colorScheme.border),
                Expanded(
                  child: ed.order.length == 0 && ed.order.groups.isEmpty
                      ? Center(
                          child: Text(
                            l.navigatorEmpty,
                            style: theme.textTheme.muted,
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, c) => _grid(context, c),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(
    BuildContext context,
    SlidesLocalizations l,
    ShadThemeData theme,
  ) => ColoredBox(
    color: theme.colorScheme.background,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: LayoutBuilder(
        builder: (context, c) {
          final roomy = c.maxWidth >= 520;
          return Row(
            children: [
              if (roomy)
                Expanded(
                  child: Text(
                    l.gridOpenHint,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  l.gridThumbSize,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: roomy ? 140 : 110,
                child: ShadSlider(
                  key: const ValueKey<String>('slides.grid.size'),
                  controller: _size,
                  min: 120,
                  max: 480,
                  semanticFormatterCallback: (x) => '${x.round()} px',
                  onChanged: (v) => _nav.setGridThumbSize(v, commit: false),
                  onChangeEnd: (v) => _nav.setGridThumbSize(v),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _grid(BuildContext context, BoxConstraints c) {
    final layout = GridLayout.of(
      _nav.rows,
      width: c.maxWidth,
      // Never wider than the view (a 480 px tile in a 360 px window).
      tileWidth: _nav.gridThumbSize.clamp(
        80.0,
        math.max(80.0, c.maxWidth - 48),
      ),
      aspect: _aspect,
    );
    _layout = layout;
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) => _cancelDrag(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (d) {
          final local = _local(d.globalPosition);
          if (local == null) return;
          final item = layout.itemAt(local.dx, local.dy + _offset);
          if (item == null) {
            widget.onContextMenu(
              SlidesContextMenuIds.navigatorEmpty,
              d.globalPosition,
            );
          }
        },
        child: KeyedSubtree(
          key: _areaKey,
          child: WonkyScrollArea(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              child: SizedBox(
                height: layout.height,
                width: c.maxWidth,
                child: ListenableBuilder(
                  listenable: _scroll,
                  builder: (context, _) =>
                      _visible(context, layout, c.maxHeight),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double get _offset => _scroll.hasClients ? _scroll.offset : 0;

  Offset? _local(Offset global) {
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  /// Only the items near the viewport are built (virtualized).
  Widget _visible(BuildContext context, GridLayout layout, double viewport) {
    final top = _offset - 300;
    final bottom = _offset + viewport + 300;
    final theme = ShadTheme.of(context);
    final children = <Widget>[
      for (final i in layout.items)
        if (i.rect.bottom >= top && i.rect.top <= bottom)
          Positioned.fromRect(rect: i.rect, child: _item(context, i)),
    ];
    final drop = _drop;
    if (_nav.drag != null && drop != null && drop.barX != null) {
      children.add(
        Positioned(
          key: const ValueKey<String>('slides.grid.dropIndicator'),
          left: drop.barX! - 1,
          top: drop.barTop,
          width: 2,
          height: drop.barBottom - drop.barTop,
          child: ColoredBox(
            color: drop.refused
                ? theme.colorScheme.destructive
                : theme.colorScheme.primary,
          ),
        ),
      );
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  Widget _item(BuildContext context, GridItem i) => switch (i.row.kind) {
    NavRowKind.group => _header(context, i.row),
    NavRowKind.emptyGroup => _emptyZone(context, i.row),
    NavRowKind.slide => _tile(context, i.row),
  };

  bool _mod() {
    final k = HardwareKeyboard.instance;
    return k.isMetaPressed || k.isControlPressed;
  }

  Set<String> get _dragged {
    final d = _nav.drag;
    if (d == null) return const {};
    return {...d.selection.groupIds, ...d.selection.allSlideIds(ed.order)};
  }

  Widget _tile(BuildContext context, NavRow r) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final e = r.entry!;
    final current = e.id == ed.currentSlideId;
    final selected = !current && ed.selectedSlideIds.contains(e.id);
    final focused = _nav.focusKey == r.key && ed.navigatorFocus.hasFocus;
    final group = r.groupId == null ? null : ed.model.group(r.groupId!);
    return Semantics(
      selected: current || selected,
      button: true,
      label: l.navigatorSlideSemantics(
        e.index + 1,
        ed.order.length,
        SlideLabels.title(ed.model, e.id).isEmpty
            ? l.slideUntitled
            : SlideLabels.title(ed.model, e.id),
      ),
      child: GestureDetector(
        key: ValueKey<String>('slides.grid.slide.${e.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_suppressTap) return;
          final key = r.key;
          final now = DateTime.now();
          final dbl =
              _lastTapKey == key &&
              now.difference(_lastTapAt).inMilliseconds < 400;
          _lastTapKey = key;
          _lastTapAt = now;
          if (dbl && !_mod()) {
            _open(e.id);
            return;
          }
          _nav.clickSlide(
            e.id,
            range: HardwareKeyboard.instance.isShiftPressed,
            toggle: _mod(),
          );
        },
        onSecondaryTapUp: (d) {
          if (!ed.selectedSlideIds.contains(e.id)) _nav.clickSlide(e.id);
          widget.onContextMenu(
            SlidesContextMenuIds.navigatorSlide,
            d.globalPosition,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: focused
                    ? Border.all(
                        color: theme.colorScheme.ring.withValues(alpha: 0.6),
                      )
                    : null,
              ),
              child: NavThumbnail(
                renderer: _renderer,
                slideId: e.id,
                width: _layout?.tileWidth ?? _nav.gridThumbSize,
                current: current,
                selected: selected,
                skipped: e.skipped,
                skippedWithGroup: group?.skipped ?? false,
                dimmed: _dragged.contains(e.id),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${e.index + 1}',
                  style: theme.textTheme.muted.copyWith(
                    fontSize: 12,
                    decoration: e.skipped ? TextDecoration.lineThrough : null,
                  ),
                ),
                // Collaborators on this slide (SL-21, 09 §1.2).
                SlidePresenceDots(editor: ed, slideId: e.id),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, NavRow r) {
    final theme = ShadTheme.of(context);
    final tokens = SlidesTokens.of(context);
    final l = slidesL10n(context);
    final g = ed.model.group(r.id);
    if (g == null) return const SizedBox.shrink();
    final title = g.title.isEmpty ? l.groupUntitled : g.title;
    final selected = ed.selectedGroupIds.contains(g.id);
    final focused = _nav.focusKey == r.key && ed.navigatorFocus.hasFocus;
    final highlight = _drop?.highlightGroupId == g.id && _nav.drag != null;
    final count = r.range?.length ?? 0;
    return Semantics(
      selected: selected,
      expanded: !r.collapsed,
      button: true,
      label: l.navigatorGroupSemantics(title, count),
      child: GestureDetector(
        key: ValueKey<String>('slides.grid.group.${g.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_suppressTap) return;
          _nav.clickGroup(
            g.id,
            range: HardwareKeyboard.instance.isShiftPressed,
            toggle: _mod(),
          );
        },
        onSecondaryTapUp: (d) {
          if (!selected) _nav.clickGroup(g.id);
          widget.onContextMenu(
            SlidesContextMenuIds.navigatorGroup,
            d.globalPosition,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: highlight
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : selected
                ? tokens.thumbnailSelection.withValues(alpha: 0.18)
                : null,
            borderRadius: BorderRadius.circular(6),
            border: highlight
                ? Border.all(color: theme.colorScheme.primary)
                : focused
                ? Border.all(
                    color: theme.colorScheme.ring.withValues(alpha: 0.6),
                  )
                : null,
          ),
          child: Opacity(
            opacity: _dragged.contains(g.id) ? 0.45 : 1,
            child: Row(
              children: [
                GestureDetector(
                  key: ValueKey<String>('slides.grid.group.${g.id}.chevron'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.services.dispatcher.invoke(
                    HardwareKeyboard.instance.isAltPressed
                        ? (r.collapsed
                              ? 'slides.group.expandAll'
                              : 'slides.group.collapseAll')
                        : 'slides.group.toggleCollapsed',
                    args: HardwareKeyboard.instance.isAltPressed
                        ? const {}
                        : {
                            'groupIds': [g.id],
                          },
                    source: InvocationSource.ui,
                  ),
                  child: SizedBox(
                    width: 24,
                    height: 32,
                    child: Icon(
                      r.collapsed
                          ? LucideIcons.chevronRight
                          : LucideIcons.chevronDown,
                      size: 16,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        tokens.groupColor(g.color) ??
                        theme.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.large.copyWith(fontSize: 16),
                  ),
                ),
                if (g.skipped)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      LucideIcons.eyeOff,
                      size: 14,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                const SizedBox(width: 8),
                Text('$count', style: theme.textTheme.muted),
                const Spacer(),
                GestureDetector(
                  key: ValueKey<String>('slides.grid.group.${g.id}.menu'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    if (!selected) _nav.clickGroup(g.id);
                    widget.onContextMenu(
                      SlidesContextMenuIds.navigatorGroup,
                      d.globalPosition,
                    );
                  },
                  child: SizedBox(
                    width: 28,
                    height: 32,
                    child: Icon(
                      LucideIcons.ellipsisVertical,
                      size: 16,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyZone(BuildContext context, NavRow r) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final highlight = _drop?.highlightGroupId == r.id && _nav.drag != null;
    return DashedBorderBox(
      color: highlight
          ? theme.colorScheme.primary
          : theme.colorScheme.mutedForeground,
      child: Center(
        child: Text(l.navigatorDropHere, style: theme.textTheme.muted),
      ),
    );
  }

  /// Opens [slideId] in Normal view (double-click / Enter, 04 §9).
  void _open(String slideId) {
    ed.setCurrentSlide(slideId);
    widget.services.dispatcher.invoke(
      'slides.view.setMode',
      args: const {'mode': 'normal'},
      source: InvocationSource.ui,
    );
  }

  // ------------------------------------------------------------- drag

  void _onPointerDown(PointerDownEvent e) {
    _suppressTap = false;
    _dragCancelled = false;
    ed.navigatorFocus.requestFocus();
    if (e.buttons != kPrimaryButton) return;
    final layout = _layout;
    if (layout == null) return;
    _downGlobal = e.position;
    _downItem = layout.itemAt(e.localPosition.dx, e.localPosition.dy + _offset);
  }

  void _onPointerMove(PointerMoveEvent e) {
    final down = _downGlobal;
    final layout = _layout;
    if (down == null || layout == null || _dragCancelled) return;
    _pointerLocal = e.localPosition;
    if (_nav.drag == null) {
      if ((e.position - down).distance < 4) return;
      final item = _downItem;
      if (item == null ||
          item.row.kind == NavRowKind.emptyGroup ||
          !ed.canEdit) {
        return;
      }
      final row = item.row;
      if (row.isSlide && !ed.selectedSlideIds.contains(row.id)) {
        _nav.clickSlide(row.id);
      } else if (row.isGroup && !ed.selectedGroupIds.contains(row.id)) {
        _nav.clickGroup(row.id);
      }
      final sel = _nav.selection;
      _suppressTap = true;
      _nav.startDrag(
        NavDragState(
          selection: sel,
          pointer: e.position,
          firstSlideId: sel.allSlideIds(ed.order).firstOrNull,
        ),
      );
    }
    _updateDrop();
  }

  void _updateDrop() {
    final layout = _layout;
    final drag = _nav.drag;
    if (layout == null || drag == null) return;
    final drop = resolveGridDrop(
      layout,
      _pointerLocal.dx,
      _pointerLocal.dy + _offset,
      draggingGroups: drag.selection.hasGroups,
    );
    setState(() => _drop = drop);
    _nav.updateDrag(copy: HardwareKeyboard.instance.isAltPressed);
  }

  void _onPointerUp(PointerUpEvent e) {
    _downGlobal = null;
    _downItem = null;
    final drag = _nav.endDrag();
    final drop = _drop;
    _drop = null;
    if (drag == null || _dragCancelled) return;
    setState(() {});
    if (drop == null || drop.refused) return;
    final sel = drag.selection;
    unawaited(
      widget.services.dispatcher.invoke(
        'slides.slide.move',
        args: {
          'slideIds': sel.slideIds,
          'groupIds': sel.groupIds,
          'to': navMoveTo(drop.target),
          if (drag.copy) 'copy': true,
        },
        source: InvocationSource.ui,
      ),
    );
  }

  void _cancelDrag() {
    _dragCancelled = true;
    _nav.endDrag();
    setState(() => _drop = null);
  }

  // ----------------------------------------------------------- keyboard

  bool _inTextField() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_inTextField()) return KeyEventResult.ignored;
    final k = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && _nav.drag != null) {
      _cancelDrag();
      return KeyEventResult.handled;
    }
    if (k.isMetaPressed || k.isControlPressed || k.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final layout = _layout;
    if (layout == null) return KeyEventResult.ignored;
    final shift = k.isShiftPressed;
    final focus = layout.items
        .where((i) => i.row.key == _nav.focusKey)
        .firstOrNull;
    if (key == LogicalKeyboardKey.arrowRight) {
      _nav.moveFocus(1, extend: shift);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _nav.moveFocus(-1, extend: shift);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final from = focus ?? layout.items.firstOrNull;
      if (from == null) return KeyEventResult.ignored;
      final to = layout.vertical(
        from,
        down: key == LogicalKeyboardKey.arrowDown,
      );
      if (to == null) return KeyEventResult.handled;
      _nav.focusRow(to.row, extend: shift);
    } else if (key == LogicalKeyboardKey.home) {
      _nav.focusEdge(last: false, extend: shift);
    } else if (key == LogicalKeyboardKey.end) {
      _nav.focusEdge(last: true, extend: shift);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final row = focus?.row;
      if (row == null) return KeyEventResult.ignored;
      if (row.isGroup) {
        _nav.toggleCollapsed(row.id);
      } else if (row.isSlide) {
        _open(row.id);
      }
    } else {
      return KeyEventResult.ignored;
    }
    _reveal();
    return KeyEventResult.handled;
  }

  void _reveal() {
    final layout = _layout;
    if (layout == null || !_scroll.hasClients) return;
    final item = layout.items
        .where((i) => i.row.key == _nav.focusKey)
        .firstOrNull;
    if (item == null) return;
    final p = _scroll.position;
    if (item.rect.top - 24 < p.pixels) {
      p.jumpTo((item.rect.top - 24).clamp(0, p.maxScrollExtent));
    } else if (item.rect.bottom + 24 > p.pixels + p.viewportDimension) {
      p.jumpTo(
        (item.rect.bottom + 24 - p.viewportDimension).clamp(
          0,
          p.maxScrollExtent,
        ),
      );
    }
  }
}
