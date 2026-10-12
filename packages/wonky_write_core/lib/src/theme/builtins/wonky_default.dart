/// Built-in theme *Wonky Default* (06 §9).
library;

import '../resolve/base_theme.dart';
import 'common.dart';

/// JSON of the built-in *Wonky Default*: the cascade base itself plus a
/// hand-tuned explicit dark variant.
final Map<String, Object?> wonkyDefaultThemeJson = {
  'schemaVersion': 1,
  'name': 'Wonky Default',
  'description':
      'Clean sans-serif typography with accent links, soft code blocks and '
      'rounded images.',
  'basedOn': 'builtin:wonky-default',
  'fonts': {'body': 'Inter', 'heading': 'Inter', 'mono': 'JetBrains Mono'},
  'palette': wonkyDefaultPaletteJson,
  'dark': {
    'mode': 'explicit',
    'palette': paletteJson(
      text: '#e6edf3',
      heading: '#f5f7fa',
      muted: '#9aa4b2',
      accent: '#7aa2ff',
      linkHover: '#a5c0ff',
      page: '#1b1d21',
      canvas: '#121417',
      border: '#3a4048',
      codeText: '#e6edf3',
      codeBg: '#24272d',
      quoteText: '#b4bcc8',
      quoteBar: '#4a515b',
      tableHeaderBg: '#262a30',
      tableStripe: '#202328',
      mentionBg: '#2c3557',
      mentionText: '#c7d2fe',
      highlight: '#4a3f12',
    ),
    'elements': <String, Object?>{},
    'syntax': githubDarkSyntaxJson,
  },
  'page': <String, Object?>{},
  'elements': <String, Object?>{},
  'syntax': wonkyDefaultSyntaxJson,
  'overlays': <String, Object?>{},
};
