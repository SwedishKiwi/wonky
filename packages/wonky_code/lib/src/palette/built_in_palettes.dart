import 'syntax_palette.dart';

/// The built-in code palettes (Slides 07 §2.5). Every token of every palette
/// has a contrast of at least 4.5:1 against its background (7:1 for the high
/// contrast pair); `test/palette/built_in_palettes_test.dart` checks it.
abstract final class BuiltInPalettes {
  /// Palette JSON by id, in display order.
  static const Map<String, Map<String, Object?>> json = {
    'wonky-light': _wonkyLight,
    'wonky-dark': _wonkyDark,
    'github-light': _githubLight,
    'github-dark': _githubDark,
    'one-dark': _oneDark,
    'dracula': _dracula,
    'solarized-light': _solarizedLight,
    'solarized-dark': _solarizedDark,
    'monochrome-light': _monochromeLight,
    'monochrome-dark': _monochromeDark,
    'high-contrast-light': _highContrastLight,
    'high-contrast-dark': _highContrastDark,
  };

  static final Map<String, SyntaxPalette> _parsed = {};

  /// Every built-in palette, in display order.
  static List<SyntaxPalette> get all => [for (final id in json.keys) byId(id)!];

  /// The built-in palette [id], or `null`.
  static SyntaxPalette? byId(String id) {
    final source = json[id];
    if (source == null) return null;
    return _parsed.putIfAbsent(id, () => SyntaxPalette.fromJson(source));
  }

  /// The default palette for [brightness]: [wonkyLight] or [wonkyDark].
  static SyntaxPalette forBrightness(PaletteBrightness brightness) =>
      brightness == PaletteBrightness.dark ? wonkyDark : wonkyLight;

  /// `wonky-light`.
  static SyntaxPalette get wonkyLight => byId('wonky-light')!;

  /// `wonky-dark`.
  static SyntaxPalette get wonkyDark => byId('wonky-dark')!;

  /// `github-light`.
  static SyntaxPalette get githubLight => byId('github-light')!;

  /// `github-dark`.
  static SyntaxPalette get githubDark => byId('github-dark')!;

  /// `one-dark`.
  static SyntaxPalette get oneDark => byId('one-dark')!;

  /// `dracula`.
  static SyntaxPalette get dracula => byId('dracula')!;

  /// `solarized-light`.
  static SyntaxPalette get solarizedLight => byId('solarized-light')!;

  /// `solarized-dark`.
  static SyntaxPalette get solarizedDark => byId('solarized-dark')!;

  /// `monochrome-light`.
  static SyntaxPalette get monochromeLight => byId('monochrome-light')!;

  /// `monochrome-dark`.
  static SyntaxPalette get monochromeDark => byId('monochrome-dark')!;

  /// `high-contrast-light`.
  static SyntaxPalette get highContrastLight => byId('high-contrast-light')!;

  /// `high-contrast-dark`.
  static SyntaxPalette get highContrastDark => byId('high-contrast-dark')!;

  /// Wonky Light — Write's default light syntax palette (*Wonky Default*).
  static const Map<String, Object?> _wonkyLight = {
    'id': 'wonky-light',
    'name': 'Wonky Light',
    'brightness': 'light',
    'background': '#f6f8fa',
    'text': '#24292f',
    'lineNumber': '#82868a',
    'lineNumberActive': '#24292f',
    'selection': '#8250df40',
    'caret': '#24292f',
    'highlightBar': '#8250df',
    'dimOverlay': '#f6f8fab3',
    'titleTabBackground': '#e5e7ea',
    'titleTabText': '#24292f',
    'border': '#d0d3d5',
    'tokens': {
      'keyword': {'color': '#cf222e'},
      'string': {'color': '#0a3069'},
      'number': {'color': '#0550ae'},
      'comment': {'color': '#57606a', 'fontStyle': 'italic'},
      'function': {'color': '#8250df'},
      'type': {'color': '#953800'},
      'variable': {'color': '#953800'},
      'operator': {'color': '#cf222e'},
      'punctuation': {'color': '#57606a'},
      'builtin': {'color': '#0550ae'},
      'literal': {'color': '#0550ae'},
      'meta': {'color': '#8250df'},
      'tag': {'color': '#116329'},
      'attribute': {'color': '#0550ae'},
      'regexp': {'color': '#0a3069'},
      'addition': {'color': '#116329'},
      'deletion': {'color': '#82071e'},
    },
  };

