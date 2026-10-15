/// Animate pane / MCP edits as planner operations (06 §5, §15): adding
/// builds with catalog defaults, field patches (options as JSON merge
/// patches), reordering, removing, the animation painter (copy/paste) and
/// transitions (set, remove, apply to all, advance). Each helper returns one
/// operation = one undo step; validation happens in the planner.
library;

import 'dart:convert';

import '../../model/api/deck_reader.dart';
import '../../model/api/kinds.dart';
import '../../model/api/records.dart';
import '../../ops/operations.dart';
import '../../schema/slides_schema.dart' show BuildCols, SlidesCols;
import '../easing/motion_easing.dart';
import '../effects/effect_catalog.dart';
import 'build_options.dart';
import 'transition_spec.dart';

/// The builds of one element copied by *Copy animation* (06 §5.6).
final class CopiedBuilds {
  /// Creates a copy.
  const CopiedBuilds(this.builds);

  /// Column values of the copied builds in sequence order (without ids,
  /// slide, element and order).
  final List<Map<String, Object?>> builds;

  /// Whether nothing was copied.
  bool get isEmpty => builds.isEmpty;
}

/// Planner operations for build and transition edits.
abstract final class BuildEdits {
  /// A build of [effect] with the catalog's default duration and easing
  /// (06 §3), [params] and [delivery] in `optionsJson`.
  static BuildSpec spec({
    required String elementId,
    required SlideBuildKind kind,
    required String effect,
    Map<String, Object?>? params,
    BuildDelivery? delivery,
    AfterBuild? afterBuild,
    SlideBuildTrigger trigger = SlideBuildTrigger.onClick,
    int delayMs = 0,
    int? durationMs,
    String? easing,
  }) {
    final e = EffectCatalog.byId(kind, effect);
    final options = BuildOptions(
      params: params ?? const {},
      delivery: delivery ?? BuildDelivery.all,
      afterBuild: afterBuild ?? AfterBuild.none,
    );
    return BuildSpec(
      elementId: elementId,
      kind: kind,
      effect: effect,
      trigger: trigger,
      delayMs: delayMs,
      durationMs: durationMs ?? e?.defaultDurationMs ?? 500,
      easing: easing ?? e?.defaultEasing ?? 'easeOut',
      optionsJson: options.encode(),
    );
  }

  /// `slides.animate.addBuild` (06 §5.2): one build per element, appended
  /// after [afterBuildId] (null = the end); several elements are ordered
  /// by z-order top to bottom, the first `onClick` and the rest
  /// `withPrevious` ([alt] inverts; an explicit [trigger] applies to all).
  static AddBuilds add(
    DeckReader deck,
    String slideId,
    List<String> elementIds, {
    required SlideBuildKind kind,
    required String effect,
    Map<String, Object?>? params,
    BuildDelivery? delivery,
    AfterBuild? afterBuild,
    SlideBuildTrigger? trigger,
    bool alt = false,
    int delayMs = 0,
    int? durationMs,
    String? easing,
    String? afterBuildId,
  }) {
    final ordered = [...elementIds]
      ..sort((a, b) {
        final za = deck.element(a)?.zKey ?? '',
            zb = deck.element(b)?.zKey ?? '';
        final c = zb.compareTo(za);
        return c != 0 ? c : a.compareTo(b);
      });
    SlideBuildTrigger triggerOf(int i) {
      if (trigger != null) return trigger;
      final first = i == 0;
      return first != alt
          ? SlideBuildTrigger.onClick
          : SlideBuildTrigger.withPrevious;
    }

    return AddBuilds(slideId, [
      for (final (i, id) in ordered.indexed)
        spec(
          elementId: id,
          kind: kind,
          effect: effect,
          params: params,
          delivery: delivery,
          afterBuild: afterBuild,
          trigger: triggerOf(i),
          delayMs: delayMs,
          durationMs: durationMs,
          easing: easing,
        ),
    ], afterBuildId: afterBuildId);
  }

