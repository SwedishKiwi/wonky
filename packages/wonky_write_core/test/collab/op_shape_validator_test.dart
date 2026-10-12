import 'package:test/test.dart';
import 'package:wonky_write_core/testing.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../support/property.dart';

void main() {
  final doc = Delta()
    ..insert('hello ')
    ..insert('mine', {
      'sug_a': {'t': 'ins', 'by': 'me', 'at': 1},
    })
    ..insert('\n');

  group('Given a commenter', () {
    final cases = <(String, Delta, bool)>[
      ('a comment anchor', Delta()..retain(5, {'cmt_t': true}), true),
      ('a plain insert', Delta()..insert('x'), false),
      (
        'an own insertion suggestion',
        Delta()..insert('x', {
          'sug_b': {'t': 'ins', 'by': 'me', 'at': 2},
        }),
        true,
      ),
      (
        'a foreign insertion suggestion',
        Delta()..insert('x', {
          'sug_b': {'t': 'ins', 'by': 'you', 'at': 2},
        }),
        false,
      ),
      ('a real delete of plain text', Delta()..delete(2), false),
      (
        'a real delete of an own insertion',
        Delta()
          ..retain(6)
          ..delete(4),
        true,
      ),
      (
        'a deletion mark',
        Delta()..retain(2, {
          'sug_c': {'t': 'del', 'by': 'me', 'at': 2},
        }),
        true,
      ),
      ('direct bold', Delta()..retain(2, {'bold': true}), false),
      (
        'a fmt suggestion with the right before',
        Delta()..retain(2, {
          'bold': true,
          'sug_d': {
            't': 'fmt',
            'by': 'me',
            'at': 2,
            'before': <String, dynamic>{},
          },
        }),
        true,
      ),
      (
        'a fmt suggestion with a wrong before',
        Delta()..retain(2, {
          'bold': true,
          'sug_d': {
            't': 'fmt',
            'by': 'me',
            'at': 2,
            'before': {'italic': true},
          },
        }),
        false,
      ),
      (
        'a heading change suggestion',
        Delta()
          ..retain(10)
          ..retain(1, {
            'header': 1,
            'sug_e': {
              't': 'fmt',
              'by': 'me',
              'at': 2,
              'before': <String, dynamic>{},
            },
          }),
        true,
      ),
    ];
    for (final (name, op, allowed) in cases) {
      test(
        'when submitting $name then it is ${allowed ? 'allowed' : 'rejected'}',
        () {
          final v = OpShapeValidator.validateCommenterOp(doc, op, 'me');
          expect(v == null, allowed, reason: '$v');
        },
      );
    }
  });

  propertyTest(
    'Given random edits when rewritten as suggestions then commenters may submit them',
    (random, run) {
      final gen = DeltaGen(
        random,
        options: const DeltaGenOptions(embeds: false, mentions: false),
      );
      final edits = EditGen(random, deltaGen: gen);
      var d = gen.document();
      final other = edits.change(d);
      d = const WonkyDeltaNormalizer()
          .normalize(
            WonkyOt.apply(
              d,
              const SuggestionRewriter().rewrite(
                d,
                other,
                const SuggestionContext(
                  userUuid: 'x',
                  nowMs: 1,
                  suggestionId: 'o',
                ),
              ),
            ),
          )
          .document;
      final change = edits.change(d);

      final s = const SuggestionRewriter().rewrite(
        d,
        change,
        SuggestionContext(userUuid: 'me', nowMs: 5, suggestionId: 's$run'),
      );

      expect(OpShapeValidator.validateCommenterOp(d, s, 'me'), isNull);
    },
  );
}
