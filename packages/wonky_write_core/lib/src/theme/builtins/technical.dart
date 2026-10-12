/// Built-in theme *Technical* (06 §9).
library;

import 'common.dart';

/// JSON of the built-in *Technical*: dense documentation layout with
/// outline-numbered headings.
final Map<String, Object?> technicalThemeJson = {
  'schemaVersion': 1,
  'name': 'Technical',
  'description':
      'Dense documentation layout with outline-numbered headings, bordered '
      'code blocks and compact lists.',
  'basedOn': 'builtin:technical',
  'fonts': {
    'body': 'IBM Plex Sans',
    'heading': 'IBM Plex Sans',
    'mono': 'IBM Plex Mono',
  },
  'palette': paletteJson(
    text: '#161616',
    heading: '#0b1424',
    muted: '#5a6270',
    accent: '#0f62fe',
    linkHover: '#0043ce',
    page: '#ffffff',
    canvas: '#f2f4f8',
    border: '#c6c6c6',
    codeText: '#161616',
    codeBg: '#f4f4f4',
    quoteText: '#393939',
    quoteBar: '@accent',
    quoteBg: '#f4f7fb',
    tableHeaderBg: '#e0e0e0',
    tableStripe: '#f6f6f6',
    mentionBg: '#d0e2ff',
    mentionText: '#002d9c',
    highlight: '#fcf4d6',
  ),
  'dark': {
    'mode': 'explicit',
    'palette': paletteJson(
      text: '#f4f4f4',
      heading: '#ffffff',
      muted: '#a8b0bc',
      accent: '#78a9ff',
      linkHover: '#a6c8ff',
      page: '#161616',
      canvas: '#0b0b0b',
      border: '#525252',
      codeText: '#f4f4f4',
      codeBg: '#262626',
      quoteText: '#c6c6c6',
      quoteBar: '@accent',
      quoteBg: '#1c2230',
      tableHeaderBg: '#393939',
      tableStripe: '#1e1e1e',
      mentionBg: '#001d6c',
      mentionText: '#d0e2ff',
      highlight: '#4a3f12',
    ),
    'elements': <String, Object?>{},
    'syntax': githubDarkSyntaxJson,
  },
  'page': <String, Object?>{},
  'elements': {
    'body': {'fontSize': '10.5pt', 'lineHeight': 1.5, 'spaceAfter': '6pt'},
    'headings': {
      'fontWeight': 600,
      'numbering': {
        'enabled': true,
        'fromLevel': 1,
        'toLevel': 3,
        'style': 'outline',
        'suffix': ' ',
      },
    },
    'h1': {'fontSize': '20pt', 'spaceBefore': '20pt', 'spaceAfter': '6pt'},
    'h2': {'fontSize': '15pt', 'spaceBefore': '16pt', 'spaceAfter': '4pt'},
    'h3': {'fontSize': '12.5pt', 'spaceBefore': '12pt', 'spaceAfter': '4pt'},
    'h4': {'fontSize': '11pt'},
    'h5': {'fontSize': '10.5pt'},
    'h6': {'fontSize': '10.5pt', 'color': '@muted'},
    'codeBlock': {
      'border': {'width': '1px', 'style': 'solid', 'color': '@border'},
      'borderRadius': '4px',
      'padding': '10px',
      'lineNumbers': true,
    },
    'inlineCode': {'borderRadius': '2px'},
    'blockquote': {
      'bar': {'width': '3px', 'style': 'solid', 'color': '@quoteBar'},
      'padding': {
        'top': '6pt',
        'right': '8pt',
        'bottom': '6pt',
        'left': '10pt',
      },
    },
    'list': {
      'itemSpacing': '0pt',
      'indentPerLevel': '16pt',
      'spaceAfter': '6pt',
    },
    'task': {'spaceAfter': '6pt'},
    'table': {
      'fontSizeRatio': 0.95,
      'borders': 'all',
      'cellPadding': {
        'top': '3pt',
        'right': '6pt',
        'bottom': '3pt',
        'left': '6pt',
      },
    },
    'image': {'borderRadius': '2px'},
  },
  'syntax': <String, Object?>{},
  'overlays': <String, Object?>{},
};
