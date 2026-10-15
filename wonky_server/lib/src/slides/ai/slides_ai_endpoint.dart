import 'package:serverpod/serverpod.dart';

import '../../platform/common/models.dart';
import '../../platform/users/user_service.dart';
import 'slides_ai_service.dart';

/// The AI features of Wonky Slides (Slides 11 §6–§9): *Generate
/// presentation* (outline, then build), *Rewrite text*, speaker notes, alt
/// text, the design-ideas ranking and the AI changes preview of
/// Suggest-mode assistant runs. The assistant panel itself uses
/// `assistant.chat` with the presentation's item uuid and the `slides*`
/// fields of [AssistantContextHints].
class SlidesAiEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Step 1 of *Generate presentation*: streams progress; `done.markdown`
  /// is the outline JSON. [itemUuid] = the open deck (insert) or null (a
  /// new presentation).
  Stream<InlineAiEvent> proposeOutline(
    Session session,
    UuidValue? itemUuid,
    SlidesAiOutlineRequest request,
  ) async* {
    final actor = await UserService.actorOf(session);
    yield* await SlidesAiService.proposeOutline(
      session,
      actor,
      itemUuid,
      request,
    );
  }

  /// Step 2: builds [outlineJson] into a new presentation ([itemUuid]
  /// null) or into the deck after [afterSlideId] (one undo step).
  Future<SlidesAiBuildResult> buildDeck(
    Session session,
    UuidValue? itemUuid,
    String outlineJson,
    String? afterSlideId,
    bool notes,
    bool groups,
    UuidValue? parentUuid,
  ) async => SlidesAiService.buildDeck(
    session,
    await UserService.actorOf(session),
    itemUuid: itemUuid,
    outlineJson: outlineJson,
    afterSlideId: afterSlideId,
    notes: notes,
    groups: groups,
    parentUuid: parentUuid,
  );

  /// *Rewrite text*: streams the rewritten Markdown (nothing is written).
  Stream<InlineAiEvent> rewrite(
    Session session,
    UuidValue itemUuid,
    SlidesAiRewriteRequest request,
  ) async* {
    final actor = await UserService.actorOf(session);
    yield* await SlidesAiService.rewrite(session, actor, itemUuid, request);
  }

  /// Speaker-notes proposals for [slideIds] (empty = all slides).
  Future<List<SlidesAiNote>> writeNotes(
    Session session,
    UuidValue itemUuid,
    List<String> slideIds,
    String length,
    String style,
    String mode,
  ) async => SlidesAiService.writeNotes(
    session,
    await UserService.actorOf(session),
    itemUuid,
    slideIds,
    length: length,
    style: style,
    mode: mode,
  );

  /// Alt-text proposals for [elementIds] (empty = every element missing
  /// alt text).
  Future<List<SlidesAiAltText>> describeElements(
    Session session,
    UuidValue itemUuid,
    List<String> elementIds,
  ) async => SlidesAiService.describeElements(
    session,
    await UserService.actorOf(session),
    itemUuid,
    elementIds,
  );

  /// Scores of the design-idea [candidates] (`id: description`) of
  /// [slideId].
  Future<List<SlidesAiDesignRank>> rankDesigns(
    Session session,
    UuidValue itemUuid,
    String slideId,
    List<String> candidates,
  ) async => SlidesAiService.rankDesigns(
    session,
    await UserService.actorOf(session),
    itemUuid,
    slideId,
    candidates,
  );

  /// The AI changes preview of a Suggest-mode run.
  Future<SlidesAiPreview> getPreview(Session session, String previewId) async =>
      SlidesAiService.getPreview(
        session,
        await UserService.actorOf(session),
        previewId,
      );

  /// Applies the checked calls (null = all) as one undo step.
  Future<SlidesAiApplyResult> applyPreview(
    Session session,
    String previewId,
    List<String>? callIds,
  ) async => SlidesAiService.applyPreview(
    session,
    await UserService.actorOf(session),
    previewId,
    callIds,
  );

  /// Discards a preview.
  Future<void> discardPreview(Session session, String previewId) async =>
      SlidesAiService.discardPreview(
        session,
        await UserService.actorOf(session),
        previewId,
      );
}
