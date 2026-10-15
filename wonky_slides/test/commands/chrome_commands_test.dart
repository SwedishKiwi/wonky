import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart' show CommandState;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/commands/slides_command.dart';
import 'package:wonky_slides/config/slides_features.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart';
import 'package:wonky_slides/features/settings/slides_user_defaults.dart';
import 'package:wonky_slides/l10n/slides_l10n.dart';
import 'package:wonky_slides_core/ops.dart';

import '../harness/deck_harness.dart';
import '../support/deck_screen.dart' show sampleDeck;

/// The chrome commands (Slides 04 §2–§8, §14) run headless through the
/// real dispatcher on the deck harness.
void main() {
  final l = slidesL10nEnglish;
  late DeckHarness d;

  setUp(() => d = DeckHarness.open(fixture: sampleDeck()));
  tearDown(() => d.dispose());

  DeckEditorController ed() => d.editor;
  CommandState state(String id, [Map<String, Object?> args = const {}]) =>
      d.services.dispatcher.stateOf(id, args);

  group('Given an open deck', () {
    test('when the view modes are chosen then the mode follows and the '
        'radio item is checked', () async {
      await d.run('slides.view.setMode', {'mode': 'grid'});
      expect(ed().mode, DeckViewMode.grid);
      expect(state('slides.view.setMode', {'mode': 'grid'}).checked, isTrue);
      expect(state('slides.view.setMode', {'mode': 'normal'}).checked, isFalse);

      await d.run('slides.view.setMode', {'mode': 'normal'});
      expect(ed().mode, DeckViewMode.normal);
    });

    test('when the panes are toggled then their visibility flips and is '
        'remembered on the device', () async {
      expect(state('slides.view.toggleInspector').checked, isTrue);
      await d.run('slides.view.toggleInspector');
      await d.run('slides.view.toggleNotes');
      await d.run('slides.view.toggleNavigator');
      expect(ed().inspectorVisible, isFalse);
      expect(ed().notesVisible, isFalse);
      expect(ed().navigatorVisible, isFalse);
      expect(state('slides.view.toggleInspector').checked, isFalse);
      await pumpEventQueue();
      final stored = await d.services.userStore.read('slides.chrome');
      expect(stored, contains('"inspectorVisible":false'));
    });

    test('when View › Show toggles run then rulers, guides and comment '
        'pins (SL-38) flip', () async {
      await d.run('slides.view.toggleRulers');
      await d.run('slides.view.toggleGuides');
      await d.run('slides.view.toggleCommentPins');
      expect(ed().rulers, isTrue);
      expect(ed().guides, isFalse);
      expect(ed().commentPins, isFalse);
      expect(state('slides.view.toggleCommentPins').checked, isFalse);
    });

    test('when the snapping toggles run then the synced Slides settings '
        'change', () async {
      final defaults = SlidesUserDefaults.of(d.services);
      expect(defaults.flag(SlidesUserDefaults.keySmartGuides), isTrue);

      await d.run('slides.view.toggleSmartGuides');
      await d.run('slides.view.toggleRemoteCursors');

      expect(defaults.flag(SlidesUserDefaults.keySmartGuides), isFalse);
      expect(defaults.flag(SlidesUserDefaults.keyShowRemoteCursors), isFalse);
      expect(state('slides.view.toggleSmartGuides').checked, isFalse);
    });

    test('when zooming then fixed steps, in/out and Fit apply', () async {
      expect(ed().zoomFit, isTrue);
      await d.run('slides.view.zoom', {'percent': 150});
      expect(ed().zoomFit, isFalse);
      expect(ed().zoom, 1.5);
      expect(state('slides.view.zoom', {'percent': 150}).checked, isTrue);

      await d.run('slides.view.zoomIn');
      expect(ed().zoom, 2.0);
      await d.run('slides.view.zoomOut');
      await d.run('slides.view.zoomOut');
      expect(ed().zoom, 1.25);

      await d.run('slides.view.zoomFit');
      expect(ed().zoomFit, isTrue);
      expect(state('slides.view.zoomFit').checked, isTrue);
    });

    test('when the inspector and the Animate alias open then tab, section '
        'and sub-tab follow (Q21)', () async {
      await d.run('slides.view.toggleInspector');
      await d.run('slides.inspector.open', {
        'tab': 'format',
        'section': 'arrange',
      });
      expect(ed().inspectorVisible, isTrue);
      expect(ed().inspectorTab, InspectorTab.format);
      expect(ed().inspectorSection, 'arrange');

      // The Animate tab (SL-30) ships: alias command and tab.
      expect(d.services.registry.byId('slides.panel.animate'), isNotNull);
      await d.run('slides.inspector.open', {'tab': 'animate'});
      expect(ed().inspectorTab, InspectorTab.animate);
      ed().openInspector(InspectorTab.animate);
      expect(ed().inspectorTab, InspectorTab.animate);
    });

    test('when the outline view and masters mode are asked for then both are '
        'offered and the mode switches (SL-34, SL-28)', () async {
      final st = state('slides.view.setMode', {'mode': 'outline'});
      expect(st.enabled, isTrue);
      await d.run('slides.view.setMode', {'mode': 'outline'});
      expect(ed().mode, DeckViewMode.outline);
      expect(state('slides.view.setMode', {'mode': 'masters'}).enabled, isTrue);
      final schema = d.services.registry
          .byId('slides.view.setMode')!
          .argsSchema
          .toJson();
      expect('$schema', contains('outline'));
    });

    test('when navigating then previous/next/go-to move the current slide '
        'and the ends disable with a reason', () async {
      expect(ed().currentEntry!.index, 0);
      expect(state('slides.nav.previousSlide').enabled, isFalse);
      expect(
        state('slides.nav.previousSlide').disabledReason,
        l.reasonFirstSlide,
      );

      await d.run('slides.nav.nextSlide');
      expect(ed().currentEntry!.index, 1);
      await d.run('slides.nav.goToSlide', {'index': 4});
      expect(ed().currentEntry!.index, 3);
      expect(state('slides.nav.nextSlide').enabled, isFalse);

      final groupId = d.model.groups.single.id;
      await d.run('slides.nav.goToGroup', {'groupId': groupId});
      expect(ed().currentEntry!.groupId, groupId);
      expect(ed().currentEntry!.index, 1);

      final r = await d.run('slides.nav.goToSlide', {'index': 9});
      expect(r.status, CommandStatus.failed);
    });

    test('when an agent invokes Go to slide without a slide then it fails '
        'instead of opening a dialog', () async {
      final r = await d.h.invoke(
        'slides.nav.goToSlide',
        const {},
        InvocationSource.mcp,
      );
      expect(r.status, CommandStatus.failed);
    });

    test('when Viewing mode is on then editing commands are disabled with '
        'the reason and Editing turns it off again', () async {
      d.services.registry.register(
        SlidesCommand(
          'test.slides.rename',
          label: (l) => 'Rename',
          mutates: true,
          run: (ctx, ed, a) {
            ed.apply(ctx, const SetDeckProps(title: 'Renamed'));
            return ok();
          },
        ),
      );
      await d.run('slides.mode.viewing');
      expect(ed().viewMode, isTrue);
      expect(d.doc.mode, 'viewing');
      final st = state('test.slides.rename');
      expect(st.enabled, isFalse);
      expect(st.disabledReason, l.reasonViewingMode);

      await d.run('slides.mode.editing');
      expect(ed().viewMode, isFalse);
      await d.run('test.slides.rename');
      expect(d.model.deck!.title, 'Renamed');
      expect(d.undoLabels, hasLength(1));
    });

    test('when a placeholder command is invoked then it is unknown: '
        'unbuilt features are hidden, not disabled (SL-23)', () async {
      // Import slides (04 §13.9) stays a P1 placeholder.
      expect(d.services.registry.byId('slides.file.importSlides'), isNull);
      expect(
        SlidesFeatures.featureOfCommand('slides.file.importSlides'),
        SlidesFeature.importSlides,
      );
      await expectLater(
        d.run('slides.file.importSlides'),
        throwsA(isA<Object>()),
      );
    });

    test('when a deck op is undone then the current slide is restored with '
        'the selection snapshot', () async {
      d.registerOp(
        'test.slides.skip',
        (a) => SetSlideProps([a.requireString('slideId')], skipped: true),
        argsSchema: const JsonSchema.object(
          properties: {'slideId': JsonSchema.string()},
        ),
      );
      final first = ed().order.entries.first.id;
      await d.run('test.slides.skip', {'slideId': first});
      await d.run('slides.nav.nextSlide');
      await d.run('slides.nav.nextSlide');
      expect(ed().currentEntry!.index, 2);

      await d.undo();
      expect(ed().currentSlideId, first);
      expect(d.model.slide(first)!.skipped, isFalse);
    });

    test('when the current slide is deleted remotely then its neighbor '
        'becomes current', () async {
      await d.run('slides.nav.goToSlide', {'index': 4});
      final last = ed().currentSlideId!;
      d.session.execute(DeleteSlides([last]));
      expect(ed().currentSlideId, isNot(last));
      expect(ed().currentEntry!.index, 2);
    });

    test('when MCP reads the document state then the editor state is '
        'described', () {
      final s = d.doc.describeState();
      expect(s['slideCount'], 4);
      expect(s['currentSlideIndex'], 0);
      expect(s['viewMode'], 'normal');
      expect(s['selectionKind'], 'none');
      expect(s['zoom'], 'fit');
      expect(d.doc.selectionSummary, 'slide 1 of 4');
    });
  });

  group('Given a viewer', () {
    setUp(() async {
      await d.dispose();
      d = DeckHarness.open(fixture: sampleDeck(), role: Role.viewer);
    });

    test('when Editing is checked then it is disabled with "You have view '
        'access" while navigation still works', () async {
      final st = state('slides.mode.editing');
      expect(st.enabled, isFalse);
      expect(st.disabledReason, l.reasonViewAccess);
      expect(ed().viewMode, isTrue);
      await d.run('slides.nav.nextSlide');
      expect(ed().currentEntry!.index, 1);
      expect(
        state('slides.view.setMode', {'mode': 'masters'}).enabled,
        isFalse,
      );
    });
  });

  group('Given the Slides settings commands', () {
    test('when valid values are set then the preferences change, and '
        'invalid keys or values fail', () async {
      final defaults = SlidesUserDefaults.of(d.services);
      await d.run('slides.prefs.set', {
        'key': 'defaultThemeKey',
        'value': 'midnight',
      });
      await d.run('slides.presenter.set', {
        'key': 'timerMode',
        'value': 'countdown',
      });
      expect(
        defaults.string(SlidesUserDefaults.keyDefaultThemeKey),
        'midnight',
      );
      expect(
        defaults.presenterString(SlidesUserDefaults.keyTimerMode),
        'countdown',
      );

      final bad = await d.run('slides.prefs.set', {
        'key': 'defaultThemeKey',
        'value': 'nope',
      });
      expect(bad.status, CommandStatus.failed);
      final badValue = await d.run('slides.presenter.set', {
        'key': 'notesSize',
        'value': 400,
      });
      expect(badValue.status, CommandStatus.failed);
      expect(defaults.presenterInt(SlidesUserDefaults.keyNotesSize), 18);
    });
  });
}
