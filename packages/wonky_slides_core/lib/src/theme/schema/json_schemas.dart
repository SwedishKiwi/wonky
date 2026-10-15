/// JSON Schemas (draft 2020-12) of the theme columns (Slides 05 §2, A-05-1),
/// exported for MCP tool descriptions. The validator ([DeckThemeValidator])
/// is authoritative; these schemas describe the same shapes for clients.
library;

import '../json/json_util.dart';
import '../model/deck_theme_data.dart';
import '../model/text_styles.dart';
import '../model/paint.dart';
import '../model/object_styles.dart';

const _hex = r'^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$';
const _colorRef =
    r'^(#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?|transparent|theme:(bg1|text1|bg2|text2|accent[1-6]|link|custom([1-9]|1[0-2]))(/(lum:[+-]?[0-9.]+|alpha:[0-9.]+))*)$';

JsonMap _str([Iterable<String>? values]) => {
  'type': 'string',
  if (values != null) 'enum': values.toList(),
};
JsonMap _num(num min, num max) => {
  'type': 'number',
  'minimum': min,
  'maximum': max,
};
JsonMap _int(int min, int max) => {
  'type': 'integer',
  'minimum': min,
  'maximum': max,
};
const JsonMap _color = {'type': 'string', 'pattern': _colorRef};
const JsonMap _hexColor = {'type': 'string', 'pattern': _hex};
const JsonMap _fontRef = {'type': 'string', 'minLength': 1, 'maxLength': 100};
const JsonMap _version = {'const': 1};
JsonMap _obj(JsonMap props, {List<String> required = const []}) => {
  'type': 'object',
  'properties': props,
  if (required.isNotEmpty) 'required': required,
  'additionalProperties': false,
};
JsonMap _quad(num max) => {
  'type': 'array',
  'items': _num(0, max),
  'minItems': 4,
  'maxItems': 4,
};

final JsonMap _fill = {
  'oneOf': [
    _obj(
      {
        'v': _version,
        'type': {'const': 'none'},
      },
      required: ['type'],
    ),
    _obj(
      {
        'v': _version,
        'type': {'const': 'solid'},
        'color': _color,
      },
      required: ['type', 'color'],
    ),
    _obj(
      {
        'v': _version,
        'type': {'const': 'gradient'},
        'kind': _str(['linear', 'radial']),
        'angle': _num(-360, 360),
        'center': {
          'type': 'array',
          'items': _num(0, 1),
          'minItems': 2,
          'maxItems': 2,
        },
        'radius': _num(0, 4),
        'stops': {
          'type': 'array',
          'minItems': 2,
          'items': _obj(
            {'at': _num(0, 1), 'color': _color},
            required: ['at', 'color'],
          ),
        },
      },
      required: ['type', 'stops'],
    ),
    _obj(
      {
        'v': _version,
        'type': {'const': 'image'},
        'fileUuid': _str(),
        'fit': _str(imageFitValues),
        'opacity': _num(0, 1),
      },
      required: ['type', 'fileUuid'],
    ),
  ],
};

final JsonMap _stroke = _obj({
  'v': _version,
  'type': _str(['none', 'solid']),
  'color': _color,
  'width': _num(0, 400),
  'dash': _str(dashValues),
  'cap': _str(['butt', 'round', 'square']),
  'join': _str(['miter', 'round', 'bevel']),
  'startArrow': _str(arrowValues),
  'endArrow': _str(arrowValues),
  'arrowSize': _str(['s', 'm', 'l']),
});

final JsonMap _textStyle = _obj({
  'font': _fontRef,
  'size': _num(minFontSize, maxFontSize),
  'weight': _int(100, 900),
  'italic': {'type': 'boolean'},
  'lineHeight': _num(0.7, 3),
  'letterSpacing': _num(-0.2, 1),
  'color': _color,
  'caps': _str(capsValues),
  'align': _str(alignValues),
  'spaceBefore': _num(0, 400),
  'spaceAfter': _num(0, 400),
});

final JsonMap _boxText = _obj({
  'v': _version,
  'anchor': _str(['top', 'middle', 'bottom']),
  'insets': _quad(2000),
  'autofit': _str(['none', 'shrink', 'resize']),
  'wrap': {'type': 'boolean'},
  'columns': _int(1, 3),
  'columnGap': _num(0, 400),
  'defaults': {'type': 'object'},
  'verticalText': {'type': 'boolean'},
});

JsonMap _scheme() =>
    _obj({for (final k in _schemeKeys) k: _hexColor}, required: _schemeKeys);

const _schemeKeys = [
  'bg1',
  'text1',
  'bg2',
  'text2',
  'accent1',
  'accent2',
  'accent3',
  'accent4',
  'accent5',
  'accent6',
  'link',
];

const _border = {
  'type': 'string',
  'pattern': r'^[0-9.]+\|(none|solid|dash|dot|dashDot|longDash)\|.+$',
};

