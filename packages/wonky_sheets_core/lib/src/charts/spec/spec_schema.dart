import '../../model/grid_range.dart';
import 'chart_type.dart';

/// One validation problem of a chart spec JSON.
final class ChartSpecIssue {
  /// Creates an issue at JSON [path] (`data.ranges[0]`).
  const ChartSpecIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is ChartSpecIssue && other.path == path && other.message == message;

  @override
  int get hashCode => Object.hash(path, message);

  @override
  String toString() => '$path: $message';
}

/// Thrown by `ChartSpec.patch` / `ChartSpec.parseStrict` when the JSON is invalid.
final class ChartSpecValidationException implements Exception {
  /// Creates the exception.
  const ChartSpecValidationException(this.issues);

  final List<ChartSpecIssue> issues;

  @override
  String toString() => 'ChartSpecValidationException(${issues.join('; ')})';
}

/// A node of the declarative chart spec schema. Unknown object keys are allowed (they are
/// preserved as extras); every known key is optional and nullable unless [required].
sealed class SchemaNode {
  const SchemaNode({this.nullable = true, this.description});

  final bool nullable;
  final String? description;

  /// Validates [value] at [path] into [out].
  void check(String path, Object? value, List<ChartSpecIssue> out) {
    if (value == null) {
      if (!nullable) out.add(ChartSpecIssue(path, 'must not be null'));
      return;
    }
    checkValue(path, value, out);
  }

  /// Validates a non-null value.
  void checkValue(String path, Object value, List<ChartSpecIssue> out);

  /// [value] in its stored form when it was written against the strict [jsonSchema]: maps
  /// sent as key/value pair lists become maps and `null` (= not set) properties are dropped.
  Object? fromStrict(Object? value) => value;

  /// JSON Schema (draft 2020-12) of this node, strict-compatible (`additionalProperties: false`,
  /// all properties listed, optional ones nullable).
  Map<String, Object?> jsonSchema();

  Map<String, Object?> _wrap(Map<String, Object?> s) {
    final out = <String, Object?>{...s, 'description': ?description};
    if (!nullable) return out;
    final t = out['type'];
    if (t is String) {
      out['type'] = [t, 'null'];
    } else if (out.containsKey('enum')) {
      out['enum'] = [...out['enum']! as List<Object?>, null];
    } else if (t == null) {
      return {
        'anyOf': [
          out,
          const {'type': 'null'},
        ],
      };
    }
    return out;
  }
}

/// An object with known [fields].
final class ObjectSchema extends SchemaNode {
  /// Creates an object schema.
  const ObjectSchema(
    this.fields, {
    this.required = const {},
    super.nullable,
    super.description,
  });

  final Map<String, SchemaNode> fields;
  final Set<String> required;

  @override
  void checkValue(String path, Object value, List<ChartSpecIssue> out) {
    if (value is! Map) {
      out.add(ChartSpecIssue(path, 'must be an object'));
      return;
    }
    for (final k in required) {
      if (!value.containsKey(k)) {
        out.add(ChartSpecIssue(_join(path, k), 'is required'));
      }
    }
    for (final e in fields.entries) {
      if (value.containsKey(e.key)) {
        e.value.check(_join(path, e.key), value[e.key], out);
      }
    }
  }

  @override
  Object? fromStrict(Object? value) {
    if (value is! Map) return value;
    return {
      for (final e in value.entries)
        if (e.value != null)
          '${e.key}': fields['${e.key}']?.fromStrict(e.value) ?? e.value,
    };
  }

  @override
  Map<String, Object?> jsonSchema() => _wrap({
    'type': 'object',
    'properties': {for (final e in fields.entries) e.key: e.value.jsonSchema()},
    'required': fields.keys.toList(),
    'additionalProperties': false,
  });
}

/// A map with arbitrary string keys (series keys, point indexes).
final class MapSchema extends SchemaNode {
  /// Creates a map schema; [intKeys] requires non-negative integer keys.
  const MapSchema(
    this.values, {
    this.intKeys = false,
    super.nullable,
    super.description,
  });

  final SchemaNode values;
  final bool intKeys;

