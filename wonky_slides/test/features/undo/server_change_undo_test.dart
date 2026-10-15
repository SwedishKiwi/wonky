import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/features/undo/server_change_undo.dart';

import '../../harness/deck_harness.dart';
import '../../support/slides_harness.dart';

String _id(int n) =>
    '00000000-0000-7000-8000-${n.toRadixString(16).padLeft(12, '0')}';

RevertResult _result(int n, {bool skipped = false}) => RevertResult(
  changeId: UuidValue.fromString(_id(n)),
  revertedCells: 1,
  skipped: [
    if (skipped)
      RevertSkip(
        table: 'slide_element',
        rowId: UuidValue.fromString(_id(0xff)),
        column: 'text',
        reason: 'changed_by_other',
      ),
  ],
);

/// The `slides.serverChange` undo domain (Slides 02 §12.2; SL-43, reused by
/// SL-39's restores).
void main() {
  group('SlidesServerChangeHandler', () {
    test('when undone then redone then revert and reapply are called with '
        'the latest record and the entry round-trips through JSON', () async {
      final h = slidesHarness();
      addTearDown(h.dispose);
      final reverts = <String>[];
      final reapplies = <String>[];
      final handler = SlidesServerChangeHandler(
        h.services,
        revert: (id) async {
          reverts.add(id);
          return _result(2);
        },
        reapply: (id) async {
          reapplies.add(id);
          return _result(3);
        },
      );
      final e = SlidesServerChangeEntry(changeId: _id(1), label: 'AI: x');
      final undone = await handler.undo(e);
      expect(undone.reverted, isTrue);
      final redone = await handler.redo(undone);
      expect(reverts, [_id(1)]);
      expect(reapplies, [_id(2)]);
      expect(redone.changeId, _id(3));
      expect(redone.reverted, isFalse);
      final json = SlidesServerChangeEntry.fromJson(undone.toJson())!;
      expect(json.changeId, _id(2));
      expect(json.reverted, isTrue);
      expect(json.label, 'AI: x');
    });

    test('when the server reports skipped columns then the undo still '
        'succeeds; not found and expired become undo conflicts', () async {
      final h = slidesHarness();
      addTearDown(h.dispose);
      var fail = false;
      final handler = SlidesServerChangeHandler(
        h.services,
        revert: (id) async {
          if (fail) {
            throw WonkyException(
              code: WonkyErrorCode.expired,
              message: 'The change can no longer be undone.',
            );
          }
          return _result(2, skipped: true);
        },
      );
      final partial = await handler.undo(
        SlidesServerChangeEntry(changeId: _id(1)),
      );
      expect(partial.changeId, _id(2));
      fail = true;
      expect(
        () => handler.undo(SlidesServerChangeEntry(changeId: _id(1))),
        throwsA(isA<UndoConflict>()),
      );
    });

    test('when a step is pushed on the shell stack (a restore from the '
        'history route) then shell undo and redo call the server', () async {
      final h = slidesHarness();
      addTearDown(h.dispose);
      final calls = <String>[];
      h.services.undo.registerHandler(
        SlidesServerChangeHandler(
          h.services,
          revert: (id) async {
            calls.add('revert $id');
            return _result(2);
          },
          reapply: (id) async {
            calls.add('reapply $id');
            return _result(3);
          },
        ),
      );
      pushSlidesServerChangeStep(
        h.services,
        changeId: _id(1),
        label: 'Restore version',
        source: InvocationSource.ui,
        stack: UndoStackKey.shell,
      );
      expect(h.services.undo.undoLabel.value, 'Restore version');
      final undone = await h.services.undo.undo();
      expect(undone?.stack, UndoStackKey.shell);
      await h.services.undo.redo();
      expect(calls, ['revert ${_id(1)}', 'reapply ${_id(2)}']);
    });

    test('when an AI run is pushed on the open deck then the deck stack '
        'undoes it through the document handler', () async {
      final d = DeckHarness.open();
      addTearDown(d.dispose);
      final calls = <String>[];
      // The document's handler, with the server calls replaced.
      d.services.undo.registerHandler(
        SlidesServerChangeHandler(
          d.services,
          revert: (id) async {
            calls.add('revert $id');
            return _result(2);
          },
        ),
      );
      expect(
        d.doc.undoHandlers.map((x) => x.domain),
        contains(slidesServerChangeDomain),
      );
      final step = pushSlidesServerChangeStep(
        d.services,
        changeId: _id(1),
        label: 'AI: Make a deck',
      );
      expect(step, 'server-${_id(1)}');
      expect(d.undoLabels.first, 'AI: Make a deck');
      await d.undo();
      expect(calls, ['revert ${_id(1)}']);
    });
  });
}
