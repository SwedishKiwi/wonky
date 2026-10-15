import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show
        AccessRole,
        ActorKind,
        Participant,
        PresenceEvent,
        PresenceHints,
        PresenceJoined,
        PresenceLeft,
        PresenceRoster,
        PresenceState,
        PresenceUpdate,
        PresenceUpdated,
        UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides/features/canvas/slide_canvas.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/collab/slides_collab.dart';
import 'package:wonky_slides/features/collab/slides_presence_cursor.dart';
import 'package:wonky_slides/features/editor_screen/canvas_region.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/text_editing/text_editing_host.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart'
    show GroupNode, SceneNode, SlideScene, TextNode;

import '../../harness/deck_harness.dart';
import '../../support/slides_harness.dart';
import '../stage/stage_fixture.dart' show RecordingFontRegistry;
import '../text_editing/text_canvas_rig.dart' show TextCanvasFixture;

/// A presence stream the test drives: records this window's updates and
/// emits server events.
class FakePresenceRepository implements PresenceRepository {
  final events = StreamController<PresenceEvent>.broadcast();
  final List<PresenceUpdate> updates = [];

  @override
  Stream<PresenceEvent> join(
    UuidValue itemUuid,
    Stream<PresenceUpdate> updates,
  ) {
    updates.listen(this.updates.add);
    return events.stream;
  }

  void emit(PresenceEvent e) => events.add(e);
}

/// A participant of the deck.
Participant participant(
  String sessionId, {
  int userId = 2,
  String name = 'Anna',
  String? cursorJson,
  PresenceState state = PresenceState.active,
  String mode = 'editing',
  int colorIndex = 3,
  ActorKind actorKind = ActorKind.user,
  DateTime? joinedAt,
}) => Participant(
  sessionId: sessionId,
  userId: userId,
  userUuid: UuidValue.fromString(
    '00000000-0000-4000-8000-${userId.toRadixString(16).padLeft(12, '0')}',
  ),
  displayName: name,
  colorIndex: colorIndex,
  role: AccessRole.editor,
  actorKind: actorKind,
  state: state,
  mode: mode,
  cursorJson: cursorJson,
  joinedAt: joinedAt ?? DateTime.utc(2026, 10, 1),
);

/// The text of [elementId]'s text node in [scene] (null: none).
String? sceneText(SlideScene scene, String elementId) {
  String? walk(SceneNode n, bool inside) {
    final mine = inside || n.elementId == elementId;
    if (n is TextNode && mine) {
      return [
        for (final l in n.layout.lines)
          for (final r in l.runs) r.text,
      ].join();
    }
    if (n is GroupNode) {
      for (final c in n.children) {
        final t = walk(c, mine);
        if (t != null) return t;
      }
    }
    return null;
  }

  for (final n in scene.nodes) {
    final t = walk(n, false);
    if (t != null) return t;
  }
  return null;
}

/// Two simulated users on one deck (Slides 09 §10): this window ("me",
/// Viktor) is a [DeckHarness] with the canvas region, a [PresenceSession]
/// on a [FakePresenceRepository] and the collaboration features attached;
/// Anna (and Bo) are remote participants whose cursors and hints the test
/// emits.
class CollabRig {
  CollabRig._(this.d, this.f, this.c, this.repo, this.session, this.collab);

  final DeckHarness d;
  final TextCanvasFixture f;
  final SlideCanvasController c;
  final FakePresenceRepository repo;
  final PresenceSession session;
  final SlidesCollab collab;

  static final me = participant('me', userId: 1, name: 'Viktor');
  static final anna = participant('anna', name: 'Anna', colorIndex: 3);
  static final bo = participant('bo', userId: 3, name: 'Bo', colorIndex: 5);

  static Future<CollabRig> pump(
    WidgetTester tester, {
    Size size = const Size(1000, 600),
    Brightness brightness = Brightness.light,
    Role role = Role.owner,
    List<Participant>? others,
  }) async {
    final f = TextCanvasFixture();
    final repo = FakePresenceRepository();
    final d = DeckHarness.open(fixture: f.b, role: role, presence: repo);
    final renderer = SlideRenderer(
      model: d.session.model,
      fonts: RecordingFontRegistry(),
    );
    final c = SlideCanvasController.attach(d.editor, renderer: renderer);
    final session = PresenceSession(
      services: d.services,
      itemUuid: d.session.itemUuid,
    )..mode = 'editing';
    session.start();
    final collab = SlidesCollab.attach(d.editor);
    d.doc.attachPresence(session);
    late final CollabRig r;
    addTearDown(() async {
      r._dispose();
      c.dispose();
      renderer.dispose();
      await d.dispose();
    });
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
    r = CollabRig._(d, f, c, repo, session, collab);
    r.repo.emit(
      PresenceRoster(sessionId: 'me', participants: [me, ...?others]),
    );
    await tester.pump();
    return r;
  }

