/// Built-in theme *Classic Serif* (06 §9).
library;

import 'common.dart';

/// JSON of the built-in *Classic Serif*: traditional book typography.
final Map<String, Object?> classicSerifThemeJson = {
  'schemaVersion': 1,
  'name': 'Classic Serif',
  'description':
      'Traditional book typography: justified serif text with old-style '
      'figures, small-caps subheads and an ornamental rule.',
  'basedOn': 'builtin:classic-serif',
  'fonts': {
    'body': 'Source Serif 4',
    'heading': 'Source Serif 4',
    'mono': 'JetBrains Mono',
  },
  'palette': paletteJson(
    text: '#2b2b2b',
    heading: '#1a1a1a',
    muted: '#6b6560',
    accent: '#8b2c2c',
    linkHover: '#6b1f1f',
    page: '#fffdf8',
    canvas: '#eeeae2',
    border: '#d9d2c5',
    codeText: '#2b2b2b',
    codeBg: '#f5f1e8',
    quoteText: '#4a4540',
    quoteBar: '#c9bfae',
    tableHeaderBg: '#f3eee4',
    tableStripe: '#faf7f0',
    mentionBg: '#f3e3e3',
    mentionText: '#7a2424',
    highlight: '#fbefc0',
  ),
  'dark': {
    'mode': 'explicit',
    'palette': paletteJson(
      text: '#e8e2d6',
      heading: '#f3ede2',
      muted: '#a8a092',
      accent: '#e8a0a0',
      linkHover: '#f2c0c0',
      page: '#282521',
      canvas: '#100e0a',
      border: '#3d3830',
      codeText: '#e8e2d6',
      codeBg: '#332f2a',
      quoteText: '#c9c0b0',
      quoteBar: '#574f43',
      tableHeaderBg: '#35312c',
      tableStripe: '#2d2a25',
      mentionBg: '#3b2626',
      mentionText: '#f0c4c4',
      highlight: '#4a3d17',
    ),
    'elements': <String, Object?>{},
    'syntax': githubDarkSyntaxJson,
  },
  'page': <String, Object?>{},
  'elements': {
    'body': {
      'fontSize': '12pt',
      'lineHeight': 1.45,
      'align': 'justify',
      'fontFeatures': ['onum'],
      'spaceAfter': '6pt',
    },
    'headings': {'fontWeight': 600, 'lineHeight': 1.2},
    'h1': {
      'fontSize': '26pt',
      'align': 'center',
      'spaceBefore': '28pt',
      'spaceAfter': '14pt',
    },
    'h2': {'fontSize': '19pt', 'spaceBefore': '22pt', 'spaceAfter': '8pt'},
    'h3': {
      'fontSize': '15pt',
      'caseTransform': 'smallCaps',
      'letterSpacing': '0.04em',
      'spaceBefore': '18pt',
      'spaceAfter': '6pt',
    },
    'h4': {'fontSize': '13pt', 'fontStyle': 'italic'},
    'italic': {'fontStyle': 'italic'},
    'blockquote': {
      'italic': true,
      'bar': {'width': '0pt', 'style': 'none'},
      'padding': {'left': '24pt', 'right': '24pt'},
    },
    'rule': {'style': 'ornament', 'ornament': '⁂', 'color': '@muted'},
    'image': {'borderRadius': '0pt'},
    'table': {'borders': 'horizontal', 'headerFontWeight': 600},
  },
  'syntax': <String, Object?>{},
  'overlays': <String, Object?>{},
};
