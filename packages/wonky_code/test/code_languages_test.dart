import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

void main() {
  group('Given typed languages', () {
    const cases = <(String, String)>[
      ('Dart', 'dart'),
      (' js ', 'javascript'),
      ('tsx', 'typescript'),
      ('py3', 'python'),
      ('zsh', 'bash'),
      ('yml', 'yaml'),
      ('c++', 'cpp'),
      ('h', 'c'),
      ('C#', 'csharp'),
      ('golang', 'go'),
      ('jsonc', 'json'),
      ('spy', 'serverpod'),
      ('gql', 'graphql'),
      ('patch', 'diff'),
      ('svg', 'xml'),
      ('text', ''),
      ('cobol', 'cobol'),
    ];
    for (final (input, expected) in cases) {
      test('when normalizing "$input" then it is "$expected"', () {
        expect(CodeLanguages.normalize(input), expected);
      });
    }
  });

  group('Given language ids', () {
    test('when naming plain text then it is "Plain text"', () {
      expect(CodeLanguages.displayName(''), 'Plain text');
    });

    test('when naming a known language then it has its display name', () {
      expect(CodeLanguages.displayName('typescript'), 'TypeScript');
    });

    test('when naming an unknown language then it is the id', () {
      expect(CodeLanguages.displayName('cobol'), 'cobol');
    });

    test('when listing the picker languages then TextMate ones come first', () {
      expect(
        CodeLanguages.pickerLanguages.take(CodeLanguages.grammars.length),
        CodeLanguages.grammars.keys,
      );
    });

    test('when listing the picker languages then each is highlighted and '
        'has a display name', () {
      expect(
        CodeLanguages.pickerLanguages.where(
          (l) =>
              !CodeLanguages.isHighlighted(l) ||
              !CodeLanguages.displayNames.containsKey(l),
        ),
        isEmpty,
      );
    });

    for (final (language, highlighted) in const [
      ('dart', true),
      ('bash', true),
      ('toml', true),
      ('', false),
      ('cobol', false),
    ]) {
      test('when asking whether "$language" is highlighted then it is '
          '$highlighted', () {
        expect(CodeLanguages.isHighlighted(language), highlighted);
      });
    }
  });

  group('Given file names', () {
    const cases = <(String, String?)>[
      ('main.dart', 'dart'),
      ('lib/src/post.spy.yaml', 'serverpod'),
      ('config.yaml', 'yaml'),
      ('Dockerfile', 'dockerfile'),
      ('Makefile', 'makefile'),
      ('README.md', 'markdown'),
      ('App.TSX', 'typescript'),
      (r'C:\code\a.rs', 'rust'),
      ('icon.svg', 'xml'),
      ('notes.txt', null),
      ('LICENSE', null),
    ];
    for (final (name, expected) in cases) {
      test('when detecting "$name" then it is $expected', () {
        expect(CodeLanguages.fromFileName(name), expected);
      });
    }

    test('when mapping every extension then the language is highlighted', () {
      expect(
        CodeLanguages.extensions.values.where(
          (l) => !CodeLanguages.isHighlighted(l),
        ),
        isEmpty,
      );
    });
  });
}