  /// `slides.animate.updateBuild` (06 §15): a field patch of [buildIds].
  /// Changing [effect] resets the duration, easing and params to the new
  /// effect's defaults unless given; [options] is a JSON merge patch over
  /// each build's current `optionsJson`; a [durationMs] of a spring-eased
  /// build also rewrites the spring's `d` (06 §4.3).
  static UpdateBuilds update(
    DeckReader deck,
    List<String> buildIds, {
    SlideBuildKind? kind,
    String? effect,
    SlideBuildTrigger? trigger,
    int? delayMs,
    int? durationMs,
    String? easing,
    Map<String, Object?>? options,
  }) {
    final updates = <String, Map<String, Object?>>{};
    for (final id in buildIds) {
      final b = deck.build(id);
      if (b == null) continue;
      final cols = <String, Object?>{};
      final k = kind ?? b.kind;
      var opts = _decodeMap(b.optionsJson);
      var dur = durationMs;
      var ease = easing;
      if (kind != null && kind != b.kind) cols[SlidesCols.kind] = kind.name;
      if (effect != null && (effect != b.effect || k != b.kind)) {
        final spec = EffectCatalog.byId(k, effect);
        cols[BuildCols.effect] = effect;
        dur ??= spec?.defaultDurationMs;
        ease ??= spec?.defaultEasing;
        opts?.remove('params');
      }
      if (options != null) opts = jsonMergePatch(opts, options);
      if (dur != null) {
        final curve = MotionEasing.tryParse(ease ?? b.easing);
        if (curve is SpringEasing) {
          ease = curve.withDuration(dur <= 0 ? curve.d : dur / 1000).expression;
        }
        cols[BuildCols.durationMs] = dur;
      }
      if (ease != null) cols[BuildCols.easing] = ease;
      if (trigger != null) cols[BuildCols.trigger] = trigger.name;
      if (delayMs != null) cols[BuildCols.delayMs] = delayMs;
      if (options != null ||
          (effect != null && cols.containsKey(BuildCols.effect))) {
        cols[BuildCols.optionsJson] = opts == null || opts.isEmpty
            ? null
            : jsonEncode({'v': 1, ...opts});
      }
      if (cols.isNotEmpty) updates[id] = cols;
    }
    return UpdateBuilds(updates);
  }

  /// `slides.animate.moveBuilds` (06 §5.4): moves [buildIds] to [index] of
  /// the slide's sequence (after removing them), or before/after a build;
  /// [trigger] is written on the first moved build ("New click").
  static MoveBuilds move(
    DeckReader deck,
    List<String> buildIds, {
    int? index,
    String? beforeBuildId,
    String? afterBuildId,
    SlideBuildTrigger? trigger,
  }) {
    if (index != null && buildIds.isNotEmpty) {
      final slideId = deck.build(buildIds.first)?.slideId;
      final moving = buildIds.toSet();
      final rest = [
        for (final b
            in slideId == null
                ? const <SlideBuildRec>[]
                : deck.buildsOf(slideId))
          if (!moving.contains(b.id)) b.id,
      ];
      final i = index.clamp(0, rest.length);
      if (i < rest.length) {
        return MoveBuilds(buildIds, beforeId: rest[i], trigger: trigger);
      }
      if (rest.isNotEmpty) {
        return MoveBuilds(buildIds, afterId: rest.last, trigger: trigger);
      }
    }
    return MoveBuilds(
      buildIds,
      beforeId: beforeBuildId,
      afterId: afterBuildId,
      trigger: trigger,
    );
  }

  /// `slides.animate.removeAll` (06 §15): every build of [slideIds].
  static DeleteBuilds removeAll(DeckReader deck, Iterable<String> slideIds) =>
      DeleteBuilds([
        for (final s in slideIds)
          for (final b in deck.buildsOf(s)) b.id,
      ]);

  /// *Copy animation* (06 §5.6): the builds of [elementId] in sequence
  /// order.
  static CopiedBuilds copy(DeckReader deck, String elementId) {
    final el = deck.element(elementId);
    final slideId = el?.slideId;
    if (slideId == null) return const CopiedBuilds([]);
    return CopiedBuilds([
      for (final b in deck.buildsOf(slideId))
        if (b.elementId == elementId)
          {
            SlidesCols.kind: b.kind.name,
            BuildCols.effect: b.effect,
            BuildCols.trigger: b.trigger.name,
            BuildCols.delayMs: b.delayMs,
            BuildCols.durationMs: b.durationMs,
            BuildCols.easing: b.easing,
            BuildCols.optionsJson: b.optionsJson,
          },
    ]);
  }