  @override
  void checkValue(String path, Object value, List<ChartSpecIssue> out) {
    if (value is! Map) {
      out.add(ChartSpecIssue(path, 'must be an object'));
      return;
    }
    for (final e in value.entries) {
      final k = '${e.key}';
      if (intKeys && (int.tryParse(k) ?? -1) < 0) {
        out.add(
          ChartSpecIssue(_join(path, k), 'key must be a non-negative integer'),
        );
      }
      values.check(_join(path, k), e.value, out);
    }
  }

  @override
  Object? fromStrict(Object? value) {
    if (value is Map) {
      return {
        for (final e in value.entries) '${e.key}': values.fromStrict(e.value),
      };
    }
    if (value is! List) return value;
    return {
      for (final pair in value)
        if (pair is Map && pair['key'] != null)
          '${pair['key']}': values.fromStrict(pair['value']),
    };
  }

  @override
  Map<String, Object?> jsonSchema() => _wrap({
    'type': 'array',
    'description':
        'Entries as key/value pairs (maps are not strict-schema compatible).',
    'items': {
      'type': 'object',
      'properties': {
        'key': {'type': 'string'},
        'value': values.jsonSchema(),
      },
      'required': ['key', 'value'],
      'additionalProperties': false,
    },
  });
}

/// A list.
final class ListSchema extends SchemaNode {
  /// Creates a list schema.
  const ListSchema(
    this.items, {
    this.minItems = 0,
    super.nullable,
    super.description,
  });

  final SchemaNode items;
  final int minItems;

  @override
  void checkValue(String path, Object value, List<ChartSpecIssue> out) {
    if (value is! List) {
      out.add(ChartSpecIssue(path, 'must be a list'));
      return;
    }
    if (value.length < minItems) {
      out.add(ChartSpecIssue(path, 'needs at least $minItems items'));
    }
    for (var i = 0; i < value.length; i++) {
      items.check('$path[$i]', value[i], out);
    }
  }

  @override
  Object? fromStrict(Object? value) =>
      value is List ? [for (final v in value) items.fromStrict(v)] : value;

  @override
  Map<String, Object?> jsonSchema() =>
      _wrap({'type': 'array', 'items': items.jsonSchema()});
}

/// An enum by name.
final class EnumSchema extends SchemaNode {
  /// Creates an enum schema.
  const EnumSchema(this.values, {super.nullable, super.description});

  final List<Enum> values;

  @override
  void checkValue(String path, Object value, List<ChartSpecIssue> out) {
    if (value is! String || !values.any((e) => e.name == value)) {
      out.add(
        ChartSpecIssue(
          path,
          'must be one of ${values.map((e) => e.name).join(', ')}',
        ),
      );
    }
  }

  @override
  Map<String, Object?> jsonSchema() => _wrap({
    'type': 'string',
    'enum': [for (final e in values) e.name],
  });
}

/// A number with optional bounds.
final class NumSchema extends SchemaNode {
  /// Creates a number schema.
  const NumSchema({
    this.min,
    this.max,
    this.integer = false,
    super.nullable,
    super.description,
  });

  final num? min;
  final num? max;
  final bool integer;

  @override
  void checkValue(String path, Object value, List<ChartSpecIssue> out) {
    if (value is! num || !value.isFinite) {
      out.add(ChartSpecIssue(path, 'must be a number'));
      return;
    }
    if (integer && value != value.truncate()) {
      out.add(ChartSpecIssue(path, 'must be an integer'));
    }
    if (min != null && value < min!) {
      out.add(ChartSpecIssue(path, 'must be ≥ $min'));
    }
    if (max != null && value > max!) {
      out.add(ChartSpecIssue(path, 'must be ≤ $max'));
    }
  }

  @override
  Map<String, Object?> jsonSchema() => _wrap({
    'type': integer ? 'integer' : 'number',
    'minimum': ?min,
    'maximum': ?max,
  });
}

/// A boolean.
final class BoolSchema extends SchemaNode {
  /// Creates a bool schema.
  const BoolSchema({super.nullable, super.description});

  @override
  void checkValue(String path, Object value, List<ChartSpecIssue> out) {
    if (value is! bool) out.add(ChartSpecIssue(path, 'must be a boolean'));
  }

  @override
  Map<String, Object?> jsonSchema() => _wrap({'type': 'boolean'});
}

/// A string, optionally a WonkyColor (`#RGB`, `#RRGGBB`, `#AARRGGBB`, `theme:<key>`).
final class StrSchema extends SchemaNode {
  /// Creates a string schema.
  const StrSchema({
    this.color = false,
    this.nonEmpty = false,
    super.nullable,
    super.description,
  });

