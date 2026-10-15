import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

import '../support/screen_pump.dart';

/// Records what the thread asks for (the board implements the same
/// interface with its own commands).
class _FakeActions extends CommentThreadActions {
  _FakeActions({this.reactions = false});

  final bool reactions;
  final List<String> calls = [];

  @override
  String get threadId => 'post-7';

  @override
  String get keyPrefix => 'board.comments';

  @override
  int? get meId => 1;

  @override
  bool get canReply => true;

  @override
  bool canEdit(ThreadComment c) => c.authorId == 1;

  @override
  bool canDelete(ThreadComment c) => c.authorId == 1;

  @override
  int? get maxLength => 5000;

  @override
  Future<void> reply(String body, {List<int> mentions = const []}) async =>
      calls.add('reply:$body');

  @override
  Future<void> edit(ThreadComment c, String body) async =>
      calls.add('edit:${c.id}:$body');

  @override
  Future<void> delete(ThreadComment c) async => calls.add('delete:${c.id}');

  @override
  Future<void> Function(ThreadComment c, String emoji)? get react =>
      reactions ? (c, emoji) async => calls.add('react:${c.id}:$emoji') : null;
}

final _comments = [
  ThreadComment(
    id: 'c1',
    authorId: 2,
    authorName: 'Ada',
    authorColor: '#3b82f6',
    authorBadge: 'Admin',
    body: 'Looks **great**, see [the spec](https://wonky.work/spec).',
    createdAt: DateTime.utc(2026, 1, 1),
    reactions: const {
      '👍': [1, 2],
    },
  ),
  ThreadComment(
    id: 'sys',
    body: '',
    createdAt: DateTime.utc(2026, 1, 2),
    systemText: 'Ada claimed the task',
  ),
  ThreadComment(
    id: 'c2',
    authorId: 1,
    authorName: 'Me',
    authorColor: '#22c55e',
    body: 'Thanks',
    createdAt: DateTime.utc(2026, 1, 3),
  ),
];

void main() {
  late CommandTestHarness h;
  setUp(() => h = CommandTestHarness());
  tearDown(() => h.dispose());

  Future<void> pump(
    WidgetTester tester,
    _FakeActions actions, {
    Brightness brightness = Brightness.light,
  }) => pumpScreen(
    tester,
    h,
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 360,
        child: CommentThreadBody.custom(
          services: h.services,
          actions: actions,
          comments: _comments,
        ),
      ),
    ),
    brightness: brightness,
  );

  for (final b in Brightness.values) {
    testWidgets('Given custom actions in ${b.name} when rendering then bodies '
        'are Markdown, system rows are text and only own comments have a '
        'menu', (tester) async {
      await pump(tester, _FakeActions(), brightness: b);
      expect(find.text('Looks great, see the spec.'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('board.comments.event.sys')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('board.comments.comment.c1.menu')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('board.comments.comment.c2.menu')),
        findsOneWidget,
      );
      // No resolve and no reactions unless the actions offer them.
      expect(
        find.byKey(const ValueKey('board.comments.comment.c1.react')),
        findsNothing,
      );
      expect(find.textContaining('resolve'), findsNothing);
      await expectAccessible(tester);
    });
  }

  testWidgets('Given custom actions when replying then the Markdown composer '
      'sends the reply to the actions', (tester) async {
    final a = _FakeActions();
    await pump(tester, a);
    await tester.tap(
      find.byKey(const ValueKey<String>('board.comments.reply.post-7.open')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('board.comments.reply.post-7.bold')),
      findsOneWidget,
    );
    await enterMarkdown(
      tester,
      find.byKey(const ValueKey<String>('board.comments.reply.post-7')),
      '  Agreed  ',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('board.comments.reply.post-7.send')),
    );
    await tester.pumpAndSettle();
    expect(a.calls, ['reply:Agreed']);
  });

  testWidgets('Given custom actions when editing and deleting an own comment '
      'then the actions get them', (tester) async {
    final a = _FakeActions();
    await pump(tester, a);
    await tester.tap(
      find.byKey(const ValueKey<String>('board.comments.comment.c2.menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await enterMarkdown(
      tester,
      find.byKey(const ValueKey<String>('board.comments.comment.c2.edit')),
      'Thanks!',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('board.comments.comment.c2.save')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('board.comments.comment.c2.menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(a.calls, ['edit:c2:Thanks!', 'delete:c2']);
  });

  testWidgets('Given actions with reactions when tapping a reaction then it '
      'toggles through the actions', (tester) async {
    final a = _FakeActions(reactions: true);
    await pump(tester, a);
    await tester.tap(
      find.byKey(
        const ValueKey<String>('board.comments.comment.c1.reaction.👍'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('board.comments.comment.c2.react')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('🎉'));
    await tester.pumpAndSettle();
    expect(a.calls, ['react:c1:👍', 'react:c2:🎉']);
  });

  test('Given a document comment when adapting it then the author, body and '
      'system event map over', () {
    final l = lookupWonkyAppLocalizations(const Locale('en'));
    final view = CommentView(
      id: 4,
      threadUuid: UuidValue.fromString('0190a5b8-0000-7000-8000-000000000001'),
      author: null,
      authorKind: ActorKind.user,
      body: '',
      mentions: const [],
      reactions: const {},
      createdAt: DateTime.utc(2026),
      deleted: false,
      systemEvent: CommentSystemEvent.orphaned,
    );
    final c = ThreadComment.fromCommentView(view, l);
    expect(c.id, '4');
    expect(c.systemText, l.commentEventOrphanedBySystem);
    expect(c.source, same(view));
  });
}
