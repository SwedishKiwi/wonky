/// Built-in theme *Modern Sans* (06 §9).
library;

import 'common.dart';

/// JSON of the built-in *Modern Sans*: bold geometric headings, airy text.
final Map<String, Object?> modernSansThemeJson = {
  'schemaVersion': 1,
  'name': 'Modern Sans',
  'description':
      'Bold geometric headings with tight tracking, airy body text and '
      'full-width striped tables.',
  'basedOn': 'builtin:modern-sans',
  'fonts': {
    'body': 'Work Sans',
    'heading': 'Montserrat',
    'mono': 'IBM Plex Mono',
  },
  'palette': paletteJson(
    text: '#1c1e21',
    heading: '#0b0d10',
    muted: '#5f6672',
    accent: '#0f766e',
    linkHover: '#115e59',
    page: '#ffffff',
    canvas: '#eef1f4',
    border: '#d5dbe1',
    codeText: '#1c1e21',
    codeBg: '#f3f5f7',
    quoteText: '#3f4650',
    quoteBar: '@accent',
    tableHeaderBg: '#eef2f5',
    tableStripe: '#f7f9fa',
    mentionBg: '#ccfbf1',
    mentionText: '#115e59',
    highlight: '#fef08a',
  ),
  'dark': {
    'mode': 'explicit',
    'palette': paletteJson(
      text: '#e4e7eb',
      heading: '#f8fafc',
      muted: '#9ba3ae',
      accent: '#5eead4',
      linkHover: '#99f6e4',
      page: '#16181b',
      canvas: '#0e0f11',
      border: '#343a40',
      codeText: '#e4e7eb',
      codeBg: '#212428',
      quoteText: '#c0c6ce',
      quoteBar: '@accent',
      tableHeaderBg: '#23272b',
      tableStripe: '#1c1f22',
      mentionBg: '#134e4a',
      mentionText: '#ccfbf1',
      highlight: '#4d4511',
    ),
    'elements': <String, Object?>{},
    'syntax': githubDarkSyntaxJson,
  },
  'page': <String, Object?>{},
  'elements': {
    'body': {'fontSize': '11pt', 'lineHeight': 1.6, 'spaceAfter': '10pt'},
    'headings': {
      'fontWeight': 700,
      'letterSpacing': '-0.01em',
      'lineHeight': 1.2,
    },
    'h1': {
      'fontSize': '28pt',
      'borderBottom': {'width': '2px', 'style': 'solid', 'color': '@accent'},
      'borderBottomGap': '6pt',
      'spaceAfter': '12pt',
    },
    'h2': {'fontSize': '20pt'},
    'h3': {'fontSize': '16pt'},
    'bold': {'fontWeight': 700},
    'link': {'underline': 'hover'},
    'blockquote': {
      'bar': {'width': '3px', 'style': 'solid', 'color': '@quoteBar'},
      'padding': {'left': '14px'},
    },
    'codeBlock': {'borderRadius': '8px'},
    'table': {
      'width': 'full',
      'zebra': true,
      'borders': 'horizontal',
      'headerFontWeight': 600,
    },
  },
  'syntax': <String, Object?>{},
  'overlays': <String, Object?>{},
};
