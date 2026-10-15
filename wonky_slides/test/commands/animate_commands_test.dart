import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/config/slides_features.dart';
import 'package:wonky_slides/features/builds/animate_preview.dart';
import 'package:wonky_slides/features/builds/animate_view.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart';
import 'package:wonky_slides/features/settings/slides_user_defaults.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/testing.dart';

import '../harness/deck_harness.dart';

void main() {
  late DeckBuilder b;
  late String s1, s2, title, body, shape, image, code;
  late DeckHarness d;

  setUp(() {
    SlidesFeatures.enabled = {
      ...SlidesFeatures.shipped,
      SlidesFeature.animations,
    };
    b = DeckBuilder(title: 'Motion');
    s1 = b.slide(layoutKey: 'blank');
    title = b.textBox(s1, 'Pricing', y: 80);
    body = b.textBox(s1, 'One\nTwo\nThree', y: 300, height: 300);
    shape = b.shape(s1, x: 1200, y: 400);
    image = b.element(s1, ElementKind.image, x: 1300, y: 700);
    (code, _) = b.codeBlock(
      s1,
      states: ['a = 1', 'a = 2\nb = 3'],
      highlights: ['1|2', '1|2|3'],
    );
    s2 = b.slide(layoutKey: 'blank');
    b.textBox(s2, 'Second');
    d = DeckHarness.open(fixture: b);
    d.editor.setCurrentSlide(s1);
  });
  tearDown(() async {
    AnimateView.maybeOf(d.editor)?.preview.stop();
    await d.dispose();
    SlidesFeatures.reset();
  });

  Future<CommandResult> agent(
    String id, [
    Map<String, Object?> args = const {},
  ]) => d.h.invoke(id, args, InvocationSource.mcp);

  /// 06 AC 11: execute → undo → redo, one undo step.
  Future<CommandResult> roundTrip(
    String id,
    Map<String, Object?> args, {
    InvocationSource source = InvocationSource.mcp,
  }) async {
    final before = d.model.dump();
    final steps = d.undoLabels.length;
    final r = await d.h.invoke(id, args, source);
    expect(r.status, CommandStatus.ok, reason: '$id: ${r.message}');
    final after = d.model.dump();
    expect(after, isNot(equals(before)), reason: '$id changed nothing');
    expect(d.undoLabels.length, steps + 1, reason: '$id: one undo step');
    await d.undo();
    expect(d.model.dump(), before, reason: '$id undo');
    await d.redo();
    expect(d.model.dump(), after, reason: '$id redo');
    return r;
  }

  List<SlideBuildRec> builds([String? slide]) => d.model.buildsOf(slide ?? s1);

  List<String> idsOf(CommandResult r) =>
      ((r.data! as Map)['buildIds'] as List).cast<String>();

  Map<String, Object?> options(SlideBuildRec b) => b.optionsJson == null
      ? const {}
      : jsonDecode(b.optionsJson!) as Map<String, Object?>;

  group('Given a slide without builds', () {
    test('when an agent adds Rise by paragraph then one build with the '
        'catalog defaults is appended and one undo removes it', () async {
      final r = await roundTrip('slides.animate.addBuild', {
        'elementIds': [body],
        'kind': 'buildIn',
        'effect': 'rise',
        'delivery': {'by': 'paragraph'},
        'afterBuild': {'mode': 'dim'},
      });
      final b = builds().single;
      expect(idsOf(r), [b.id]);
      expect(
        (b.kind, b.effect, b.trigger),
        (SlideBuildKind.buildIn, 'rise', SlideBuildTrigger.onClick),
      );
      expect(b.durationMs, 600);
      expect(b.easing, 'spring(0.6,0)');
      expect(options(b)['delivery'], {'by': 'paragraph'});
      expect((options(b)['afterBuild'] as Map)['mode'], 'dim');
      // 06 AC 1: one click per bullet.
      expect(AnimateView.of(d.editor).timelineOf(s1).stepCount, 3);
    });

    test('when the context menu adds a build in without an effect then the '
        'Default build setting is used and the Build tab opens', () async {
      d.editor.selectElements([shape]);
      final r = await d.run('slides.animate.addBuild', {'kind': 'in'});
      expect(r.status, CommandStatus.ok);
      expect(builds().single.effect, 'appear');
      expect(d.editor.inspectorTab, InspectorTab.animate);
      expect(d.editor.animateTab, 'build');
      expect(AnimateView.of(d.editor).selectedBuildIds, [builds().single.id]);
    });

    test('when several objects get a build then the topmost starts on '
        'click and the rest with it; Alt inverts the triggers', () async {
      await agent('slides.animate.addBuild', {
        'elementIds': [title, shape],
        'kind': 'buildIn',
        'effect': 'fade',
      });
      expect(
        [for (final x in builds()) x.trigger],
        [SlideBuildTrigger.onClick, SlideBuildTrigger.withPrevious],
      );
      // The shape is above the title (added later): it comes first.
      expect(builds().first.elementId, shape);
      await agent('slides.animate.addBuild', {
        'elementIds': [title, shape],
        'kind': 'buildOut',
        'effect': 'fadeOut',
        'alt': true,
      });
      expect(
        [for (final x in builds().skip(2)) x.trigger],
        [SlideBuildTrigger.withPrevious, SlideBuildTrigger.onClick],
      );
    });

    test('when Typewriter is added to an image then it is refused with the '
        'reason', () async {
      final r = await agent('slides.animate.addBuild', {
        'elementIds': [image],
        'kind': 'buildIn',
        'effect': 'typewriter',
      });
      expect(r.status, CommandStatus.failed);
      expect(r.message, 'Typewriter works on text only');
      expect(builds(), isEmpty);
    });

    test('when a build is inserted at index 0 then it comes first', () async {
      await agent('slides.animate.addBuild', {
        'elementIds': [title],
        'kind': 'in',
        'effect': 'fade',
      });
      await roundTrip('slides.animate.addBuild', {
        'elementIds': [shape],
        'kind': 'in',
        'effect': 'pop',
        'at': {'index': 0},
      });
      expect([for (final x in builds()) x.effect], ['pop', 'fade']);
    });

    test('when nothing is selected then adding is disabled with a reason', () {
      final st = d.services.dispatcher.stateOf('slides.animate.addBuild', {
        'kind': 'in',
      });
      expect(st.enabled, isFalse);
      expect(st.disabledReason, 'Select an object');
    });
  });

  group('Given builds on the slide', () {
    late String bTitle, bBody, bShape;
    setUp(() async {
      final r = await agent('slides.animate.addBuild', {
        'elementIds': [title],
        'kind': 'in',
        'effect': 'fade',
      });
      bTitle = idsOf(r).single;
      bBody = idsOf(
        await agent('slides.animate.addBuild', {
          'elementIds': [body],
          'kind': 'in',
          'effect': 'rise',
        }),
      ).single;
      bShape = idsOf(
        await agent('slides.animate.addBuild', {
          'elementIds': [shape],
          'kind': 'emphasis',
          'effect': 'pulse',
        }),
      ).single;
    });

    test('when the effect changes then duration and easing take the new '
        'defaults and the params reset', () async {
      await agent('slides.animate.updateBuild', {
        'buildIds': [bBody],
        'patch': {
          'options': {
            'params': {'distance': 80},
          },
        },
      });
      expect(options(d.model.build(bBody)!)['params'], {'distance': 80});
      await roundTrip('slides.animate.updateBuild', {
        'buildIds': [bBody],
        'patch': {'effect': 'zoom'},
      });
      final x = d.model.build(bBody)!;
      expect((x.effect, x.durationMs, x.easing), ('zoom', 600, 'easeOutQuint'));
      expect(options(x)['params'], isNull);
    });

    test(
      'when an option is patched then the rest of optionsJson stays',
      () async {
        await agent('slides.animate.updateBuild', {
          'buildIds': [bBody],
          'patch': {
            'options': {
              'delivery': {'by': 'word'},
            },
          },
        });
        await roundTrip('slides.animate.updateBuild', {
          'buildIds': [bBody],
          'patch': {
            'options': {
              'delivery': {'order': 'backward'},
            },
          },
        });
        expect(options(d.model.build(bBody)!)['delivery'], {
          'by': 'word',
          'order': 'backward',
        });
      },
    );

    test('when a slider edits the duration several times with one '
        'coalesceKey then it is one undo step', () async {
      final steps = d.undoLabels.length;
      for (final ms in [700, 800, 900]) {
        final r = await d.run('slides.animate.updateBuild', {
          'buildIds': [bTitle],
          'patch': {'durationMs': ms},
          'coalesceKey': 'duration',
        });
        expect(r.status, CommandStatus.ok);
      }
      expect(d.model.build(bTitle)!.durationMs, 900);
      expect(d.undoLabels.length, steps + 1);
      await d.undo();
      expect(d.model.build(bTitle)!.durationMs, 500);
    });

    test('when an unknown effect is set then it is refused', () async {
      final r = await agent('slides.animate.updateBuild', {
        'buildIds': [bTitle],
        'patch': {'effect': 'sparkle'},
      });
      expect(r.status, CommandStatus.failed);
    });

    test('when the trigger is set then the steps follow (06 §4.2)', () async {
      expect(AnimateView.of(d.editor).timelineOf(s1).stepCount, 3);
      await roundTrip('slides.animate.setTrigger', {
        'buildIds': [bBody],
        'trigger': 'withPrevious',
      });
      expect(AnimateView.of(d.editor).timelineOf(s1).stepCount, 2);
      final st = d.services.dispatcher.stateOf('slides.animate.setTrigger', {
        'buildIds': [bBody],
        'trigger': 'withPrevious',
      });
      expect(st.checked, isTrue);
    });

    test('when builds move up, down and to an index then the order follows '
        'and the edges are disabled', () async {
      await roundTrip('slides.animate.moveBuilds', {
        'buildIds': [bShape],
        'by': -1,
      });
      expect([for (final x in builds()) x.id], [bTitle, bShape, bBody]);
      await roundTrip('slides.animate.moveBuilds', {
        'buildIds': [bShape],
        'to': {'index': 0},
        'trigger': 'onClick',
      });
      expect([for (final x in builds()) x.id], [bShape, bTitle, bBody]);
      final st = d.services.dispatcher.stateOf('slides.animate.moveBuilds', {
        'buildIds': [bShape],
        'by': -1,
      });
      expect(st.enabled, isFalse);
      await roundTrip('slides.animate.moveBuilds', {
        'buildIds': [bShape],
        'to': {'afterBuildId': bBody},
      });
      expect([for (final x in builds()) x.id], [bTitle, bBody, bShape]);
    });

    test(
      'when the selected builds are deleted then undo restores them',
      () async {
        AnimateView.of(d.editor).selectBuilds([bTitle, bShape]);
        await roundTrip('slides.animate.deleteBuilds', {});
        expect([for (final x in builds()) x.id], [bBody]);
      },
    );

    test('when the context menu removes the animations of the selected '
        'object then its builds go', () async {
      AnimateView.of(d.editor).clearBuildSelection();
      d.editor.selectElements([shape]);
      await roundTrip('slides.animate.deleteBuilds', {});
      expect(builds().any((x) => x.elementId == shape), isFalse);
    });

    test('when every animation of the slide is removed then the slide has '
        'none and Remove all is disabled', () async {
      await roundTrip('slides.animate.removeAll', {});
      expect(builds(), isEmpty);
      expect(
        d.services.dispatcher.stateOf('slides.animate.removeAll').enabled,
        isFalse,
      );
    });

    test('when the title\'s animation is copied and pasted on the shape '
        'then the shape gets the same build at the end', () async {
      final c = await agent('slides.animate.copyBuilds', {'elementId': title});
      expect((c.data! as Map)['count'], 1);
      final r = await roundTrip('slides.animate.pasteBuilds', {
        'elementIds': [image],
      });
      final pasted = d.model.build(idsOf(r).single)!;
      expect((pasted.elementId, pasted.effect), (image, 'fade'));
      expect(builds().last.id, pasted.id);
    });

    test('when a build is selected then the Order list rows carry steps, '
        'parts and timing', () {
      final o = AnimateView.of(d.editor).orderOf(s1);
      expect([for (final r in o.rows) r.step], [1, 2, 3]);
      expect(o.rowOf(bBody)!.durationMs, greaterThan(0));
      expect(o.steps.map((s) => s.index), [1, 2, 3]);
      expect(o.byElement[shape]!.single.id, bShape);
    });

    test('when the whole slide is previewed then a preview plays from step '
        '0 and Stop ends it', () async {
      final r = await d.run('slides.animate.preview');
      expect(r.status, CommandStatus.ok);
      final p = AnimateView.of(d.editor).preview;
      expect(p.active, isTrue);
      expect(p.kind, PreviewKind.slide);
      expect(p.timeline!.stepCount, 3);
      expect(
        d.services.dispatcher.stateOf('slides.animate.stopPreview').enabled,
        isTrue,
      );
      await d.run('slides.animate.stopPreview');
      expect(p.active, isFalse);
    });

    test(
      'when previewing from a build then the preview starts at its step',
      () async {
        await d.run('slides.animate.preview', {'fromBuildId': bShape});
        final p = AnimateView.of(d.editor).preview;
        expect((p.kind, p.step), (PreviewKind.fromBuild, 3));
      },
    );

    test('when the builds change during a preview then it stops', () async {
      await d.run('slides.animate.preview');
      await agent('slides.animate.deleteBuilds', {
        'buildIds': [bShape],
      });
      expect(AnimateView.of(d.editor).preview.active, isFalse);
    });
  });

  group('Given a code block with two states and highlight steps', () {
    test('when Build all steps runs then each step and state change is one '
        'click', () async {
      final r = await roundTrip('slides.animate.buildAllSteps', {
        'elementId': code,
      });
      final ids = idsOf(r);
      final effects = [
        for (final id in ids)
          '${d.model.build(id)!.effect} '
              '${jsonEncode(options(d.model.build(id)!)['params'])}',
      ];
      expect(effects, [
        'codeHighlight {"step":1}',
        'codeHighlight {"step":2}',
        'codeState {"state":2}',
        'codeHighlight {"step":1}',
        'codeHighlight {"step":2}',
        'codeHighlight {"step":3}',
      ]);
    });

    test('when a text box is selected then Build all steps is disabled', () {
      d.editor.selectElements([title]);
      final st = d.services.dispatcher.stateOf('slides.animate.buildAllSteps');
      expect(st.enabled, isFalse);
      expect(st.disabledReason, 'Select a code block with steps or a chart');
    });
  });

  group('Given motion builds', () {
    test('when a motion path preset is chosen then the path is written and '
        'one undo step', () async {
      final r = await agent('slides.animate.addBuild', {
        'elementIds': [shape],
        'kind': 'motion',
        'effect': 'path',
      });
      final id = idsOf(r).single;
      await roundTrip('slides.animate.setMotionPath', {
        'buildId': id,
        'preset': 'arc',
      });
      final params = options(d.model.build(id)!)['params'] as Map;
      expect(params['preset'], 'arc');
      expect(params['path'], startsWith('M0 0 Q'));
    });

    test('when a transform target is set then params.to holds it', () async {
      final r = await agent('slides.animate.addBuild', {
        'elementIds': [shape],
        'kind': 'action',
        'effect': 'moveTo',
      });
      final id = idsOf(r).single;
      expect(d.model.build(id)!.kind, SlideBuildKind.motion);
      await roundTrip('slides.animate.setTransformTarget', {
        'buildId': id,
        'to': {'x': 200, 'rotation': 45},
      });
      expect((options(d.model.build(id)!)['params'] as Map)['to'], {
        'x': 200,
        'rotation': 45,
      });
    });
  });

  group('Given transitions', () {
    TransitionSpec spec(String slide) => TransitionSpec.effective(
      d.model.slide(slide)!.transitionJson,
      d.model.deck?.defaultsJson,
    );

    test('when Push from the left is set then the slide has it and one '
        'undo restores the cut', () async {
      await roundTrip('slides.transition.set', {
        'transition': {
          'type': 'push',
          'params': {'direction': 'right'},
        },
      });
      expect(spec(s1).type, 'push');
      expect(spec(s1).durationMs, 700);
      expect(spec(s1).params['direction'], 'right');
    });

    test('when several slides are selected then the transition applies to '
        'all of them', () async {
      d.editor.selectSlides([s1, s2]);
      await roundTrip('slides.transition.set', {
        'transition': {'type': 'cube'},
      });
      expect([spec(s1).type, spec(s2).type], ['cube', 'cube']);
    });

    test('when an unknown type is set then it is refused', () async {
      final r = await agent('slides.transition.set', {
        'transition': {'type': 'warp'},
      });
      expect(r.status, CommandStatus.failed);
    });

    test('when it is applied to all slides then the deck default holds it '
        'and the slides inherit', () async {
      await agent('slides.transition.set', {
        'slideIds': [s2],
        'transition': {'type': 'fade'},
      });
      await agent('slides.transition.set', {
        'transition': {'type': 'flip'},
      });
      await roundTrip('slides.transition.applyToAll', {});
      expect(d.model.slide(s2)!.transitionJson, isNull);
      expect(spec(s2).type, 'flip');
      expect(
        DeckMotionDefaults.decode(d.model.deck?.defaultsJson).transition?.type,
        'flip',
      );
    });

    test('when the transition is removed then the slide cuts', () async {
      await agent('slides.transition.set', {
        'transition': {'type': 'fade'},
      });
      await roundTrip('slides.transition.remove', {});
      expect(spec(s1).isNone, isTrue);
    });

    test('when the slide advances automatically after 3 s then advance '
        'holds it', () async {
      await roundTrip('slides.transition.setAdvance', {
        'advance': {'mode': 'auto', 'afterMs': 3000},
      });
      expect(spec(s1).advance.auto, isTrue);
      expect(spec(s1).advance.afterMs, 3000);
    });

    test(
      'when the transition is previewed then a transition preview plays',
      () async {
        d.editor.setCurrentSlide(s2);
        await d.run('slides.transition.preview');
        final p = AnimateView.of(d.editor).preview;
        expect(
          (p.active, p.kind, p.slideId),
          (true, PreviewKind.transition, s2),
        );
      },
    );
  });

  group('Given Magic Move', () {
    test('when a Magic Move slide is added then the copy follows with the '
        'Magic Move transition in one undo step', () async {
      final r = await roundTrip('slides.slide.duplicateForMagicMove', {});
      final copy = (r.data! as Map)['slideId'] as String;
      expect(d.editor.order.indexOf(copy), d.editor.order.indexOf(s1) + 1);
      expect(
        TransitionSpec.effective(
          d.model.slide(copy)!.transitionJson,
          d.model.deck?.defaultsJson,
        ).type,
        'magicMove',
      );
      // Elements keep their match keys (06 §8.2).
      final keys = {for (final e in d.model.elementsOf(s1)) e.matchKey};
      expect({for (final e in d.model.elementsOf(copy)) e.matchKey}, keys);
    });

    test('when a Magic Move ID is set then the element has it', () async {
      d.editor.selectElements([shape]);
      await roundTrip('slides.element.setMatchKey', {'matchKey': 'logo'});
      expect(d.model.element(shape)!.matchKey, 'logo');
    });

    test('when the canvas toggles flip then they are checked', () async {
      await d.run('slides.animate.toggleOrderOverlay');
      await d.run('slides.magicMove.toggleMatches');
      expect(
        d.services.dispatcher
            .stateOf('slides.animate.toggleOrderOverlay')
            .checked,
        isTrue,
      );
      expect(
        d.services.dispatcher.stateOf('slides.magicMove.toggleMatches').checked,
        isTrue,
      );
    });
  });

  group('Given the animations feature is off', () {
    test(
      'when the harness opens then no animate command is registered',
      () async {
        SlidesFeatures.enabled = {...SlidesFeatures.shipped}
          ..remove(SlidesFeature.animations);
        addTearDown(SlidesFeatures.reset);
        final h = DeckHarness.open(fixture: DeckBuilder()..slide());
        addTearDown(h.dispose);
        for (final id in [
          'slides.animate.addBuild',
          'slides.transition.set',
          'slides.element.setMatchKey',
          'slides.slide.duplicateForMagicMove',
        ]) {
          expect(h.services.registry.byId(id), isNull, reason: id);
        }
      },
    );
  });

  group('Given the Animations settings', () {
    test('when a default transition is chosen then blank presentations get '
        'it as their deck default, and None writes nothing', () async {
      final u = SlidesUserDefaults.of(d.services);
      expect(SlidesUserDefaults.deckDefaultsJson(u), isNull);
      await u.set(SlidesUserDefaults.keyDefaultTransition, 'cube');
      await u.set(SlidesUserDefaults.keyDefaultTransitionMs, 1500);
      final t = DeckMotionDefaults.decode(
        SlidesUserDefaults.deckDefaultsJson(u),
      ).transition!;
      expect((t.type, t.durationMs), ('cube', 1500));
      expect(SlidesUserDefaults.transitions, isNot(contains('magicMove')));
      expect(SlidesUserDefaults.builds, containsAll(['appear', 'rise']));
      expect(SlidesUserDefaults.builds, isNot(contains('typewriter')));
    });
  });

  group('Given the editor in masters mode', () {
    test('when builds would be added then it is refused', () async {
      d.editor.selectElements([shape]);
      d.editor.setMode(DeckViewMode.masters);
      final st = d.services.dispatcher.stateOf('slides.animate.addBuild', {
        'kind': 'in',
        'effect': 'fade',
      });
      expect(st.enabled, isFalse);
    });
  });
}
