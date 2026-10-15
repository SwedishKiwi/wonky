import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart' show ShellServices;
import 'package:wonky_slides_core/model.dart';

import '../../l10n/slides_l10n.dart';
import '../../theme/slides_tokens.dart';
import '../editor_screen/slide_labels.dart';
import '../stage/slide_renderer.dart';
import '../thumbnails/slide_thumbnail.dart';
import 'present_controller.dart';

/// The slide picker (Slides 10 §4.5): a full-screen overlay with the
/// deck's thumbnails in 4–8 columns under **group headers** (title, color
/// dot, slide count; collapsed as in the navigator, toggled here without
/// changing it), skipped slides dimmed with `eye-off` and still
/// selectable, the current slide outlined. Typing filters by title or
/// number; arrows, Home/End and PageUp/PageDown move; `Enter` shows the
/// slide, `Esc` closes.
class SlidePicker extends StatefulWidget {
  const SlidePicker({
    super.key,
    required this.controller,
    required this.renderer,
    required this.services,
    required this.deckId,
  });

  final PresentController controller;
  final SlideRenderer renderer;
  final ShellServices services;
  final String deckId;

  @override
  State<SlidePicker> createState() => _SlidePickerState();
}

class _SlidePickerState extends State<SlidePicker> {
  final _filter = TextEditingController();
  final _filterFocus = FocusNode(debugLabel: 'slides.present.picker.filter');
  final _scroll = ScrollController();
  final Set<String> _collapsed = {};
  int _focus = -1;
  int _columns = 4;

