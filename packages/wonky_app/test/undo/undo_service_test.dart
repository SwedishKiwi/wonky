import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../support/counter_undo.dart';

const _doc = UndoStackKey('doc-1');

void main() {
  late Map<String, int> values;
  late CounterHandler handler;
  late UndoService undo;

  setUp(() {
    values = {'a': 0, 'b': 0};
    handler = CounterHandler(values);
    undo = UndoService(ids: UuidV7Generator())..registerHandler(handler);
    undo.setActiveDocument(_doc);
  });
  tearDown(() => undo.dispose());

  /// Applies `values[key] = to` as one undoable step.
  void change(
    String key,
    int to, {
    String label = 'Change',
    String? coalesceKey,
    UndoStackKey stack = _doc,
  }) {
    final t = undo.beginTransaction(
      label,
      stack: stack,
      coalesceKey: coalesceKey,
    );
    t.record(CounterEntry(key, values[key]!, to));
    values[key] = to;
    t.commit();
  }

  group('Given a committed step', () {
    setUp(() => change('a', 5, label: 'Set A'));

    test(
      'when undoing then the value is restored and redo is offered',
      () async {
        await undo.undo();

        expect(values['a'], 0);
        expect(undo.canUndo.value, isFalse);
        expect(undo.redoLabel.value, 'Set A');
      },
    );

    test('when undoing then redoing then the value is re-applied', () async {
      await undo.undo();
      await undo.redo();

      expect(values['a'], 5);
      expect(undo.undoLabel.value, 'Set A');
    });

    test(
      'when a new step is pushed after an undo then redo is cleared',
      () async {
        await undo.undo();
        change('b', 1);

        expect(undo.canRedo.value, isFalse);
      },
    );
  });

  test('Given a transaction without entries when committing then no step is '
      'pushed', () {
    undo.beginTransaction('Nothing', stack: _doc).commit();

    expect(undo.canUndo.value, isFalse);
  });

  test('Given a transaction when rolling back then its entries are reverted '
      'and nothing is pushed', () async {
    final t = undo.beginTransaction('Half', stack: _doc);
    t.record(const CounterEntry('a', 0, 3));
    values['a'] = 3;

    await t.rollback();

    expect(values['a'], 0);
    expect(undo.canUndo.value, isFalse);
  });

  group('Given steps with the same coalesce key', () {
    test('when they fall within the window then they merge into one step', () {
      final t0 = DateTime.utc(2026, 10, 12, 9);
      withClock(Clock.fixed(t0), () => change('a', 1, coalesceKey: 'typing'));
      withClock(
        Clock.fixed(t0.add(const Duration(milliseconds: 500))),
        () => change('a', 2, coalesceKey: 'typing'),
      );

      final steps = undo.undoStepsOf(_doc);
      expect(steps, hasLength(1));
      expect(
        steps.single.entries.single,
        isA<CounterEntry>()
            .having((e) => e.before, 'before', 0)
            .having((e) => e.after, 'after', 2),
      );
    });

    test('when they are further apart than the window then both are kept', () {
      final t0 = DateTime.utc(2026, 10, 12, 9);
      withClock(Clock.fixed(t0), () => change('a', 1, coalesceKey: 'typing'));
      withClock(
        Clock.fixed(t0.add(const Duration(seconds: 3))),
        () => change('a', 2, coalesceKey: 'typing'),
      );

      expect(undo.undoStepsOf(_doc), hasLength(2));
    });
  });

  test('Given a step whose entry conflicts when undoing then the other '
      'entries apply and the outcome is partial', () async {
    final t = undo.beginTransaction('Both', stack: _doc);
    t.record(const CounterEntry('a', 0, 1));
    t.record(const CounterEntry('b', 0, 1));
    values
      ..['a'] = 1
      ..['b'] = 1;
    t.commit();
    handler.conflicting.add('b');

    final outcome = await undo.undo();

    expect(outcome?.partial, isTrue);
    expect(values, {'a': 0, 'b': 1});
  });

  test('Given steps on the document and shell stacks when undoing then the '
      'most recent one across both is undone first', () async {
    final t0 = DateTime.utc(2026, 10, 12, 9);
    withClock(Clock.fixed(t0), () => change('a', 1, label: 'Doc'));
    withClock(
      Clock.fixed(t0.add(const Duration(seconds: 5))),
      () => change('b', 1, label: 'Drive', stack: UndoStackKey.shell),
    );

    expect([for (final h in undo.history()) h.step.label], ['Drive', 'Doc']);
    await undo.undo();
    expect(values, {'a': 1, 'b': 0});
  });

  test('Given three steps when undoing to the oldest then all three are '
      'undone in order', () async {
    final t0 = DateTime.utc(2026, 10, 12, 9);
    for (var i = 1; i <= 3; i++) {
      withClock(
        Clock.fixed(t0.add(Duration(seconds: i * 5))),
        () => change('a', i, label: 'Step $i'),
      );
    }
    final oldest = undo.history().last.step.id;

    await undo.undoTo(oldest);

    expect(values['a'], 0);
    expect(undo.canUndo.value, isFalse);
    expect(undo.redoStepsOf(_doc), hasLength(3));
  });

  test('Given more steps than the limit when pushing then the oldest are '
      'dropped', () {
    final small = UndoService(maxSteps: 2, ids: UuidV7Generator())
      ..registerHandler(handler)
      ..setActiveDocument(_doc);
    addTearDown(small.dispose);
    final t0 = DateTime.utc(2026, 10, 12, 9);
    for (var i = 1; i <= 3; i++) {
      withClock(Clock.fixed(t0.add(Duration(seconds: i * 5))), () {
        final t = small.beginTransaction('Step $i', stack: _doc);
        t.record(CounterEntry('a', i - 1, i));
        t.commit();
      });
    }

    expect(
      [for (final s in small.undoStepsOf(_doc)) s.label],
      ['Step 2', 'Step 3'],
    );
  });

  test('Given a remote delete of an entry target when rebasing then steps '
      'that become empty disappear', () {
    change('a', 1);

    undo.applyRemote(
      _doc,
      const FieldRemoteChange(
        domain: CounterEntry.domainName,
        target: 'a',
        key: 'value',
        deleted: true,
      ),
    );

    expect(undo.canUndo.value, isFalse);
  });

  test('Given a persisted stack when reopening it then the steps are '
      'restored', () async {
    final store = MemoryStore();
    final first = UndoService(persistence: store, ids: UuidV7Generator())
      ..registerHandler(handler);
    await first.openStack(_doc);
    first.setActiveDocument(_doc);
    final t = first.beginTransaction('Persisted', stack: _doc);
    t.record(const CounterEntry('a', 0, 7));
    t.commit();
    await first.closeStack(_doc);
    first.dispose();

    final second = UndoService(persistence: store, ids: UuidV7Generator())
      ..registerHandler(handler);
    addTearDown(second.dispose);
    await second.openStack(_doc);
    second.setActiveDocument(_doc);

    expect(second.undoLabel.value, 'Persisted');
    await second.undo();
    expect(values['a'], 0);
  });
}