  /// Wonky Dark — Write's default dark syntax palette (GitHub-dark-like).
  static const Map<String, Object?> _wonkyDark = {
    'id': 'wonky-dark',
    'name': 'Wonky Dark',
    'brightness': 'dark',
    'background': '#2d3036',
    'text': '#e6edf3',
    'lineNumber': '#93989e',
    'lineNumberActive': '#e6edf3',
    'selection': '#d2a8ff40',
    'caret': '#e6edf3',
    'highlightBar': '#d2a8ff',
    'dimOverlay': '#2d3036b3',
    'titleTabBackground': '#3c3f45',
    'titleTabText': '#e6edf3',
    'border': '#4e5258',
    'tokens': {
      'keyword': {'color': '#ff7b72'},
      'string': {'color': '#a5d6ff'},
      'number': {'color': '#79c0ff'},
      'comment': {'color': '#9198a1', 'fontStyle': 'italic'},
      'function': {'color': '#d2a8ff'},
      'type': {'color': '#ffa657'},
      'variable': {'color': '#ffa657'},
      'operator': {'color': '#ff7b72'},
      'punctuation': {'color': '#c9d1d9'},
      'builtin': {'color': '#79c0ff'},
      'literal': {'color': '#79c0ff'},
      'meta': {'color': '#d2a8ff'},
      'tag': {'color': '#7ee787'},
      'attribute': {'color': '#79c0ff'},
      'regexp': {'color': '#a5d6ff'},
      'addition': {'color': '#7ee787'},
      'deletion': {'color': '#ffa198'},
    },
  };

  /// GitHub Light — GitHub light colors.
  static const Map<String, Object?> _githubLight = {
    'id': 'github-light',
    'name': 'GitHub Light',
    'brightness': 'light',
    'background': '#ffffff',
    'text': '#1f2328',
    'lineNumber': '#848689',
    'lineNumberActive': '#1f2328',
    'selection': '#6639ba40',
    'caret': '#1f2328',
    'highlightBar': '#6639ba',
    'dimOverlay': '#ffffffb3',
    'titleTabBackground': '#ededee',
    'titleTabText': '#1f2328',
    'border': '#d7d7d8',
    'tokens': {
      'keyword': {'color': '#cf222e'},
      'string': {'color': '#0a3069'},
      'number': {'color': '#0550ae'},
      'comment': {'color': '#59636e', 'fontStyle': 'italic'},
      'function': {'color': '#6639ba'},
      'type': {'color': '#953800'},
      'variable': {'color': '#953800'},
      'operator': {'color': '#cf222e'},
      'punctuation': {'color': '#1f2328'},
      'builtin': {'color': '#0550ae'},
      'literal': {'color': '#0550ae'},
      'meta': {'color': '#6639ba'},
      'tag': {'color': '#116329'},
      'attribute': {'color': '#0550ae'},
      'regexp': {'color': '#0a3069'},
      'addition': {'color': '#116329'},
      'deletion': {'color': '#82071e'},
    },
  };

  /// GitHub Dark — GitHub dark colors (`githubDarkSyntaxJson` in Write).
  static const Map<String, Object?> _githubDark = {
    'id': 'github-dark',
    'name': 'GitHub Dark',
    'brightness': 'dark',
    'background': '#0d1117',
    'text': '#e6edf3',
    'lineNumber': '#848a90',
    'lineNumberActive': '#e6edf3',
    'selection': '#d2a8ff40',
    'caret': '#e6edf3',
    'highlightBar': '#d2a8ff',
    'dimOverlay': '#0d1117b3',
    'titleTabBackground': '#1e2329',
    'titleTabText': '#e6edf3',
    'border': '#34393f',
    'tokens': {
      'keyword': {'color': '#ff7b72'},
      'string': {'color': '#a5d6ff'},
      'number': {'color': '#79c0ff'},
      'comment': {'color': '#9198a1', 'fontStyle': 'italic'},
      'function': {'color': '#d2a8ff'},
      'type': {'color': '#ffa657'},
      'variable': {'color': '#ffa657'},
      'operator': {'color': '#ff7b72'},
      'punctuation': {'color': '#e6edf3'},
      'builtin': {'color': '#79c0ff'},
      'literal': {'color': '#79c0ff'},
      'meta': {'color': '#d2a8ff'},
      'tag': {'color': '#7ee787'},
      'attribute': {'color': '#79c0ff'},
      'regexp': {'color': '#a5d6ff'},
      'addition': {'color': '#7ee787'},
      'deletion': {'color': '#ffa198'},
    },
  };

