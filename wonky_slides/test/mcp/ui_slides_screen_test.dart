import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_slides/features/collab/slides_collab.dart';
import 'package:wonky_slides/features/collab/soft_locks.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart';
import 'package:wonky_slides/features/navigator/deck_renderer.dart';
import 'package:wonky_slides/features/spellcheck/slides_spelling.dart';
import 'package:wonky_slides/features/text_editing/text_editing_host.dart';
import 'package:wonky_charts/wonky_charts.dart' show ChartData;
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart'
    show ChartDataTableStrings;
import 'package:wonky_slides/mcp/agent_flash.dart';
import 'package:wonky_slides/mcp/dialog_adapters.dart';
import 'package:wonky_slides/mcp/ui_slides_tools.dart';
import 'package:wonky_slides_core/model.dart' show SlidesText;
import 'package:wonky_slides_core/testing.dart' show DeckBuilder;
import 'package:wonky_ui/testing.dart';

import '../features/spellcheck/spelling_fixture.dart';
import '../support/deck_screen.dart';

/// A tool context whose dialogs open from the test's widget tree (the
/// test app has no shell navigator).
class _Ctx extends UiToolContext {
  _Ctx(this._context, ShellServices services)
    : super(
        services: services,
        boundaryKey: GlobalKey(),
        events: UiEventLog(),
        agentName: 'Claude Code (MCP)',
      );

  final BuildContext _context;

  @override
  BuildContext? get context => _context;
}

