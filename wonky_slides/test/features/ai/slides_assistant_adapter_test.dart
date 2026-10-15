import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/config/slides_features.dart';
import 'package:wonky_slides/features/ai/slides_ai_api.dart';
import 'package:wonky_slides/features/ai/slides_ai_controller.dart';
import 'package:wonky_slides/features/ai/slides_assistant_adapter.dart';
import 'package:wonky_slides/features/undo/server_change_undo.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

import '../../harness/deck_harness.dart';
import '../../support/fake_slides_ai_api.dart';

/// The Slides specialization of the shared assistant panel (suite 10 §3.1,
/// Slides 11 §6.2–§6.3).
void main() {
  late DeckHarness d;
  late SlidesAiController ai;
  late FakeSlidesAiApi api;
  late List<String> reverted;
  late String s1, s2;

  setUp(() async {
    SlidesFeatures.enabled = {
      ...SlidesFeatures.shipped,
      SlidesFeature.assistant,
    };
    final b = DeckBuilder();
    s1 = b.slide(layoutKey: 'title', title: 'Q3');
    s2 = b.slide(title: 'Plan', body: 'Ship');
    d = DeckHarness.open(fixture: b);
    api = FakeSlidesAiApi();
    SlidesAiApis.install(d.services, api);
    ShellAssistant.install(d.services, api: FakeAssistantApi());
    await ShellAssistant.of(d.services)!.refreshStatus();
    ai = SlidesAiController.of(d.editor);
    reverted = [];
    d.services.undo.registerHandler(
      SlidesServerChangeHandler(
        d.services,
        revert: (id) async {
          reverted.add(id);
          return RevertResult(
            changeId: UuidValue.fromString(
              '00000000-0000-7000-8000-0000000000dd',
            ),
            revertedCells: 1,
            skipped: const [],
          );
        },
      ),
    );
  });
  tearDown(() async {
    ai.dispose();
    ShellAssistant.uninstall(d.services);
    SlidesFeatures.reset();
    await d.dispose();
  });

  SlidesAssistantAdapter adapter() => ai.adapter;

  test('when a slide and objects are selected then chips and hints name '
      'them; removed chips are not sent', () {
    d.editor.setCurrentSlide(s2);
    final body = d.model
        .elementsOf(s2)
        .firstWhere((e) => e.placeholderType == SlidePlaceholderType.body)
        .id;
    d.editor.selectElements([body]);
    expect(
      [for (final c in adapter().chips) c.label],
      ['Slide 2', '1 selected object'],
    );
    final all = adapter().hints(
      applyMode: AiApplyMode.edit,
      chips: {
        SlidesAssistantAdapter.chipSlide,
        SlidesAssistantAdapter.chipSelection,
      },
    );
    expect(all.slidesCurrentSlide, s2);
    expect(all.slidesSelectedElements, [body]);
    final none = adapter().hints(applyMode: AiApplyMode.suggest, chips: {});
    expect(none.slidesCurrentSlide, isNull);
    expect(none.slidesSelectedElements, isNull);
    expect(none.applyMode, AiApplyMode.suggest);
  });

  test('when a chip shows a change then the slide opens with the element '
      'selected', () {
    final title = d.model
        .elementsOf(s2)
        .firstWhere((e) => e.placeholderType == SlidePlaceholderType.title)
        .id;
    adapter().show(
      AssistantActivity(
        toolUseId: 't',
        toolName: 'slides.set_text',
        summary: 'Set the text',
        range: s2,
        objectId: title,
      ),
    );
    expect(d.editor.currentSlideId, s2);
    expect(d.editor.selectedElementIds, [title]);
  });

  test('when an Edit-mode run commits then it is one undo step "AI: …" and '
      'the panel Undo undoes that step', () async {
    final reply = AssistantReplyEntry('r1', runId: 'run1');
    adapter().runCommitted(
      reply,
      '00000000-0000-7000-8000-000000000001',
      'Added 3 slides',
    );
    expect(d.undoLabels.first, 'AI: Added 3 slides');
    expect(await adapter().undoRun('run1'), isTrue);
    expect(reverted, ['00000000-0000-7000-8000-000000000001']);
  });

  test('when the run step is no longer the latest then Undo reverts the '
      'change on the server', () async {
    final reply = AssistantReplyEntry('r1', runId: 'run2');
    adapter().runCommitted(reply, '00000000-0000-7000-8000-000000000002', '');
    pushSlidesServerChangeStep(
      d.services,
      changeId: '00000000-0000-7000-8000-000000000003',
      label: 'Later',
    );
    expect(await adapter().undoRun('run2'), isTrue);
    expect(api.reverted, ['00000000-0000-7000-8000-000000000002']);
    expect(reverted, isEmpty);
  });

  test('when a Suggest-mode run records a preview then it is pending for '
      'the apply/discard commands', () async {
    ai.previewReady('p9');
    expect(ai.pendingPreview, 'p9');
    expect(
      d.services.dispatcher.stateOf('slides.ai.applyPreview').enabled,
      isTrue,
    );
    final r = await d.services.dispatcher.invoke(
      'slides.ai.discardPreview',
      source: InvocationSource.mcp,
    );
    expect(r.isOk, isTrue);
    expect(api.discarded, ['p9']);
    expect(ai.previewOutcome('p9'), 'discarded');
    expect(ai.pendingPreview, isNull);
  });

  test('when the user can only view then quick prompts offer no edits', () {
    d.editor.itemRole = Role.viewer;
    expect(adapter().role, Role.viewer);
    expect(adapter().quickPrompts, hasLength(1));
    d.editor.itemRole = Role.owner;
    expect(adapter().quickPrompts.length, greaterThan(1));
  });

  test('when the assistant answers then Insert adds its text as a slide '
      'after the current one in one undo step', () async {
    d.editor.setCurrentSlide(s1);
    final r = await d.services.dispatcher.invoke(
      'slides.ai.insertAsSlide',
      args: {'markdown': '# Summary\n- One\n- Two'},
      source: InvocationSource.ai,
    );
    expect(r.isOk, isTrue);
    final id = (r.data! as Map)['slideId'] as String;
    expect(d.editor.order.indexOf(id), 1);
    expect(d.editor.currentSlideId, id);
    await d.undo();
    expect(d.model.slide(id), isNull);
  });
}