  /// One Dark — Atom One Dark colors; comment and red lightened to 4.5:1.
  static const Map<String, Object?> _oneDark = {
    'id': 'one-dark',
    'name': 'One Dark',
    'brightness': 'dark',
    'background': '#282c34',
    'text': '#abb2bf',
    'lineNumber': '#707680',
    'lineNumberActive': '#abb2bf',
    'selection': '#61afef40',
    'caret': '#abb2bf',
    'highlightBar': '#61afef',
    'dimOverlay': '#282c34b3',
    'titleTabBackground': '#32373f',
    'titleTabText': '#abb2bf',
    'border': '#40444d',
    'tokens': {
      'keyword': {'color': '#c678dd'},
      'string': {'color': '#98c379'},
      'number': {'color': '#d19a66'},
      'comment': {'color': '#90949d', 'fontStyle': 'italic'},
      'function': {'color': '#61afef'},
      'type': {'color': '#e5c07b'},
      'variable': {'color': '#e1727b'},
      'operator': {'color': '#56b6c2'},
      'punctuation': {'color': '#abb2bf'},
      'builtin': {'color': '#56b6c2'},
      'literal': {'color': '#d19a66'},
      'meta': {'color': '#c678dd'},
      'tag': {'color': '#e1727b'},
      'attribute': {'color': '#d19a66'},
      'regexp': {'color': '#56b6c2'},
      'addition': {'color': '#98c379'},
      'deletion': {'color': '#e1727b'},
    },
  };

  /// Dracula — Dracula spec colors; comment lightened to 4.5:1.
  static const Map<String, Object?> _dracula = {
    'id': 'dracula',
    'name': 'Dracula',
    'brightness': 'dark',
    'background': '#282a36',
    'text': '#f8f8f2',
    'lineNumber': '#9a9b9d',
    'lineNumberActive': '#f8f8f2',
    'selection': '#50fa7b40',
    'caret': '#f8f8f2',
    'highlightBar': '#50fa7b',
    'dimOverlay': '#282a36b3',
    'titleTabBackground': '#393a45',
    'titleTabText': '#f8f8f2',
    'border': '#4d4f58',
    'tokens': {
      'keyword': {'color': '#ff79c6'},
      'string': {'color': '#f1fa8c'},
      'number': {'color': '#bd93f9'},
      'comment': {'color': '#8591b8', 'fontStyle': 'italic'},
      'function': {'color': '#50fa7b'},
      'type': {'color': '#8be9fd'},
      'variable': {'color': '#f8f8f2'},
      'operator': {'color': '#ff79c6'},
      'punctuation': {'color': '#f8f8f2'},
      'builtin': {'color': '#8be9fd'},
      'literal': {'color': '#bd93f9'},
      'meta': {'color': '#ff79c6'},
      'tag': {'color': '#ff79c6'},
      'attribute': {'color': '#50fa7b'},
      'regexp': {'color': '#ff5555'},
      'addition': {'color': '#50fa7b'},
      'deletion': {'color': '#ff5555'},
    },
  };

