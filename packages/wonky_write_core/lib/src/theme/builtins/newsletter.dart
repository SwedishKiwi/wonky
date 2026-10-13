/// Built-in theme *Newsletter* (06 §9).
library;

import 'common.dart';

/// JSON of the built-in *Newsletter*: editorial layout with a display
/// heading face and an accent color.
final Map<String, Object?> newsletterThemeJson = {
  'schemaVersion': 1,
  'name': 'Newsletter',
  'description':
      'Editorial layout: large display headings in the accent color, a '
      'narrow reading column, shadowed images with captions and an accent '
      'quote bar.',
  'basedOn': 'builtin:newsletter',
  'fonts': {
    'body': 'Lora',
    'heading': 'Playfair Display',
    'mono': 'Source Code Pro',
  },
  'palette': paletteJson(
    text: '#2d2a26',
    heading: '#1b1a18',
    muted: '#6d665e',
    accent: '#c2410c',
    linkHover: '#9a3412',
    page: '#ffffff',
    canvas: '#f5f2ed',
    border: '#e2dbd0',
    codeText: '#2d2a26',
    codeBg: '#f7f4ef',
    quoteText: '#4a443d',
    quoteBar: '@accent',
    tableHeaderBg: '#f4efe7',
    tableStripe: '#faf8f4',
    mentionBg: '#ffedd5',
    mentionText: '#9a3412',
    highlight: '#fde68a',
  ),
  'dark': {
    'mode': 'explicit',
    'palette': paletteJson(
      text: '#ebe5dc',
      heading: '#f6f1ea',
      muted: '#aaa197',
      accent: '#fb923c',
      linkHover: '#fdba74',
      page: '#262320',
      canvas: '#0f0d0b',
      border: '#3d3731',
      codeText: '#ebe5dc',
      codeBg: '#322e28',
      quoteText: '#cfc6ba',
      quoteBar: '@accent',
      tableHeaderBg: '#342f2a',
      tableStripe: '#2c2924',
      mentionBg: '#43230f',
      mentionText: '#fed7aa',
      highlight: '#4d3a0f',
    ),
    'elements': <String, Object?>{},
    'syntax': githubDarkSyntaxJson,
  },
  'page': {'pagelessMaxWidth': '640px'},
  'elements': {
    'body': {'fontSize': '11.5pt', 'lineHeight': 1.55, 'spaceAfter': '10pt'},
    'headings': {'fontWeight': 700, 'lineHeight': 1.15},
    'h1': {
      'fontSize': '34pt',
      'color': '@accent',
      'spaceBefore': '28pt',
      'spaceAfter': '12pt',
    },
    'h2': {'fontSize': '22pt', 'spaceBefore': '24pt'},
    'h3': {'fontSize': '16pt'},
    'blockquote': {
      'italic': true,
      'fontSize': '13pt',
      'bar': {'width': '4px', 'style': 'solid', 'color': '@accent'},
      'padding': {'left': '16px'},
      'spaceBefore': '8pt',
      'spaceAfter': '12pt',
    },
    'image': {
      'align': 'center',
      'shadow': 'soft',
      'borderRadius': '4px',
      'spaceBefore': '12pt',
      'spaceAfter': '12pt',
      'caption': {
        'show': true,
        'align': 'center',
        'fontStyle': 'italic',
        'fontSize': '0.9em',
        'gap': '6pt',
      },
    },
    'rule': {'width': '40%', 'color': '@accent', 'thickness': '2px'},
    'table': {'zebra': true, 'borders': 'horizontal'},
    'link': {'underline': 'always'},
  },
  'syntax': <String, Object?>{},
  'overlays': <String, Object?>{},
};
