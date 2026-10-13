import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/src/notifications/notifications_button.dart';
import 'package:wonky_app/src/notifications/notifications_controller.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';

final _now = DateTime(2026, 10, 13, 15);

NotificationView _n(
  int id, {
  NotificationKind kind = NotificationKind.mention,
  Map<String, Object?> payload = const {},
  DateTime? at,
  bool read = false,
}) => NotificationView(
  id: id,
  kind: kind,
  itemUuid: UuidValue.fromString('00000000-0000-4000-8000-0000000000aa'),
  itemName: 'Plan',
  itemKind: DriveItemKind.document,
  actor: TestUsers.bob,
  payload: jsonEncode(payload),
  createdAt: at ?? _now.subtract(Duration(minutes: id)),
  readAt: read ? _now : null,
);

Future<void> _pump(
  WidgetTester tester,
  NotificationsController c, {
  Brightness brightness = Brightness.light,
  ValueChanged<NotificationView>? onOpen,
  VoidCallback? onOpenSettings,
}) async {
  await pumpWonky(
    tester,
    Align(
      alignment: Alignment.topCenter,
      child: NotificationsPanel(
        controller: c,
        now: _now,
        onOpen: onOpen ?? (_) {},
        onOpenSettings: onOpenSettings ?? () {},
      ),
    ),
    brightness: brightness,
    extraDelegates: const [WonkyAppLocalizations.delegate],
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Given a notifications controller with 3 notifications', () {
    late FakeNotificationRepository repo;
    late NotificationsController c;
    setUp(() {
      repo = FakeNotificationRepository(
        items: [_n(3), _n(2), _n(1, read: true)],
      );
      c = NotificationsController(repo, pageSize: 2);
    });
    tearDown(() => c.dispose());

    test(
      'when loading then the first page and the unread count show',
      () async {
        await c.load();

        expect(c.items.map((n) => n.id), [3, 2]);
        expect(c.unreadCount, 2);
        expect(c.hasMore, isTrue);
      },
    );

    test('when loading more then the next page is appended', () async {
      await c.load();

      await c.loadMore();

      expect(c.items.map((n) => n.id), [3, 2, 1]);
      expect(c.hasMore, isFalse);
    });

    test('when filtering unread then read ones are left out', () async {
      await c.setUnreadOnly(true);

      expect(c.items.map((n) => n.id), [3, 2]);
      expect(c.hasMore, isFalse);
    });

    test(
      'when marking one read then the count drops and the server knows',
      () async {
        await c.load();

        await withClock(Clock.fixed(_now), () => c.markRead(c.items.first));

        expect(c.unreadCount, 1);
        expect(c.items.first.readAt, isNotNull);
        expect(repo.items.firstWhere((n) => n.id == 3).readAt, isNotNull);
      },
    );

    test('when marking all read then nothing is unread', () async {
      await c.load();

      await c.markAllRead();

      expect(c.unreadCount, 0);
      expect(repo.unreadCount, 0);
    });

    test(
      'when a live notification arrives then it is prepended once',
      () async {
        await c.load();
        final n = _n(4);

        c.onEvent(NotificationEvent(notification: n, unreadCount: 3));
        c.onEvent(NotificationEvent(notification: n, unreadCount: 3));

        expect(c.items.first.id, 4);
        expect(c.items.where((x) => x.id == 4), hasLength(1));
        expect(c.unreadCount, 3);
      },
    );
  });

  group('Given the notifications panel', () {
    late FakeNotificationRepository repo;
    late NotificationsController c;
    setUp(() {
      repo = FakeNotificationRepository(
        items: [
          _n(3, payload: {'excerpt': 'Can you check   the intro?'}),
          _n(
            2,
            kind: NotificationKind.suggestionDecided,
            payload: {'decision': 'accepted'},
          ),
          _n(
            1,
            kind: NotificationKind.shared,
            at: _now.subtract(const Duration(days: 9)),
            read: true,
          ),
        ],
      );
      c = NotificationsController(repo);
    });
    tearDown(() => c.dispose());

    testWidgets('when it shows then items are grouped with their excerpt', (
      tester,
    ) async {
      await c.load();
      await _pump(tester, c);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      expect(find.text('Bob Stone mentioned you in Plan'), findsOneWidget);
      expect(find.text('“Can you check the intro?”'), findsOneWidget);
      expect(
        find.text('Bob Stone accepted your suggestion in Plan'),
        findsOneWidget,
      );
    });

    testWidgets('when tapping an item then it is opened', (tester) async {
      await c.load();
      NotificationView? opened;
      await _pump(tester, c, onOpen: (n) => opened = n);

      await tester.tap(find.byKey(NotificationKeys.item(3)));

      expect(opened?.id, 3);
    });

    testWidgets('when pressing Enter on a focused item then it is opened', (
      tester,
    ) async {
      await c.load();
      NotificationView? opened;
      await _pump(tester, c, onOpen: (n) => opened = n);
      Focus.of(
        tester.element(
          find.descendant(
            of: find.byKey(NotificationKeys.item(2)),
            matching: find.byType(GestureDetector),
          ),
        ),
      ).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(opened?.id, 2);
    });

    testWidgets('when choosing Unread then only unread items show', (
      tester,
    ) async {
      await c.load();
      await _pump(tester, c);

      await tester.tap(find.byKey(NotificationKeys.filterUnread));
      await tester.pumpAndSettle();

      expect(find.byKey(NotificationKeys.item(1)), findsNothing);
      expect(find.byKey(NotificationKeys.item(3)), findsOneWidget);
    });

    testWidgets('when marking all read then nothing is unread', (tester) async {
      await c.load();
      await _pump(tester, c);

      await tester.tap(find.byKey(NotificationKeys.markAllRead));
      await tester.pumpAndSettle();

      expect(repo.unreadCount, 0);
      expect(c.unreadCount, 0);
    });

    testWidgets('when there is nothing unread under Unread then the empty '
        'state says so', (tester) async {
      await c.load();
      await c.markAllRead();
      await c.setUnreadOnly(true);
      await _pump(tester, c);

      expect(find.text('No unread notifications'), findsOneWidget);
    });

    testWidgets('when tapping Notification settings then the callback runs', (
      tester,
    ) async {
      await c.load();
      var opened = false;
      await _pump(tester, c, onOpenSettings: () => opened = true);

      await tester.tap(find.byKey(NotificationKeys.settings));

      expect(opened, isTrue);
    });

    for (final b in Brightness.values) {
      testWidgets('when it shows in ${b.name} then it is accessible', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await c.load();
        await _pump(tester, c, brightness: b);

        expect(
          find.bySemanticsLabel(
            RegExp(r'Bob Stone mentioned you in Plan.*unread'),
          ),
          findsOneWidget,
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  });
}
