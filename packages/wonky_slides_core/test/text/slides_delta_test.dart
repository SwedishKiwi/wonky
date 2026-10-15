import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart' show Delta;
import 'package:wonky_slides_core/text.dart';

List<String> _codes(List<SlidesDeltaIssue> issues) => [
  for (final i in issues) i.code,
];

void main() {
  final validator = SlidesDeltaValidator();
  final normalizer = SlidesDeltaNormalizer();

  group('Given the body validator', () {
    test('when the body is canonical and valid then there is no issue', () {
      final d = Delta()
        ..insert('Hello ', {'bold': true, 'size': 40})
        ..insert('slide', {'link': 'https://wonky.dev/'})
        ..insert('\n', {'style': 'title', 'align': 'center'})
        ..insert('Item more')
        ..insert('\n', {'list': 'bullet', 'indent': 2});
      expect(validator.validate(d), isEmpty);
      expect(validator.validateJson(null), isEmpty);
      expect(validator.validateJson(jsonEncode(d.toJson())), isEmpty);
    });

    test('when the JSON is not a Delta then not_a_delta', () {
      expect(_codes(validator.validateJson('{')), [SlidesDeltaIssue.notADelta]);
      expect(_codes(validator.validateJson('{"a":1}')), [
        SlidesDeltaIssue.notADelta,
      ]);
    });

    test('when it breaks the schema then every problem is reported', () {
      final issues = validator.validateValue([
        {
          'insert': {'image': 'x'},
        },
        {
          'insert': 'a\u0001b',
          'attributes': {'bold': 'yes', 'style': 'title', 'blink': true},
        },
        {
          'insert': 'end',
          'attributes': {'link': 'javascript:alert(1)'},
        },
      ]);
      expect(_codes(issues), [
        SlidesDeltaIssue.embed,
        SlidesDeltaIssue.controlCharacter,
        SlidesDeltaIssue.invalidAttribute, // bold: 'yes'
        SlidesDeltaIssue.unknownAttribute, // style on text
        SlidesDeltaIssue.unknownAttribute, // blink
        SlidesDeltaIssue.invalidAttribute, // link scheme
        SlidesDeltaIssue.missingFinalNewline,
      ]);
      expect(issues[3].attribute, 'style');
      expect(issues[3].toJson(), containsPair('op', 1));
    });

    test('when text and an attributed line break share an insert, or equal '
        'inserts are not merged, then not_canonical', () {
      expect(
        _codes(validator.validate(Delta()..insert('a\n', {'bold': true}))),
        [SlidesDeltaIssue.notCanonical],
      );
      final split = Delta.fromJson([
        {'insert': 'a'},
        {'insert': 'b\n'},
      ]);
      expect(_codes(validator.validate(split)), [
        SlidesDeltaIssue.notCanonical,
      ]);
    });

    test('when notes use body-only attributes then they are unknown', () {
      final notes = SlidesDeltaValidator(notes: true);
      expect(
        _codes(
          notes.validate(
            Delta()
              ..insert('x', {'size': 20})
              ..insert('\n'),
          ),
        ),
        [SlidesDeltaIssue.unknownAttribute],
      );
    });

    test('when a body exceeds the limit then too_long', () {
      final v = SlidesDeltaValidator(maxLength: 5);
      expect(_codes(v.validate(Delta()..insert('12345\n'))), isEmpty);
      expect(_codes(v.validate(Delta()..insert('123456\n'))), [
        SlidesDeltaIssue.tooLong,
      ]);
    });
  });

  group('Given the body normalizer', () {
    test('when normalizing then the result is valid and stable', () {
      final dirty = Delta.fromJson([
        {
          'insert': {'image': 'x'},
        },
        {
          'insert': 'a\tb\u0007',
          'attributes': {'bold': true, 'style': 'title'},
        },
        {
          'insert': 'c',
          'attributes': {'bold': true},
        },
      ]);
      final r = normalizer.normalize(dirty);
      expect(r.changed, isTrue);
      expect(r.truncated, isFalse);
      expect(r.delta.toJson(), [
        {
          'insert': 'a    bc',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
      ]);
      expect(validator.validate(r.delta), isEmpty);
      final again = normalizer.normalize(r.delta);
      expect(again.changed, isFalse);
      expect(again.delta, r.delta);
    });

    test('when a body is too long then it is cut keeping the paragraph '
        'attributes of the cut line', () {
      final n = SlidesDeltaNormalizer(maxLength: 4);
      final r = n.normalize(
        Delta()
          ..insert('ab')
          ..insert('\n', {'list': 'bullet'})
          ..insert('cdef')
          ..insert('\n', {'align': 'right'}),
      );
      expect(r.truncated, isTrue);
      expect(r.delta.toJson(), [
        {'insert': 'ab'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'c'},
        {
          'insert': '\n',
          'attributes': {'align': 'right'},
        },
      ]);
      expect(SlidesDeltaValidator(maxLength: 4).validate(r.delta), isEmpty);
    });

    test('when normalizing JSON values then strings become paragraphs and '
        'anything else the empty body', () {
      expect(normalizer.normalizeJson(null), isNull);
      expect(
        normalizer.normalizeJson('[{"insert":"x"}]'),
        '[{"insert":"x\\n"}]',
      );
      expect(normalizer.normalizeValue('a\nb').delta.toJson(), [
        {'insert': 'a\nb\n'},
      ]);
      expect(normalizer.normalizeValue(42).delta.toJson(), [
        {'insert': '\n'},
      ]);
      expect(() => normalizer.normalizeJson('{'), throwsFormatException);
    });

    test('when building from plain text then list markers are detected only '
        'when asked', () {
      final d = normalizer
          .normalize(normalizer.fromPlainText('- a\n2) b\nc'))
          .delta;
      expect(d.toJson(), [
        {'insert': 'a'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'b'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'c\n'},
      ]);
      expect(normalizer.fromPlainText('- a', lists: false).toJson(), [
        {'insert': '- a\n'},
      ]);
    });
  });
}
