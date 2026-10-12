import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_write_core/wonky_write_core.dart' show SuggestionInfo;

import '../document/write_document_session.dart';
import '../document/reveal.dart';
import '../suggestions/suggestion_card.dart';
import 'comment_margin_layout.dart';

/// The comment margin (Write 08 §3.2): open comment threads and pending
/// suggestions as cards next to their anchors, in document order, never
/// overlapping; the active card aligns with its anchor.
///
/// Place it to the right of the page (Pages) or content column (Pageless)
/// — inside the same scroll view as the document, or outside with
/// [scrollController] so positions follow scrolling. Positions are computed
/// from the editor's document layout in this widget's coordinate space.
class CommentMargin extends StatefulWidget {
  const CommentMargin({
    super.key,
    required this.session,
    this.width = 300,
    this.scrollController,
    this.showSuggestions = true,
    this.gap = 8,
  });

  final WriteDocumentSession session;
  final double width;
  final ScrollController? scrollController;
  final bool showSuggestions;
  final double gap;

  @override
  State<CommentMargin> createState() => _CommentMarginState();
}

class _CardItem {
  _CardItem.thread(this.thread, this.offset) : suggestion = null;
  _CardItem.suggestion(this.suggestion, this.offset) : thread = null;

  final CommentThreadView? thread;
  final SuggestionInfo? suggestion;
  final int offset;

  String get id =>
      thread != null ? 'c:${thread!.uuid.uuid}' : 's:${suggestion!.id}';
}

class _CommentMarginState extends State<CommentMargin> {
  final Map<String, double> _heights = {};
  Map<String, double> _tops = const {};
  List<_CardItem> _items = const [];
  bool _scheduled = false;

  WriteDocumentSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    _listen(true);
    _schedule();
  }

  @override
  void didUpdateWidget(CommentMargin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.scrollController != widget.scrollController) {
      _listenTo(oldWidget, false);
      _listen(true);
    }
    _schedule();
  }

  @override
  void dispose() {
    _listen(false);
    super.dispose();
  }

  void _listen(bool on) => _listenTo(widget, on);

  void _listenTo(CommentMargin w, bool on) {
    final ls = <Listenable>[
      w.session.comments,
      w.session.suggestions,
      w.session.editor.view,
      w.session.contentVersion,
      ?w.scrollController,
    ];
    for (final l in ls) {
      if (on) {
        l.addListener(_schedule);
      } else {
        l.removeListener(_schedule);
      }
    }
  }

  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _relayout();
    });
  }

  List<_CardItem> _collect() {
    final comments = s.comments;
    if (!comments.visible) return const [];
    final anchors = comments.anchors;
    return [
      for (final t in comments.anchoredOpenThreads)
        _CardItem.thread(t, anchors[t.uuid.uuid]!.start),
      if (widget.showSuggestions)
        for (final x in s.suggestions.pending) _CardItem.suggestion(x, x.start),
    ];
  }

  void _relayout() {
    final items = _collect();
    final layout = s.editor.documentLayout;
    final box = context.findRenderObject();
    if (layout == null || box is! RenderBox || !box.hasSize) {
      if (items.length != _items.length) setState(() => _items = items);
      return;
    }
    final marginItems = <MarginItem>[];
    for (final item in items) {
      final global = globalTopOfOffset(layout, s.editor.mirror, item.offset);
      if (global == null) continue;
      final local = box.globalToLocal(global);
      marginItems.add(
        MarginItem(
          id: item.id,
          anchorTop: local.dy,
          anchorOffset: item.offset,
          height: _heights[item.id] ?? CommentMarginLayout.estimatedHeight,
        ),
      );
    }
    final activeThread = s.comments.activeThreadUuid;
    final activeSuggestion = s.suggestions.activeId;
    final active = activeThread != null
        ? 'c:$activeThread'
        : (activeSuggestion != null ? 's:$activeSuggestion' : null);
    final tops = CommentMarginLayout.layout(
      marginItems,
      activeId: active,
      gap: widget.gap,
    );
    if (!_sameTops(tops, _tops) || items.length != _items.length) {
      setState(() {
        _tops = tops;
        _items = items;
      });
    } else {
      _items = items;
    }
  }

  static bool _sameTops(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      if (o == null || (o - e.value).abs() > 0.5) return false;
    }
    return true;
  }

  void _onMeasured(String id, Size size) {
    if ((_heights[id] ?? -1) == size.height) return;
    _heights[id] = size.height;
    _schedule();
  }

  @override
  Widget build(BuildContext context) {
    final controller = s.comments.controller;
    var height = 0.0;
    final children = <Widget>[];
    for (final item in _items) {
      final top = _tops[item.id];
      if (top == null || controller == null) continue;
      height = math.max(
        height,
        top + (_heights[item.id] ?? CommentMarginLayout.estimatedHeight),
      );
      final t = item.thread;
      final card = t != null
          ? CommentThreadCard(
              key: ValueKey<String>('write.margin.thread.${t.uuid.uuid}'),
              services: s.services,
              controller: controller,
              thread: t,
              onTap: () => controller.activate(t.uuid.uuid),
            )
          : SuggestionCard(
              key: ValueKey<String>(
                'write.margin.suggestion.${item.suggestion!.id}',
              ),
              session: s,
              suggestion: item.suggestion!,
              active: s.suggestions.activeId == item.suggestion!.id,
            );
      children.add(
        AnimatedPositioned(
          key: ValueKey<String>(item.id),
          duration: MediaQuery.maybeDisableAnimationsOf(context) == true
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          top: top,
          left: 0,
          right: 0,
          child: _Measure(
            onSize: (size) => _onMeasured(item.id, size),
            child: card,
          ),
        ),
      );
    }
    return SizedBox(
      key: const ValueKey<String>('write.commentMargin'),
      width: widget.width,
      height: height,
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}

/// Reports its child's size after layout.
class _Measure extends SingleChildRenderObjectWidget {
  const _Measure({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasure(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasure renderObject) {
    renderObject.onSize = onSize;
  }
}

class _RenderMeasure extends RenderProxyBox {
  _RenderMeasure(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _last) {
      _last = size;
      final s = size;
      SchedulerBinding.instance.addPostFrameCallback((_) => onSize(s));
    }
  }
}
