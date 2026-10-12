import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_write_core/testing.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../support/property.dart';

Delta d(List<Map<String, dynamic>> json) => Delta.fromJson(json);

Map<String, dynamic> sug(
  String t, {
  String by = 'u1',
  int at = 1,
  Map<String, dynamic>? before,
}) => {'t': t, 'by': by, 'at': at, 'before': ?before};

const ctx = SuggestionContext(userUuid: 'u1', nowMs: 100, suggestionId: 'S');

void main() {
  const rewriter = SuggestionRewriter();

  group('Given the suggestion rewriter', () {
    final doc = d([
      {'insert': 'ab'},
      {
        'insert': 'mine',
        'attributes': {'sug_o': sug('ins')},
      },
      {
        'insert': 'gone',
        'attributes': {'sug_x': sug('del', by: 'u2')},
      },
      {
        'insert': 'theirs',
        'attributes': {'sug_t': sug('ins', by: 'u2')},
      },
      {'insert': '\n'},
    ]);

    final cases = <(String, Delta, List<Map<String, dynamic>>)>[
      (
        'an insert gets an ins mark',
        Delta()
          ..retain(1)
          ..insert('X', {'sug_t': sug('ins', by: 'u2'), 'bold': true}),
        [
          {'retain': 1},
          {
            'insert': 'X',
            'attributes': {'bold': true, 'sug_S': sug('ins', at: 100)},
          },
        ],
      ),
      (
        'deleting plain text marks it deleted',
        Delta()..delete(2),
        [
          {
            'retain': 2,
            'attributes': {'sug_S': sug('del', at: 100)},
          },
        ],
      ),
      (
        'deleting own insertion is a real delete',
        Delta()
          ..retain(2)
          ..delete(4),
        [
          {'retain': 2},
          {'delete': 4},
        ],
      ),
      (
        'deleting already deleted text is a no-op',
        Delta()
          ..retain(6)
          ..delete(4),
        <Map<String, dynamic>>[],
      ),
      (
        'deleting others\' insertion marks it deleted',
        Delta()
          ..retain(10)
          ..delete(6),
        [
          {'retain': 10},
          {
            'retain': 6,
            'attributes': {'sug_S': sug('del', at: 100)},
          },
        ],
      ),
      (
        'formatting plain text adds fmt with before',
        Delta()..retain(2, {'bold': true}),
        [
          {
            'retain': 2,
            'attributes': {
              'bold': true,
              'sug_S': sug('fmt', at: 100, before: {}),
            },
          },
        ],
      ),
      (
        'formatting own insertion applies directly',
        Delta()
          ..retain(2)
          ..retain(4, {'italic': true}),
        [
          {'retain': 2},
          {
            'retain': 4,
            'attributes': {'italic': true},
          },
        ],
      ),
      (
        'a block change adds a block fmt',
        Delta()
          ..retain(16)
          ..retain(1, {'header': 2}),
        [
          {'retain': 16},
          {
            'retain': 1,
            'attributes': {
              'header': 2,
              'sug_S': sug('fmt', at: 100, before: {}),
            },
          },
        ],
      ),
      (
        'comment changes pass through',
        Delta()..retain(2, {'cmt_c': true}),
        [
          {
            'retain': 2,
            'attributes': {'cmt_c': true},
          },
        ],
      ),
    ];
    for (final (name, change, expected) in cases) {
      test('when rewriting: $name', () {
        expect(rewriter.rewrite(doc, change, ctx).toJson(), equals(expected));
      });
    }

    test(
      'when re-formatting own fmt back to the original then the mark is removed',
      () {
        final formatted = d([
          {
            'insert': 'ab',
            'attributes': {'bold': true, 'sug_f': sug('fmt', before: {})},
          },
          {'insert': '\n'},
        ]);

        final s = rewriter.rewrite(
          formatted,
          Delta()..retain(2, {'bold': null}),
          ctx,
        );

        expect(s.toJson(), [
          {
            'retain': 2,
            'attributes': {'bold': null, 'sug_f': null},
          },
        ]);
      },
    );
  });

  group('Given random documents and edits in suggesting mode', () {
    propertyTest(
      'when rewriting then the original view never changes and accepted equals the edit',
      (random, run) {
        final gen = DeltaGen(
          random,
          options: const DeltaGenOptions(embeds: false, mentions: false),
        );
        final edits = EditGen(random, deltaGen: gen);
        var doc = gen.document();
        // A few previous suggestions by other users.
        for (var i = 0; i < 2; i++) {
          final other = SuggestionContext(
            userUuid: 'u${2 + i}',
            nowMs: 10 + i,
            suggestionId: 'p$i',
          );
          final c = edits.change(doc);
          doc = WonkyOt.apply(doc, rewriter.rewrite(doc, c, other));
          doc = const WonkyDeltaNormalizer().normalize(doc).document;
        }
        final change = edits.change(doc);

        final s = rewriter.rewrite(
          doc,
          change,
          SuggestionContext(
            userUuid: 'u1',
            nowMs: 1000 + run,
            suggestionId: 'S',
          ),
        );
        final after = const WonkyDeltaNormalizer()
            .normalize(WonkyOt.apply(doc, s))
            .document;

        // Soft breaks typed into code blocks become line breaks (normalizer),
        // possibly in a different order of operations; compare line breaks
        // of either kind as equal.
        String text(Delta x) => DeltaUtils.text(x).replaceAll(softBreak, '\n');
        expect(
          text(SuggestionView.original(after)),
          text(SuggestionView.original(doc)),
        );
        expect(
          text(SuggestionView.accepted(after)),
          text(
            SuggestionView.accepted(
              const WonkyDeltaNormalizer()
                  .normalize(WonkyOt.apply(doc, change))
                  .document,
            ),
          ),
        );
      },
      runs: 150,
    );
  });

  group('Given a replacement suggestion', () {
    final doc = d([
      {'insert': 'keep '},
      {
        'insert': 'red',
        'attributes': {'sug_1': sug('del')},
      },
      {
        'insert': 'blue',
        'attributes': {'sug_1': sug('ins')},
      },
      {
        'insert': 'X',
        'attributes': {'bold': true, 'sug_2': sug('fmt', by: 'u2', before: {})},
      },
      {'insert': '\n'},
    ]);

    test('when accepting it then the old text is deleted and the new kept', () {
      final after = WonkyOt.apply(doc, SuggestionOps.accept(doc, {'1'}));

      expect(DeltaUtils.text(after), 'keep blueX\n');
      expect(SuggestionIndex.list(after).map((s) => s.id), ['2']);
    });

    test('when rejecting it then the new text is deleted and the old kept', () {
      final after = WonkyOt.apply(doc, SuggestionOps.reject(doc, {'1'}));

      expect(DeltaUtils.text(after), 'keep redX\n');
    });

    test('when rejecting a format suggestion then before is restored', () {
      final after = WonkyOt.apply(doc, SuggestionOps.reject(doc, {'2'}));

      expect(after.toJson().last, {'insert': 'X\n'});
    });

    test('when listing then parts and summaries describe the suggestions', () {
      final list = SuggestionIndex.list(doc);

      expect(list.map((s) => s.summary), [
        'Replace: ‘red’ with ‘blue’',
        'Format: Bold',
      ]);
      expect(list.first.parts.map((p) => (p.kind, p.start, p.length)), [
        (SuggestionPartKind.delete, 5, 3),
        (SuggestionPartKind.insert, 8, 4),
      ]);
    });

    test(
      'when accepting through an op then the decision is inferred as accepted',
      () {
        final op = SuggestionOps.accept(doc, {'1'});
        final inverse = WonkyOt.invert(op, doc);

        expect(
          SuggestionDecisions.infer(
            op: op,
            inverse: inverse,
            suggestionId: '1',
            actorUuid: 'editor',
          ),
          SuggestionDecision.accepted,
        );
      },
    );

    test('when the author rejects then the decision is withdrawn', () {
      final op = SuggestionOps.reject(doc, {'1'});

      expect(
        SuggestionDecisions.infer(
          op: op,
          inverse: WonkyOt.invert(op, doc),
          suggestionId: '1',
          actorUuid: 'u1',
        ),
        SuggestionDecision.withdrawn,
      );
    });

    test(
      'when a whole paragraph is deleted then the decision is superseded',
      () {
        final op = Delta()..delete(13);

        expect(
          SuggestionDecisions.infer(
            op: op,
            inverse: WonkyOt.invert(op, doc),
            suggestionId: '1',
            actorUuid: 'editor',
          ),
          SuggestionDecision.superseded,
        );
      },
    );

    test(
      'when rejecting a format suggestion then the decision is rejected',
      () {
        final op = SuggestionOps.reject(doc, {'2'});

        expect(
          SuggestionDecisions.infer(
            op: op,
            inverse: WonkyOt.invert(op, doc),
            suggestionId: '2',
            actorUuid: 'editor',
          ),
          SuggestionDecision.rejected,
        );
      },
    );
  });

  group('Given the overlay index', () {
    final doc = d([
      {
        'insert': 'abc',
        'attributes': {'cmt_t': true},
      },
      {'insert': 'def\n'},
    ]);

    test(
      'when all anchored text is deleted then the thread disappears and undo restores it',
      () {
        final index = OverlayIndex()..reset(doc);
        final del = Delta()..delete(3);
        final inv = WonkyOt.invert(del, doc);

        expect(index.apply(del, inv), [
          const OverlayTransition('cmt_t', appeared: false),
        ]);
        final after = WonkyOt.apply(doc, del);
        expect(index.apply(inv, WonkyOt.invert(inv, after)), [
          const OverlayTransition('cmt_t', appeared: true),
        ]);
      },
    );

    test('when a comment is added by a retain then it appears', () {
      final index = OverlayIndex()..reset(doc);
      final op = CommentAnchors.addAnchor('n', 3, 2);

      expect(index.apply(op, WonkyOt.invert(op, doc)), [
        const OverlayTransition('cmt_n', appeared: true),
      ]);
      expect(index.count('cmt_n'), 2);
    });

    propertyTest(
      'when applying random overlay edits then counts equal a full rescan',
      (random, _) {
        final gen = DeltaGen(
          random,
          options: const DeltaGenOptions(overlays: true),
        );
        final edits = EditGen(random, deltaGen: gen);
        var current = gen.document();
        final index = OverlayIndex()..reset(current);
        for (var i = 0; i < 5; i++) {
          final op = edits.change(current, overlays: true);
          final inv = WonkyOt.invert(op, current);
          index.apply(op, inv);
          current = WonkyOt.apply(current, op);
        }
        final rescan = OverlayIndex()..reset(current);

        expect(index.counts, equals(rescan.counts));
      },
    );
  });

  group('Given comment anchors', () {
    final doc = d([
      {'insert': 'a '},
      {
        'insert': 'quoted',
        'attributes': {'cmt_t': true},
      },
      {
        'insert': '\n',
        'attributes': {'cmt_t': true},
      },
      {
        'insert': 'more',
        'attributes': {'cmt_t': true},
      },
      {'insert': ' end\n'},
    ]);

    test(
      'when extracting the anchor then a multi-line range is one contiguous run',
      () {
        final anchor = CommentAnchors.anchorOf(doc, 't')!;

        expect(
          (anchor.start, anchor.length, anchor.quote),
          (2, 11, 'quoted more'),
        );
      },
    );

    test('when an open thread has no anchor then it is orphaned', () {
      expect(CommentAnchors.orphaned(doc, ['t', 'gone']), {'gone'});
    });

    test('when removing a thread then no anchor remains', () {
      final after = WonkyOt.apply(doc, CommentAnchors.removeAnchor(doc, 't'));

      expect(CommentAnchors.anchors(after), isEmpty);
    });
  });

  group('Given an op history', () {
    final a = d([
      {'insert': 'Hello world\n'},
    ]);
    final ops = [
      AuthoredOp(
        Delta()
          ..retain(6)
          ..delete(5)
          ..insert('there'),
        authorUuid: 'anna',
      ),
      AuthoredOp(Delta()..retain(5, {'bold': true}), authorUuid: 'bo'),
      AuthoredOp(
        Delta()
          ..retain(11)
          ..insert('!'),
        authorUuid: 'anna',
      ),
    ];

    test(
      'when diffing then insertions, tombstones and formatting are attributed',
      () {
        final diff = AttributedDiff.diff(a, ops);

        expect(diff.delta.toJson(), [
          {
            'insert': 'Hello',
            'attributes': {
              'bold': true,
              'diff_fmt': {'by': 'bo', 'before': <String, dynamic>{}},
            },
          },
          {'insert': ' '},
          {
            'insert': 'world',
            'attributes': {
              'diff_del': {'by': 'anna'},
            },
          },
          {
            'insert': 'there!',
            'attributes': {
              'diff_ins': {'by': 'anna'},
            },
          },
          {'insert': '\n'},
        ]);
        expect(diff.changeCount, 2);
        expect(diff.exact, isTrue);
      },
    );

    propertyTest(
      'when replaying random histories then visible text equals doc(B) and old text equals doc(A)',
      (random, _) {
        final gen = DeltaGen(
          random,
          options: const DeltaGenOptions(overlays: true),
        );
        final edits = EditGen(random, deltaGen: gen);
        final docA = gen.document();
        var current = docA;
        final history = <AuthoredOp>[];
        for (var i = 0; i < 1 + random.nextInt(6); i++) {
          final op = edits.change(current, overlays: true);
          history.add(AuthoredOp(op, authorUuid: 'u${random.nextInt(3)}'));
          current = WonkyOt.apply(current, op);
        }

        final diff = AttributedDiff.diff(docA, history);

        final visible = StringBuffer();
        final old = StringBuffer();
        for (final op in diff.delta.operations) {
          final t = op.data is String ? op.data as String : embedChar;
          if (!(op.attributes?.containsKey(DiffAttr.del) ?? false)) {
            visible.write(t);
          }
          if (!(op.attributes?.containsKey(DiffAttr.ins) ?? false)) {
            old.write(t);
          }
        }
        expect(visible.toString(), DeltaUtils.text(current));
        expect(old.toString(), DeltaUtils.text(docA));
      },
    );

    test('when falling back to snapshots then changes are unattributed', () {
      final b = ops.fold(a, (doc, op) => WonkyOt.apply(doc, op.delta));

      final diff = AttributedDiff.diffSnapshots(a, b);

      expect(diff.exact, isFalse);
      expect(diff.authors.single.userUuid, isNull);
      expect(
        DeltaUtils.text(diff.delta).replaceAll(embedChar, ''),
        contains('there'),
      );
    });
  });

  group('Given a suggestion session', () {
    test('when typing continuously in one block then the id is reused', () {
      var n = 0;
      final s = SuggestionSession(() => 'id${n++}');
      final a = s.forTextEdit(
        blockStart: 0,
        caretBefore: 3,
        caretAfter: 4,
        nowMs: 0,
      );
      final b = s.forTextEdit(
        blockStart: 0,
        caretBefore: 4,
        caretAfter: 5,
        nowMs: 1000,
      );
      final c = s.forTextEdit(
        blockStart: 0,
        caretBefore: 9,
        caretAfter: 10,
        nowMs: 2000,
      );

      expect([a, b, c], ['id0', 'id0', 'id1']);
    });
  });

  test('unused random guard', () => expect(Random(1).nextInt(1), 0));
}