  final bool color;
  final bool nonEmpty;

  static final _color = RegExp(
    r'^(#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})|theme:[A-Za-z][A-Za-z0-9]*)$',
  );

  @override
  void checkValue(String path, Object value, List<ChartSpecIssue> out) {
    if (value is! String) {
      out.add(ChartSpecIssue(path, 'must be a string'));
      return;
    }
    if (nonEmpty && value.isEmpty) {
      out.add(ChartSpecIssue(path, 'must not be empty'));
    }
    if (color && !_color.hasMatch(value)) {
      out.add(
        ChartSpecIssue(path, 'must be a color (#RRGGBB or theme:<name>)'),
      );
    }
  }

  @override
  Map<String, Object?> jsonSchema() =>
      _wrap({'type': 'string', if (color) 'pattern': _color.pattern});
}

/// A GridRange JSON object.
final class GridRangeSchema extends SchemaNode {
  /// Creates the schema.
  const GridRangeSchema({super.nullable, super.description});

  @override
  void checkValue(String path, Object value, List<ChartSpecIssue> out) {
    if (GridRange.tryParse(value) == null) {
      out.add(
        ChartSpecIssue(path, 'must be a GridRange {"s": sheetId, "r1"…"c2"}'),
      );
    }
  }

  @override
  Map<String, Object?> jsonSchema() => _wrap({
    'type': 'object',
    'properties': {
      for (final k in ['s', 'r1', 'r2', 'c1', 'c2', 'r1k', 'r2k', 'c1k', 'c2k'])
        k: k == 's'
            ? const {'type': 'string'}
            : const {
                'type': ['string', 'null'],
              },
    },
    'required': ['s', 'r1', 'r2', 'c1', 'c2', 'r1k', 'r2k', 'c1k', 'c2k'],
    'additionalProperties': false,
  });
}

/// Any JSON value (P2 payloads kept verbatim).
final class AnySchema extends SchemaNode {
  /// Creates the schema.
  const AnySchema({super.description});

  @override
  void checkValue(String path, Object value, List<ChartSpecIssue> out) {}

  @override
  Map<String, Object?> jsonSchema() => {'description': ?description};
}

String _join(String path, String key) => path.isEmpty ? key : '$path.$key';

/// The `ChartSpec` v1 schema (08 §3): validation after merge patches and JSON Schema export
/// for MCP (08 §17).
abstract final class ChartSpecSchema {
  static const _font = ObjectSchema({
    'family': StrSchema(),
    'size': NumSchema(min: 4, max: 200),
    'bold': BoolSchema(),
    'italic': BoolSchema(),
    'color': StrSchema(color: true),
  });

  static const _title = ObjectSchema({
    'text': StrSchema(),
    'font': _font,
    'align': EnumSchema(TitleAlign.values),
  });

  static const _axis = ObjectSchema({
    'title': _title,
    'showLine': BoolSchema(),
    'labels': ObjectSchema({
      'show': BoolSchema(),
      'font': _font,
      'slant': EnumSchema(LabelSlant.values),
      'angle': NumSchema(min: -90, max: 90),
    }),
    'reverse': BoolSchema(),
    'min': NumSchema(),
    'max': NumSchema(),
    'logScale': BoolSchema(),
    'numberFormat': StrSchema(),
    'dateGrouping': StrSchema(),
  });

  static const _gridline = ObjectSchema({
    'show': BoolSchema(),
    'count': NumSchema(min: 0, max: 50, integer: true),
    'spacing': NumSchema(min: 0),
    'color': StrSchema(color: true),
  });

  static const _axisGridlines = ObjectSchema({
    'major': _gridline,
    'minor': _gridline,
    'ticks': ObjectSchema({
      'major': EnumSchema(TickMark.values),
      'minor': EnumSchema(TickMark.values),
    }),
  });

  static const _dataRef = ObjectSchema({
    'range': NumSchema(min: 0, integer: true),
    'offset': NumSchema(min: 0, integer: true),
  });