  PresentController get c => widget.controller;
  DeckModel get model => c.model;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCollapsed());
    _filter.addListener(() => setState(() => _focus = 0));
    final cur = c.position?.slideId;
    final i = cur == null ? -1 : _visible().indexWhere((e) => e.id == cur);
    _focus = math.max(0, i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _filterFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    _filterFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The navigator's collapsed groups (`slides.view.<deckId>`), read once.
  Future<void> _loadCollapsed() async {
    try {
      final raw = await widget.services.userStore.read(
        'slides.view.${widget.deckId}',
      );
      final v = raw is String ? jsonDecode(raw) : raw;
      final list = v is Map ? v['collapsedGroups'] : null;
      if (list is List && mounted) {
        setState(() {
          _collapsed.addAll(list.whereType<String>());
          final cur = c.currentEntry?.groupId;
          if (cur != null) _collapsed.remove(cur);
        });
      }
    } on Object {
      // No view state: everything expanded.
    }
  }

  String get _query => _filter.text.trim().toLowerCase();

  bool _matches(SlideOrderEntry e) {
    final q = _query;
    if (q.isEmpty) return true;
    if ('${e.index + 1}' == q) return true;
    return SlideLabels.title(model, e.id).toLowerCase().contains(q);
  }

  /// The selectable slides in order (filtered; collapsed groups folded
  /// unless filtering).
  List<SlideOrderEntry> _visible() => [
    for (final e in c.sequence.order.entries)
      if (_matches(e) &&
          (_query.isNotEmpty ||
              e.groupId == null ||
              !_collapsed.contains(e.groupId)))
        e,
  ];

  void _go(SlideOrderEntry e) {
    c.goTo(e.id);
    c.setPicker(false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final items = _visible();
    final k = event.logicalKey;
    int? move;
    if (k == LogicalKeyboardKey.arrowRight) move = 1;
    if (k == LogicalKeyboardKey.arrowLeft) move = -1;
    if (k == LogicalKeyboardKey.arrowDown) move = _columns;
    if (k == LogicalKeyboardKey.arrowUp) move = -_columns;
    if (k == LogicalKeyboardKey.pageDown) move = _columns * 3;
    if (k == LogicalKeyboardKey.pageUp) move = -_columns * 3;
    if (k == LogicalKeyboardKey.home) move = -items.length;
    if (k == LogicalKeyboardKey.end) move = items.length;
    if (move != null) {
      if (items.isNotEmpty) {
        setState(() => _focus = (_focus + move!).clamp(0, items.length - 1));
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (_focus >= 0 && _focus < items.length) _go(items[_focus]);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      c.setPicker(false);
      return KeyEventResult.handled;
    }
    // Typing filters: the present shortcuts (N, P, B…) must not run.
    final kb = HardwareKeyboard.instance;
    if (!kb.isMetaPressed && !kb.isControlPressed) {
      return KeyEventResult.skipRemainingHandlers;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        label: l.presentPickerTitle,
        child: ColoredBox(
          key: const ValueKey<String>('slides.present.picker'),
          color: theme.colorScheme.background.withValues(alpha: 0.97),
          child: Focus(
            onKeyEvent: _onKey,
            child: LayoutBuilder(
              builder: (context, box) {
                _columns = (box.maxWidth / 220).floor().clamp(4, 8);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context),
                    Expanded(child: _grid(context, box.maxWidth)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              l.presentPickerTitle,
              style: theme.textTheme.large,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: ShadInput(
                key: const ValueKey<String>('slides.present.picker.filter'),
                controller: _filter,
                focusNode: _filterFocus,
                placeholder: Text(l.presentPickerFilter),
                leading: const Icon(LucideIcons.search, size: 14),
              ),
            ),
          ),
          const SizedBox(width: 4),
          ShadTooltip(
            builder: (_) => Text(l.presentPickerClose),
            child: ShadIconButton.ghost(
              key: const ValueKey<String>('slides.present.picker.close'),
              semanticLabel: l.presentPickerClose,
              icon: const Icon(LucideIcons.x, size: 16),
              onPressed: () => c.setPicker(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, double width) {
    final order = c.sequence.order;
    final visible = _visible();
    final focusedId = _focus >= 0 && _focus < visible.length
        ? visible[_focus].id
        : null;
    final gap = 12.0;
    final thumb = ((width - 32 - gap * (_columns - 1)) / _columns).clamp(
      60.0,
      400.0,
    );
    final children = <Widget>[];
    void addTiles(Iterable<SlideOrderEntry> entries) {
      final tiles = [
        for (final e in entries)
          if (_matches(e)) _tile(context, e, thumb, e.id == focusedId),
      ];
      if (tiles.isEmpty) return;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(spacing: gap, runSpacing: gap, children: tiles),
        ),
      );
    }

    var top = <SlideOrderEntry>[];
    for (final item in order.topLevel) {
      if (!item.isGroup) {
        final e = order.entry(item.id);
        if (e != null) top.add(e);
        continue;
      }
      addTiles(top);
      top = [];
      final r = order.range(item.id);
      if (r == null) continue;
      final entries = order.entries.sublist(r.start, r.end);
      final matching = entries.where(_matches).length;
      if (_query.isNotEmpty && matching == 0) continue;
      children.add(_groupHeader(context, r));
      if (_query.isNotEmpty || !_collapsed.contains(item.id)) {
        addTiles(entries);
      }
    }
    addTiles(top);
    // Orphan slides (a missing group) come last.
    addTiles(order.entries.where((e) => e.orphan));
    if (children.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            slidesL10n(context).presentPickerNoMatch,
            style: ShadTheme.of(context).textTheme.muted,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _groupHeader(BuildContext context, SlideGroupRange r) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final g = r.group;
    final collapsed = _collapsed.contains(g.id);
    final color =
        SlidesTokens.of(context).groupColor(g.color) ??
        theme.colorScheme.mutedForeground;
    final title = g.title.isEmpty ? l.groupUntitled : g.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Semantics(
        button: true,
        expanded: !collapsed,
        label: l.presentPickerGroup(title, r.length),
        child: GestureDetector(
          key: ValueKey<String>('slides.present.picker.group.${g.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            if (!_collapsed.remove(g.id)) _collapsed.add(g.id);
          }),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(
                  collapsed
                      ? LucideIcons.chevronRight
                      : LucideIcons.chevronDown,
                  size: 14,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: theme.textTheme.small,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${r.length}', style: theme.textTheme.muted),
                if (g.skipped) ...[
                  const SizedBox(width: 6),
                  Icon(
                    LucideIcons.eyeOff,
                    size: 13,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    SlideOrderEntry e,
    double width,
    bool focused,
  ) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final current = e.id == c.position?.slideId;
    final title = SlideLabels.title(model, e.id);
    final ring = current
        ? theme.colorScheme.primary
        : focused
        ? theme.colorScheme.ring
        : theme.colorScheme.border;
    return Semantics(
      button: true,
      selected: current,
      label: l.presentPickerSlide(
        e.index + 1,
        title.isEmpty ? l.slideUntitled : title,
      ),
      hint: e.skipped ? l.presentPickerSkipped : null,
      child: GestureDetector(
        key: ValueKey<String>('slides.present.picker.slide.${e.id}'),
        onTap: () => _go(e),
        child: ExcludeSemantics(
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: e.skipped ? 0.45 : 1,
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: ring,
                        width: current || focused ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SlideThumbnail(
                        renderer: widget.renderer,
                        slideId: e.id,
                        width: width,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${e.index + 1}', style: theme.textTheme.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small,
                      ),
                    ),
                    if (e.skipped)
                      Icon(
                        LucideIcons.eyeOff,
                        size: 13,
                        color: theme.colorScheme.mutedForeground,
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
