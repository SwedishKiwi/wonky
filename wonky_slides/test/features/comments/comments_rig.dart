import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show
        ActorKind,
        CommentAnchorKind,
        CommentEvent,
        CommentFilter,
        CommentStatus,
        CommentThreadView,
        CommentView,
        UuidValue;
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_slides/config/slides_features.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/comments/slides_comments.dart';
import 'package:wonky_slides/features/editor_screen/canvas_region.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/text_editing/text_editing_host.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/testing.dart';

import '../../harness/deck_harness.dart';
import '../../support/slides_harness.dart';
import '../stage/stage_fixture.dart' show RecordingFontRegistry;

/// In-memory comments with the server's basic semantics; records anchor
/// moves.
class FakeCommentRepository implements CommentRepository {
  final Map<String, CommentThreadView> threads = {};
  final events = StreamController<CommentEvent>.broadcast();
  final List<(String, String)> anchorMoves = [];
  int _next = 1;
  int _seeded = 0;

  CommentThreadView _put(CommentThreadView t) => threads[t.uuid.uuid] = t;

  /// Seeds a thread by [author] (default Anna, the signed-in test user).
  CommentThreadView seed({
    required CommentAnchorKind kind,
    required String anchorJson,
    String body = 'Seeded',
    String? quotedText,
    CommentStatus status = CommentStatus.open,
    String? uuid,
  }) {
    final id = UuidValue.fromString(
      uuid ??
          '0190a000-0000-7000-8000-${(++_seeded).toRadixString(16).padLeft(12, '0')}',
    );
    return _put(
      CommentThreadView(
        uuid: id,
        itemUuid: UuidValue.fromString('00000000-0000-7000-8000-000000000000'),
        anchorKind: kind,
        anchorJson: anchorJson,
        quotedText: quotedText,
        status: status,
        createdBy: TestUsers.anna,
        createdAt: DateTime.utc(2026, 10, 1),
        comments: [_comment(id, body)],
      ),
    );
  }

  @override
  Future<List<CommentThreadView>> listThreads(
    UuidValue itemUuid, {
    CommentFilter filter = CommentFilter.all,
  }) async => threads.values.toList();

  @override
  Future<CommentThreadView> createThread({
    required UuidValue threadUuid,
    required UuidValue itemUuid,
    required CommentAnchorKind anchorKind,
    required String anchorJson,
    String? quotedText,
    required String body,
    List<int> mentions = const [],
    int? assigneeId,
  }) async => _put(
    CommentThreadView(
      uuid: threadUuid,
      itemUuid: itemUuid,
      anchorKind: anchorKind,
      anchorJson: anchorJson,
      quotedText: quotedText,
      status: CommentStatus.open,
      createdBy: TestUsers.anna,
      createdAt: DateTime.utc(2026, 10, 1),
      comments: [_comment(threadUuid, body)],
    ),
  );

  CommentView _comment(UuidValue thread, String body) => CommentView(
    id: _next++,
    threadUuid: thread,
    author: TestUsers.anna,
    authorKind: ActorKind.user,
    body: body,
    mentions: const [],
    reactions: const {},
    createdAt: DateTime.utc(2026, 10, 1),
    deleted: false,
  );

  @override
  Future<CommentThreadView> reply(
    UuidValue threadUuid, {
    required String body,
    List<int> mentions = const [],
    UuidValue? commentUuid,
  }) async {
    final t = threads[threadUuid.uuid]!;
    return _put(
      t.copyWith(comments: [...t.comments, _comment(threadUuid, body)]),
    );
  }

  @override
  Future<CommentView> edit(int commentId, String body) =>
      throw UnimplementedError();

  @override
  Future<void> delete(int commentId) async {}

  @override
  Future<void> deleteThread(UuidValue threadUuid) async =>
      threads.remove(threadUuid.uuid);

  @override
  Future<CommentThreadView> resolve(UuidValue threadUuid) async =>
      _put(threads[threadUuid.uuid]!.copyWith(status: CommentStatus.resolved));

  @override
  Future<CommentThreadView> reopen(UuidValue threadUuid) async =>
      _put(threads[threadUuid.uuid]!.copyWith(status: CommentStatus.open));

  @override
  Future<CommentView> react(int commentId, String emoji) =>
      throw UnimplementedError();