/// The `ui.slides.*` tools on the deck editor screen (Slides 11 §5, 04
/// AC-9; SL-42): offscreen screenshots equal the thumbnails, the agent
/// highlight on the canvas, the inspector as a describable panel, the
/// soft-lock popover and every kind of Slides dialog through
/// `ui.slides.open_dialog` / `ui.get_dialog` / `ui.press_dialog_button`.
void main() {
  late DeckScreenRig r;
  late Map<String, UiToolHandler> tools;
  late WidgetTester t;

  Future<void> open(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    DeckBuilder? fixture,
  }) async {
    t = tester;
    r = await pumpDeckScreen(tester, brightness: brightness, fixture: fixture);
    tools = {...SharedUiTools.all, ...UiSlidesToolHandlers.all(r.services)};
  }

  /// Runs a tool while pumping frames (its waits are frames and the clock).
  Future<UiToolResult> call(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    final context = t.element(find.byKey(const ValueKey('slides.canvas')));
    UiToolResult? result;
    Object? error;
    var done = false;
    unawaited(
      tools[name]!(_Ctx(context, r.services), args).then(
        (v) {
          result = v;
          done = true;
        },
        onError: (Object e) {
          error = e;
          done = true;
        },
      ),
    );
    for (var i = 0; i < 400 && !done; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    if (error != null) throw error!;
    expect(done, isTrue, reason: '$name did not finish');
    return result!;
  }

  Future<void> close(WidgetTester tester) async {
    await settleTooltips(tester);
    await r.close(tester);
  }

  String titleOf(int index) {
    final slide = r.editor.order.entries[index].id;
    return r.editor.model
        .elementsOf(slide)
        .firstWhere((e) => e.placeholderType?.name == 'title')
        .id;
  }

  testWidgets('Given a deck when slide 2 is screenshot at half scale then '
      'the PNG equals its in-app thumbnail', (tester) async {
    await open(tester);
    final second = r.editor.order.entries[1].id;

    final shot = await tester.runAsync(
      () => tools['ui.slides.screenshot_slide']!(
        _Ctx(
          tester.element(find.byKey(const ValueKey('slides.canvas'))),
          r.services,
        ),
        {'slide': 2, 'scale': 0.5},
      ),
    );
    final (pixels, thumb) = (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        base64Decode(shot!.imageBase64!),
      );
      final image = (await codec.getNextFrame()).image;
      final renderer = DeckThumbnails.acquire(r.editor);
      final picture = renderer.thumbnail(second, width: 960)!.picture;
      final expected = await picture.toImage(960, 540);
      final a = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final b = await expected.toByteData(format: ui.ImageByteFormat.rawRgba);
      DeckThumbnails.release(r.editor, renderer);
      return (a!.buffer.asUint8List(), b!.buffer.asUint8List());
    }))!;

    expect(shot!.result['width'], 960);
    expect(shot.result['height'], 540);
    expect(shot.result['slide_id'], second);
    expect(pixels, thumb);
    await close(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Given the editor (${brightness.name}) when an agent '
        'highlights the title then a violet outline with its tag shows and '
        'fades after the duration', (tester) async {
      await open(tester, brightness: brightness);

      await call('ui.slides.highlight_element', {
        'element_ids': [titleOf(0)],
        'duration_ms': 1500,
      });

      final tag = find.text('✦ Claude Code (MCP)');
      expect(tag, findsOneWidget);
      final box = tester.widget<Container>(
        find.ancestor(of: tag, matching: find.byType(Container)).first,
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        SlidesAgentFlash.colorFor(brightness),
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(tag, findsNothing);
      await close(tester);
    });
  }

  testWidgets('Given the inspector when it is described then its tabs are '
      'buttons and pressing the Slide tab switches to it', (tester) async {
    await open(tester);
    await call('ui.slides.open_panel', {'panel': 'inspector_format'});

    final d = await call('ui.slides.describe_panel');
    final buttons = [for (final b in d.result['buttons']! as List) b['id']];
    expect(d.result['panel'], 'inspector_format');
    expect(buttons, contains('slides.inspector.tab.slide'));

    await call('ui.slides.press_panel_button', {
      'button_id': 'slides.inspector.tab.slide',
    });
    expect(r.editor.inspectorTab, InspectorTab.slide);
    await close(tester);
  });

  testWidgets('Given someone edits a text when the soft-lock popover asks '
      'then MCP reads it as a dialog and answers Edit anyway', (tester) async {
    await open(tester);
    final locks = SlidesCollab.of(r.editor)!.locks;
    final answer = locks.ask(
      SoftLockPrompt(
        target: TextLockTarget.element(titleOf(0)),
        holders: const [],
      ),
    );
    await tester.pump();

    final d = await call('ui.get_dialog');
    final dialog = d.result['dialog']! as Map;
    expect(dialog['kind'], 'softLock');
    expect(
      [for (final b in dialog['buttons']! as List) b['id']],
      ['no', 'yes'],
    );
    await call('ui.press_dialog_button', {'button_id': 'yes'});

    expect(await answer, isTrue);
    expect(r.services.openDialogs, isEmpty);
    await close(tester);
  });

  testWidgets('Given a slide with a build when its animation is previewed '
      'then the tool resolves after the preview played', (tester) async {
    final b = DeckBuilder(title: 'Builds');
    final slide = b.slide(title: 'Steps');
    b.build_(slide, b.textBox(slide, 'Appears'));
    await open(tester, fixture: b);

    final res = await call('ui.slides.preview_animation');

    expect(res.result['completed'], isTrue);
    expect(res.result['slide_id'], slide);
    expect(res.result['steps'], 1);
    expect(res.result['played_ms'] as int, greaterThan(0));
    await close(tester);
  });

  testWidgets('Given a chart\'s data table dialog when MCP reads it then '
      'the table and a close button are described', (tester) async {
    await open(tester);
    final context = tester.element(find.byKey(const ValueKey('slides.canvas')));
    unawaited(
      showDescribableChartDataDialog(
        context,
        data: ChartData.empty(),
        strings: const ChartDataTableStrings(
          title: 'Data: Revenue',
          close: 'Close',
          noData: 'No data',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final d = (await call('ui.get_dialog')).result['dialog']! as Map;
    expect(d['title'], 'Data: Revenue');
    expect(d['kind'], 'chartData');
    expect(d['table'], isA<Map<String, Object?>>());
    await call('ui.press_dialog_button', {'button_id': 'close'});
    await tester.pump(const Duration(milliseconds: 400));

    expect(r.services.openDialogs, isEmpty);
    await close(tester);
  });

  group('Given a misspelled title', () {
    setUp(installFakeSpelling);
    tearDown(resetSpelling);

    testWidgets('when Check spelling opens over MCP then the word and its '
        'suggestions are described and Change fixes it', (tester) async {
      final b = DeckBuilder(title: 'Spelling')
        ..slide(layoutKey: 'title', title: 'Helo world');
      await open(tester, fixture: b);
      await SlidesSpelling.of(r.editor).whenSettled();

      final opened = await call('ui.slides.open_dialog', {
        'command_id': 'slides.spelling.check',
      });
      final dialog = opened.result['dialog']! as Map;
      expect(dialog['kind'], 'spelling');
      expect(dialog['word'], 'Helo');
      final field = (dialog['fields']! as List).single as Map;
      expect(field['options'], contains('hello'));

      await call('ui.fill_dialog', {
        'values': {'suggestion': 'hello'},
      });
      await call('ui.press_dialog_button', {'button_id': 'change'});
      await call('ui.press_dialog_button', {'button_id': 'done'});
      await tester.pump(const Duration(milliseconds: 400));

      final slide = r.editor.order.entries.first.id;
      final title = r.session.model
          .elementsOf(slide)
          .firstWhere((e) => e.placeholderType?.name == 'title');
      expect(SlidesText.plainText(title.text), startsWith('hello world'));
      expect(r.services.openDialogs, isEmpty);
      await close(tester);
    });
  });

  // Dialogs opened through ui.slides.open_dialog (04 §13, AC-9): each is
  // described with a title and buttons and closes through its own button.
  final dialogs = <(String, Map<String, Object?>, String?, String)>[
    ('slides.file.pageSetup', {}, null, 'cancel'),
    ('slides.deck.openNumbering', {}, null, 'cancel'),
    ('slides.nav.goToSlide', {}, null, 'cancel'),
    ('slides.insert.shape', {'pick': true}, null, 'cancel'),
    ('slides.insert.icon', {}, null, 'cancel'),
    ('slides.insert.code', {'pick': true}, null, 'cancel'),
    ('slides.element.editAltText', {}, 'select', 'cancel'),
    ('slides.file.download', {'format': 'png'}, null, 'cancel'),
    ('shell.help.shortcuts', {}, null, 'close'),
    ('slides.spelling.personalDictionary', {}, null, 'done'),
    ('slides.insert.specialCharacter', {}, 'edit', 'close'),
    ('slides.insert.emoji', {}, null, 'close'),
  ];
  for (final (id, args, setup, cancel) in dialogs) {
    testWidgets('Given the editor when $id opens its dialog over MCP then '
        'ui.get_dialog describes it and "$cancel" closes it', (tester) async {
      await open(tester);
      if (setup == 'select' || setup == 'edit') {
        await r.run('slides.select.elements', {
          'ids': [titleOf(0)],
        });
      }
      if (setup == 'edit') {
        await textEditingOf(r.editor).begin(titleOf(0));
        await tester.pump();
      }

      final opened = await call('ui.slides.open_dialog', {
        'command_id': id,
        'args': args,
      });

      final dialog = opened.result['dialog'] as Map?;
      expect(dialog, isNotNull, reason: '$id: ${opened.result}');
      expect(dialog!['title'], isA<String>());
      final buttons = [for (final b in dialog['buttons']! as List) b['id']];
      expect(buttons, contains(cancel));
      final got = await call('ui.get_dialog');
      expect((got.result['dialog']! as Map)['title'], dialog['title']);
      expect(tester.takeException(), isNull);

      await call('ui.press_dialog_button', {'button_id': cancel});
      await tester.pump(const Duration(milliseconds: 400));
      expect(r.services.openDialogs, isEmpty, reason: id);
      await close(tester);
    });
  }
}