  /// Solarized Light — Solarized accents, darkened to 4.5:1 on base3.
  static const Map<String, Object?> _solarizedLight = {
    'id': 'solarized-light',
    'name': 'Solarized Light',
    'brightness': 'light',
    'background': '#fdf6e3',
    'text': '#586e75',
    'lineNumber': '#868e8a',
    'lineNumberActive': '#586e75',
    'selection': '#2075b040',
    'caret': '#586e75',
    'highlightBar': '#2075b0',
    'dimOverlay': '#fdf6e3b3',
    'titleTabBackground': '#f0ebda',
    'titleTabText': '#586e75',
    'border': '#dfdecf',
    'tokens': {
      'keyword': {'color': '#687700'},
      'string': {'color': '#207c75'},
      'number': {'color': '#c8337c'},
      'comment': {'color': '#687272', 'fontStyle': 'italic'},
      'function': {'color': '#2075b0'},
      'type': {'color': '#8d6b00'},
      'variable': {'color': '#c34815'},
      'operator': {'color': '#687700'},
      'punctuation': {'color': '#586e75'},
      'builtin': {'color': '#2075b0'},
      'literal': {'color': '#6469b6'},
      'meta': {'color': '#c34815'},
      'tag': {'color': '#2075b0'},
      'attribute': {'color': '#8d6b00'},
      'regexp': {'color': '#d3302d'},
      'addition': {'color': '#687700'},
      'deletion': {'color': '#d3302d'},
    },
  };

  /// Solarized Dark — Solarized accents, lightened to 4.5:1 on base03.
  static const Map<String, Object?> _solarizedDark = {
    'id': 'solarized-dark',
    'name': 'Solarized Dark',
    'brightness': 'dark',
    'background': '#002b36',
    'text': '#93a1a1',
    'lineNumber': '#5b757a',
    'lineNumberActive': '#93a1a1',
    'selection': '#3794d640',
    'caret': '#93a1a1',
    'highlightBar': '#3794d6',
    'dimOverlay': '#002b36b3',
    'titleTabBackground': '#0c343f',
    'titleTabText': '#93a1a1',
    'border': '#1a4049',
    'tokens': {
      'keyword': {'color': '#859900'},
      'string': {'color': '#2aa198'},
      'number': {'color': '#dd649f'},
      'comment': {'color': '#809196', 'fontStyle': 'italic'},
      'function': {'color': '#3794d6'},
      'type': {'color': '#b58900'},
      'variable': {'color': '#d67349'},
      'operator': {'color': '#859900'},
      'punctuation': {'color': '#93a1a1'},
      'builtin': {'color': '#3794d6'},
      'literal': {'color': '#8488cd'},
      'meta': {'color': '#d67349'},
      'tag': {'color': '#3794d6'},
      'attribute': {'color': '#b58900'},
      'regexp': {'color': '#e56563'},
      'addition': {'color': '#859900'},
      'deletion': {'color': '#e56563'},
    },
  };

  /// Monochrome Light — Write's `monochromeSyntaxJson` (bold keywords, italic comments).
  static const Map<String, Object?> _monochromeLight = {
    'id': 'monochrome-light',
    'name': 'Monochrome Light',
    'brightness': 'light',
    'background': '#f6f8fa',
    'text': '#24292f',
    'lineNumber': '#82868a',
    'lineNumberActive': '#24292f',
    'selection': '#24292f40',
    'caret': '#24292f',
    'highlightBar': '#24292f',
    'dimOverlay': '#f6f8fab3',
    'titleTabBackground': '#e5e7ea',
    'titleTabText': '#24292f',
    'border': '#d0d3d5',
    'tokens': {
      'keyword': {'color': '#24292f', 'fontWeight': 700},
      'string': {'color': '#24292f'},
      'number': {'color': '#24292f'},
      'comment': {'color': '#57606a', 'fontStyle': 'italic'},
      'function': {'color': '#24292f'},
      'type': {'color': '#24292f'},
      'variable': {'color': '#24292f'},
      'operator': {'color': '#24292f'},
      'punctuation': {'color': '#24292f'},
      'builtin': {'color': '#24292f'},
      'literal': {'color': '#24292f'},
      'meta': {'color': '#57606a'},
      'tag': {'color': '#24292f', 'fontWeight': 700},
      'attribute': {'color': '#24292f'},
      'regexp': {'color': '#24292f'},
      'addition': {'color': '#24292f'},
      'deletion': {'color': '#57606a'},
    },
  };

