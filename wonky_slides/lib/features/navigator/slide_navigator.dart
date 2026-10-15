import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../collab/presence_widgets.dart'
    show SlidePresenceDots, StructureShimmer;
import '../comments/comment_badge.dart';
import '../../commands/navigator_commands.dart' show navMoveTo;
import '../../commands/slides_command.dart' show SlidesKeyScopes;
import '../../config/menus/context_menu_specs.dart';
import '../../config/slides_features.dart';
import '../../config/menus/slides_menu_spec.dart'
    show groupColorLabel, slideGroupColors;
import '../../l10n/slides_l10n.dart';
import '../../theme/slides_tokens.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../editor_screen/slide_labels.dart';
import '../stage/slide_renderer.dart';
import '../toolbar/command_ui.dart';
import 'deck_renderer.dart';
import 'nav_thumbnail.dart';
import 'navigator_controller.dart';
import 'navigator_drop.dart';
import 'navigator_model.dart';

/// Opens a context menu at a global position (`context.<id>`, 04 §11).
typedef OpenContextMenu = void Function(String menuId, Offset global);

/// The slide navigator (Slides 04 §5, decision D11): a virtualized list of
/// group headers (chevron, color dot, title, count, skip badge, stacked
/// preview when collapsed) and slide rows (group color bar, indent, number,
/// thumbnail with current/selected rings, skipped dimming), with
///
/// - selection by click, Shift (range in visible order) and Mod (toggle);
///   a header selects its group (04 §5.5);
/// - inline rename (double-click / F2), the color menu, collapse per user
///   and device (Alt+click: all groups);
/// - drag and drop of the whole selection after 4 px with live drop
///   indicators (indented inside a group, the x rule below a group's last
///   slide, header append, red when groups would nest), Alt copies,
///   auto-scroll near the edges, Esc cancels — nothing is written before
///   the drop, which is one undo step (04 §5.10);
/// - the insertion caret (a click between rows, 04 §5.8);
/// - the keyboard of 04 §5.9 in the `slidesNavigator` scope;
/// - *+ New slide* with the layout chevron, empty states (04 §5.11) and
///   the navigator context menus (04 §11.5–§11.7).
class SlideNavigator extends StatefulWidget {
  const SlideNavigator({
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
  State<SlideNavigator> createState() => _SlideNavigatorState();
}

class _SlideNavigatorState extends State<SlideNavigator> {
  final _scroll = ScrollController();
  final _listKey = GlobalKey();
  late SlideRenderer _renderer;
  late NavigatorController _nav;

  // Pointer / drag tracking (04 §5.10).
  Offset? _downGlobal;
  NavRow? _downRow;
  bool _dragCancelled = false;
  bool _suppressTap = false;
  Timer? _autoScroll;
  double _autoScrollSpeed = 0;
  Offset _lastLocal = Offset.zero;

  // Double-click on a header title (rename) without delaying single taps.
  String? _lastTapKey;
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);

  String? _hoverKey;

  static const _padTop = 6.0;
  static const _headerHeight = 34.0;
  static const _emptyHeight = 46.0;
  static const _indentX = 24.0;

  DeckEditorController get ed => widget.editor;

  @override
  void initState() {
    super.initState();
    _nav = navigatorOf(ed);
    _renderer = DeckThumbnails.acquire(ed);
  }

  @override
  void didUpdateWidget(SlideNavigator old) {
    super.didUpdateWidget(old);
    if (!identical(old.editor, widget.editor)) {
      DeckThumbnails.release(old.editor, _renderer);
      _nav = navigatorOf(ed);
      _renderer = DeckThumbnails.acquire(ed);
    }
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    if (_nav.drag != null) _nav.endDrag();
    DeckThumbnails.release(ed, _renderer);
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- layout

  bool get _compact => widget.width < 170;

  /// Thumbnail width = navigator width − 56 px (04 §5.1); compact (140 px,
  /// 04 §16) shows the number inside the thumbnail.
  double get _thumbWidth => math.max(48, widget.width - (_compact ? 28 : 56));

  double get _aspect {
    final s = _renderer.slideSize;
    return s.width <= 0 ? 9 / 16 : s.height / s.width;
  }

  double get _slideHeight => _thumbWidth * _aspect + 10;

  double get _collapsedHeight => _headerHeight + 64 * _aspect + 14;

  double _heightOf(NavRow r) => switch (r.kind) {
    NavRowKind.group =>
      r.collapsed && (r.range?.length ?? 0) > 0
          ? _collapsedHeight
          : _headerHeight,
    NavRowKind.emptyGroup => _emptyHeight,
    NavRowKind.slide => _slideHeight,
  };

  List<NavRowBox> _boxes(List<NavRow> rows) {
    final out = <NavRowBox>[];
    var y = _padTop;
    for (final r in rows) {
      final h = _heightOf(r);
      out.add((row: r, top: y, height: h));
      y += h;
    }
    return out;
  }

  /// The content y of a local y in the list viewport.
  double _contentY(double localY) =>
      localY + (_scroll.hasClients ? _scroll.offset : 0);

  NavRowBox? _boxAt(List<NavRowBox> boxes, double contentY) {
    for (final b in boxes) {
      if (contentY >= b.top && contentY < b.top + b.height) return b;
    }
    return null;
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_nav, widget.services.registry]),
    builder: (context, _) {
      final l = slidesL10n(context);
      final theme = ShadTheme.of(context);
      final tokens = SlidesTokens.of(context);
      final ui = SlidesCommandUi(context, widget.services);
      final rows = _nav.rows;
      return Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: KeymapScope(
          scope: SlidesKeyScopes.navigator,
          keymap: widget.services.keymap,
          focusNode: ed.navigatorFocus,
          child: Semantics(
            container: true,
            label: l.navigatorLabel,
            child: ColoredBox(
              key: const ValueKey<String>('slides.navigator'),
              color: tokens.navigatorBackground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: rows.isEmpty
                        ? _emptyDeck(context, l, theme)
                        : _list(context, rows),
                  ),
                  Container(height: 1, color: theme.colorScheme.border),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: _footer(context, ui),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _emptyDeck(
    BuildContext context,
    SlidesLocalizations l,
    ShadThemeData theme,
  ) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: ed.navigatorFocus.requestFocus,
    onSecondaryTapUp: (d) => widget.onContextMenu(
      SlidesContextMenuIds.navigatorEmpty,
      d.globalPosition,
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Text(
            l.navigatorEmpty,
            key: const ValueKey<String>('slides.navigator.empty'),
            style: theme.textTheme.muted,
          ),
          // *Generate with AI* (Slides 11 §6.4; SL-43).
          if (SlidesFeatures.isOn(SlidesFeature.assistant) &&
              widget.services.dispatcher
                  .stateOf('slides.ai.generateDeck')
                  .enabled)
            ShadButton.ghost(
              key: const ValueKey<String>('slides.navigator.generate'),
              size: ShadButtonSize.sm,
              leading: const Icon(LucideIcons.sparkles, size: 14),
              onPressed: () => unawaited(
                widget.services.dispatcher.invoke(
                  'slides.ai.generateDeck',
                  source: InvocationSource.ui,
                  context: context,
                ),
              ),
              child: Text(l.cmdAiGenerateDeck),
            ),
        ],
      ),
    ),
  );

  Widget _list(BuildContext context, List<NavRow> rows) {
    final boxes = _boxes(rows);
    final contentHeight = boxes.isEmpty
        ? 0.0
        : boxes.last.top + boxes.last.height;
    return LayoutBuilder(
      builder: (context, c) => Listener(
        onPointerDown: (e) => _onPointerDown(e, boxes),
        onPointerMove: (e) => _onPointerMove(e, c.maxHeight),
        onPointerUp: (e) => _onPointerUp(e, boxes),
        onPointerCancel: (_) => _cancelDrag(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            // A click below the rows clears to the current slide.
            if (_suppressTap) return;
            final y = _contentY(_lastLocal.dy);
            if (y > contentHeight) _nav.clickEmpty();
          },
          onSecondaryTapUp: (d) {
            final local = _localOf(d.globalPosition);
            if (local != null && _contentY(local.dy) > contentHeight) {
              widget.onContextMenu(
                SlidesContextMenuIds.navigatorEmpty,
                d.globalPosition,
              );
            }
          },
          child: Stack(
            key: _listKey,
            children: [
              Positioned.fill(
                child: WonkyScrollArea(
                  controller: _scroll,
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(top: _padTop, bottom: 24),
                    itemCount: rows.length,
                    itemExtentBuilder: (i, _) =>
                        i < rows.length ? _heightOf(rows[i]) : null,
                    itemBuilder: (context, i) => _row(context, rows[i]),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ListenableBuilder(
                    listenable: _scroll,
                    builder: (context, _) => _indicators(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Offset? _localOf(Offset global) {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  // ------------------------------------------------------------------ rows

  Widget _row(BuildContext context, NavRow r) => switch (r.kind) {
    NavRowKind.group => _groupRow(context, r),
    NavRowKind.emptyGroup => _emptyGroupRow(context, r),
    NavRowKind.slide => _slideRow(context, r),
  };

  bool _modPressed() {
    final k = HardwareKeyboard.instance;
    return k.isMetaPressed || k.isControlPressed;
  }

  bool get _dragging => _nav.drag != null;

  Set<String> get _draggedIds {
    final d = _nav.drag;
    if (d == null) return const {};
    return {...d.selection.groupIds, ...d.selection.allSlideIds(ed.order)};
  }

  Widget _slideRow(BuildContext context, NavRow r) {
    final theme = ShadTheme.of(context);
    final tokens = SlidesTokens.of(context);
    final l = slidesL10n(context);
    final e = r.entry!;
    final current = e.id == ed.currentSlideId;
    final selected = !current && ed.selectedSlideIds.contains(e.id);
    final focused = _nav.focusKey == r.key && ed.navigatorFocus.hasFocus;
    final group = r.groupId == null ? null : ed.model.group(r.groupId!);
    final groupColor = group == null
        ? null
        : tokens.groupColor(group.color) ?? theme.colorScheme.border;
    final title = SlideLabels.title(ed.model, e.id);
    final name = title.isEmpty ? l.slideUntitled : title;
    final number = Text(
      '${e.index + 1}',
      textAlign: TextAlign.right,
      style: theme.textTheme.muted.copyWith(
        fontSize: 12,
        decoration: e.skipped ? TextDecoration.lineThrough : null,
        color: e.skipped
            ? theme.colorScheme.mutedForeground.withValues(alpha: 0.6)
            : null,
      ),
    );
    final hover = _hoverKey == r.key && !_dragging;
    final thumb = NavThumbnail(
      renderer: _renderer,
      slideId: e.id,
      width: _thumbWidth,
      current: current,
      selected: selected,
      skipped: e.skipped,
      skippedWithGroup: group?.skipped ?? false,
      dimmed: _draggedIds.contains(e.id),
      overlay: Positioned.fill(
        child: Stack(
          children: [
            // A collaborator's structure change (SL-37, 09 §2.4).
            Positioned.fill(
              child: StructureShimmer(editor: ed, id: e.id),
            ),
            if (_compact) Positioned(left: 4, top: 2, child: number),
            // Collaborators on this slide (SL-21, 09 §1.2).
            Positioned(
              right: 2,
              bottom: 2,
              child: SlidePresenceDots(editor: ed, slideId: e.id),
            ),
            // Open comments on this slide (SL-38, 04 §5.2).
            Positioned(
              left: 2,
              bottom: 2,
              child: SlideCommentBadge(editor: ed, slideId: e.id),
            ),
            if (hover)
              Positioned(
                right: 2,
                top: 2,
                child: _menuButton(
                  context,
                  key: 'slides.navigator.slide.${e.id}.menu',
                  tooltip: l.navigatorSlideMenu,
                  onPressed: (global) {
                    if (!ed.selectedSlideIds.contains(e.id)) {
                      _nav.clickSlide(e.id);
                    }
                    widget.onContextMenu(
                      SlidesContextMenuIds.navigatorSlide,
                      global,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
    final semantics = group == null
        ? l.navigatorSlideSemantics(e.index + 1, ed.order.length, name)
        : l.navigatorSlideInGroupSemantics(
            e.index + 1,
            ed.order.length,
            group.title.isEmpty ? l.groupUntitled : group.title,
            name,
          );
    return MouseRegion(
      onEnter: (_) => setState(() => _hoverKey = r.key),
      onExit: (_) {
        if (_hoverKey == r.key) setState(() => _hoverKey = null);
      },
      child: Semantics(
        selected: current || selected,
        button: true,
        label: e.skipped ? '$semantics, ${l.navigatorSkipped}' : semantics,
        child: GestureDetector(
          key: ValueKey<String>('slides.navigator.slide.${e.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_suppressTap) return;
            _nav.clickSlide(
              e.id,
              range: HardwareKeyboard.instance.isShiftPressed,
              toggle: _modPressed(),
            );
          },
          onSecondaryTapUp: (d) {
            if (!ed.selectedSlideIds.contains(e.id)) _nav.clickSlide(e.id);
            widget.onContextMenu(
              SlidesContextMenuIds.navigatorSlide,
              d.globalPosition,
            );
          },
          child: Container(
            foregroundDecoration: focused
                ? BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.ring.withValues(alpha: 0.6),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group color bar (4 px) + 12 px indent inside a group.
                Container(
                  width: 4,
                  margin: EdgeInsets.only(right: group == null ? 0 : 12),
                  decoration: BoxDecoration(
                    color: groupColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (!_compact)
                  SizedBox(
                    width: group == null ? 36 : 24,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, right: 6),
                      child: number,
                    ),
                  ),
                thumb,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupRow(BuildContext context, NavRow r) {
    final theme = ShadTheme.of(context);
    final tokens = SlidesTokens.of(context);
    final l = slidesL10n(context);
    final g = ed.model.group(r.id);
    final range = r.range!;
    if (g == null) return const SizedBox.shrink();
    final color =
        tokens.groupColor(g.color) ?? theme.colorScheme.mutedForeground;
    final title = g.title.isEmpty ? l.groupUntitled : g.title;
    final selected = ed.selectedGroupIds.contains(g.id);
    final focused = _nav.focusKey == r.key && ed.navigatorFocus.hasFocus;
    final holdsCurrent = r.collapsed && ed.currentEntry?.groupId == g.id;
    final renaming = _nav.renamingGroupId == g.id;
    final highlight = _nav.drag?.drop?.highlightGroupId == g.id;
    final refused = highlight && (_nav.drag?.drop?.refused ?? false);
    final hover = _hoverKey == r.key && !_dragging;
    final state = [
      r.collapsed ? l.navigatorGroupCollapsed : l.navigatorGroupExpanded,
      if (g.skipped) l.navigatorSkipped,
    ].join(', ');
    final header = Row(
      children: [
        _chevron(context, r, l),
        _colorDot(context, g.id, color, l),
        const SizedBox(width: 6),
        Expanded(
          child: renaming
              ? _RenameField(
                  key: ValueKey<String>('slides.navigator.rename.${g.id}'),
                  initial: g.title,
                  label: l.navigatorRenameField,
                  onCommit: (t) => _commitRename(g.id, t),
                  onCancel: () {
                    _nav.endRename();
                    ed.navigatorFocus.requestFocus();
                  },
                )
              : Text(
                  title,
                  key: ValueKey<String>('slides.navigator.group.${g.id}.title'),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        if (g.skipped)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              LucideIcons.eyeOff,
              key: ValueKey<String>('slides.navigator.group.${g.id}.skipped'),
              size: 12,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        // Collaborators inside a collapsed group (SL-21, 09 §1.2).
        if (r.collapsed) SlidePresenceDots(editor: ed, groupId: g.id),
        // Open comments inside a collapsed group (SL-38, 09 §3.3).
        if (r.collapsed)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: SlideCommentBadge(editor: ed, groupId: g.id),
          ),
        const SizedBox(width: 6),
        Text(
          '${range.length}',
          key: ValueKey<String>('slides.navigator.group.${g.id}.count'),
          style: theme.textTheme.muted.copyWith(fontSize: 12),
        ),
        SizedBox(
          width: 22,
          child: hover || selected
              ? _menuButton(
                  context,
                  key: 'slides.navigator.group.${g.id}.menu',
                  tooltip: l.navigatorGroupMenu,
                  onPressed: (global) {
                    if (!selected) _nav.clickGroup(g.id);
                    widget.onContextMenu(
                      SlidesContextMenuIds.navigatorGroup,
                      global,
                    );
                  },
                )
              : null,
        ),
      ],
    );
    final firstSlide = range.length > 0
        ? ed.order.entries[range.start].id
        : null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoverKey = r.key),
      onExit: (_) {
        if (_hoverKey == r.key) setState(() => _hoverKey = null);
      },
      child: Semantics(
        selected: selected,
        expanded: !r.collapsed,
        button: true,
        label: '${l.navigatorGroupSemantics(title, range.length)}, $state',
        child: GestureDetector(
          key: ValueKey<String>('slides.navigator.group.${g.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _onHeaderTap(g.id),
          onSecondaryTapUp: (d) {
            if (!selected) _nav.clickGroup(g.id);
            widget.onContextMenu(
              SlidesContextMenuIds.navigatorGroup,
              d.globalPosition,
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
            decoration: BoxDecoration(
              color: highlight
                  ? (refused
                        ? theme.colorScheme.destructive.withValues(alpha: 0.15)
                        : theme.colorScheme.primary.withValues(alpha: 0.15))
                  : selected
                  ? tokens.thumbnailSelection.withValues(alpha: 0.18)
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            // Borders as foreground: they don't shrink the fixed rows.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: highlight
                  ? Border.all(
                      color: refused
                          ? theme.colorScheme.destructive
                          : theme.colorScheme.primary,
                    )
                  : holdsCurrent
                  ? Border.all(color: tokens.thumbnailRing, width: 2)
                  : focused
                  ? Border.all(
                      color: theme.colorScheme.ring.withValues(alpha: 0.6),
                    )
                  : null,
            ),
            child: Opacity(
              opacity: _draggedIds.contains(g.id) ? 0.45 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: _headerHeight - 4,
                    child: Stack(
                      children: [
                        // A collaborator's structure change (SL-37).
                        Positioned.fill(
                          child: StructureShimmer(editor: ed, id: g.id),
                        ),
                        Positioned.fill(child: header),
                      ],
                    ),
                  ),
                  if (r.collapsed && firstSlide != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, bottom: 6),
                      child: StackedSlidePreview(
                        key: ValueKey<String>(
                          'slides.navigator.group.${g.id}.preview',
                        ),
                        renderer: _renderer,
                        slideId: firstSlide,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onHeaderTap(String groupId) {
    if (_suppressTap) return;
    final key = 'group:$groupId';
    final now = DateTime.now();
    final isDouble =
        _lastTapKey == key && now.difference(_lastTapAt).inMilliseconds < 400;
    _lastTapKey = key;
    _lastTapAt = now;
    if (isDouble && !_modPressed()) {
      _lastTapKey = null;
      unawaited(
        widget.services.dispatcher.invoke(
          'slides.group.startRename',
          args: {'groupId': groupId},
          source: InvocationSource.ui,
        ),
      );
      return;
    }
    _nav.clickGroup(
      groupId,
      range: HardwareKeyboard.instance.isShiftPressed,
      toggle: _modPressed(),
    );
  }

  Widget _chevron(BuildContext context, NavRow r, SlidesLocalizations l) {
    final theme = ShadTheme.of(context);
    return ShadTooltip(
      builder: (_) =>
          Text(r.collapsed ? l.navigatorExpandGroup : l.navigatorCollapseGroup),
      child: GestureDetector(
        key: ValueKey<String>('slides.navigator.group.${r.id}.chevron'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ed.navigatorFocus.requestFocus();
          // Alt+click collapses/expands every group (04 §5.3).
          if (HardwareKeyboard.instance.isAltPressed) {
            widget.services.dispatcher.invoke(
              r.collapsed
                  ? 'slides.group.expandAll'
                  : 'slides.group.collapseAll',
              source: InvocationSource.ui,
            );
            return;
          }
          widget.services.dispatcher.invoke(
            'slides.group.toggleCollapsed',
            args: {
              'groupIds': [r.id],
            },
            source: InvocationSource.ui,
          );
        },
        child: SizedBox(
          width: 20,
          height: 24,
          child: Icon(
            r.collapsed ? LucideIcons.chevronRight : LucideIcons.chevronDown,
            size: 14,
            color: theme.colorScheme.mutedForeground,
          ),
        ),
      ),
    );
  }

  Widget _colorDot(
    BuildContext context,
    String groupId,
    Color color,
    SlidesLocalizations l,
  ) => ShadTooltip(
    builder: (_) => Text(l.navigatorGroupColor),
    child: GestureDetector(
      key: ValueKey<String>('slides.navigator.group.$groupId.color'),
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _openColorMenu(context, groupId, d.globalPosition),
      child: SizedBox(
        width: 16,
        height: 24,
        child: Center(
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      ),
    ),
  );

  void _openColorMenu(BuildContext context, String groupId, Offset global) {
    final host = WonkyPopupMenuHost.maybeOf(context);
    if (host == null) return;
    final l = slidesL10n(context);
    host.show(
      global,
      () => MenuResolver(widget.services).entries(context, [
        for (final c in slideGroupColors)
          MenuSpec.command(
            'slides.group.setColor',
            label: groupColorLabel(l, c),
            args: {
              'groupIds': [groupId],
              'color': c,
            },
            id: 'navigator.color.$c',
            radio: true,
          ),
        MenuSpec.command(
          'slides.group.setColor',
          label: l.colorNone,
          args: {
            'groupIds': [groupId],
            'color': null,
          },
          id: 'navigator.color.none',
          radio: true,
        ),
      ]),
      onClosed: ed.navigatorFocus.requestFocus,
    );
  }

  Widget _emptyGroupRow(BuildContext context, NavRow r) {
    final theme = ShadTheme.of(context);
    final tokens = SlidesTokens.of(context);
    final l = slidesL10n(context);
    final g = ed.model.group(r.id);
    final highlight = _nav.drag?.drop?.highlightGroupId == r.id;
    final color =
        tokens.groupColor(g?.color) ?? theme.colorScheme.mutedForeground;
    return Padding(
      key: ValueKey<String>('slides.navigator.empty.${r.id}'),
      padding: const EdgeInsets.fromLTRB(20, 4, 10, 6),
      child: DashedBorderBox(
        color: highlight ? theme.colorScheme.primary : color,
        child: Center(
          child: Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l.navigatorDropHere,
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
              if (ed.canEdit)
                GestureDetector(
                  key: ValueKey<String>('slides.navigator.empty.${r.id}.new'),
                  onTap: () => widget.services.dispatcher.invoke(
                    'slides.slide.new',
                    args: {'groupId': r.id},
                    source: InvocationSource.ui,
                  ),
                  child: Text(
                    l.menuNewSlideInGroup,
                    style: theme.textTheme.small.copyWith(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton(
    BuildContext context, {
    required String key,
    required String tooltip,
    required void Function(Offset global) onPressed,
  }) {
    final theme = ShadTheme.of(context);
    return ShadTooltip(
      builder: (_) => Text(tooltip),
      child: GestureDetector(
        key: ValueKey<String>(key),
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => onPressed(d.globalPosition),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: theme.colorScheme.background.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: Icon(
            LucideIcons.ellipsisVertical,
            size: 13,
            color: theme.colorScheme.foreground,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------- indicators and ghost

  Widget _indicators(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tokens = SlidesTokens.of(context);
    final l = slidesL10n(context);
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    final children = <Widget>[];
    Widget line(double y, bool inside, Color color, String key) {
      final left = inside ? _indentX : 4.0;
      return Positioned(
        key: ValueKey<String>(key),
        left: left,
        right: 6,
        top: y - offset - 3,
        height: 6,
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
            ),
            Expanded(child: Container(height: 2, color: color)),
          ],
        ),
      );
    }

    final drag = _nav.drag;
    final drop = drag?.drop;
    if (drop != null && drop.highlightGroupId == null) {
      final color = drop.refused
          ? theme.colorScheme.destructive
          : drop.inside
          ? (tokens.groupColor(ed.model.group(drop.groupId ?? '')?.color) ??
                theme.colorScheme.primary)
          : theme.colorScheme.primary;
      children.add(
        line(drop.y, drop.inside, color, 'slides.navigator.dropIndicator'),
      );
    }
    if (drop != null && drop.refused) {
      children.add(
        Positioned(
          key: const ValueKey<String>('slides.navigator.dropRefused'),
          left: _indentX,
          top: drop.y - offset + 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.destructive,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              l.reasonGroupsCantNest,
              style: theme.textTheme.small.copyWith(
                fontSize: 11,
                color: theme.colorScheme.destructiveForeground,
              ),
            ),
          ),
        ),
      );
    }
    final insertion = _nav.insertionY;
    if (drag == null && insertion != null && _nav.insertion != null) {
      children.add(
        line(
          insertion,
          _nav.insertionInside,
          theme.colorScheme.primary,
          'slides.navigator.insertion',
        ),
      );
    }
    if (drag != null) children.add(_ghost(context, drag));
    return Stack(clipBehavior: Clip.hardEdge, children: children);
  }

  Widget _ghost(BuildContext context, NavDragState drag) {
    final theme = ShadTheme.of(context);
    final local = _localOf(drag.pointer) ?? Offset.zero;
    final first = drag.firstSlideId;
    const w = 72.0;
    return Positioned(
      key: const ValueKey<String>('slides.navigator.ghost'),
      left: local.dx + 8,
      top: local.dy + 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (first != null && ed.order.entry(first) != null)
            StackedSlidePreview(renderer: _renderer, slideId: first, width: w),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              drag.copy ? '+ ${drag.label}' : drag.label,
              style: theme.textTheme.small.copyWith(
                fontSize: 11,
                color: theme.colorScheme.primaryForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- pointer, drag

  void _onPointerDown(PointerDownEvent e, List<NavRowBox> boxes) {
    _lastLocal = e.localPosition;
    _suppressTap = false;
    if (e.buttons != kPrimaryButton) {
      if (e.buttons == kSecondaryButton) ed.navigatorFocus.requestFocus();
      return;
    }
    if (_nav.renamingGroupId == null) ed.navigatorFocus.requestFocus();
    _downGlobal = e.position;
    _downRow = _boxAt(boxes, _contentY(e.localPosition.dy))?.row;
    _dragCancelled = false;
  }

  void _onPointerMove(PointerMoveEvent e, double viewportHeight) {
    _lastLocal = e.localPosition;
    final down = _downGlobal;
    if (down == null || _dragCancelled) return;
    if (!_dragging) {
      if ((e.position - down).distance < 4) return;
      final row = _downRow;
      if (row == null ||
          row.kind == NavRowKind.emptyGroup ||
          !ed.canEdit ||
          _nav.renamingGroupId != null) {
        return;
      }
      _startDrag(row, e.position);
    }
    _updateDrop(e.localPosition);
    _updateAutoScroll(e.localPosition.dy, viewportHeight);
  }

  void _startDrag(NavRow row, Offset global) {
    // Dragging an unselected row selects it first (04 §5.10).
    if (row.isSlide && !ed.selectedSlideIds.contains(row.id)) {
      _nav.clickSlide(row.id);
    } else if (row.isGroup && !ed.selectedGroupIds.contains(row.id)) {
      _nav.clickGroup(row.id);
    }
    final sel = _nav.selection;
    final l = slidesL10n(context);
    final slides = sel.allSlideIds(ed.order);
    final String label;
    if (sel.groupIds.length == 1 && sel.slideIds.isEmpty) {
      final g = ed.model.group(sel.groupIds.single);
      final t = g == null || g.title.isEmpty ? l.groupUntitled : g.title;
      label = l.navigatorDragGroup(t, slides.length);
    } else {
      label = l.navigatorDragSlides(slides.length);
    }
    _suppressTap = true;
    _nav.startDrag(
      NavDragState(
        selection: sel,
        pointer: global,
        label: label,
        firstSlideId: slides.firstOrNull,
      ),
    );
  }

  void _updateDrop(Offset local) {
    final drag = _nav.drag;
    if (drag == null) return;
    final boxes = _boxes(_nav.rows);
    final drop = resolveNavDrop(
      boxes,
      local.dx,
      _contentY(local.dy),
      draggingGroups: drag.selection.hasGroups,
      indentX: _indentX,
    );
    final global =
        (_listKey.currentContext?.findRenderObject() as RenderBox?)
            ?.localToGlobal(local) ??
        drag.pointer;
    _nav.updateDrag(
      pointer: global,
      drop: drop,
      copy: HardwareKeyboard.instance.isAltPressed,
    );
  }

  /// Auto-scroll within 32 px of the list edges, speed ∝ distance.
  void _updateAutoScroll(double y, double height) {
    double speed = 0;
    if (y < 32) speed = -(32 - y) * 0.6;
    if (y > height - 32) speed = (y - (height - 32)) * 0.6;
    _autoScrollSpeed = speed;
    if (speed == 0) {
      _autoScroll?.cancel();
      _autoScroll = null;
      return;
    }
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients || _nav.drag == null) {
        _autoScroll?.cancel();
        _autoScroll = null;
        return;
      }
      final p = _scroll.position;
      final to = (p.pixels + _autoScrollSpeed).clamp(
        p.minScrollExtent,
        p.maxScrollExtent,
      );
      if (to != p.pixels) {
        p.jumpTo(to);
        _updateDrop(_lastLocal);
      }
    });
  }

  void _onPointerUp(PointerUpEvent e, List<NavRowBox> boxes) {
    _lastLocal = e.localPosition;
    _autoScroll?.cancel();
    _autoScroll = null;
    final drag = _nav.endDrag();
    final down = _downGlobal;
    _downGlobal = null;
    _downRow = null;
    if (drag != null) {
      if (!_dragCancelled) _drop(drag);
      return;
    }
    // A click in the gap between two rows sets the insertion caret.
    if (down == null || (e.position - down).distance > 4) return;
    final y = _contentY(e.localPosition.dy);
    for (var i = 1; i < boxes.length; i++) {
      final edge = boxes[i].top;
      if ((y - edge).abs() <= 3) {
        _suppressTap = true;
        _nav.setInsertion(
          resolveNavDrop(
            boxes,
            e.localPosition.dx,
            edge + (y < edge ? -0.5 : 0.5),
            draggingGroups: false,
            indentX: _indentX,
          ),
        );
        return;
      }
    }
  }

  void _cancelDrag() {
    _autoScroll?.cancel();
    _autoScroll = null;
    _dragCancelled = true;
    _nav.endDrag();
  }

  /// One drop = one undo step (04 §5.10): `slides.slide.move` with the
  /// selection and the target (Alt: `copy`).
  void _drop(NavDragState drag) {
    final drop = drag.drop;
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

  // --------------------------------------------------------------- rename

  void _commitRename(String groupId, String text) {
    _nav.endRename();
    final t = text.trim();
    ed.navigatorFocus.requestFocus();
    // Empty or too long: the title reverts (04 §5.4).
    if (t.isEmpty || t.length > 100) return;
    if (t == ed.model.group(groupId)?.title) return;
    unawaited(
      widget.services.dispatcher.invoke(
        'slides.group.rename',
        args: {'groupId': groupId, 'title': t},
        source: InvocationSource.ui,
      ),
    );
  }

  // -------------------------------------------------------------- keyboard

  bool _inTextField() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// The navigator keys of 04 §5.9 the keymap doesn't bind: arrows,
  /// Home/End, Enter, Esc and type-ahead.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_inTextField()) return KeyEventResult.ignored;
    final k = HardwareKeyboard.instance;
    final mod = k.isMetaPressed || k.isControlPressed;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_dragging) {
        _cancelDrag();
        return KeyEventResult.handled;
      }
      if (_nav.insertion != null) {
        _nav.clearInsertion();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (mod || k.isAltPressed) return KeyEventResult.ignored;
    final shift = k.isShiftPressed;
    final focus = _nav.focusKey;
    final row = _nav.rows.where((r) => r.key == focus).firstOrNull;
    if (key == LogicalKeyboardKey.arrowDown) {
      _nav.moveFocus(1, extend: shift);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _nav.moveFocus(-1, extend: shift);
    } else if (key == LogicalKeyboardKey.home) {
      _nav.focusEdge(last: false, extend: shift);
    } else if (key == LogicalKeyboardKey.end) {
      _nav.focusEdge(last: true, extend: shift);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (row == null) return KeyEventResult.ignored;
      if (row.isGroup) {
        _nav.setCollapsed([row.id], true);
      } else if (row.groupId != null) {
        _nav.setFocus('group:${row.groupId}');
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (row == null || !row.isGroup) return KeyEventResult.ignored;
      _nav.setCollapsed([row.id], false);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (row == null) return KeyEventResult.ignored;
      if (row.isGroup) {
        _nav.toggleCollapsed(row.id);
      } else {
        ed.canvasFocus.requestFocus();
      }
    } else {
      final ch = event.character;
      if (ch == null || ch.length != 1 || ch.trim().isEmpty) {
        return KeyEventResult.ignored;
      }
      if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(ch)) {
        return KeyEventResult.ignored;
      }
      return _nav.typeAhead(ch)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    _revealFocus();
    return KeyEventResult.handled;
  }

  /// Scrolls the focus row into view.
  void _revealFocus() {
    if (!_scroll.hasClients) return;
    final boxes = _boxes(_nav.rows);
    final b = boxes.where((b) => b.row.key == _nav.focusKey).firstOrNull;
    if (b == null) return;
    final p = _scroll.position;
    final top = b.top - _padTop;
    final bottom = b.top + b.height;
    if (top < p.pixels) {
      p.jumpTo(top.clamp(p.minScrollExtent, p.maxScrollExtent));
    } else if (bottom > p.pixels + p.viewportDimension) {
      p.jumpTo(
        (bottom - p.viewportDimension).clamp(
          p.minScrollExtent,
          p.maxScrollExtent,
        ),
      );
    }
  }

  // ---------------------------------------------------------------- footer

  Widget _footer(BuildContext context, SlidesCommandUi ui) {
    final st = ui.state('slides.slide.new');
    final l = ui.l;
    final button = ShadButton.ghost(
      key: const ValueKey<String>('slides.navigator.newSlide'),
      height: 30,
      enabled: st.enabled,
      leading: const Icon(LucideIcons.plus, size: 14),
      onPressed: () =>
          ui.run('slides.slide.new', const {}, InvocationSource.ui),
      child: Text(l.cmdSlideNew),
    );
    final reason = st.disabledReason;
    final main = st.enabled || reason == null
        ? button
        : ShadTooltip(builder: (_) => Text(reason), child: button);
    return Row(
      children: [
        Expanded(child: main),
        ShadTooltip(
          builder: (_) => Text(l.navigatorNewSlideLayout),
          child: Builder(
            builder: (context) => ShadIconButton.ghost(
              key: const ValueKey<String>('slides.navigator.newSlideLayout'),
              width: 28,
              height: 30,
              iconSize: 14,
              enabled: st.enabled,
              icon: const Icon(LucideIcons.chevronDown),
              onPressed: () {
                final box = context.findRenderObject() as RenderBox?;
                final at = box == null
                    ? Offset.zero
                    : box.localToGlobal(Offset(0, box.size.height));
                _openLayoutMenu(context, at);
              },
            ),
          ),
        ),
      ],
    );
  }

  void _openLayoutMenu(BuildContext context, Offset global) {
    final host = WonkyPopupMenuHost.maybeOf(context);
    if (host == null) return;
    host.show(global, () {
      final r = MenuResolver(widget.services);
      return [
        for (final layout in SlideLabels.layouts(ed.model))
          ?r.commandEntry(
            context,
            'slides.slide.new',
            args: {'layoutId': layout.id},
            label: layout.name,
            key: 'navigator.newSlideLayout.${layout.id}',
          ),
      ];
    }, onClosed: ed.navigatorFocus.requestFocus);
  }
}

/// The inline rename field of a group header (04 §5.4): select-all on
/// focus, Enter/blur commit, Esc cancels.
class _RenameField extends StatefulWidget {
  const _RenameField({
    super.key,
    required this.initial,
    required this.label,
    required this.onCommit,
    required this.onCancel,
  });

  final String initial;
  final String label;
  final ValueChanged<String> onCommit;
  final VoidCallback onCancel;

  @override
  State<_RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<_RenameField> {
  late final _controller = TextEditingController(text: widget.initial);
  final _focus = FocusNode(debugLabel: 'slides.navigator.rename');
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _commit() {
    if (_done) return;
    _done = true;
    widget.onCommit(_controller.text);
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: (node, e) {
      if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
        _done = true;
        widget.onCancel();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: SizedBox(
      height: 26,
      child: ShadInput(
        controller: _controller,
        focusNode: _focus,
        placeholder: Text(widget.label),
        maxLength: 100,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        onSubmitted: (_) => _commit(),
      ),
    ),
  );
}

/// A rounded box with a dashed 1 px border (the empty group drop zone).
class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashedPainter(color), child: child);
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      const Radius.circular(4),
    );
    final path = Path()..addRRect(r);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color;
}
