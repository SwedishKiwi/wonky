import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show Role, UiSlidesTools;
import 'package:wonky_slides/config/slides_features.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart';
import 'package:wonky_slides/features/present/active_presentation.dart';
import 'package:wonky_slides/features/present/present_controller.dart';
import 'package:wonky_slides/features/present/presentation_link.dart';
import 'package:wonky_slides/mcp/agent_flash.dart';
import 'package:wonky_slides/mcp/ui_slides_tools.dart';

import '../harness/deck_harness.dart';
import '../support/deck_screen.dart' show sampleDeck;

/// A present screen stand-in: `slides.present.*` reach its controller.
class _FakePresentation implements PresentHandle {
  _FakePresentation(this.controller);

  @override
  final PresentController controller;

  @override
  PresentationLink? get link => null;

  @override
  PresentView get view => controller.view;

  @override
  Future<void> toggleFullscreen() async {}

  @override
  Future<void> openOnAnotherDevice() async {}
}

/// The `ui.slides.*` handlers (Slides 11 §5; SL-42) on a headless deck:
/// they read the editor state, navigate through the commands (source
/// `mcp`), respect feature switches and roles, and flash what they target.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DeckHarness d;
  late Map<String, UiToolHandler> tools;

  UiToolContext ctx() => UiToolContext(
    services: d.services,
    boundaryKey: GlobalKey(),
    events: UiEventLog(),
    agentName: 'Claude Code (MCP)',
  );

  Future<UiToolResult> call(
    String name, [
    Map<String, Object?> args = const {},
  ]) => tools[name]!(ctx(), args);

  Matcher failsWith(String code) =>
      throwsA(isA<UiToolException>().having((e) => e.code, 'code', code));

  setUp(() {
    d = DeckHarness.open(fixture: sampleDeck());
    tools = UiSlidesToolHandlers.all(d.services);
  });

  tearDown(() async {
    activePresentation.value = null;
    SlidesFeatures.reset();
    SlidesAgentFlash.maybeOf(d.editor)?.dispose();
    await d.dispose();
  });

  test('every ui.slides definition has a handler and vice versa', () {
    expect(tools.keys.toSet(), {for (final t in UiSlidesTools.all) t.name});
  });

  group('Given an open deck', () {
    test('when reading the selection then the current slide, view and '
        'role are reported', () async {
      final r = await call('ui.slides.get_selection');

      expect(r.result['deck_uuid'], d.session.itemUuid.uuid);
      expect(r.result['current_slide'], containsPair('position', 1));
      expect(r.result['slide_count'], 4);
      expect(r.result['selected_elements'], isEmpty);
      expect(r.result['view_mode'], 'normal');
      expect(r.result['can_edit'], isTrue);
    });

    test('when going to slide 3 by position then the editor shows it and '
        'the slide flashes with the agent tag', () async {
      final third = d.editor.order.entries[2].id;

      final r = await call('ui.slides.go_to_slide', {'slide': 3});

      expect(d.editor.currentSlideId, third);
      expect(r.result['current_slide'], containsPair('slide_id', third));
      final flash = SlidesAgentFlash.of(d.editor).active.single;
      expect(flash.slideId, third);
      expect(flash.label, 'Claude Code (MCP)');
    });

    test('when going to a slide that does not exist then not_found', () {
      expect(
        call('ui.slides.go_to_slide', {'slide': 9}),
        failsWith('not_found'),
      );
    });

    test('when selecting the title placeholder of slide 2 then it is the '
        'selected element and flashes', () async {
      final second = d.editor.order.entries[1].id;

      final r = await call('ui.slides.select', {
        'elements': [
          {'slide': 2, 'placeholder': 'title'},
        ],
      });

      expect(d.editor.currentSlideId, second);
      final selected = d.editor.selectedElementIds.single;
      expect(d.model.element(selected)!.slideId, second);
      expect(
        (r.result['selected_elements']! as List).single,
        containsPair('element_id', selected),
      );
      final flash = SlidesAgentFlash.of(d.editor).active.last;
      expect(flash.elementIds, [selected]);
    });

    test('when selecting slides 2 and 4 then the navigator selection holds '
        'both', () async {
      final ids = d.editor.order.entries.map((e) => e.id).toList();

      final r = await call('ui.slides.select', {
        'slides': [2, 4],
      });

      expect(d.editor.selectedSlideIds, {ids[1], ids[3]});
      expect(r.result['selected_slides'], hasLength(2));
    });

    test('when switching to grid view at 50 % then view mode and zoom '
        'follow', () async {
      await call('ui.slides.set_view', {'view_mode': 'grid', 'zoom': 50});

      expect(d.editor.mode, DeckViewMode.grid);
      expect(d.editor.zoom, 0.5);
      final view = await call('ui.slides.get_view');
      expect(view.result['view_mode'], 'grid');
      expect(view.result['zoom'], 50);
      expect(view.result['presenting'], isNull);
    });

    test('when the outline view is switched off then set_view to it is '
        'refused', () {
      SlidesFeatures.enabled = {...SlidesFeatures.shipped}
        ..remove(SlidesFeature.outlineView);

      expect(
        call('ui.slides.set_view', {'view_mode': 'outline'}),
        failsWith('unsupported'),
      );
    });

    test('when opening the Slide tab then the inspector shows it', () async {
      await call('ui.slides.open_panel', {'panel': 'inspector_slide'});

      expect(d.editor.inspectorVisible, isTrue);
      expect(d.editor.inspectorTab, InspectorTab.slide);
    });

    test('when opening the themes panel then the side panel is open', () async {
      final r = await call('ui.slides.open_panel', {'panel': 'themes'});

      expect(d.services.panels.activePanelId, 'slides.panel.themes');
      expect(r.result['panel_id'], 'slides.panel.themes');
    });

    test('when the assistant is not shipped then its panel is unsupported', () {
      SlidesFeatures.enabled = {...SlidesFeatures.shipped}
        ..remove(SlidesFeature.assistant);

      expect(
        call('ui.slides.open_panel', {'panel': 'assistant'}),
        failsWith('unsupported'),
      );
    });

    test('when reading the context menu without a selection then the slide '
        'menu with command states is returned', () async {
      final r = await call('ui.slides.get_context_menu');

      expect(r.result['menu'], 'context.slide');
      final items = (r.result['items']! as List).cast<Map<String, Object?>>();
      final commands = [
        for (final i in items)
          if (i['type'] == 'command') i,
      ];
      expect(commands, isNotEmpty);
      expect(commands.first.keys, containsAll(['commandId', 'enabled']));
    });

    test('when highlighting an element then it flashes for the requested '
        'time on its slide', () async {
      final fourth = d.editor.order.entries[3].id;
      final title = d.model
          .elementsOf(fourth)
          .firstWhere((e) => e.placeholderType?.name == 'title')
          .id;

      final r = await call('ui.slides.highlight_element', {
        'element_ids': [title],
        'duration_ms': 1500,
      });

      expect(d.editor.currentSlideId, fourth);
      expect(r.result['element_ids'], [title]);
      final flash = SlidesAgentFlash.of(d.editor).active.single;
      expect(flash.slideId, fourth);
      expect(flash.elementIds, [title]);
    });
  });

  group('Given ui.invoke_command (suite 09 §6.2) in Slides', () {
    Future<UiToolResult> invoke(String id, [Map<String, Object?>? args]) =>
        SharedUiTools.all['ui.invoke_command']!(ctx(), {
          'command_id': id,
          'args': ?args,
        });

    test('when a registered command runs then it goes through the '
        'dispatcher as an agent step', () async {
      final r = await invoke('slides.slide.new');

      expect(r.result['status'], 'ok');
      expect(d.editor.order.length, 5);
      // Agent steps are labelled like AI ones ("AI: …", suite 08 §3.4).
      expect(d.undoLabels.first, startsWith('AI: '));
    });

    test('when a command of an unshipped feature is invoked then it is not '
        'found', () {
      expect(invoke('slides.file.importSlides'), failsWith('not_found'));
    });

    test('when a hidden argument value is used then the args are invalid', () {
      SlidesFeatures.enabled = {...SlidesFeatures.shipped}
        ..remove(SlidesFeature.imageExports);
      // The command's schema lists the formats when it is built.
      d.services.registry.register(
        d.services.config
            .commands(d.services)
            .firstWhere((c) => c.id.value == 'slides.file.download'),
        replace: true,
      );

      expect(
        invoke('slides.file.download', {'format': 'png'}),
        failsWith('invalid_args'),
      );
    });
  });

  group('Given a viewer', () {
    setUp(() async {
      await d.dispose();
      d = DeckHarness.open(fixture: sampleDeck(), role: Role.viewer);
      tools = UiSlidesToolHandlers.all(d.services);
    });

    test('when reading the selection then can_edit is false', () async {
      final r = await call('ui.slides.get_selection');

      expect(r.result['can_edit'], isFalse);
      expect(r.result['role'], 'viewer');
    });

    test('when entering masters mode then the command refuses it', () {
      expect(
        call('ui.slides.set_view', {'view_mode': 'masters'}),
        failsWith('disabled'),
      );
    });

    test('when a mutating command is invoked then it is forbidden', () {
      expect(
        SharedUiTools.all['ui.invoke_command']!(ctx(), {
          'command_id': 'slides.slide.new',
        }),
        failsWith('forbidden'),
      );
    });

    test('when navigating then it works like for editors', () async {
      await call('ui.slides.go_to_slide', {'slide': 2});

      expect(d.editor.currentSlideId, d.editor.order.entries[1].id);
    });
  });

  group('Given a running presentation', () {
    late PresentController pc;
    setUp(() {
      pc = PresentController(
        model: d.model,
        view: PresentView.present,
        burstMs: 0,
      );
      activePresentation.value = _FakePresentation(pc);
    });
    tearDown(() => pc.dispose());

    test('when stepping to the next slide then the position follows', () async {
      final r = await call('ui.slides.present_control', {
        'action': 'next_slide',
      });

      expect(r.result['position'], 2);
      expect(pc.position!.slideId, d.editor.order.entries[1].id);
    });

    test('when going to slide 4 then it is shown', () async {
      final r = await call('ui.slides.present_control', {
        'action': 'go_to',
        'slide': 4,
      });

      expect(r.result['slide_id'], d.editor.order.entries[3].id);
    });

    test('when blanking to black twice then the screen stays black', () async {
      await call('ui.slides.present_control', {'action': 'black'});
      final r = await call('ui.slides.present_control', {'action': 'black'});

      expect(r.result['blank'], 'black');
      expect(pc.blank, PresentBlank.black);
    });

    test('when reading the view then the presentation is described', () async {
      final r = await call('ui.slides.get_view');

      final p = r.result['presenting']! as Map;
      expect(p['view'], 'present');
      expect(p['position'], 1);
    });

    test('when starting another presentation then it is refused', () {
      expect(call('ui.slides.present'), failsWith('disabled'));
    });
  });

  group('Given no presentation is open in the window', () {
    setUp(() => d.services.deactivate(d.doc));
    tearDown(() => d.services.activate(d.doc));

    test('when a tool runs then no_document', () {
      expect(call('ui.slides.get_selection'), failsWith('no_document'));
    });
  });
}
