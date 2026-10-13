/// Built-in theme *Minimal Mono* (06 §9).
library;

import 'common.dart';

/// JSON of the built-in *Minimal Mono*: monochrome monospace, no
/// backgrounds.
final Map<String, Object?> minimalMonoThemeJson = {
  'schemaVersion': 1,
  'name': 'Minimal Mono',
  'description':
      'Monospace everything in a monochrome palette: headings differ from '
      'body text by weight only, and nothing has a background.',
  'basedOn': 'builtin:minimal-mono',
  'fonts': {
    'body': 'IBM Plex Mono',
    'heading': 'IBM Plex Mono',
    'mono': 'IBM Plex Mono',
  },
  'palette': paletteJson(
    text: '#111111',
    heading: '#000000',
    muted: '#666666',
    accent: '#111111',
    linkHover: '#000000',
    page: '#ffffff',
    canvas: '#f0f0f0',
    border: '#cccccc',
    codeText: '#111111',
    codeBg: 'transparent',
    quoteText: '#444444',
    quoteBar: '#cccccc',
    tableHeaderBg: 'transparent',
    tableStripe: 'transparent',
    mentionBg: 'transparent',
    mentionText: '#111111',
    highlight: '#eeeeee',
  ),
  'dark': {
    'mode': 'explicit',
    'palette': paletteJson(
      text: '#dddddd',
      heading: '#ffffff',
      muted: '#999999',
      accent: '#eeeeee',
      linkHover: '#ffffff',
      page: '#1d1d1d',
      canvas: '#070707',
      border: '#444444',
      codeText: '#dddddd',
      codeBg: 'transparent',
      quoteText: '#bbbbbb',
      quoteBar: '#444444',
      tableHeaderBg: 'transparent',
      tableStripe: 'transparent',
      mentionBg: 'transparent',
      mentionText: '#eeeeee',
      highlight: '#333333',
    ),
    'elements': <String, Object?>{},
    'syntax': null,
  },
  'page': <String, Object?>{'pageShadow': 'none'},
  'elements': {
    'body': {'fontSize': '10.5pt', 'lineHeight': 1.6, 'spaceAfter': '10pt'},
    'headings': {
      'fontSize': '10.5pt',
      'fontWeight': 700,
      'lineHeight': 1.6,
      'spaceBefore': '16pt',
      'spaceAfter': '6pt',
    },
    'h1': {'spaceBefore': '20pt'},
    'link': {'underline': 'always', 'underlineStyle': 'dotted'},
    'mention': {'fontWeight': 700},
    'inlineCode': {'sizeRatio': 1, 'paddingX': '0pt', 'fontWeight': 700},
    'codeBlock': {
      'fontSize': '1em',
      'border': {'width': '1px', 'style': 'solid', 'color': '@border'},
      'borderRadius': '0pt',
      'padding': '8px',
      'showLanguageLabel': false,
    },
    'blockquote': {
      'bar': {'width': '1px', 'style': 'solid', 'color': '@quoteBar'},
      'padding': {'left': '12px'},
    },
    'list': {
      'bullets': ['-', '-', '-', '-', '-', '-', '-', '-', '-'],
      'itemSpacing': '0pt',
    },
    'task': {
      'checkbox': {
        'shape': 'square',
        'checkedFill': '@text',
        'checkColor': '@page',
      },
    },
    'rule': {'style': 'dashed'},
    'image': {'borderRadius': '0pt'},
    'table': {'borders': 'horizontal', 'headerFontWeight': 700},
  },
  'syntax': monochromeSyntaxJson,
  'overlays': <String, Object?>{},
};
