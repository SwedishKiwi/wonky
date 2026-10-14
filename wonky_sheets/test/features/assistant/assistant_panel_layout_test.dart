import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sheets/features/ai/server_change_undo.dart';
import 'package:wonky_sheets/features/ai/sheets_ai_controller.dart';
import 'package:wonky_sheets/features/assistant/sheets_assistant_panel.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';
import '../ai/support/fake_sheets_ai_api.dart';

void main() {
  late SheetsHarness s;
  late FakeAssistantApi chatApi;
  late SheetsAiController ai;

  setUp(() async {
    s = SheetsHarness.open();
    SheetsAiApis.install(s.services, FakeSheetsAiApi());
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

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    for (final width in [300.0, 360.0, 380.0, 400.0]) {
      testWidgets('Given a reply with tool chips ($mode, ${width.toInt()} px) '
          'when the panel shows it then nothing overflows', (tester) async {
        chatApi.chatScripts.add([
          AssistantEvent(
            type: AssistantEventType.toolStarted,
            toolUseId: 't1',
            toolName: 'sheets.set_values',
          ),
          AssistantEvent(
            type: AssistantEventType.toolFinished,
            toolUseId: 't1',
            toolName: 'sheets.set_values',
            toolSummary:
                'Wrote 1,200 cells to Sheet1!A1:D300 with a long summary',
            changeId: 'c1',
            range: 'Sheet1!A1:D300',
          ),
          AssistantEvent(
            type: AssistantEventType.textDelta,
            text:
                'Done. I wrote the **numbers** and added a total row.\n\n'
                '| Region | Revenue | Margin | Growth |\n|---|---|---|---|\n'
                '| North | 10 | 0.2 | 5% |\n',
          ),
          AssistantEvent(type: AssistantEventType.done, changeId: 'run1'),
        ]);
        await pumpSheets(
          tester,
          s,
          dark: dark,
          size: Size(width, 800),
          child: SheetsAssistantPanel(ai: ai),
        );
        await settle(tester);
        expect(
          find.text(
            'Ask about this spreadsheet or tell the assistant '
            'what to change.',
          ),
          findsOneWidget,
        );
        await tester.runAsync(() => ai.chat!.send('Fill in the numbers'));
        await settle(tester);
        expect(find.byKey(const ValueKey('assistant.activity.t1')), findsOne);
        expect(tester.takeException(), isNull);
        await finish(tester);
      });
    }

    testWidgets('Given a Suggest-mode reply ($mode, 300 px) when the preview '
        'is ready then the footer and mode toggle fit', (tester) async {
      final api = FakeSheetsAiApi();
      SheetsAiApis.install(s.services, api);
      api.previews['p1'] = twoCallPreview('p1', s.session.itemUuid);
      chatApi.chatScripts.add([
        AssistantEvent(type: AssistantEventType.textDelta, text: 'Planned.'),
        AssistantEvent(type: AssistantEventType.done, previewId: 'p1'),
      ]);
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(300, 800),
        child: SheetsAssistantPanel(ai: ai),
      );
      await settle(tester);
      ai.chat!.setApplyMode(AiApplyMode.suggest);
      await tester.runAsync(() => ai.chat!.send('Build a dashboard'));
      await settle(tester);
      expect(find.byKey(const ValueKey('sheets.ai.reviewChanges')), findsOne);
      expect(find.byKey(const ValueKey('assistant.mode.edit')), findsOne);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  }
}
