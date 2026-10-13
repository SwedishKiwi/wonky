import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/src/activity/activity_dashboard_controller.dart';
import 'package:wonky_app/src/activity/activity_dashboard_dialog.dart';
import 'package:wonky_app/src/activity/trend_chart.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_client/wonky_client.dart';

import '../support/screen_pump.dart';

final _today = DateTime.utc(2026, 10, 13);

List<ActivityTrendPoint> _trend(List<int> counts) => [
  for (var i = 0; i < counts.length; i++)
    ActivityTrendPoint(
      day: _today.subtract(Duration(days: counts.length - 1 - i)),
      count: counts[i],
    ),
];

ActivityDashboard _dashboard({bool canSeeViewers = true, int hidden = 0}) =>
    ActivityDashboard(
      days: 28,
      canSeeViewers: canSeeViewers,
      viewers: canSeeViewers
          ? [
              ActivityViewer(
                user: TestUsers.bob,
                role: AccessRole.editor,
                lastViewedAt: DateTime.now().subtract(const Duration(hours: 2)),
                views: 5,
              ),
            ]
          : const [],
      hiddenViewers: hidden,
      viewTrend: _trend([0, 1, 3, 2]),
      commentTrend: _trend([1, 0, 0, 4]),
      showMyViewHistory: true,
    );

void main() {
  late CommandTestHarness h;
  late FakeActivityRepository activity;
  late DriveItemView doc;

  setUp(() {
    activity = FakeActivityRepository();
    h = CommandTestHarness(activity: activity);
    doc = h.drive.seed(name: 'Plan');
    activity.dashboards[doc.uuid.uuid] = _dashboard(hidden: 2);
  });
  tearDown(() => h.dispose());

  Widget view() => SizedBox(
    width: 560,
    height: 480,
    child: ActivityDashboardView(services: h.services, item: doc),
  );

  group('Given the activity dashboard controller', () {
    test('when changing the period then the dashboard is reloaded', () async {
      final c = ActivityDashboardController(activity, doc.uuid);
      await c.load();

      await c.setDays(7);

      expect(activity.requestedDays, [28, 7]);
      c.dispose();
    });

    test(
      'when saving the view-history setting fails then it reverts',
      () async {
        final c = ActivityDashboardController(activity, doc.uuid);
        await c.load();
        activity.failSetting = StateError('offline');

        await c.setShowViewHistory(false);

        expect(c.showViewHistory, isTrue);
        expect(c.settingError, isA<StateError>());
        c.dispose();
      },
    );
  });

  testWidgets('Given an editor when the dashboard opens then viewers are '
      'listed with their views', (tester) async {
    await pumpScreen(tester, h, view());

    expect(
      find.byKey(ActivityDashboardKeys.viewer(TestUsers.bob.id)),
      findsOneWidget,
    );
    expect(find.text('Bob Stone'), findsOneWidget);
    expect(find.text('5 views'), findsOneWidget);
    expect(
      find.text('2 more people turned off their view history'),
      findsOneWidget,
    );
  });

  testWidgets('Given a viewer when the dashboard opens then there is no '
      'Viewers tab and the trends show', (tester) async {
    activity.dashboards[doc.uuid.uuid] = _dashboard(canSeeViewers: false);

    await pumpScreen(tester, h, view());

    expect(
      find.byKey(const ValueKey<String>('activity.dashboard.tab.viewers')),
      findsNothing,
    );
    expect(find.byType(TrendChart), findsNWidgets(2));
  });

  testWidgets('Given the Trends tab when it shows then the charts announce '
      'their totals', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester, h, view());

    await tester.tap(
      find.byKey(const ValueKey<String>('activity.dashboard.tab.trends')),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Views: 6 in total, at most 3 on one day'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Comments: 5 in total, at most 4 on one day'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('Given the dashboard when turning off "Show my view history" '
      'then the setting is saved', (tester) async {
    await pumpScreen(tester, h, view());

    await tester.tap(find.byType(ShadSwitch));
    await tester.pumpAndSettle();

    expect(activity.viewHistory, isFalse);
  });

  for (final b in Brightness.values) {
    for (final tab in ['viewers', 'trends']) {
      testWidgets('Given the $tab tab in ${b.name} when it shows then it is '
          'accessible', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester, h, view(), brightness: b);
        await tester.tap(
          find.byKey(ValueKey<String>('activity.dashboard.tab.$tab')),
        );
        await tester.pumpAndSettle();

        await expectAccessible(tester);
        semantics.dispose();
      });
    }
  }
}
