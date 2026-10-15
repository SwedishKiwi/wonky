import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show CommentAnchorKind, CommentStatus, CommentThreadView;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides_core/model.dart';

import '../../l10n/slides_l10n.dart';
import '../../theme/slides_tokens.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../editor_screen/slide_labels.dart';
import '../layers/element_names.dart';
import '../text_editing/text_editing_host.dart';
import 'comment_anchor_moves.dart';
import 'slides_comment_anchor.dart';

/// A thread placed on a slide: its anchor and the slide the anchor resolves
/// to now (an element's current slide).
@immutable
class PlacedDeckThread {
  const PlacedDeckThread(this.thread, this.anchor, this.slideId);

  final CommentThreadView thread;
  final SlidesCommentAnchor anchor;

  /// The slide the anchor is on now.
  final String slideId;

  String get uuid => thread.uuid.uuid;

  /// The element of an element anchor.
  String? get elementId => anchor.elementId;
}

/// Wonky Slides' side of comments (Slides 09 §3): the
/// `CommentAnchorProvider` + `CommentPanelOptions` of the shell's comments
/// controller — anchors from the selection (element > slide; the element
/// being edited, with the selected text quoted; notes → the slide), live
/// labels and position sort, *This slide / All slides* scopes, slide
/// headers under slide-group sections, reveal — and the index of open
/// threads per slide for the canvas pins, the navigator/grid badges,
/// next/previous and the docked card.
///
/// One per open deck editor ([attach] / [of]); it attaches itself to the
/// shell's comments controller of the deck (offline queueing on, 09 §3.6).
class SlidesComments extends ChangeNotifier
    implements
        CommentAnchorProvider,
        CommentPanelOptions,
        CommentPanelSections {
  SlidesComments._(this.editor) {
    services.comments.addListener(_onControllerChanged);
    editor.addListener(_onEditor);
    editor.model.addListener(_onModel);
    _slide = editor.currentSlideId;
    _onControllerChanged();
    moves = CommentAnchorMoves(this);
  }

  static final Expando<SlidesComments> _of = Expando('slidesComments');

  /// The comments of [editor] (null when not attached).
  static SlidesComments? of(DeckEditorController editor) => _of[editor];

  /// Creates (or returns) the comments of [editor].
  static SlidesComments attach(DeckEditorController editor) =>
      _of[editor] ??= SlidesComments._(editor);

  /// Comment panel scopes (09 §3.5).
  static const scopeSlide = 'slide';
  static const scopeAll = 'all';

  final DeckEditorController editor;

  /// Comments moving with cut & pasted elements and slides (09 §3.2).
  late final CommentAnchorMoves moves;

  ShellServices get services => editor.services;
  DeckModel get model => editor.model;

  CommentsController? _controller;
  Map<String, List<PlacedDeckThread>>? _bySlide;
  String? _slide;
  bool _disposed = false;

  /// The shell's comments controller of this deck (null before it opened).
  CommentsController? get controller => _controller;

  /// Whether the docked card of the active thread was closed (until another
  /// thread is shown).
  final ValueNotifier<bool> dockDismissed = ValueNotifier(false);

  void _onControllerChanged() {
    final c = services.comments.value;
    final next = c != null && c.itemUuid == editor.session.itemUuid ? c : null;
    if (next != _controller) {
      _controller?.removeListener(_onThreads);
      _controller = next;
      next?.addListener(_onThreads);
      if (next != null) {
        next.anchors = this;
        // Offline comments are queued (09 §3.6, as Sheets 10 §3.7).
        next.queueOffline = true;
      }
    }
    _onThreads();
  }

  void _onThreads() {
    _bySlide = null;
    if (_disposed) return;
    if (_deepLink != null) _openDeepLink();
    notifyListeners();
  }

  void _onModel(DeckChangeBatch batch) => _onThreads();

  /// The *This slide* scope follows the current slide.
  void _onEditor() {
    if (_slide == editor.currentSlideId) return;
    _slide = editor.currentSlideId;
    final c = _controller;
    if (c != null && c.scope == scopeSlide) c.setScope(scopeSlide);
    notifyListeners();
  }

  // ---------------------------------------------------------- permissions

  /// Whether the user may see comments (viewers only when the owner allows
  /// it, suite 06).
  bool get visible {
    final item = services.currentItem.value;
    return editor.itemRole.canComment || (item?.viewersSeeComments ?? false);
  }

  /// Whether the user may comment.
  bool get canComment => editor.itemRole >= Role.commenter;

  /// Whether pins are drawn on the canvas (View › Show › Comments on
  /// canvas, 09 §3.3).
  bool get pinsOn => editor.commentPins && visible;

  // ----------------------------------------------------------- resolving

  /// The slide [a] is on now: an element's current slide (the anchor's
  /// slide id is only a hint), or the anchored slide; null when the slide
  /// or element is gone (orphaned or about to be) or not on a slide.
  String? slideOf(SlidesCommentAnchor a) {
    switch (a.kind) {
      case CommentAnchorKind.element:
        final e = model.element(a.elementId!);
        final s = e?.slideId;
        return s != null && editor.order.entry(s) != null ? s : null;
      case CommentAnchorKind.slide:
        return editor.order.entry(a.slideId!) != null ? a.slideId : null;
      default:
        return null;
    }
  }

  /// The anchor of [t] (null for anchors of other apps).
  static SlidesCommentAnchor? anchorOf(CommentThreadView t) =>
      SlidesCommentAnchor.parse(t.anchorKind, t.anchorJson);

  /// Open threads with a resolvable anchor, per slide, in reading order
  /// (slide anchors first, then elements top to bottom, left to right).
  Map<String, List<PlacedDeckThread>> get bySlide => _bySlide ??= _index();

  final Set<String> _hintFixed = {};

  Map<String, List<PlacedDeckThread>> _index() {
    final out = <String, List<PlacedDeckThread>>{};
    for (final t in _controller?.threads ?? const <CommentThreadView>[]) {
      if (t.status != CommentStatus.open) continue;
      final a = anchorOf(t);
      if (a == null) continue;
      final slide = slideOf(a);
      if (slide == null) continue;
      out.putIfAbsent(slide, () => []).add(PlacedDeckThread(t, a, slide));
      if (a.kind == CommentAnchorKind.element && a.slideId != slide) {
        _fixSlideHint(t, a, slide);
      }
    }
    for (final list in out.values) {
      list.sort((x, y) => _readingKey(x).compareTo(_readingKey(y)));
    }
    return out;
  }

  /// The element moved to another slide (drag to a navigator thumbnail):
  /// the stored slide hint is updated lazily, once per thread, when this
  /// user may move the anchor (its author or editors, 09 §3.1).
  void _fixSlideHint(CommentThreadView t, SlidesCommentAnchor a, String slide) {
    final c = _controller;
    final me = services.me?.id;
    final mayMove =
        editor.itemRole >= Role.editor || (me != null && t.createdBy?.id == me);
    if (c == null || !mayMove || !_hintFixed.add(t.uuid.uuid)) return;
    scheduleMicrotask(() {
      if (_disposed) return;
      unawaited(
        c.updateAnchor(t.uuid.uuid, a.withSlide(slide).encode()).catchError((
          Object e,
        ) {
          debugPrint('Updating the slide of comment ${t.uuid.uuid}: $e');
          return t;
        }),
      );
    });
  }

  /// Sort key inside a slide: slide anchors first, then the element's
  /// top-level position (top to bottom, left to right).
  double _readingKey(PlacedDeckThread p) {
    final id = p.elementId;
    if (id == null) return -1;
    var e = model.element(id);
    while (e != null && e.parentId != null) {
      final parent = model.element(e.parentId!);
      if (parent == null) break;
      e = parent;
    }
    final y = e?.y ?? 0;
    final x = e?.x ?? 0;
    return y.clamp(0, 1e5) * 1e5 + x.clamp(0, 1e5 - 1);
  }

  /// Open threads on [slideId] in reading order.
  List<PlacedDeckThread> threadsOn(String slideId) =>
      bySlide[slideId] ?? const [];

  /// Open threads of the slides of group [groupId] (collapsed headers).
  int openCountOfGroup(String groupId) {
    var n = 0;
    for (final e in editor.order.entries) {
      if (e.groupId == groupId) n += threadsOn(e.id).length;
    }
    return n;
  }

  /// Open threads in presentation order (slide order, then reading order).
  List<PlacedDeckThread> get readingOrder => [
    for (final e in editor.order.entries) ...threadsOn(e.id),
  ];

  /// The placed thread [uuid] (open, resolvable), or null.
  PlacedDeckThread? placed(String uuid) {
    for (final list in bySlide.values) {
      for (final p in list) {
        if (p.uuid == uuid) return p;
      }
    }
    return null;
  }

  // ------------------------------------------------- CommentAnchorProvider

  /// The last right-click on the canvas (pin at the click point, 09 §3.1):
  /// slide, point in su, the element under it and when.
  ({String slideId, Offset su, String? elementId, DateTime at})? _click;

  /// Remembers a right-click at [su] on the current slide (the canvas
  /// layer reports it before the context menu opens).
  void noteContextClick(Offset su) {
    final slide = editor.currentSlideId;
    if (slide == null) return;
    final ids = editor.selectedElementIds;
    _click = (
      slideId: slide,
      su: su,
      elementId: ids.length == 1 ? ids.single : null,
      at: clock.now(),
    );
  }

  /// How long a right-click point is used for the next comment.
  static const clickMemory = Duration(minutes: 1);

  Offset? _clickPoint(String slideId, String? elementId) {
    final c = _click;
    if (c == null ||
        c.slideId != slideId ||
        c.elementId != elementId ||
        clock.now().difference(c.at) > clickMemory) {
      return null;
    }
    if (elementId == null) return c.su;
    final e = model.element(elementId);
    final x = e?.x, y = e?.y, w = e?.width, h = e?.height;
    if (x == null || y == null || w == null || h == null || w <= 0 || h <= 0) {
      return null;
    }
    return Offset(
      ((c.su.dx - x) / w).clamp(0.0, 1.0),
      ((c.su.dy - y) / h).clamp(0.0, 1.0),
    );
  }

  @override
  NewCommentAnchor? anchorForSelection() {
    if (!canComment || !editor.isReady) return null;
    if (editor.mode == DeckViewMode.masters) return null;
    final slide = editor.currentSlideId;
    if (slide == null) return null;
    final l = slidesL10nOf(services);
    // The body being edited: the element, with the selected text quoted.
    final text = textEditingOf(editor).active;
    if (text != null) {
      final id = text.elementId;
      final r = text.selectionRange;
      String? quote;
      if (r != null && r.$1 != r.$2) {
        final plain = SlidesText.plainText(text.json);
        if (r.$2 <= plain.length) quote = plain.substring(r.$1, r.$2).trim();
      }
      return _elementAnchor(l, slide, id, quote: quote);
    }
    final ids = editor.selectedElementIds;
    if (ids.isNotEmpty && !editor.notesFocus.hasFocus) {
      return _elementAnchor(l, slide, ids.first);
    }
    final a = SlidesCommentAnchor.slide(slide, point: _clickPoint(slide, null));
    final label = slideQuote(l, slide);
    return NewCommentAnchor(
      kind: a.kind,
      anchorJson: a.encode(),
      quotedText: label,
      label: label,
    );
  }

  NewCommentAnchor? _elementAnchor(
    SlidesLocalizations l,
    String slide,
    String id, {
    String? quote,
  }) {
    final e = model.element(id);
    if (e == null || e.slideId == null) return null;
    final a = SlidesCommentAnchor.element(
      e.slideId!,
      id,
      point: _clickPoint(slide, id),
    );
    final q = quote == null || quote.isEmpty ? elementQuote(l, e) : quote;
    return NewCommentAnchor(
      kind: a.kind,
      anchorJson: a.encode(),
      quotedText: q,
      label: q,
    );
  }

  /// The quoted text of an element comment (09 §3.1): its text (first 120
  /// characters) or its kind label ("Image: team photo").
  static String elementQuote(SlidesLocalizations l, SlideElementRec e) {
    final text = e.text == null
        ? ''
        : SlidesText.plainText(e.text).trim().replaceAll('\n', ' ');
    if (text.isNotEmpty) {
      return text.length > 120 ? '${text.substring(0, 120)}…' : text;
    }
    return ElementNames.of(l, e);
  }

  /// "Slide 4: Our mission" (the quoted text of a slide comment).
  String slideQuote(SlidesLocalizations l, String slideId) =>
      l.commentSlideQuote(
        editor.order.indexOf(slideId) + 1,
        _titleOr(l, slideId),
      );

  String _titleOr(SlidesLocalizations l, String slideId) {
    final t = SlideLabels.title(model, slideId);
    return t.isEmpty ? l.slideUntitled : t;
  }

  @override
  String? labelFor(CommentThreadView thread) {
    final a = anchorOf(thread);
    final q = thread.quotedText;
    if (a == null || a.kind == CommentAnchorKind.document) return q;
    final l = slidesL10nOf(services);
    final slide = slideOf(a);
    if (slide == null || thread.status == CommentStatus.orphaned) {
      return q == null || q.isEmpty
          ? l.commentAnchorDeleted
          : l.commentAnchorDeletedQuote(q);
    }
    // Slide labels follow the slide's number and title.
    if (a.kind == CommentAnchorKind.slide) return slideQuote(l, slide);
    return q;
  }

  @override
  num positionOf(CommentThreadView thread) {
    final a = anchorOf(thread);
    final slide = a == null ? null : slideOf(a);
    if (a == null || slide == null) return double.maxFinite;
    final index = editor.order.indexOf(slide);
    if (index < 0) return double.maxFinite;
    return index * 1e11 +
        _readingKey(PlacedDeckThread(thread, a, slide)).clamp(-1, 1e10) +
        1;
  }

  /// Shows [thread]'s anchor: Normal view on its slide, the element
  /// selected (09 §3.4).
  @override
  void reveal(CommentThreadView thread) {
    final a = anchorOf(thread);
    final slide = a == null ? null : slideOf(a);
    if (a == null || slide == null) return;
    if (editor.mode != DeckViewMode.normal) editor.setMode(DeckViewMode.normal);
    textEditingOf(editor).commit();
    editor.setCurrentSlide(slide);
    if (a.elementId != null) {
      editor.selectElements([a.elementId!]);
    } else {
      editor.clearElementSelection();
    }
    dockDismissed.value = false;
  }

  @override
  void onThreadCreated(CommentThreadView thread) {
    _click = null;
    dockDismissed.value = false;
    _onThreads();
  }

  @override
  void onThreadDeleted(CommentThreadView thread) => _onThreads();

  /// The open thread on the selected element (or the current slide when
  /// nothing is selected), for the panel's active card.
  @override
  String? get activeThreadUuid {
    final slide = editor.currentSlideId;
    if (slide == null) return null;
    final ids = editor.selectedElementIds.toSet();
    for (final p in threadsOn(slide)) {
      if (ids.isEmpty ? p.elementId == null : ids.contains(p.elementId)) {
        return p.uuid;
      }
    }
    return null;
  }

  // -------------------------------------------------- CommentPanelOptions

  /// New comments compose next to their pin while the panel is closed.
  @override
  bool get composesInline => true;

  @override
  Map<String, String> get scopes {
    final l = slidesL10nOf(services);
    return {scopeSlide: l.commentsScopeSlide, scopeAll: l.commentsScopeAll};
  }

  @override
  String? get defaultScope => scopeAll;

  @override
  bool inScope(CommentThreadView thread, String scope) {
    if (scope != scopeSlide) return true;
    final a = anchorOf(thread);
    return a != null &&
        editor.currentSlideId != null &&
        slideOf(a) == editor.currentSlideId;
  }

  /// "4 · Our mission" headers in presentation order; "Orphaned" last.
  @override
  String? groupOf(CommentThreadView thread) {
    final a = anchorOf(thread);
    if (a == null || a.kind == CommentAnchorKind.document) return null;
    final l = slidesL10nOf(services);
    final slide = slideOf(a);
    if (slide == null || thread.status == CommentStatus.orphaned) {
      return l.commentsOrphanedGroup;
    }
    return l.commentsSlideHeader(
      editor.order.indexOf(slide) + 1,
      _titleOr(l, slide),
    );
  }

  /// Slide groups as sections (color dot + title) above the slide headers.
  @override
  CommentPanelSection? sectionOf(CommentThreadView thread) {
    final a = anchorOf(thread);
    final slide = a == null ? null : slideOf(a);
    if (slide == null || thread.status == CommentStatus.orphaned) return null;
    final groupId = editor.order.entry(slide)?.groupId;
    final g = groupId == null ? null : model.group(groupId);
    if (g == null) return null;
    final l = slidesL10nOf(services);
    final color = g.color;
    return CommentPanelSection(
      id: g.id,
      title: g.title.isEmpty ? l.groupUntitled : g.title,
      leading: (context) {
        final c = SlidesTokens.of(context).groupColor(color);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: c ?? const Color(0x00000000),
            shape: BoxShape.circle,
            border: c == null
                ? Border.all(color: const Color(0xff9ca3af))
                : null,
          ),
        );
      },
    );
  }

  // ----------------------------------------------------- next / previous

  /// The next (or previous) open thread after the current position in
  /// presentation order, wrapping around (09 §3.4). The position is the
  /// active thread, else the current slide (before its threads).
  PlacedDeckThread? neighbor({required bool forward}) {
    final list = readingOrder;
    if (list.isEmpty) return null;
    final active = _controller?.activeThreadUuid;
    final at = active == null ? -1 : list.indexWhere((p) => p.uuid == active);
    if (at >= 0) {
      return list[(at + (forward ? 1 : -1)) % list.length];
    }
    final slide = editor.currentSlideId;
    final here = slide == null ? 0 : editor.order.indexOf(slide);
    int indexOf(PlacedDeckThread p) => editor.order.indexOf(p.slideId);
    if (forward) {
      return list.where((p) => indexOf(p) >= here).firstOrNull ?? list.first;
    }
    return list.reversed.where((p) => indexOf(p) < here).firstOrNull ??
        list.last;
  }

  /// Shows [uuid] in place: reveals its anchor, makes it the active thread
  /// and undocks the card (`slides.comments.show`).
  bool show(String uuid) {
    final c = _controller;
    final t = c?.thread(uuid);
    if (c == null || t == null) return false;
    c.activate(uuid);
    dockDismissed.value = false;
    return true;
  }

  String? _deepLink;

  /// `?comment=<threadUuid>` (09 §3.4, notification emails): once the
  /// threads are loaded, opens the thread's slide, selects its element and
  /// shows the thread card (orphaned threads in the comments panel).
  void openDeepLink(String threadUuid) {
    _deepLink = threadUuid;
    _openDeepLink();
  }

  void _openDeepLink() {
    final id = _deepLink;
    final c = _controller;
    if (id == null || c == null || c.loading) return;
    _deepLink = null;
    if (c.thread(id) == null) return;
    if (placed(id) == null) services.panels.open(ShellPanels.comments);
    show(id);
  }

  /// Comment counts for MCP `ui.get_state`.
  Map<String, Object?> describeState() => {
    'openComments': readingOrder.length,
    'activeComment': _controller?.activeThreadUuid,
    'commentPins': pinsOn,
  };

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    moves.dispose();
    services.comments.removeListener(_onControllerChanged);
    editor.removeListener(_onEditor);
    editor.model.removeListener(_onModel);
    _controller?.removeListener(_onThreads);
    if (_controller?.anchors == this) _controller?.anchors = null;
    dockDismissed.dispose();
    if (identical(_of[editor], this)) _of[editor] = null;
    super.dispose();
  }
}
