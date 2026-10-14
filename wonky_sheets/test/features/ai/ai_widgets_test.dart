import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sheets/features/ai/server_change_undo.dart';
import 'package:wonky_sheets/features/ai/sheets_ai_controller.dart';
import 'package:wonky_sheets/features/assistant/sheets_assistant_panel.dart';
import 'package:wonky_sheets/features/explore/explore_panel.dart';
import 'package:wonky_sheets/features/grid/grid_area.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';
import 'support/fake_sheets_ai_api.dart';

void main() {
  late SheetsHarness s;
  late FakeAssistantApi chatApi;
  late FakeSheetsAiApi api;
  late SheetsAiController ai;

  setUp(() async {
    s = SheetsHarness.open();
    api = FakeSheetsAiApi();
    SheetsAiApis.install(s.services, api);
    s.services.undo.registerHandler(
      SheetsServerChangeHandler(
        s.services,
        revert: (id) => api.revertChange(UuidValue.fromString(id)),
      ),
    );
    chatApi = FakeAssistantApi();
    ShellAssistant.install(s.services, api: chatApi);
    await ShellAssistant.of(s.services)!.refreshStatus();
    ai = SheetsAiController.of(s.editor);
  });

  tearDown(() async {
    ShellAssistant.uninstall(s.services);
    await s.dispose();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  BuildContext gridContext(WidgetTester tester) =>
      tester.element(find.byType(GridArea));

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('Given the ✨ popover ($mode) when a formula is asked for '
        'then it previews it and Insert writes it', (tester) async {
      await pumpSheets(tester, s, dark: dark);
      await s.type('A1', '1');
      await s.type('A2', '5');
      await s.select('A4');
      unawaited(ai.openSuggest());
      await settle(tester);
      expect(
        find.byKey(const ValueKey('sheets.ai.popover.suggest')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('sheets.ai.suggest.prompt')),
        'sum of A',
      );
      await tester.tap(find.byKey(const ValueKey('sheets.ai.suggest.ask')));
      await settle(tester);
      expect(api.suggestCalls.single, ('Sheet1!A4', 'sum of A'));
      expect(find.text('Result: 6'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sheets.ai.suggest.insert')));
      await settle(tester);
      expect(s.content('A4'), isNotNull);
      expect(
        find.byKey(const ValueKey('sheets.ai.popover.suggest')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('Given Fill with AI ($mode) when proposals arrive then '
        'low-confidence rows are unchecked and Apply is one undo step', (
      tester,
    ) async {
      await pumpSheets(tester, s, dark: dark);
      final done = ai.fill(range: 'Sheet1!B1:B3', context: gridContext(tester));
      await settle(tester);
      expect(find.byKey(const ValueKey('dialog.fillWithAi')), findsOneWidget);
      expect(find.text('bob@x.com'), findsOneWidget);
      expect(find.text('Apply 1 value'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dialog.fillWithAi.apply')));
      await settle(tester);
      final r = await done;
      expect(r?.cellsAffected, 1);
      expect(api.applied.single.single.cell, 'Sheet1!B2');
      expect(s.h.undoLabels, ['AI: Fill Sheet1!B1:B3']);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('Given an AI changes preview ($mode) when one call is '
        'unchecked then Apply applies only the checked one', (tester) async {
      await pumpSheets(tester, s, dark: dark);
      api.previews['p1'] = twoCallPreview('p1', s.session.itemUuid);
      final done = ai.openPreview('p1', context: gridContext(tester));
      await settle(tester);
      expect(find.byKey(const ValueKey('dialog.aiPreview')), findsOneWidget);
      expect(find.text('North'), findsOneWidget);
      // Uncheck the second call.
      final second = find.byKey(const ValueKey('dialog.aiPreview.call.c2'));
      await tester.tap(
        find.descendant(of: second, matching: find.byType(ShadCheckbox)),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dialog.aiPreview.apply')));
      await settle(tester);
      await done;
      expect(api.appliedPreviews.single.$1, 'p1');
      expect(api.appliedPreviews.single.$2, ['c1']);
      expect(ai.previewOutcome('p1'), 'applied');
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('Given data ($mode) when Explore is shown then it lists '
        'statistics, chart suggestions and insights', (tester) async {
      await s.type('A1', 'Region');
      await s.type('B1', 'Revenue');
      await s.type('A2', 'North');
      await s.type('B2', '10');
      await s.type('A3', 'South');
      await s.type('B3', '20');
      await s.select('A1:B3');
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(360, 800),
        child: ExplorePanel(ai: ai),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester);
      expect(
        find.byKey(const ValueKey('sheets.explore.scope')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('sheets.explore.stat.sum')), findsOne);
      expect(find.text('30'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sheets.explore.insight.Find anomalies')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  }

  testWidgets('Given AI is not configured when the assistant panel shows '
      'then it explains it and offers adding a key', (tester) async {
    chatApi.status = AssistantStatus(
      available: false,
      reason: 'notConfigured',
      quality: AiQuality.best,
      tokensUsedToday: 0,
      dailyTokenBudget: 0,
      userKeysAllowed: true,
    );
    await ShellAssistant.of(s.services)!.refreshStatus();
    await pumpSheets(
      tester,
      s,
      size: const Size(360, 800),
      child: SheetsAssistantPanel(ai: ai),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('assistant.unavailable')), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant.addApiKey')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('Given a Suggest-mode reply when the preview is ready then the '
      'panel offers Review suggested changes', (tester) async {
    api.previews['p1'] = twoCallPreview('p1', s.session.itemUuid);
    chatApi.chatScripts.add([
      AssistantEvent(type: AssistantEventType.textDelta, text: 'Planned.'),
      AssistantEvent(type: AssistantEventType.done, previewId: 'p1'),
    ]);
    await pumpSheets(
      tester,
      s,
      size: const Size(520, 800),
      child: SheetsAssistantPanel(ai: ai),
    );
    await settle(tester);
    ai.chat!.setApplyMode(AiApplyMode.suggest);
    await tester.runAsync(() => ai.chat!.send('Build a dashboard'));
    await settle(tester);
    // (In the app the dialog also opens by itself at the end of the turn.)
    await tester.tap(find.byKey(const ValueKey('sheets.ai.reviewChanges')));
    await settle(tester);
    expect(find.byKey(const ValueKey('dialog.aiPreview')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dialog.aiPreview.discard')));
    await settle(tester);
    expect(api.discarded, ['p1']);
    expect(find.text('Suggested changes discarded.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
