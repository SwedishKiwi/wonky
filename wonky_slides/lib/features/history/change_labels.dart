import 'package:wonky_client/wonky_client.dart' show UserSummary;
import 'package:wonky_slides_core/history.dart';
import 'package:wonky_slides_core/model.dart';

import '../../config/menus/slides_menu_spec.dart' show placeholderTypeLabel;
import '../../l10n/slides_l10n.dart';
import '../layers/element_names.dart';

/// Human texts of version changes (Slides 09 §4.2 step 4): "Title: text
/// edited — Anna", "Image added — Claude via MCP (Bo)", slide-level rows.
class VersionChangeLabels {
  VersionChangeLabels(
    this.l, {
    required this.authors,
    required this.changes,
    required this.someone,
  });

  final SlidesLocalizations l;

  /// The version's authors (user summaries by profile id).
  final List<UserSummary> authors;

  /// Who changed what (`slidesVersion.changes`).
  final SlidesVersionChanges changes;

  /// "Someone" (unknown authors).
  final String someone;

  /// The short label of an element: its name, its placeholder type or its
  /// kind ("Title", "Image", "Chart").
  String element(SlideElementRec e) {
    final name = e.name;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final p = e.placeholderType;
    if (p != null) return placeholderTypeLabel(l, p);
    return ElementNames.kind(l, e.kind);
  }

  /// The kinds of change, joined ("text edited, moved or resized").
  String kinds(Set<ElementChangeKind> kinds) => [
    for (final k in ElementChangeKind.values)
      if (kinds.contains(k))
        switch (k) {
          ElementChangeKind.text => l.versionKindText,
          ElementChangeKind.frame => l.versionKindFrame,
          ElementChangeKind.style => l.versionKindStyle,
          ElementChangeKind.data => l.versionKindData,
          ElementChangeKind.order => l.versionKindOrder,
          ElementChangeKind.visibility => l.versionKindVisibility,
          ElementChangeKind.animation => l.versionKindAnimation,
        },
  ].join(', ');

  /// What changed on [c] (without the author).
  String elementWhat(ElementChange c) => switch (c.status) {
    DiffStatus.added => l.versionElementAdded(element(c.record)),
    DiffStatus.removed => l.versionElementRemoved(element(c.record)),
    DiffStatus.changed => l.versionElementChange(
      element(c.record),
      kinds(c.kinds),
    ),
  };

  /// The display name of profile [id] (an agent's user as "Claude via MCP
  /// (Anna)"), or "Someone".
  String author(int? id) {
    if (id == null) return someone;
    final name =
        authors.where((a) => a.id == id).firstOrNull?.displayName ?? someone;
    final kinds = changes.agents[id];
    if (kinds == null || kinds.isEmpty) return name;
    return kinds.contains('mcp')
        ? l.versionAgentMcp(name)
        : l.versionAgentAi(name);
  }

  /// The author of an element change (its latest author, else the slide's,
  /// else the version's single author).
  int? authorOfElement(ElementChange c) =>
      changes.latestOfElement(c.id) ??
      changes.latestOfSlide(c.slideId) ??
      (authors.length == 1 ? authors.single.id : null);

  /// The author of a slide change.
  int? authorOfSlide(String slideId) =>
      changes.latestOfSlide(slideId) ??
      (authors.length == 1 ? authors.single.id : null);

  /// "{what} — {who}".
  String by(String what, int? authorId) =>
      l.versionChangeBy(what, author(authorId));

  /// The slide-level rows of [c] (added, moved, skip, own columns, builds),
  /// without the elements.
  List<String> slideRows(SlideChange c) => [
    if (c.status == DiffStatus.added) l.versionSlideAdded,
    if (c.status == DiffStatus.removed) l.versionSlideDeleted,
    if (c.moved) l.versionSlideMoved,
    if (c.skipToggled) l.versionSlideSkipToggled,
    for (final o in SlideOwnChange.values)
      if (c.own.contains(o))
        switch (o) {
          SlideOwnChange.background => l.versionSlideBackground,
          SlideOwnChange.layout => l.versionSlideLayout,
          SlideOwnChange.transition => l.versionSlideTransition,
          SlideOwnChange.notes => l.versionSlideNotes,
          SlideOwnChange.timings => l.versionSlideTimings,
          SlideOwnChange.masters => l.versionSlideMasters,
        },
    if (!c.builds.isEmpty)
      l.versionAnimations(c.builds.added + c.builds.removed + c.builds.changed),
  ];

  /// The deck-level rows (top of the change list): theme, settings,
  /// groups.
  List<String> deckRows(DeckDiff d) => [
    if (d.themeChanged) l.versionThemeChanged,
    if (d.deckChanged.isNotEmpty) l.versionDeckChanged,
    for (final g in d.groups.values)
      switch (g.status) {
        DiffStatus.added => l.versionGroupAdded(g.after?.title ?? ''),
        DiffStatus.removed => l.versionGroupRemoved(g.before?.title ?? ''),
        DiffStatus.changed => l.versionGroupChanged(g.after?.title ?? ''),
      },
  ];

  /// The version summary ("2 slides changed · 1 slide deleted · Theme
  /// changed"), or "No changes".
  String summary(DeckDiff d) {
    var added = 0, changed = 0, moved = 0;
    for (final c in d.slides.values) {
      if (c.status == DiffStatus.added) {
        added++;
      } else if (c.contentChanged || c.skipToggled) {
        changed++;
      } else if (c.moved) {
        moved++;
      }
    }
    final parts = [
      if (added > 0) l.versionSlidesAdded(added),
      if (changed > 0) l.versionSlidesChanged(changed),
      if (moved > 0) l.versionSlidesMoved(moved),
      if (d.removedSlides.isNotEmpty)
        l.versionSlidesDeleted(d.removedSlides.length),
      if (d.themeChanged) l.versionThemeChanged,
    ];
    return parts.isEmpty ? l.versionNoChanges : parts.join(' · ');
  }

  /// The plain title of a placeholder type (export for the conflicts).
  static String placeholder(SlidesLocalizations l, SlideElementRec e) =>
      e.placeholderType == null
      ? ElementNames.kind(l, e.kind)
      : placeholderTypeLabel(l, e.placeholderType!);
}