  static const _trendline = ObjectSchema({
    'type': EnumSchema(TrendlineType.values),
    'degree': NumSchema(min: 2, max: 10, integer: true),
    'period': NumSchema(min: 2, integer: true),
    'label': EnumSchema(TrendlineLabel.values),
    'customLabel': StrSchema(),
    'showR2': BoolSchema(),
    'color': StrSchema(color: true),
    'opacity': NumSchema(min: 0, max: 1),
    'lineWidth': NumSchema(min: 0, max: 8),
    'lineDash': EnumSchema(LineDash.values),
    'forward': NumSchema(min: 0),
    'backward': NumSchema(min: 0),
  });

  static const _series = ObjectSchema({
    'type': EnumSchema(SeriesChartType.values),
    'axis': EnumSchema(SeriesAxis.values),
    'color': StrSchema(color: true),
    'fillOpacity': NumSchema(min: 0, max: 1),
    'lineColor': StrSchema(color: true),
    'lineOpacity': NumSchema(min: 0, max: 1),
    'lineWidth': NumSchema(min: 0, max: 8),
    'lineDash': EnumSchema(LineDash.values),
    'pointSize': NumSchema(min: 0, max: 50),
    'pointShape': EnumSchema(PointShape.values),
    'dataLabels': ObjectSchema({
      'show': BoolSchema(),
      'position': EnumSchema(DataLabelPosition.values),
      'type': EnumSchema(DataLabelType.values),
      'font': _font,
    }),
    'trendline': _trendline,
    'errorBars': AnySchema(description: 'P2'),
    'points': MapSchema(
      ObjectSchema({'color': StrSchema(color: true)}),
      intKeys: true,
    ),
    'labelOverride': StrSchema(),
  });

  static const _typeOptions = ObjectSchema({
    // pie
    'pieHole': NumSchema(min: 0, max: 0.9),
    'sliceLabel': EnumSchema(SliceLabel.values),
    'borderColor': StrSchema(color: true),
    'slices': MapSchema(
      ObjectSchema({
        'color': StrSchema(color: true),
        'offset': NumSchema(min: 0, max: 1),
      }),
      intKeys: true,
    ),
    'startAngle': NumSchema(min: -360, max: 360),
    'pieOtherThreshold': NumSchema(min: 2, max: 1000, integer: true),
    // histogram
    'bucketSize': NumSchema(min: 0),
    'outlierPercentile': NumSchema(min: 0, max: 25),
    'showItemDividers': BoolSchema(),
    // candlestick
    'risingColor': StrSchema(color: true),
    'fallingColor': StrSchema(color: true),
    'risingFilled': BoolSchema(),
    'fallingFilled': BoolSchema(),
    // waterfall
    'connectorLines': ObjectSchema({
      'show': BoolSchema(),
      'color': StrSchema(color: true),
      'dash': EnumSchema(LineDash.values),
    }),
    'subtotals': ListSchema(
      ObjectSchema(
        {
          'afterIndex': NumSchema(min: 0, integer: true, nullable: false),
          'label': StrSchema(),
        },
        required: {'afterIndex'},
      ),
    ),
    'firstValueIsSubtotal': BoolSchema(),
    'positiveColor': StrSchema(color: true),
    'negativeColor': StrSchema(color: true),
    'subtotalColor': StrSchema(color: true),
    // scorecard
    'keyValueRef': GridRangeSchema(),
    'baselineRef': GridRangeSchema(),
    'aggregate': EnumSchema(ChartAggregate.values),
    'compareMode': EnumSchema(ScorecardCompareMode.values),
    'keyFormat': StrSchema(),
    'baselineFormat': StrSchema(),
    'showSparkline': BoolSchema(),
    // table
    'pageSize': NumSchema(min: 0, max: 10000, integer: true),
    'sortColumn': NumSchema(min: 0, integer: true),
    'sortAscending': BoolSchema(),
    'showRowNumbers': BoolSchema(),
    'alternatingColors': BoolSchema(),
    'formatFromSource': BoolSchema(),
    // radar
    'fillOpacity': NumSchema(min: 0, max: 1),
    'gridShape': EnumSchema(RadarGridShape.values),
    // bubble
    'sizeRange': ListSchema(
      NumSchema(min: 1, max: 400, nullable: false),
      minItems: 2,
    ),
    'colorBy': EnumSchema(BubbleColorBy.values),
  });

