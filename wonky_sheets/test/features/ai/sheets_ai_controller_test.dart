import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sheets/features/ai/server_change_undo.dart';
import 'package:wonky_sheets/features/ai/sheets_ai_controller.dart';
import 'package:wonky_sheets/features/ai/sheets_assistant_adapter.dart';

import '../../support/sheets_harness.dart';
import 'support/fake_sheets_ai_api.dart';

const _change = '01923456-789a-7bcd-8ef0-00000000aaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    final assistant = ShellAssistant.install(s.services, api: chatApi);
    await assistant.refreshStatus();
    ai = SheetsAiController.of(s.editor);
  });

  tearDown(() async {
    ShellAssistant.uninstall(s.services);
    await s.dispose();
  });

  group('Given the assistant adapter', () {
    test('when a range is selected then the chips and hints carry the '
        'sheet, selection and active cell', () async {
      await s.select('B2:C4');
      final chips = ai.adapter.chips;
      expect([for (final c in chips) c.id], ['selection', 'sheet']);
      expect(chips.first.label, 'Sheet1!B2:C4');

      final hints = ai.adapter.hints(
        applyMode: AiApplyMode.edit,
        chips: {'selection', 'sheet'},
      );
      expect(hints.sheetsActiveSheet, 'Sheet1');
      expect(hints.sheetsSelection, ['Sheet1!B2:C4']);
      expect(hints.sheetsActiveCell, 'Sheet1!B2');

      final without = ai.adapter.hints(
        applyMode: AiApplyMode.edit,
        chips: {'sheet'},
      );
      expect(without.sheetsSelection, isNull);
    });

    test('when the user can edit then the quick prompts are analyze, chart, '
        'clean data and formula', () {
      expect(ai.adapter.quickPrompts.length, 4);
    });

    test('when Analyze runs then the server chips become the quick '
        'prompts', () async {
      final r = await s.run('sheets.ai.analyze');
      expect(r.isOk, isTrue);
      expect([for (final p in ai.adapter.quickPrompts) p.label].take(2), [
        'Summarize this table',
        'Find anomalies',
      ]);
    });
  });

  group('Given an Edit-mode run that wrote cells', () {
    setUp(() {
      chatApi.chatScripts.add([
        AssistantEvent(
          type: AssistantEventType.toolStarted,
          toolUseId: 't1',
          toolName: 'sheets.set_values',
          toolSummary: 'Writing cells',
        ),
        AssistantEvent(
          type: AssistantEventType.toolFinished,
          toolUseId: 't1',
          toolName: 'sheets.set_values',
          toolSummary: 'Wrote 3 cells to Sheet1!A1:A3',
          changeId: '01923456-789a-7bcd-8ef0-00000000bbbb',
          range: 'Sheet1!A1:A3',
        ),
        AssistantEvent(type: AssistantEventType.textDelta, text: 'Done.'),
        AssistantEvent(type: AssistantEventType.done, changeId: _change),
      ]);
    });

    test('when it finishes then it is one undo step "AI: …" that reverts '
        'and re-applies the composite server change', () async {
      await ai.chat!.send('Fill A1:A3 with 1, 2, 3');
      await pumpEventQueue();

      final reply = ai.chat!.entries.last as AssistantReplyEntry;
      expect(reply.changeId, _change);
      expect(reply.activities.single.range, 'Sheet1!A1:A3');
      expect(reply.activities.single.hasRange, isTrue);
      expect(s.h.undoLabels, ['AI: Wrote 3 cells to Sheet1!A1:A3']);
      // The written range flashes (agent presence highlight).
      expect(ai.highlights.active.single.label, 'AI');

      await s.undo();
      expect(api.reverted, [_change]);
      await s.redo();
      // Redo reverts the revert record.
      expect(api.reverted.length, 2);
      expect(api.reverted.last, isNot(_change));
    });

    test('when the panel undoes the reply then the step is undone', () async {
      await ai.chat!.send('Fill A1:A3');
      await pumpEventQueue();
      final reply = ai.chat!.entries.last as AssistantReplyEntry;
      await ai.chat!.undoReply(reply);
      expect(reply.undone, isTrue);
      expect(api.reverted, [_change]);
      expect(s.h.undoLabels, isEmpty);
    });

    test('when Show is pressed then the range is selected', () async {
      await ai.chat!.send('Fill A1:A3');
      await pumpEventQueue();
      final reply = ai.chat!.entries.last as AssistantReplyEntry;
      ai.chat!.show(reply.activities.single);
      expect(s.editor.selection.describe(), 'A1:A3');
    });
  });

  group('Given a Suggest-mode run with a preview', () {
    test('when previewReady arrives then the reply remembers it and '
        'applying it is one undo step', () async {
      api.previews['p1'] = twoCallPreview('p1', s.session.itemUuid);
      chatApi.chatScripts.add([
        AssistantEvent(
          type: AssistantEventType.previewReady,
          previewId: 'p1',
          toolSummary: '2 suggested changes',
        ),
        AssistantEvent(type: AssistantEventType.done, previewId: 'p1'),
      ]);
      ai.chat!.setApplyMode(AiApplyMode.suggest);
      await ai.chat!.send('Build a dashboard');
      await pumpEventQueue();
      final reply = ai.chat!.entries.last as AssistantReplyEntry;
      expect(reply.previewId, 'p1');

      final r = await s.run('sheets.ai.applyPreview', {
        'previewId': 'p1',
        'selectedCallIds': ['c1'],
      });
      expect(r.isOk, isTrue);
      expect(api.appliedPreviews.single.$1, 'p1');
      expect(api.appliedPreviews.single.$2, ['c1']);
      expect(ai.previewOutcome('p1'), 'applied');
      expect(s.h.undoLabels, ['AI: Suggested changes']);
    });

    test('when it is discarded then nothing is applied', () async {
      final r = await s.run('sheets.ai.discardPreview', {'previewId': 'p9'});
      expect(r.isOk, isTrue);
      expect(api.discarded, ['p9']);
      expect(ai.previewOutcome('p9'), 'discarded');
      expect(s.h.undoLabels, isEmpty);
    });
  });

  group('Given inline AI', () {
    test('when a formula is suggested with a prompt then it is returned '
        'and Insert writes it as one undo step', () async {
      await s.type('A1', '1');
      await s.type('A2', '2');
      await s.type('A3', '3');
      await s.select('A4');
      final r = await s.run('sheets.ai.suggestFormula', {
        'prompt': 'sum of the column',
      });
      expect(r.isOk, isTrue);
      expect((r.data! as Map)['formula'], '=SUM(A1:A3)');
      expect(api.suggestCalls.single.$1, 'Sheet1!A4');

      expect(await ai.insertSuggestion(), isTrue);
      expect(s.text('A4'), '6');
      expect(ai.popover.value, isNull);
      await s.undo();
      expect(s.content('A4'), isNull);
    });

    test('when a formula cell is explained then the explanation streams '
        'into the popover', () async {
      await s.type('A1', '=1+2');
      await s.select('A1');
      final r = await s.run('sheets.ai.explainFormula');
      expect(r.isOk, isTrue);
      await pumpEventQueue();
      expect(ai.popover.value?.markdown, 'Adds the values.');
      expect(ai.popover.value?.formula, '=1+2');
    });

    test('when the cell has no formula then Explain is disabled', () async {
      await s.select('C9');
      final st = s.services.dispatcher.stateOf('sheets.ai.explainFormula');
      expect(st.enabled, isFalse);
    });

    test('when a chart is described then the alt text is returned', () async {
      final r = await s.run('sheets.ai.describeChart', {
        'objectId': 'chart1',
        'show': false,
      });
      expect((r.data! as Map)['alt_text'], contains('revenue'));
    });
  });

  group('Given an assistant result', () {
    test('when a Markdown table is inserted then it fills cells in one '
        'undo step', () async {
      await s.select('B2');
      final r = await s.run('sheets.ai.insertResult', {
        'markdown':
            'Here:\n\n| Region | Total |\n|---|---:|\n| North | 10 |\n'
            '| **South** | 7 |\n',
      });
      expect(r.isOk, isTrue);
      expect((r.data! as Map)['range'], 'Sheet1!B2:C4');
      expect(s.text('B2'), 'Region');
      expect(s.text('C3'), '10');
      expect(s.text('B4'), 'South');
      expect(s.h.undoLabels, hasLength(1));
    });

    test('markdownToRows falls back to lines without a table', () {
      expect(markdownToRows('- one\n- two'), [
        ['one'],
        ['two'],
      ]);
    });
  });

  group('Given AI is not configured', () {
    test('when the commands are checked then they are disabled with the '
        "server's reason", () async {
      chatApi.status = AssistantStatus(
        available: false,
        reason: 'notConfigured',
        message: "AI isn't configured on this server.",
        quality: AiQuality.best,
        tokensUsedToday: 0,
        dailyTokenBudget: 0,
        userKeysAllowed: true,
      );
      await ShellAssistant.of(s.services)!.refreshStatus();
      final st = s.services.dispatcher.stateOf('sheets.ai.suggestFormula');
      expect(st.enabled, isFalse);
      expect(st.disabledReason, isNotNull);
      expect(ai.shown, isTrue);
      expect(ai.available, isFalse);
      // Explore and Analyze stay usable (deterministic).
      expect(
        s.services.dispatcher.stateOf('sheets.explore.toggle').enabled,
        isTrue,
      );
    });
  });
}
