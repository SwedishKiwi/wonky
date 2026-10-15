import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

void main() {
  const tokenizer = DefaultCodeTokenizer.instance;

  group('Given a language with a TextMate grammar', () {
    test('when tokenizing then the TextMate tokens are used', () {
      const code = 'final x = "a"; // note';

      expect(
        tokenizer.tokenize(code, 'dart'),
        TextMateTokenizer.instance.tokenize(code, 'dart'),
      );
    });
  });

  group('Given a language with only highlight.js support', () {
    test('when tokenizing bash then the comment is a comment', () {
      const code = 'echo "hi" # done';

      final tokens = tokenizer.tokenize(code, 'bash');

      expect(
        tokens,
        contains(
          CodeToken(code.indexOf('#'), code.length, SyntaxToken.comment),
        ),
      );
    });
  });

  group('Given plain text or an unknown language', () {
    for (final language in ['', 'cobol']) {
      test('when tokenizing "$language" then there are no tokens', () {
        expect(tokenizer.tokenize('x = 1 # c', language), isEmpty);
      });
    }

    test('when asking for support of "cobol" then it is unsupported', () {
      expect(tokenizer.supports('cobol'), isFalse);
    });
  });
}
