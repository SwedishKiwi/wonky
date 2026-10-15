import 'dart:async';

import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_slides/features/ai/slides_ai_api.dart';

/// An in-memory [SlidesAiApi] for widget tests (no model calls): scripted
/// answers per feature, recorded requests.
class FakeSlidesAiApi implements SlidesAiApi {
  /// Events of the next outline / rewrite streams, in order.
  final List<List<InlineAiEvent>> outlineScripts = [];
  final List<List<InlineAiEvent>> rewriteScripts = [];

  /// Answers of the other calls.
  SlidesAiBuildResult? buildResult;
  List<SlidesAiNote> notes = const [];
  List<SlidesAiAltText> altTexts = const [];
  List<SlidesAiDesignRank> ranks = const [];
  final Map<String, SlidesAiPreview> previews = {};
  SlidesAiApplyResult applyResult = SlidesAiApplyResult(
    changeId: '00000000-0000-7000-8000-0000000000aa',
    label: 'AI: Apply 1 suggestion',
    appliedCalls: 1,
    skipped: 0,
  );

  /// Errors thrown by the next unary call (AI unavailable, …).
  Object? failWith;

  final List<SlidesAiOutlineRequest> outlineRequests = [];
  final List<SlidesAiRewriteRequest> rewriteRequests = [];
  final List<Map<String, Object?>> builds = [];
  final List<(List<String>, String, String, String)> notesRequests = [];
  final List<List<String>> altRequests = [];
  final List<List<String>> rankRequests = [];
  final List<(String, List<String>?)> applied = [];
  final List<String> discarded = [];
  final List<String> reverted = [];

  static InlineAiEvent done(String markdown) =>
      InlineAiEvent(type: InlineAiEventType.done, markdown: markdown);

  static InlineAiEvent delta(String text) =>
      InlineAiEvent(type: InlineAiEventType.textDelta, text: text);

  Stream<InlineAiEvent> _play(List<List<InlineAiEvent>> scripts) {
    final events = scripts.isEmpty ? <InlineAiEvent>[] : scripts.removeAt(0);
    return Stream.fromIterable(events);
  }

  void _maybeFail() {
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Stream<InlineAiEvent> proposeOutline(
    UuidValue? itemUuid,
    SlidesAiOutlineRequest request,
  ) {
    outlineRequests.add(request);
    return _play(outlineScripts);
  }

  @override
  Future<SlidesAiBuildResult> buildDeck({
    UuidValue? itemUuid,
    required String outlineJson,
    String? afterSlideId,
    bool notes = true,
    bool groups = true,
    UuidValue? parentUuid,
  }) async {
    _maybeFail();
    builds.add({
      'itemUuid': itemUuid?.uuid,
      'outline': outlineJson,
      'after': afterSlideId,
      'notes': notes,
      'groups': groups,
    });
    return buildResult ??
        SlidesAiBuildResult(
          itemUuid: itemUuid ?? UuidValue.fromString(_newDeck),
          changeId: itemUuid == null
              ? null
              : '00000000-0000-7000-8000-0000000000bb',
          slideIds: const [],
          warnings: const [],
        );
  }

  static const _newDeck = '00000000-0000-4000-8000-00000000ffff';

  @override
  Stream<InlineAiEvent> rewrite(
    UuidValue itemUuid,
    SlidesAiRewriteRequest request,
  ) {
    rewriteRequests.add(request);
    return _play(rewriteScripts);
  }

  @override
  Future<List<SlidesAiNote>> writeNotes(
    UuidValue itemUuid,
    List<String> slideIds, {
    required String length,
    required String style,
    required String mode,
  }) async {
    _maybeFail();
    notesRequests.add((slideIds, length, style, mode));
    return notes;
  }

  @override
  Future<List<SlidesAiAltText>> describeElements(
    UuidValue itemUuid,
    List<String> elementIds,
  ) async {
    _maybeFail();
    altRequests.add(elementIds);
    return altTexts;
  }

  @override
  Future<List<SlidesAiDesignRank>> rankDesigns(
    UuidValue itemUuid,
    String slideId,
    List<String> candidates,
  ) async {
    rankRequests.add(candidates);
    return ranks;
  }

  @override
  Future<SlidesAiPreview> getPreview(String previewId) async {
    final p = previews[previewId];
    if (p == null) {
      throw WonkyException(
        code: WonkyErrorCode.expired,
        message: 'These suggestions have expired.',
      );
    }
    return p;
  }

  @override
  Future<SlidesAiApplyResult> applyPreview(
    String previewId,
    List<String>? callIds,
  ) async {
    applied.add((previewId, callIds));
    return applyResult;
  }

  @override
  Future<void> discardPreview(String previewId) async {
    discarded.add(previewId);
  }

  @override
  Future<void> revertChange(UuidValue changeId) async {
    reverted.add(changeId.uuid);
  }
}
