/// Generates the theme JSON schema v1 from the property catalog.
///
/// The published schema is the constant `themeSchemaV1Json`; a test asserts
/// that it equals [generateThemeSchemaV1] so the two never drift apart.
library;

import '../../fonts/font_registry.dart';
import '../model/catalog.dart';
import '../model/color_ref.dart';
import '../model/json_util.dart';
import '../model/syntax_token.dart';
import '../model/values.dart';
import '../model/write_theme_data.dart';

/// Builds the JSON schema (draft 2020-12) of theme schema v1.
JsonMap generateThemeSchemaV1() {
  final paletteKeys = PaletteKey.values.map((k) => k.name).join('|');
  final colorDef = {
    'anyOf': [
      {'type': 'string', 'pattern': r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$'},
      {'type': 'string', 'pattern': '^@($paletteKeys)\$'},
      {
        'enum': ['transparent'],
      },
      {'type': 'null'},
    ],
  };
  JsonMap palette({required bool complete}) => {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      for (final k in PaletteKey.values) k.name: {r'$ref': r'#/$defs/color'},
    },
    if (complete)
      'required': [
        for (final k in PaletteKey.values)
          if (!k.isCustom) k.name,
      ],
  };
  final elements = {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      for (final e in ThemeElement.values)
        e.name: ThemeCatalog.elements[e]!.schema(),
    },
  };
  final syntax = {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      for (final t in SyntaxToken.values)
        t.name: ThemeCatalog.syntaxToken.schema(),
    },
  };
  final familyEnum = [for (final f in FontRegistry.families) f.family];
  return {
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    r'$id': themeSchemaUrl,
    'title': 'Wonky Write theme',
    'description':
        'Theme JSON (schemaVersion 1). Unknown properties are dropped with '
        'a warning; lengths are "<number><unit>" with unit pt, px, em, mm, '
        'in or %; colors are #RRGGBB, #RRGGBBAA, @paletteKey, transparent '
        'or null (inherit).',
    'type': 'object',
    'required': ['schemaVersion', 'name', 'palette'],
    'additionalProperties': false,
    'properties': {
      r'$schema': {'type': 'string'},
      'exportedAt': {'type': 'string'},
      'schemaVersion': {'const': currentThemeSchemaVersion},
      'name': {'type': 'string', 'minLength': 1, 'maxLength': 80},
      'description': {
        'type': ['string', 'null'],
        'maxLength': 500,
      },
      'basedOn': {
        'type': ['string', 'null'],
        'maxLength': 200,
      },
      'fonts': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          for (final r in FontRole.values) r.name: {r'$ref': r'#/$defs/fontFamily'},
        },
      },
      'palette': {r'$ref': r'#/$defs/palette'},
      'dark': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'mode': {
            'enum': [for (final m in DarkMode.values) m.json],
          },
          'palette': {r'$ref': r'#/$defs/partialPalette'},
          'elements': {r'$ref': r'#/$defs/elements'},
          'syntax': {
            'anyOf': [
              {r'$ref': r'#/$defs/syntax'},
              {'type': 'null'},
            ],
          },
        },
      },
      'page': ThemeCatalog.page.schema(),
      'elements': {r'$ref': r'#/$defs/elements'},
      'syntax': {r'$ref': r'#/$defs/syntax'},
      'overlays': ThemeCatalog.overlays.schema(),
    },
    r'$defs': {
      'length': {
        'type': 'string',
        'pattern': r'^-?(\d+(\.\d*)?|\.\d+)([eE][-+]?\d+)?(pt|px|em|mm|in|%)$',
      },
      'color': colorDef,
      'font': {
        'anyOf': [
          {
            'enum': ['@body', '@heading', '@mono'],
          },
          {r'$ref': r'#/$defs/fontFamily'},
        ],
      },
      'fontFamily': {'enum': familyEnum},
      'fontWeight': {'type': 'integer', 'minimum': 100, 'maximum': 900},
      'border': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'width': {r'$ref': r'#/$defs/length'},
          'style': {
            'enum': ['none', 'solid', 'dashed', 'dotted', 'double'],
          },
          'color': {r'$ref': r'#/$defs/color'},
        },
      },
      'lengthEdges': {
        'anyOf': [
          {r'$ref': r'#/$defs/length'},
          {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              for (final s in const ['top', 'right', 'bottom', 'left'])
                s: {r'$ref': r'#/$defs/length'},
            },
          },
        ],
      },
      'borderEdges': {
        'anyOf': [
          {r'$ref': r'#/$defs/border'},
          {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              for (final s in const ['top', 'right', 'bottom', 'left'])
                s: {r'$ref': r'#/$defs/border'},
            },
          },
        ],
      },
      'palette': palette(complete: true),
      'partialPalette': palette(complete: false),
      'elements': elements,
      'syntax': syntax,
    },
  };
}