  /// The root schema.
  static const root = ObjectSchema(
    {
      'v': NumSchema(min: 1, integer: true, nullable: false),
      'type': EnumSchema(ChartType.values, nullable: false),
      'stacking': EnumSchema(ChartStacking.values),
      'data': ObjectSchema({
        'ranges': ListSchema(GridRangeSchema(nullable: false), nullable: false),
        'switchRowsColumns': BoolSchema(),
        'headerCount': NumSchema(min: 0, max: 100, integer: true),
        'useFirstColumnAsLabels': BoolSchema(),
        'treatLabelsAsText': BoolSchema(),
        'aggregate': EnumSchema(ChartAggregate.values),
        'domain': ObjectSchema({
          'ref': _dataRef,
          'reverse': BoolSchema(),
          'key': StrSchema(),
        }),
        'seriesRefs': ListSchema(
          ObjectSchema(
            {
              'key': StrSchema(nonEmpty: true, nullable: false),
              'ref': _dataRef,
              'hidden': BoolSchema(),
            },
            required: {'key'},
          ),
        ),
        'includeHidden': BoolSchema(),
        'emptyCells': EnumSchema(EmptyCellMode.values),
        'maxPoints': NumSchema(min: 100, integer: true),
      }, nullable: false),
      'style': ObjectSchema({
        'background': StrSchema(color: true),
        'fontFamily': StrSchema(),
        'border': StrSchema(color: true),
        'maximize': BoolSchema(),
        'smooth': BoolSchema(),
        'plotNullValues': BoolSchema(),
        'compareMode': EnumSchema(CompareMode.values),
        'palette': ListSchema(StrSchema(color: true, nullable: false)),
      }),
      'title': _title,
      'subtitle': _title,
      'axes': ObjectSchema({'h': _axis, 'v': _axis, 'v2': _axis}),
      'legend': ObjectSchema({
        'position': EnumSchema(LegendPosition.values),
        'font': _font,
        'alignment': EnumSchema(LegendAlignment.values),
      }),
      'gridlines': ObjectSchema({'h': _axisGridlines, 'v': _axisGridlines}),
      'series': MapSchema(_series),
      'typeOptions': _typeOptions,
    },
    required: {'v', 'type', 'data'},
    nullable: false,
  );

  /// Validates a spec JSON map; empty list = valid.
  static List<ChartSpecIssue> validate(Map<String, Object?> json) {
    final out = <ChartSpecIssue>[];
    root.check('', json, out);
    final data = json['data'];
    if (data is Map) {
      final ranges = data['ranges'];
      final n = ranges is List ? ranges.length : 0;
      void checkRef(String path, Object? ref) {
        if (ref is Map &&
            ref['range'] is num &&
            (ref['range'] as num) >= n &&
            n > 0) {
          out.add(ChartSpecIssue('$path.range', 'refers to a missing range'));
        }
      }

      final domain = data['domain'];
      if (domain is Map) checkRef('data.domain.ref', domain['ref']);
      final refs = data['seriesRefs'];
      if (refs is List) {
        final keys = <String>{};
        for (var i = 0; i < refs.length; i++) {
          final r = refs[i];
          if (r is! Map) continue;
          checkRef('data.seriesRefs[$i].ref', r['ref']);
          final k = r['key'];
          if (k is String && !keys.add(k)) {
            out.add(
              ChartSpecIssue('data.seriesRefs[$i].key', 'duplicate series key'),
            );
          }
        }
      }
    }
    final axes = json['axes'];
    if (axes is Map) {
      for (final a in ['h', 'v', 'v2']) {
        final ax = axes[a];
        if (ax is Map && ax['min'] is num && ax['max'] is num) {
          if ((ax['min'] as num) >= (ax['max'] as num)) {
            out.add(ChartSpecIssue('axes.$a.min', 'must be smaller than max'));
          }
        }
      }
    }
    return out;
  }

  /// A spec JSON written against the strict [jsonSchema] (MCP clients in strict mode) in its
  /// stored form: key/value pair lists become maps and `null` properties are dropped. Run
  /// [validate] (or `ChartSpec.parseStrict`) on the result.
  static Map<String, Object?> fromStrictJson(Map<String, Object?> json) =>
      (root.fromStrict(json)! as Map).cast();

  /// JSON Schema of `ChartSpec` (MCP, 08 §17).
  static Map<String, Object?> jsonSchema() => {
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    'title': 'ChartSpec',
    ...root.jsonSchema(),
  };
}
