/// Built-in theme *Academic (APA-like)* (06 §9).
library;

import 'common.dart';

/// JSON of the built-in *Academic (APA-like)*: double-spaced Times-metric
/// text with uniform 12pt bold headings.
final Map<String, Object?> academicApaThemeJson = {
  'schemaVersion': 1,
  'name': 'Academic (APA-like)',
  'description':
      'Double-spaced 12pt serif text with first-line indents, uniform bold '
      'headings and horizontal-rule tables, in the spirit of APA style.',
  'basedOn': 'builtin:academic-apa',
  'fonts': {
    'body': 'Liberation Serif',
    'heading': 'Liberation Serif',
    'mono': 'JetBrains Mono',
  },
  'palette': paletteJson(
    text: '#000000',
    heading: '#000000',
    muted: '#4d4d4d',
    accent: '#1f4e9c',
    linkHover: '#163a75',
    page: '#ffffff',
    canvas: '#eeeeee',
    border: '#9e9e9e',
    codeText: '#000000',
    codeBg: '#f4f4f4',
    quoteText: '#1a1a1a',
    quoteBar: '#9e9e9e',
    tableHeaderBg: 'transparent',
    tableStripe: '#f7f7f7',
    mentionBg: '#e8eef8',
    mentionText: '#1f4e9c',
    highlight: '#fff59d',
  ),
  'dark': {
    'mode': 'explicit',
    'palette': paletteJson(
      text: '#e8e8e8',
      heading: '#f2f2f2',
      muted: '#ababab',
      accent: '#9bbcf0',
      linkHover: '#c0d4f5',
      page: '#252525',
      canvas: '#0d0d0d',
      border: '#5a5a5a',
      codeText: '#e8e8e8',
      codeBg: '#313131',
      quoteText: '#d6d6d6',
      quoteBar: '#5a5a5a',
      tableHeaderBg: 'transparent',
      tableStripe: '#2c2c2c',
      mentionBg: '#26334a',
      mentionText: '#c9dafa',
      highlight: '#4d4515',
    ),
    'elements': <String, Object?>{},
    'syntax': githubDarkSyntaxJson,
  },
  'page': {'defaultMargins': '1in'},
  'elements': {
    'body': {
      'fontSize': '12pt',
      'lineHeight': 2.0,
      'firstLineIndent': '0.5in',
      'spaceAfter': '0pt',
    },
    'headings': {
      'fontSize': '12pt',
      'fontWeight': 700,
      'lineHeight': 2.0,
      'spaceBefore': '0pt',
      'spaceAfter': '0pt',
    },
    'h1': {'align': 'center'},
    'h3': {'fontStyle': 'italic'},
    'h4': {'fontStyle': 'normal'},
    'h5': {'fontStyle': 'italic'},
    'blockquote': {
      'bar': {'width': '0pt', 'style': 'none'},
      'padding': {'left': '0.5in'},
      'spaceAfter': '0pt',
    },
    'codeBlock': {'borderRadius': '0pt', 'spaceAfter': '12pt'},
    'list': {'spaceAfter': '0pt', 'itemSpacing': '0pt'},
    'task': {'spaceAfter': '0pt'},
    'image': {
      'borderRadius': '0pt',
      'caption': {'fontStyle': 'italic', 'align': 'left', 'fontSize': '1em'},
    },
    'table': {
      'borders': 'horizontal',
      'zebra': false,
      'headerFontWeight': 700,
      'borderColor': '@text',
    },
    'link': {'underline': 'always'},
  },
  'syntax': <String, Object?>{},
  'overlays': <String, Object?>{},
};
