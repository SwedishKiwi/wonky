import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart';

class _FieldEntry extends UndoEntry {
  const _FieldEntry(this.target, this.before, this.after);
  final String target;
  final String before;
  final String after;
  @override
  String get domain => 'test';
  @override
  UndoEntry? rebase(RemoteChange change) {
    if (change is FieldRemoteChange && change.target == target) return null;
    return this;
  }

  @override
  Map<String, Object?> toJson() => {'t': target, 'b': before, 'a': after};
}

void main() {
  UndoStep step() => UndoStep(
    id: 's1',
    label: 'Rename',
    entries: const [_FieldEntry('a', '1', '2'), _FieldEntry('b', '1', '2')],
    selectionBefore: const SelectionSnapshot('drive.list', {
      'ids': ['a'],
    }),
    createdAt: DateTime.utc(2026),
    source: InvocationSource.mcp,
  );

  group('Given a step with two entries', () {
    test('when a remote change hits one target then that entry is dropped and '
        'the step is marked partial', () {
      final r = step().rebase(
        const FieldRemoteChange(domain: 'test', target: 'a', key: 'name'),
      );
      expect(r!.entries, hasLength(1));
      expect(r.partiallyRebased, isTrue);
    });

    test('when a remote change of another domain arrives then the step is '
        'unchanged', () {
      final s = step();
      expect(
        s.rebase(
          const FieldRemoteChange(domain: 'other', target: 'a', key: 'x'),
        ),
        same(s),
      );
    });

    test('when both targets change remotely then the step disappears', () {
      final s = step()
          .rebase(
            const FieldRemoteChange(domain: 'test', target: 'a', key: 'n'),
          )!
          .rebase(
            const FieldRemoteChange(domain: 'test', target: 'b', key: 'n'),
          );
      expect(s, isNull);
    });

    test('when persisted and decoded then the step round-trips', () {
      final json = step().toJson()!;
      final decoded = UndoStep.fromJson(json, {
        'test': (j) => _FieldEntry('${j['t']}', '${j['b']}', '${j['a']}'),
      })!;
      expect(decoded.label, 'Rename');
      expect(decoded.entries, hasLength(2));
      expect(decoded.source, InvocationSource.mcp);
      expect(decoded.selectionBefore, step().selectionBefore);
      expect(decoded.createdAt, DateTime.utc(2026));
    });

    test('when decoding without a decoder for the domain then null is '
        'returned', () {
      expect(UndoStep.fromJson(step().toJson()!, const {}), isNull);
    });
  });
}