  bool _closed = false;

  void _dispose() {
    if (_closed) return;
    _closed = true;
    textEditingOf(d.editor).dispose();
    collab.dispose();
    session.dispose();
  }

  /// Ends the test: disposes the presence session and the collaboration
  /// features (their timers) and the widget tree.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    _dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  DeckModel get model => d.model;
  SlideTextEditing get text => textEditingOf(d.editor);

  /// A participant joins with [cursor].
  Future<void> join(
    WidgetTester tester,
    Participant p, [
    SlidesPresenceCursor? cursor,
  ]) async {
    repo.emit(
      PresenceJoined(participant: p.copyWith(cursorJson: cursor?.encode())),
    );
    await tester.pump();
    await tester.pump();
  }

  /// [sessionId]'s cursor changes.
  Future<void> move(
    WidgetTester tester,
    String sessionId,
    SlidesPresenceCursor cursor, {
    PresenceState state = PresenceState.active,
  }) async {
    repo.emit(
      PresenceUpdated(
        sessionId: sessionId,
        state: state,
        cursorJson: cursor.encode(),
        mode: 'editing',
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> leave(WidgetTester tester, String sessionId) async {
    repo.emit(PresenceLeft(sessionId: sessionId));
    await tester.pump();
    await tester.pump();
  }

  /// [sessionId] sends [hints].
  Future<void> hints(
    WidgetTester tester,
    String sessionId,
    List<Map<String, Object?>> hints,
  ) async {
    repo.emit(
      PresenceHints(
        sessionId: sessionId,
        hints: [for (final h in hints) jsonEncode(h)],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// The cursors this window sent (parsed).
  List<SlidesPresenceCursor> get sent => [
    for (final u in repo.updates) ?SlidesPresenceCursor.tryParse(u.cursorJson),
  ];

  /// The last cursor sent (after the 100 ms throttle).
  Future<SlidesPresenceCursor> lastSent(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 150));
    return sent.last;
  }

  /// The hints this window sent (parsed).
  List<Map<String, Object?>> get sentHints => [
    for (final u in repo.updates)
      for (final h in u.hints ?? const <String>[])
        (jsonDecode(h) as Map).cast<String, Object?>(),
  ];

  /// A text claim on element [id] of the current slide.
  EditingClaim claim(String id, {int since = 1000, bool forced = false}) =>
      EditingClaim(
        kind: 'text',
        slideId: d.editor.currentSlideId,
        elementId: id,
        since: since,
        forced: forced,
      );

  /// Anna's cursor on the current slide.
  SlidesPresenceCursor cursor({
    List<String> selection = const [],
    EditingClaim? editing,
    String? slideId,
    PresentingState? presenting,
    DeckViewport? viewport,
    String? following,
  }) => SlidesPresenceCursor(
    slideId: slideId ?? d.editor.currentSlideId,
    selection: selection,
    editing: editing,
    presenting: presenting,
    viewport: viewport,
    following: following,
  );

  /// The text of [id] in the canvas' stage scene (hints applied).
  String? stageText(WidgetTester tester, String id) {
    final canvas = tester.widget<SlideCanvas>(find.byType(SlideCanvas));
    var scene = canvas.controller.scene!;
    scene = collab.hints.hintedScene(scene, canvas.controller);
    return sceneText(scene, id);
  }

  String textOf(String id) => SlidesText.plainText(model.element(id)?.text);

  /// Global position of slide point ([x], [y]).
  Offset at(WidgetTester tester, double x, double y) =>
      tester.getTopLeft(find.byType(SlideCanvas)) +
      c.viewport.toViewport(Offset(x, y));

  int _time = 1000;
  Duration _next([int ms = 1000]) => Duration(milliseconds: _time += ms);

  Future<void> click(WidgetTester tester, double x, double y) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.down(at(tester, x, y), timeStamp: _next());
    await g.up(timeStamp: _next(10));
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  Future<void> doubleClick(WidgetTester tester, double x, double y) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final p = at(tester, x, y);
    await g.down(p, timeStamp: _next());
    await g.up(timeStamp: _next(20));
    await g.down(p, timeStamp: _next(80));
    await g.up(timeStamp: _next(20));
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }
}