  /// Monochrome Dark — Write's `monochromeSyntaxJson`, dark.
  static const Map<String, Object?> _monochromeDark = {
    'id': 'monochrome-dark',
    'name': 'Monochrome Dark',
    'brightness': 'dark',
    'background': '#2d3036',
    'text': '#e6edf3',
    'lineNumber': '#93989e',
    'lineNumberActive': '#e6edf3',
    'selection': '#e6edf340',
    'caret': '#e6edf3',
    'highlightBar': '#e6edf3',
    'dimOverlay': '#2d3036b3',
    'titleTabBackground': '#3c3f45',
    'titleTabText': '#e6edf3',
    'border': '#4e5258',
    'tokens': {
      'keyword': {'color': '#e6edf3', 'fontWeight': 700},
      'string': {'color': '#e6edf3'},
      'number': {'color': '#e6edf3'},
      'comment': {'color': '#9198a1', 'fontStyle': 'italic'},
      'function': {'color': '#e6edf3'},
      'type': {'color': '#e6edf3'},
      'variable': {'color': '#e6edf3'},
      'operator': {'color': '#e6edf3'},
      'punctuation': {'color': '#e6edf3'},
      'builtin': {'color': '#e6edf3'},
      'literal': {'color': '#e6edf3'},
      'meta': {'color': '#9198a1'},
      'tag': {'color': '#e6edf3', 'fontWeight': 700},
      'attribute': {'color': '#e6edf3'},
      'regexp': {'color': '#e6edf3'},
      'addition': {'color': '#e6edf3'},
      'deletion': {'color': '#9198a1'},
    },
  };

  /// High Contrast Light — WCAG AAA (7:1).
  static const Map<String, Object?> _highContrastLight = {
    'id': 'high-contrast-light',
    'name': 'High Contrast Light',
    'brightness': 'light',
    'background': '#ffffff',
    'text': '#000000',
    'lineNumber': '#737373',
    'lineNumberActive': '#000000',
    'selection': '#5a1a9e40',
    'caret': '#000000',
    'highlightBar': '#5a1a9e',
    'dimOverlay': '#ffffffb3',
    'titleTabBackground': '#ebebeb',
    'titleTabText': '#000000',
    'border': '#d1d1d1',
    'tokens': {
      'keyword': {'color': '#a0001c'},
      'string': {'color': '#003f8a'},
      'number': {'color': '#0b4a00'},
      'comment': {'color': '#4a4a4a', 'fontStyle': 'italic'},
      'function': {'color': '#5a1a9e'},
      'type': {'color': '#7a3300'},
      'variable': {'color': '#7a3300'},
      'operator': {'color': '#a0001c'},
      'punctuation': {'color': '#000000'},
      'builtin': {'color': '#003f8a'},
      'literal': {'color': '#0b4a00'},
      'meta': {'color': '#5a1a9e'},
      'tag': {'color': '#0b4a00'},
      'attribute': {'color': '#003f8a'},
      'regexp': {'color': '#003f8a'},
      'addition': {'color': '#0b4a00'},
      'deletion': {'color': '#a0001c'},
    },
  };

  /// High Contrast Dark — WCAG AAA (7:1).
  static const Map<String, Object?> _highContrastDark = {
    'id': 'high-contrast-dark',
    'name': 'High Contrast Dark',
    'brightness': 'dark',
    'background': '#000000',
    'text': '#ffffff',
    'lineNumber': '#8c8c8c',
    'lineNumberActive': '#ffffff',
    'selection': '#e2b8ff40',
    'caret': '#ffffff',
    'highlightBar': '#e2b8ff',
    'dimOverlay': '#000000b3',
    'titleTabBackground': '#141414',
    'titleTabText': '#ffffff',
    'border': '#2e2e2e',
    'tokens': {
      'keyword': {'color': '#ff9a9a'},
      'string': {'color': '#9fd3ff'},
      'number': {'color': '#b6f2a0'},
      'comment': {'color': '#c0c0c0', 'fontStyle': 'italic'},
      'function': {'color': '#e2b8ff'},
      'type': {'color': '#ffc98a'},
      'variable': {'color': '#ffc98a'},
      'operator': {'color': '#ff9a9a'},
      'punctuation': {'color': '#ffffff'},
      'builtin': {'color': '#9fd3ff'},
      'literal': {'color': '#b6f2a0'},
      'meta': {'color': '#e2b8ff'},
      'tag': {'color': '#b6f2a0'},
      'attribute': {'color': '#9fd3ff'},
      'regexp': {'color': '#9fd3ff'},
      'addition': {'color': '#b6f2a0'},
      'deletion': {'color': '#ff9a9a'},
    },
  };
}
