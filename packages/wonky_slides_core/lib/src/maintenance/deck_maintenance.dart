import 'package:wonky_sync_models/ids.dart' show SlidesIds;

import '../model/api/deck_model.dart';
import '../model/api/kinds.dart';
import '../model/api/records.dart';
import '../model/index/deck_indexes.dart';
import '../ops/operations.dart';
import '../schema/slides_schema.dart';

/// Invariants and maintenance of a deck (02 §10).
///
/// After merges (debounced 1 s) the first editor client that detects a
/// violation — and the server writer before headless writes — plans
/// [repairOp] and executes it as a normal plan (`actorKind: user`, label
/// [label], **not** on the undo stack). Every rule is deterministic (same
/// state → same writes, deterministic ids for inserted rows), so
/// concurrent repairs on several replicas converge, and repairing twice
/// changes nothing ([detect] is empty after a repair).
abstract final class DeckMaintenance {
  /// The undo/change-log label of repairs.
  static const label = 'Repair presentation';

  /// A slide whose `groupId` names a missing group.
  static const orphanSlide = 'orphanSlide';

  /// Two instances on one slide pointing at the same layout placeholder.
  static const dupPlaceholder = 'dupPlaceholder';

  /// A placeholder instance whose `placeholderOf` is missing.
  static const danglingPlaceholder = 'danglingPlaceholder';

  /// An element in a parent cycle (the member with the smallest id).
  static const groupCycle = 'groupCycle';

  /// An element group without children.
  static const emptyGroup = 'emptyGroup';

  /// A child whose parent belongs to another owner.
  static const foreignParent = 'foreignParent';

  /// A child whose parent is missing or not an element group (SL-7
  /// addition; the engine cascades deletes, merges of concurrent edits may
  /// still leave one).
  static const missingParent = 'missingParent';

  /// `Deck.themeId` missing or naming a missing theme.
  static const missingDeckTheme = 'missingDeckTheme';

  /// No theme with a layout at all.
  static const noTheme = 'noTheme';

  /// Overlapping table merges (the merge whose origin has the larger id).
  static const mergeOverlap = 'mergeOverlap';

  /// A code element on a slide without states (placeholders excluded).
  static const codeWithoutState = 'codeWithoutState';

  /// A build whose element or slide is gone (06 A-06-8; SL-7 addition).
  static const orphanBuild = 'orphanBuild';

  /// Rule keys in repair order.
  static const rules = [
    noTheme,
    missingDeckTheme,
    orphanSlide,
    groupCycle,
    foreignParent,
    missingParent,
    emptyGroup,
    danglingPlaceholder,
    dupPlaceholder,
    mergeOverlap,
    codeWithoutState,
    orphanBuild,
  ];

  /// The id of the state inserted for a code element without states.
  static String repairCodeStateId(String elementId) =>
      SlidesIds.themePartId(elementId, 'repair:codeState');

