import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

void main() {
  group('Given TextMate scopes', () {
    test('when punctuation is inside a string then it is a string', () {
      expect(
        ScopeClassifier.tokenFor([
          'source.js',
          'string.quoted.double.js',
          'punctuation.definition.string.begin.js',
        ]),
        SyntaxToken.string,
      );
    });

    test(
      'when plain code is embedded in a template string then it is plain',
      () {
        expect(
          ScopeClassifier.tokenFor([
            'source.ts',
            'string.template.ts',
            'meta.template.expression.ts',
          ]),
          isNull,
        );
      },
    );

    test('when only a separator is scoped then it is punctuation', () {
      expect(
        ScopeClassifier.tokenFor(['source.go', 'punctuation.separator.go']),
        SyntaxToken.punctuation,
      );
    });

    test('when a scope has no rule then the enclosing scope decides', () {
      expect(
        ScopeClassifier.tokenFor(['source.dart', 'comment.line', 'meta.x']),
        SyntaxToken.comment,
      );
    });

    test('when nothing has a rule then it is plain', () {
      expect(ScopeClassifier.tokenFor(['source.dart', 'meta.x']), isNull);
    });

    const cases = <(String, SyntaxToken)>[
      ('entity.name.function.dart', SyntaxToken.function),
      ('entity.other.inherited-class', SyntaxToken.function),
      ('support.function.builtin', SyntaxToken.builtin),
      ('support.class.dart', SyntaxToken.type),
      ('storage.modifier.lifetime.rust', SyntaxToken.literal),
      ('storage.type.annotation.python', SyntaxToken.meta),
      ('keyword.operator.assignment', SyntaxToken.operator),
      ('constant.numeric.integer', SyntaxToken.number),
      ('constant.language.boolean', SyntaxToken.literal),
      ('variable.language.this', SyntaxToken.keyword),
      ('markup.heading.markdown', SyntaxToken.function),
      ('markup.inserted.diff', SyntaxToken.addition),
      ('markup.deleted.diff', SyntaxToken.deletion),
    ];
    for (final (scope, token) in cases) {
      test('when classifying "$scope" then it is ${token.name}', () {
        expect(ScopeClassifier.tokenFor(['source.x', scope]), token);
      });
    }
  });
}