JsonMap _tableArea() => _obj({
  'fill': _color,
  'text': _obj({
    'color': _color,
    'weight': _int(100, 900),
    'style': _str(themeTextStyleKeys),
    'italic': {'type': 'boolean'},
  }),
  'borderTop': _border,
});

/// The JSON Schemas of the `DeckTheme` columns.
abstract final class DeckThemeSchemas {
  /// The schema of [column].
  static JsonMap forColumn(DeckThemeColumn column) => switch (column) {
    DeckThemeColumn.colorsJson => _obj(
      {
        'v': _version,
        'light': _scheme(),
        'dark': _scheme(),
        'custom': {
          'type': 'array',
          'maxItems': 12,
          'items': _obj(
            {'name': _str(), 'light': _hexColor, 'dark': _hexColor},
            required: ['name', 'light', 'dark'],
          ),
        },
      },
      required: ['light', 'dark'],
    ),
    DeckThemeColumn.fontsJson => _obj(
      {
        'v': _version,
        for (final role in ['heading', 'body', 'mono'])
          role: _obj(
            {'family': _str(), 'weight': _int(100, 900)},
            required: ['family'],
          ),
      },
      required: ['heading', 'body', 'mono'],
    ),
    DeckThemeColumn.textStylesJson => _obj(
      {
        'v': _version,
        'styles': _obj({for (final k in themeTextStyleKeys) k: _textStyle}),
        'lists': _obj({
          'bullets': {
            'type': 'array',
            'items': _str(),
            'minItems': 9,
            'maxItems': 9,
          },
          'numbering': {
            'type': 'array',
            'items': _str(numberingKeys),
            'minItems': 9,
            'maxItems': 9,
          },
          'bulletColor': _color,
          'indentPerLevel': _num(0, 400),
          'markerGap': _num(0, 200),
          'levelSizeScale': _num(0.5, 1),
        }),
        'links': _obj({
          'color': _color,
          'underline': {'type': 'boolean'},
        }),
        'inlineCode': _obj({
          'background': _color,
          'radius': _num(0, 200),
          'paddingX': _num(0, 200),
        }),
      },
      required: ['styles'],
    ),
    DeckThemeColumn.backgroundJson => _obj(
      {
        'v': _version,
        'fill': _fill,
        'fillDark': {
          'oneOf': [
            {'type': 'null'},
            _fill,
          ],
        },
        'overlay': {
          'oneOf': [
            {'type': 'null'},
            _fill,
          ],
        },
      },
      required: ['fill'],
    ),
    DeckThemeColumn.shapeStyleJson => _obj({
      'v': _version,
      for (final k in ['text', 'shape', 'line', 'icon'])
        k: _obj({'fill': _fill, 'stroke': _stroke, 'textStyle': _boxText}),
      'quickStyles': {
        'type': 'array',
        'maxItems': ThemeShapeStyles.maxQuickStyles,
        'items': _obj({'fill': _fill, 'stroke': _stroke, 'textColor': _color}),
      },
      'shadow': _obj(
        {
          'color': _color,
          'blur': _num(0, 400),
          'dx': _num(-400, 400),
          'dy': _num(-400, 400),
          'spread': _num(-400, 400),
        },
        required: ['color'],
      ),
    }),
    DeckThemeColumn.tableStyleJson => _obj({
      'v': _version,
      'header': _tableArea(),
      'body': _tableArea(),
      'bandFill': _color,
      'firstColumn': _tableArea(),
      'totalRow': _tableArea(),
      'borders': _obj({
        'outer': _border,
        'horizontal': _border,
        'vertical': _border,
      }),
      'cellPadding': _quad(200),
      'radius': _num(0, 200),
    }),
    DeckThemeColumn.codeStyleJson => _obj({
      'v': _version,
      'palettes': _obj({'light': _str(), 'dark': _str()}),
      'custom': {
        'oneOf': [
          {'type': 'null'},
          _obj({
            'light': {'type': 'object'},
            'dark': {'type': 'object'},
          }),
        ],
      },
      'font': _fontRef,
      'box': _obj({
        'cornerRadius': _num(0, 400),
        'shadow': _str(['none', 'soft', 'strong']),
      }),
      'chrome': _str(codeChromeValues),
    }),
    DeckThemeColumn.chartStyleJson => _obj({
      'v': _version,
      'palette': {
        'type': 'array',
        'items': _color,
        'minItems': 1,
        'maxItems': 12,
      },
      'font': _fontRef,
      'textColor': _color,
      'titleStyle': _str(themeTextStyleKeys),
      'gridlines': _color,
      'axis': _color,
      'background': _color,
      'threeD': _obj({
        'lighting': _str(['soft', 'studio', 'flat']),
        'floor': _color,
      }),
    }),
  };

  /// `{columnName: schema}` for every column.
  static Map<String, JsonMap> get all => {
    for (final c in DeckThemeColumn.values) c.name: forColumn(c),
  };
}
