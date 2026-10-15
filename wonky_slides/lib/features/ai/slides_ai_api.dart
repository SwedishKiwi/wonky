import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

/// The Slides AI endpoints (`slidesAi`, Slides 11 §6, §9) behind an
/// interface so widget tests use a fake (`FakeSlidesAiApi` in the tests'
/// support).
abstract class SlidesAiApi {
  /// *Generate presentation* step 1: progress, then `done.markdown` = the
  /// outline JSON. [itemUuid] = the open deck (insert) or null.
  Stream<InlineAiEvent> proposeOutline(
    UuidValue? itemUuid,
    SlidesAiOutlineRequest request,
  );

  /// Step 2: builds the outline (new deck when [itemUuid] is null).
  Future<SlidesAiBuildResult> buildDeck({
    UuidValue? itemUuid,
    required String outlineJson,
    String? afterSlideId,
    bool notes = true,
    bool groups = true,
    UuidValue? parentUuid,
  });

  /// *Rewrite text*: the rewritten Markdown, streamed.
  Stream<InlineAiEvent> rewrite(
    UuidValue itemUuid,
    SlidesAiRewriteRequest request,
  );

  /// Speaker-notes proposals.
  Future<List<SlidesAiNote>> writeNotes(
    UuidValue itemUuid,
    List<String> slideIds, {
    required String length,
    required String style,
    required String mode,
  });

  /// Alt-text proposals ([elementIds] empty = every missing one).
  Future<List<SlidesAiAltText>> describeElements(
    UuidValue itemUuid,
    List<String> elementIds,
  );

  /// Scores of design-idea candidates (`id: description`).
  Future<List<SlidesAiDesignRank>> rankDesigns(
    UuidValue itemUuid,
    String slideId,
    List<String> candidates,
  );

  /// The AI changes preview of a Suggest-mode run.
  Future<SlidesAiPreview> getPreview(String previewId);

  /// Applies the checked calls (null = all) as one server change.
  Future<SlidesAiApplyResult> applyPreview(
    String previewId,
    List<String>? callIds,
  );

  Future<void> discardPreview(String previewId);

  /// Undo of a server change when its undo step is gone (panel *Undo*).
  Future<void> revertChange(UuidValue changeId);
}

/// [SlidesAiApi] over the generated client.
class ServerSlidesAiApi implements SlidesAiApi {
  ServerSlidesAiApi(this.client);

  final Client client;

  EndpointSlidesAi get _a => client.slidesAi;

  @override
  Stream<InlineAiEvent> proposeOutline(
    UuidValue? itemUuid,
    SlidesAiOutlineRequest request,
  ) => _a.proposeOutline(itemUuid, request);

  @override
  Future<SlidesAiBuildResult> buildDeck({
    UuidValue? itemUuid,
    required String outlineJson,
    String? afterSlideId,
    bool notes = true,
    bool groups = true,
    UuidValue? parentUuid,
  }) => _a.buildDeck(
    itemUuid,
    outlineJson,
    afterSlideId,
    notes,
    groups,
    parentUuid,
  );

  @override
  Stream<InlineAiEvent> rewrite(
    UuidValue itemUuid,
    SlidesAiRewriteRequest request,
  ) => _a.rewrite(itemUuid, request);

  @override
  Future<List<SlidesAiNote>> writeNotes(
    UuidValue itemUuid,
    List<String> slideIds, {
    required String length,
    required String style,
    required String mode,
  }) => _a.writeNotes(itemUuid, slideIds, length, style, mode);

  @override
  Future<List<SlidesAiAltText>> describeElements(
    UuidValue itemUuid,
    List<String> elementIds,
  ) => _a.describeElements(itemUuid, elementIds);

  @override
  Future<List<SlidesAiDesignRank>> rankDesigns(
    UuidValue itemUuid,
    String slideId,
    List<String> candidates,
  ) => _a.rankDesigns(itemUuid, slideId, candidates);

  @override
  Future<SlidesAiPreview> getPreview(String previewId) =>
      _a.getPreview(previewId);

  @override
  Future<SlidesAiApplyResult> applyPreview(
    String previewId,
    List<String>? callIds,
  ) => _a.applyPreview(previewId, callIds);

  @override
  Future<void> discardPreview(String previewId) => _a.discardPreview(previewId);

  @override
  Future<void> revertChange(UuidValue changeId) async {
    await client.slides.revertChange(changeId);
  }
}

/// Used without a client (widget tests without a fake).
class UnavailableSlidesAiApi implements SlidesAiApi {
  const UnavailableSlidesAiApi();

  static final _error = WonkyException(
    code: WonkyErrorCode.unavailable,
    message: "AI isn't configured on this server.",
  );

  Never _fail() => throw _error;

  @override
  Stream<InlineAiEvent> proposeOutline(
    UuidValue? itemUuid,
    SlidesAiOutlineRequest request,
  ) => Stream.error(_error);

  @override
  Future<SlidesAiBuildResult> buildDeck({
    UuidValue? itemUuid,
    required String outlineJson,
    String? afterSlideId,
    bool notes = true,
    bool groups = true,
    UuidValue? parentUuid,
  }) async => _fail();

  @override
  Stream<InlineAiEvent> rewrite(
    UuidValue itemUuid,
    SlidesAiRewriteRequest request,
  ) => Stream.error(_error);

  @override
  Future<List<SlidesAiNote>> writeNotes(
    UuidValue itemUuid,
    List<String> slideIds, {
    required String length,
    required String style,
    required String mode,
  }) async => _fail();

  @override
  Future<List<SlidesAiAltText>> describeElements(
    UuidValue itemUuid,
    List<String> elementIds,
  ) async => _fail();

  @override
  Future<List<SlidesAiDesignRank>> rankDesigns(
    UuidValue itemUuid,
    String slideId,
    List<String> candidates,
  ) async => _fail();

  @override
  Future<SlidesAiPreview> getPreview(String previewId) async => _fail();

  @override
  Future<SlidesAiApplyResult> applyPreview(
    String previewId,
    List<String>? callIds,
  ) async => _fail();

  @override
  Future<void> discardPreview(String previewId) async {}

  @override
  Future<void> revertChange(UuidValue changeId) async => _fail();
}

/// The [SlidesAiApi] of each signed-in shell (tests install fakes).
abstract final class SlidesAiApis {
  static final Expando<SlidesAiApi> _apis = Expando('SlidesAiApi');

  /// The API of [services] (the server's, or the installed fake).
  static SlidesAiApi of(ShellServices services) {
    final installed = _apis[services];
    if (installed != null) return installed;
    final client = services.client;
    if (client == null) return const UnavailableSlidesAiApi();
    return _apis[services] = ServerSlidesAiApi(client);
  }

  /// Installs [api] for [services] (widget tests).
  static void install(ShellServices services, SlidesAiApi api) =>
      _apis[services] = api;
}
