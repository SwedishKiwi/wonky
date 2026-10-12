import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart';

void main() {
  group('Given an object schema with a required string and an int range', () {
    const schema = JsonSchema.object(
      properties: {
        'name': JsonSchema.string(minLength: 1),
        'count': JsonSchema.integer(minimum: 1, maximum: 10),
        'mode': JsonSchema.string(enumValues: ['a', 'b']),
      },
      required: ['name'],
    );

    test('when validating a valid value then there are no violations', () {
      expect(schema.validate({'name': 'x', 'count': 3, 'mode': 'a'}), isEmpty);
    });

    test('when a required property is missing then it is reported', () {
      expect(
        schema.validate({'count': 3}),
        [const JsonSchemaViolation(r'$', 'missing required property "name"')],
      );
    });

    test('when values are out of range or not in the enum then each path is '
        'reported', () {
      final v = schema.validate({'name': '', 'count': 11, 'mode': 'c'});
      expect(v.map((e) => e.path), [r'$.name', r'$.count', r'$.mode']);
    });

    test('when an unknown property is passed then it is rejected', () {
      expect(schema.validate({'name': 'x', 'extra': 1}), hasLength(1));
    });

    test('when serialized then it is a JSON schema object', () {
      final json = schema.toJson();
      expect(json['type'], 'object');
      expect(json['required'], ['name']);
      expect((json['properties'] as Map)['count'], {
        'type': 'integer',
        'minimum': 1,
        'maximum': 10,
      });
    });
  });

  group('Given composite schemas', () {
    test('when an array item is invalid then the index is in the path', () {
      const s = JsonSchema.array(JsonSchema.boolean());
      expect(s.validate([true, 'x']).single.path, r'$[1]');
    });

    test('when a nullable schema gets null then it is valid', () {
      const s = JsonSchema.nullable(JsonSchema.string());
      expect(s.validate(null), isEmpty);
      expect(s.toJson()['type'], ['string', 'null']);
    });

    test('when a uuid format string is malformed then it is rejected', () {
      const s = JsonSchema.string(format: 'uuid');
      expect(s.accepts('0199d3a0-0000-7000-8000-000000000000'), isTrue);
      expect(s.accepts('nope'), isFalse);
    });

    test('when anyOf gets a value matching one option then it is valid', () {
      const s = JsonSchema.anyOf([JsonSchema.integer(), JsonSchema.string()]);
      expect(s.accepts('a'), isTrue);
      expect(s.accepts(true), isFalse);
    });
  });

  group('Given JsonArgs', () {
    const args = JsonArgs({'n': 3, 's': 'x', 'b': true, 'l': ['a', 1]});
    test('when reading typed values then they are converted', () {
      expect(args.integer('n'), 3);
      expect(args.string('s'), 'x');
      expect(args.boolean('b'), isTrue);
      expect(args.strings('l'), ['a']);
      expect(args.string('missing', 'd'), 'd');
    });
    test('when a required string is missing then InvalidCommandArgs is '
        'thrown', () {
      expect(() => args.requireString('zz'), throwsA(isA<InvalidCommandArgs>()));
    });
  });

  test('Given command ids when checking validity then dotted camelCase '
      'segments are valid', () {
    expect(const CommandId('shell.drive.newFolder').isValid, isTrue);
    expect(const CommandId('shell.drive.newFolder').namespace, 'shell');
    expect(const CommandId('bad id').isValid, isFalse);
  });
}
