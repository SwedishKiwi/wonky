import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/layers/layers_controller.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/testing.dart';

import '../harness/deck_harness.dart';

/// The Layers panel's commands (Slides 03 §8.1, §17.2; SL-34).
void main() {
  late DeckBuilder b;
  late String slide, back, front, grp, child;
  late DeckHarness d;

  setUp(() {
    b = DeckBuilder(title: 'Layers');
    slide = b.slide(layoutKey: 'blank');
    back = b.shape(slide, x: 100, y: 100);
    grp = '00000000-0000-4000-8000-00000000bb01';
    child = b.shape(
      slide,
      x: 900,
      y: 100,
      width: 100,
      height: 100,
      parentId: grp,
    );
    b.shape(slide, x: 1100, y: 300, width: 100, height: 100, parentId: grp);
    b.elementGroup(
      slide,
      groupId: grp,
      x: 900,
      y: 100,
      width: 300,
      height: 300,
    );
    front = b.shape(slide, x: 400, y: 600);
    d = DeckHarness.open(fixture: b);
    d.editor.setCurrentSlide(slide);
  });
  tearDown(() => d.dispose());

  List<String> top() => [
    for (final e in d.model.indexes.tree(slide).roots) e.id,
  ];

  test('when the Layers panel is opened on the reading order tab then the '
      'tab is remembered', () async {
    final r = await d.run('slides.panel.layers', {'tab': 'readingOrder'});

    expect((r.data as Map)['tab'], 'readingOrder');
    expect(layersOf(d.editor).tab, LayersTab.readingOrder);
  });

  test('when the selection is set behind a shape then it moves there in '
      'one step that undoes', () async {
    selectionOf(d.editor).select([front]);

    await d.run('slides.arrange.setZ', {'belowId': back});

    expect(top().first, front);
    expect(d.editor.selectedElementIds, [front]);
    expect(d.undoLabels, hasLength(1));
    await d.undo();
    expect(top().last, front);
  });

  test('when an element is dropped into a group then it is re-parented and '
      'stays selected', () async {
    selectionOf(d.editor).select([front]);

    await d.run('slides.arrange.setZ', {'groupId': grp});

    expect(d.model.element(front)!.parentId, grp);
    expect(d.editor.selectedElementIds, [front]);
    await d.undo();
    expect(d.model.element(front)!.parentId, isNull);
  });

  test('when a group would move into its own child then setZ is '
      'disabled', () {
    final st = d.services.dispatcher.stateOf('slides.arrange.setZ', {
      'ids': [grp],
      'groupId': grp,
    });
    expect(st.enabled, isFalse);
    expect(
      d.services.dispatcher.stateOf('slides.arrange.setZ', {
        'ids': [grp],
        'aboveId': child,
      }).enabled,
      isTrue,
    );
  });

  test('when a reading order is set and reset then the keys are written and '
      'cleared, each one step', () async {
    await d.run('slides.a11y.setReadingOrder', {
      'ids': [front, back],
    });
    expect(d.model.element(front)!.readingKey, isNotNull);
    expect(
      d.services.dispatcher.stateOf('slides.a11y.resetReadingOrder').enabled,
      isTrue,
    );

    await d.run('slides.a11y.resetReadingOrder');

    expect(d.model.element(front)!.readingKey, isNull);
    expect(d.undoLabels, hasLength(2));
    expect(
      d.services.dispatcher.stateOf('slides.a11y.resetReadingOrder').enabled,
      isFalse,
    );
  });

  test('when lock and unlock name ids then those elements change without '
      'a selection', () async {
    await d.run('slides.element.lock', {
      'ids': [back],
    });
    expect(d.model.element(back)!.locked, isTrue);
    expect(d.editor.selectedElementIds, isEmpty);

    await d.run('slides.element.unlock', {
      'ids': [back],
    });
    expect(d.model.element(back)!.locked, isFalse);
  });
}