  @override
  Future<CommentThreadView> updateAnchor(
    UuidValue threadUuid,
    String anchorJson,
  ) async {
    anchorMoves.add((threadUuid.uuid, anchorJson));
    final t = threads[threadUuid.uuid]!;
    return _put(
      t.copyWith(
        anchorJson: anchorJson,
        status: t.status == CommentStatus.orphaned
            ? CommentStatus.open
            : t.status,
      ),
    );
  }

  @override
  Stream<CommentEvent> watch(UuidValue itemUuid) => events.stream;
}

/// A deck with two slides (the second in group "Intro"), a text box and a
/// shape on slide 1, a text box on slide 2.
class CommentsFixture {
  CommentsFixture() {
    s1 = b.slide(layoutKey: 'title', title: 'Our mission');
    box = b.textBox(s1, 'Revenue grew', x: 100, y: 600);
    shape = b.shape(s1, x: 900, y: 100);
    group = b.group('Intro', color: 'blue');
    s2 = b.slide(layoutKey: 'blank', groupId: group);
    note = b.textBox(s2, 'Second slide text', x: 100, y: 100);
  }

  final b = DeckBuilder(title: 'Launch');
  late final String group, s1, s2, box, shape, note;
}

/// Comments on a headless deck (Slides 09 §3): a [DeckHarness] with the
/// shell's comments controller on a [FakeCommentRepository] and the Slides
/// comments attached; [pump] adds the canvas region.
class CommentsRig {
  CommentsRig._(this.d, this.f, this.repo, this.controller, this.comments);

  final DeckHarness d;
  final CommentsFixture f;
  final FakeCommentRepository repo;
  final CommentsController controller;
  final SlidesComments comments;
  SlideCanvasController? canvas;
  SlideRenderer? _renderer;

  static Future<CommentsRig> open({
    Role role = Role.owner,
    FakeCommentRepository? repo,
    CommentsFixture? fixture,
    bool viewersSeeComments = true,
  }) async {
    SlidesFeatures.enabled = {
      ...SlidesFeatures.shipped,
      SlidesFeature.comments,
    };
    final f = fixture ?? CommentsFixture();
    final r = repo ?? FakeCommentRepository();
    final d = DeckHarness.open(fixture: f.b, role: role, comments: r);
    final item = d.h.drive.item(d.session.itemUuid);
    d.services.currentItem.value = item.copyWith(
      viewersSeeComments: viewersSeeComments,
    );
    final controller = CommentsController(
      services: d.services,
      itemUuid: d.session.itemUuid,
    );
    d.services.comments.value = controller;
    final comments = SlidesComments.attach(d.editor);
    await controller.start();
    await pumpEventQueue();
    d.editor.setCurrentSlide(f.s1);
    return CommentsRig._(d, f, r, controller, comments);
  }

  /// Pumps the canvas region of the deck.
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1200, 760),
    Brightness brightness = Brightness.light,
  }) async {
    final renderer = _renderer = SlideRenderer(
      model: d.session.model,
      fonts: RecordingFontRegistry(),
    );
    canvas = SlideCanvasController.attach(d.editor, renderer: renderer);
    await pumpSlides(
      tester,
      d.h,
      CanvasRegion(
        services: d.services,
        editor: d.editor,
        onContextMenu: (_, _) {},
      ),
      size: size,
      brightness: brightness,
    );
  }

  DeckModel get model => d.model;
  ShellServices get services => d.services;

  Future<CommandResult> run(
    String id, [
    Map<String, Object?> args = const {},
  ]) => d.run(id, args);

  /// Creates a comment on the current selection; returns the thread uuid.
  Future<String> comment(String body) async {
    final r = await run('shell.comments.create', {'body': body});
    expect(r.isOk, isTrue, reason: r.message);
    return (r.data! as Map)['threadUuid'] as String;
  }

  CommentThreadView thread(String uuid) => controller.thread(uuid)!;

  Future<void> close([WidgetTester? tester]) async {
    if (tester != null) {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(_dispose);
      return;
    }
    await _dispose();
  }

  Future<void> _dispose() async {
    textEditingOf(d.editor).dispose();
    comments.dispose();
    controller.dispose();
    canvas?.dispose();
    _renderer?.dispose();
    await d.dispose();
    SlidesFeatures.reset();
  }
}
