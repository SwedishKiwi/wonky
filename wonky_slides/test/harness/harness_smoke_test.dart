import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/ops.dart';

import 'deck_harness.dart';

const _titleArgs = JsonSchema.object(
  properties: {'title': JsonSchema.string()},
  required: ['title'],
);

void main() {
  group('Given the deck harness with a one-slide deck', () {
    late DeckHarness d;

    setUp(() {
      d = DeckHarness.open();
      d.registerOp(
        'test.slides.rename',
        (a) => SetDeckProps(title: a.requireString('title')),
        argsSchema: _titleArgs,
      );
      d.registerOp('test.slides.noop', (_) => const SetDeckProps());
    });

    tearDown(() async => d.dispose());

    test('when a no-op command runs then it succeeds and pushes no undo '
        'step', () async {
      final r = await d.run('test.slides.noop');

      expect(r.isOk, isTrue);
      expect(d.undoLabels, isEmpty);
      expect(d.session.persisted, isEmpty);
    });

    test('when a command executes, is undone and redone then the deck '
        'follows each step through the real undo service', () async {
      final before = d.model.dump();

      await d.run('test.slides.rename', {'title': 'Q3 review'});
      final after = d.model.dump();
      expect(d.model.deck!.title, 'Q3 review');
      expect(d.undoLabels, ['test.slides.rename']);

      await d.undo();
      expect(d.model.dump(), before);

      await d.redo();
      expect(d.model.dump(), after);
      expect(d.session.persistedLabels, [
        'Rename presentation',
        'Undo Rename presentation',
        'Redo Rename presentation',
      ]);
    });

    test('when a viewer invokes an editing command then the dispatcher '
        'refuses it and nothing changes', () async {
      await d.dispose();
      d = DeckHarness.open(role: Role.viewer);
      d.registerOp(
        'test.slides.rename',
        (a) => SetDeckProps(title: a.requireString('title')),
        argsSchema: _titleArgs,
      );
      final before = d.model.dump();

      await expectLater(
        d.run('test.slides.rename', {'title': 'Nope'}),
        throwsA(isA<CommandException>()),
      );
      expect(d.model.dump(), before);
    });
  });
}
