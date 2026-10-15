import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';
import 'package:wonky_slides_core/code.dart';

void main() {
  group('Given no dataJson', () {
    test('when parsing then the 07 §3.1 defaults apply', () {
      final d = CodeElementData.fromJson(null);

      expect(d.language, '');
      expect(d.lineNumbers, isTrue);
      expect((d.fontSizeMin, d.fontSizeMax), (14, 40));
      expect(d.lineHeight, 1.5);
      expect(d.tabSize, 2);
      expect(d.padding, 32);
      expect(d.palette, 'auto');
      expect(d.fitAcrossStates, isTrue);
      expect(d.highlightStyle.style, CodeHighlightStyleKind.dim);
      expect(d.highlightStyle.dimOpacity, 0.3);
      expect(d.copyButton, 'present');
      expect(d.typing, TypingSettings.defaults);
      expect(d.callouts.maxWidth, 520);
    });
  });

  group('Given a full dataJson', () {
    final json = {
      'v': 1,
      'language': 'TS',
      'lineNumbers': false,
      'startLine': 40,
      'wrap': true,
      'fontSize': 22,
      'title': 'lib/main.dart',
      'chrome': 'tab',
      'showLanguage': true,
      'palette': 'dracula',
      'fontFamily': 'Roboto Mono',
      'fontSizeMin': 30,
      'fontSizeMax': 20,
      'lineHeight': 1.4,
      'ligatures': true,
      'fitAcrossStates': false,
      'tabSize': 4,
      'padding': 24,
      'box': {
        'background': '#101010',
        'border': {'color': 'theme:accent1', 'width': 2},
        'cornerRadius': 8,
        'shadow': 'strong',
      },
      'highlightStyle': {
        'style': 'bar',
        'focus': 'zoom',
        'gutterMarker': false,
      },
      'copyButton': 'always',
      'typing': {'cps': 40, 'crossSlideMode': 'type'},
      'callouts': {'style': 'pill', 'maxWidth': 300},
    };

    test('when parsing then every key is read and the language is '
        'normalized', () {
      final d = CodeElementData.fromJson(json);

      expect(d.language, 'typescript');
      expect(d.startLine, 40);
      expect(d.fontSize, 22);
      expect(d.chrome, 'tab');
      expect(d.palette, 'dracula');
      expect(d.box.borderColor, 'theme:accent1');
      expect(d.box.borderWidth, 2);
      expect(d.box.shadow, 'strong');
      expect(d.highlightStyle.style, CodeHighlightStyleKind.bar);
      expect(d.highlightStyle.focus, CodeFocusMode.zoom);
      expect(d.typing.cps, 40);
      expect(d.typing.crossSlideMode, CodeTransitionMode.type);
      expect(d.callouts.style, 'pill');
    });

    test('when the size bounds are reversed then they are swapped', () {
      final d = CodeElementData.fromJson(json);

      expect((d.fontSizeMin, d.fontSizeMax), (20, 30));
    });

    test('when round-tripping then the data is unchanged', () {
      final d = CodeElementData.fromJson(json);

      final again = CodeElementData.fromJson(d.toJson());

      expect(again.toJson(), d.toJson());
    });
  });

  group('Given invalid values', () {
    test('when parsing then they fall back to the defaults', () {
      final d = CodeElementData.fromJson({
        'tabSize': 3,
        'chrome': 'banner',
        'copyButton': 'sometimes',
        'lineHeight': 'big',
        'box': {'shadow': 'huge'},
      });

      expect(d.tabSize, 2);
      expect(d.chrome, isNull);
      expect(d.copyButton, 'present');
      expect(d.lineHeight, 1.5);
      expect(d.box.shadow, isNull);
    });

    test('when the chrome is missing then the theme default is used', () {
      final d = CodeElementData.fromJson({});

      expect(d.chromeOr('tab'), CodeChrome.tab);
      expect(d.chromeOr('nonsense'), CodeChrome.window);
    });
  });

  group('Given annotationsJson', () {
    test('when parsing then 1-based step keys become 0-based', () {
      final a = CodeAnnotations.fromJson({
        'v': 1,
        'steps': {
          '2': {
            'text': '**Null-safe** by default',
            'anchor': {'line': 5, 'side': 'right'},
            'style': 'bubble',
            'dx': 4,
          },
          'x': {'text': 'ignored'},
          '3': {'text': '  '},
        },
      });

      expect(a.steps.keys, [1]);
      expect(a[1]!.anchorLine, 5);
      expect(a[1]!.side, 'right');
      expect(a[1]!.dx, 4);
    });

    test('when a text is too long then it is cut at 280 characters', () {
      final a = CodeAnnotations.fromJson({
        'steps': {
          '1': {'text': 'x' * 400},
        },
      });

      expect(a[0]!.text.length, 280);
    });

    test('when round-tripping then the callouts are kept', () {
      final a = CodeAnnotations.fromJson({
        'steps': {
          '1': {
            'text': 'Hi',
            'anchor': {'side': 'below'},
          },
        },
      });

      expect(CodeAnnotations.fromJson(a.toJson()).toJson(), a.toJson());
    });
  });
}