  /// Every violation of [deck] that editors repair, in a deterministic
  /// order (rule order, then row id).
  static List<DeckViolation> detect(DeckModel deck) {
    final d = deck.deck;
    if (d == null) return const [];
    final ix = deck.indexes;
    final out = <DeckViolation>[];
    void add(String rule, String table, String id) =>
        out.add(DeckViolation(rule, table, id));

    // Themes.
    final hasLayout = deck.themes.any(
      (t) => ix.themes.layoutsOfTheme(t.id).isNotEmpty,
    );
    if (!hasLayout) add(noTheme, SlidesTables.deck, d.id);
    final themeId = d.themeId;
    if (deck.themes.isNotEmpty &&
        (themeId == null || deck.theme(themeId) == null)) {
      add(missingDeckTheme, SlidesTables.deck, d.id);
    }

    // Slide order.
    for (final e in ix.order.entries) {
      if (e.orphan) add(orphanSlide, SlidesTables.slide, e.id);
    }

    // Element trees of every owner.
    final owners = <String>{
      for (final r in deck.records(SlidesTables.slideElement))
        ?(r as SlideElementRec).ownerId,
    };
    for (final owner in (owners.toList()..sort())) {
      final tree = ix.tree(owner);
      for (final id in tree.cycleBreakers) {
        add(groupCycle, SlidesTables.slideElement, id);
      }
      for (final id in tree.foreignParent) {
        add(foreignParent, SlidesTables.slideElement, id);
      }
      for (final id in tree.missingParent) {
        add(missingParent, SlidesTables.slideElement, id);
      }
      for (final g in tree.emptyGroups) {
        add(emptyGroup, SlidesTables.slideElement, g.id);
      }
    }

    // Placeholders on slides.
    for (final s in deck.records(SlidesTables.slide)) {
      final byTarget = <String, List<SlideElementRec>>{};
      for (final e in ix.placeholders.instancesOf(s.id)) {
        final of = e.placeholderOf;
        if (of == null) continue;
        if (ix.placeholders.isDangling(e)) {
          add(danglingPlaceholder, SlidesTables.slideElement, e.id);
          continue;
        }
        (byTarget[of] ??= []).add(e);
      }
      for (final MapEntry(key: target, value: list) in byTarget.entries) {
        if (list.length < 2) continue;
        final keep = _keeper(s.id, target, list);
        for (final e in list) {
          if (e.id != keep) {
            add(dupPlaceholder, SlidesTables.slideElement, e.id);
          }
        }
      }
    }

    // Tables, code, builds.
    for (final r in deck.records(SlidesTables.slideElement)) {
      final e = r as SlideElementRec;
      switch (e.kind) {
        case ElementKind.table:
          for (final m in ix.table(e.id).overlapping) {
            add(mergeOverlap, SlidesTables.slideTableCell, m.origin.id);
          }
        case ElementKind.code:
          // Code placeholders (definitions and empty instances) hold no
          // states until code is inserted.
          if (e.slideId != null &&
              e.placeholderType == null &&
              deck.codeStatesOf(e.id).isEmpty) {
            add(codeWithoutState, SlidesTables.slideElement, e.id);
          }
        default:
          break;
      }
    }
    for (final r in deck.records(SlidesTables.slideBuild)) {
      final bd = r as SlideBuildRec;
      final el = bd.elementId == null ? null : deck.element(bd.elementId!);
      if (el == null ||
          bd.slideId == null ||
          deck.slide(bd.slideId!) == null ||
          el.slideId != bd.slideId) {
        add(orphanBuild, SlidesTables.slideBuild, bd.id);
      }
    }

    out.sort((a, b) {
      final r = rules.indexOf(a.rule).compareTo(rules.indexOf(b.rule));
      if (r != 0) return r;
      final t = a.table.compareTo(b.table);
      return t != 0 ? t : a.rowId.compareTo(b.rowId);
    });
    return out;
  }

  /// Of several instances on [slideId] pointing at [target], the one kept:
  /// the deterministic id, else the smallest id.
  static String _keeper(
    String slideId,
    String target,
    List<SlideElementRec> list,
  ) {
    final det = SlidesIds.placeholderInstanceId(slideId, target);
    if (list.any((e) => e.id == det)) return det;
    return (list.map((e) => e.id).toList()..sort()).first;
  }

  /// Whether [instance] is the kept one of its duplicates (public for the
  /// planner's re-check).
  static bool isKept(SlideElementRec instance, List<SlideElementRec> all) {
    final of = instance.placeholderOf;
    final slide = instance.slideId;
    if (of == null || slide == null) return true;
    final same = [
      for (final e in all)
        if (e.placeholderOf == of) e,
    ];
    if (same.length < 2) return true;
    return _keeper(slide, of, same) == instance.id;
  }

  /// The repair operation for [deck], or null when it holds no violation.
  static RepairDeck? repairOp(DeckModel deck) {
    final v = detect(deck);
    return v.isEmpty ? null : RepairDeck(v);
  }
}