  /// *Paste animation* (06 §5.6): appends the copied builds for each of
  /// [elementIds] (on the slide of the first one) at the end of the
  /// sequence, triggers preserved. Null when nothing applies.
  static AddBuilds? paste(
    DeckReader deck,
    CopiedBuilds copied,
    List<String> elementIds,
  ) {
    if (copied.isEmpty || elementIds.isEmpty) return null;
    final slideId = deck.element(elementIds.first)?.slideId;
    if (slideId == null) return null;
    final specs = <BuildSpec>[];
    for (final id in elementIds) {
      if (deck.element(id)?.slideId != slideId) continue;
      for (final c in copied.builds) {
        specs.add(
          BuildSpec(
            elementId: id,
            kind:
                SlideBuildKind.fromName(c[SlidesCols.kind]) ??
                SlideBuildKind.buildIn,
            effect: c[BuildCols.effect] as String,
            trigger:
                SlideBuildTrigger.fromName(c[BuildCols.trigger]) ??
                SlideBuildTrigger.onClick,
            delayMs: c[BuildCols.delayMs] as int? ?? 0,
            durationMs: c[BuildCols.durationMs] as int? ?? 500,
            easing: c[BuildCols.easing] as String? ?? 'easeOut',
            optionsJson: c[BuildCols.optionsJson] as String?,
          ),
        );
      }
    }
    return specs.isEmpty ? null : AddBuilds(slideId, specs);
  }

  /// `slides.transition.set` (06 §15): [patch] (JSON merge patch) over
  /// the effective transition of the first of [slideIds], written to all
  /// of them. Throws [FormatException] for an invalid result.
  static SetSlideProps setTransition(
    DeckReader deck,
    List<String> slideIds,
    Map<String, Object?> patch,
  ) {
    final first = slideIds.isEmpty ? null : deck.slide(slideIds.first);
    final current = TransitionSpec.effective(
      first?.transitionJson,
      deck.deck?.defaultsJson,
    );
    final v = TransitionSpec.patch(current, patch);
    if (!v.isValid) {
      throw FormatException('Invalid transition: ${v.errors.first}');
    }
    return SetSlideProps(slideIds, transitionJson: Patch(v.value.encode()));
  }

  /// `slides.transition.remove`: an explicit cut on [slideIds].
  static SetSlideProps removeTransition(List<String> slideIds) => SetSlideProps(
    slideIds,
    transitionJson: Patch(TransitionSpec.none.encode()),
  );

  /// `slides.transition.setAdvance`: [advance] merged into the transition
  /// of [slideIds].
  static SetSlideProps setAdvance(
    DeckReader deck,
    List<String> slideIds,
    Map<String, Object?> advance,
  ) => setTransition(deck, slideIds, {'advance': advance});

  /// `slides.transition.applyToAll` (06 §15): writes [transition] (default:
  /// the effective transition of [fromSlideId]) as the deck default and
  /// resets every slide's own transition.
  static SetDeckProps applyTransitionToAll(
    DeckReader deck, {
    TransitionSpec? transition,
    String? fromSlideId,
  }) {
    final from = fromSlideId == null ? null : deck.slide(fromSlideId);
    final t =
        transition ??
        TransitionSpec.effective(from?.transitionJson, deck.deck?.defaultsJson);
    return SetDeckProps(
      defaultsJson: Patch(
        DeckMotionDefaults.withTransition(deck.deck?.defaultsJson, t),
      ),
      resetSlideTransitions: true,
    );
  }

  static Map<String, Object?>? _decodeMap(String? json) {
    if (json == null) return null;
    try {
      final v = jsonDecode(json);
      if (v is! Map<String, Object?>) return null;
      return {...v}..remove('v');
    } on FormatException {
      return null;
    }
  }
}
