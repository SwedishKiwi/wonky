/// Typed, catalog-driven style properties: property types, parsing with
/// issue reporting, and the immutable [PropertyBag] (06 §2.4, §2.7).
library;

import 'package:collection/collection.dart';

import '../../fonts/font_registry.dart';
import 'color_ref.dart';
import 'json_util.dart';
import 'length.dart';
import 'values.dart';

/// Severity of a [ThemeIssue].
enum ThemeIssueSeverity implements JsonEnum {
  /// Blocking: the theme cannot be saved/imported.
  error,

  /// Non-blocking: the value was cleaned (dropped, snapped, replaced).
  warning;

  @override
  String get json => name;
}

/// A validation finding at a JSON [path] (e.g. `elements.h2.fontSize`).
final class ThemeIssue {
  /// Creates an issue.
  const ThemeIssue(this.severity, this.path, this.code, this.message);

  /// Severity.
  final ThemeIssueSeverity severity;

  /// Dotted JSON path of the offending value (`""` = root).
  final String path;

  /// Stable machine-readable code, e.g. `out_of_bounds`, `unknown_property`.
  final String code;

  /// Human-readable message (English).
  final String message;

  /// JSON form `{path, code, message, severity}` (MCP `details`).
  JsonMap toJson() => {
    'path': path,
    'code': code,
    'message': message,
    'severity': severity.json,
  };

  @override
  bool operator ==(Object other) =>
      other is ThemeIssue &&
      other.severity == severity &&
      other.path == path &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(severity, path, code, message);

  @override
  String toString() => '${severity.name} $code at "$path": $message';
}

/// Collects [ThemeIssue]s while parsing.
final class ThemeIssueSink {
  /// Blocking issues.
  final List<ThemeIssue> errors = [];

  /// Non-blocking issues.
  final List<ThemeIssue> warnings = [];

  /// Records an error.
  void error(String path, String code, String message) =>
      errors.add(ThemeIssue(ThemeIssueSeverity.error, path, code, message));

  /// Records a warning.
  void warning(String path, String code, String message) =>
      warnings.add(ThemeIssue(ThemeIssueSeverity.warning, path, code, message));
}

/// Context for parsing property values.
final class PropParseContext {
  /// Creates a context.
  const PropParseContext({
    required this.issues,
    required this.roleFamilies,
    this.defaultRole = FontRole.body,
    this.weightFamilyOverride,
  });

  /// Where issues are reported.
  final ThemeIssueSink issues;

  /// Concrete family per font role (from the theme's `fonts`).
  final Map<FontRole, String> roleFamilies;

  /// Role used to replace unknown families and for weight snapping when
  /// the element sets no family.
  final FontRole defaultRole;

  /// Explicit family for weight snapping (the element's own `fontFamily`).
  final String? weightFamilyOverride;

  /// Family against which `fontWeight` values are snapped.
  String get weightFamily =>
      weightFamilyOverride ??
      roleFamilies[defaultRole] ??
      FontRegistry.defaultFor(defaultRole.name);

  /// A copy with other [defaultRole] / [weightFamily].
  PropParseContext copyWith({FontRole? defaultRole, String? weightFamily}) =>
      PropParseContext(
        issues: issues,
        roleFamilies: roleFamilies,
        defaultRole: defaultRole ?? this.defaultRole,
        weightFamilyOverride: weightFamily ?? weightFamilyOverride,
      );
}

/// Allowed units and bounds of a length property (06 §2.7).
enum LengthKind {
  /// Font sizes: 6–96 pt (em relative to body: 0.3–8).
  fontSize(
    {
      LengthUnit.pt,
      LengthUnit.px,
      LengthUnit.em,
      LengthUnit.mm,
      LengthUnit.inch,
    },
    6,
    96,
    0.3,
    8,
  ),

  /// Spacing, padding, radii, indents: 0–200 pt (em 0–20).
  spacing(
    {
      LengthUnit.pt,
      LengthUnit.px,
      LengthUnit.em,
      LengthUnit.mm,
      LengthUnit.inch,
    },
    0,
    200,
    0,
    20,
  ),

  /// Line widths (borders, thickness, caret): 0–36 pt (em 0–2).
  stroke({LengthUnit.pt, LengthUnit.px, LengthUnit.em, LengthUnit.mm}, 0, 36, 0, 2),

  /// Letter spacing: −20–20 pt (em −0.5–1).
  letterSpacing({LengthUnit.pt, LengthUnit.px, LengthUnit.em}, -20, 20, -0.5, 1),

  /// Page margins: 0–3 in.
  margin({LengthUnit.pt, LengthUnit.px, LengthUnit.mm, LengthUnit.inch}, 0, 216, 0, 0),

  /// Widths relative to the content width (`%` 0–100) or absolute
  /// (0–3000 pt).
  width(
    {
      LengthUnit.pt,
      LengthUnit.px,
      LengthUnit.mm,
      LengthUnit.inch,
      LengthUnit.percent,
    },
    0,
    3000,
    0,
    0,
  ),

  /// Pageless content width: 200–3000 pt.
  pageWidth({LengthUnit.pt, LengthUnit.px, LengthUnit.mm, LengthUnit.inch}, 150, 3000, 0, 0);

  const LengthKind(this.units, this.minPt, this.maxPt, this.minEm, this.maxEm);

  /// Allowed units.
  final Set<LengthUnit> units;

  /// Inclusive bounds for absolute units, in pt.
  final double minPt, maxPt;

  /// Inclusive bounds for `em` values.
  final double minEm, maxEm;
}

/// The type of a theme property: parsing, validation and JSON schema.
sealed class PropType {
  const PropType();

  /// Parses [json] at [path]; returns the typed value or `null` when the
  /// value is invalid (an issue was reported) or JSON `null`.
  Object? parse(Object? json, String path, PropParseContext ctx);

  /// JSON-schema fragment of this type.
  JsonMap schema();
}

String _typeName(Object? v) => switch (v) {
  null => 'null',
  String() => 'string',
  bool() => 'boolean',
  num() => 'number',
  List() => 'array',
  Map() => 'object',
  _ => v.runtimeType.toString(),
};

void _wrongType(PropParseContext ctx, String path, String expected, Object? v) {
  ctx.issues.error(
    path,
    'wrong_type',
    'Expected $expected, got ${_typeName(v)}.',
  );
}

/// A [Length] property of a given [kind].
final class LengthProp extends PropType {
  /// Creates a length property.
  const LengthProp(this.kind);

  /// Units and bounds.
  final LengthKind kind;

  @override
  Length? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is num && json == 0) return Length.zero;
    if (json is! String) {
      _wrongType(ctx, path, 'a length string like "11pt"', json);
      return null;
    }
    final l = Length.tryParse(json);
    if (l == null) {
      ctx.issues.error(path, 'invalid_length', 'Invalid length "$json".');
      return null;
    }
    if (!kind.units.contains(l.unit)) {
      ctx.issues.error(
        path,
        'unit_not_allowed',
        'Unit "${l.unit.json}" is not allowed here '
            '(allowed: ${kind.units.map((u) => u.json).join(', ')}).',
      );
      return null;
    }
    final (lo, hi, v, unit) = switch (l.unit) {
      LengthUnit.em => (kind.minEm, kind.maxEm, l.value, 'em'),
      LengthUnit.percent => (0.0, 100.0, l.value, '%'),
      _ => (kind.minPt, kind.maxPt, l.toPt(), 'pt'),
    };
    if (v < lo - 1e-9 || v > hi + 1e-9) {
      ctx.issues.error(
        path,
        'out_of_bounds',
        'Length $json is outside ${formatThemeNumber(lo)}–'
            '${formatThemeNumber(hi)} $unit.',
      );
      return null;
    }
    return l;
  }

  @override
  JsonMap schema() => {r'$ref': '#/\$defs/length'};
}

/// A [ColorRef] property.
final class ColorProp extends PropType {
  /// Creates a color property.
  const ColorProp();

  @override
  ColorRef? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is! String) {
      _wrongType(ctx, path, 'a color string', json);
      return null;
    }
    final c = ColorRef.tryParse(json.trim());
    if (c == null) {
      ctx.issues.error(path, 'invalid_color', 'Invalid color "$json".');
    }
    return c;
  }

  @override
  JsonMap schema() => {r'$ref': '#/\$defs/color'};
}

/// A [FontRef] property; unknown families are replaced with the context's
/// role with a warning (06 §2.1).
final class FontProp extends PropType {
  /// Creates a font property.
  const FontProp();

  @override
  FontRef? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is! String) {
      _wrongType(ctx, path, 'a font reference', json);
      return null;
    }
    final ref = FontRef.tryParse(json);
    if (ref == null) {
      ctx.issues.error(path, 'invalid_font', 'Invalid font reference "$json".');
      return null;
    }
    if (ref.family == null) return ref;
    final canonical = FontRegistry.canonicalName(ref.family!);
    if (canonical == null) {
      ctx.issues.warning(
        path,
        'unknown_font',
        'Unknown font family "${ref.family}"; using @${ctx.defaultRole.name}.',
      );
      return FontRef.role(ctx.defaultRole);
    }
    return FontRef.family(canonical);
  }

  @override
  JsonMap schema() => {r'$ref': '#/\$defs/font'};
}

/// A font weight (100–900), snapped to the nearest shipped weight of the
/// context family with a warning (06 §8.2).
final class WeightProp extends PropType {
  /// Creates a weight property.
  const WeightProp();

  @override
  int? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is! num || json != json.roundToDouble()) {
      _wrongType(ctx, path, 'an integer weight 100–900', json);
      return null;
    }
    final w = json.toInt();
    if (w < 100 || w > 900) {
      ctx.issues.error(path, 'out_of_bounds', 'Weight $w is outside 100–900.');
      return null;
    }
    final family = ctx.weightFamily;
    final snapped = FontRegistry.snapWeight(family, w);
    if (snapped != w) {
      ctx.issues.warning(
        path,
        'weight_snapped',
        'Weight $w is not shipped for "$family"; snapped to $snapped.',
      );
    }
    return snapped;
  }

  @override
  JsonMap schema() => {r'$ref': '#/\$defs/fontWeight'};
}

/// A number within [min]…[max].
final class NumberProp extends PropType {
  /// Creates a number property.
  const NumberProp(this.min, this.max);

  /// Inclusive bounds.
  final double min, max;

  @override
  double? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is! num || !json.isFinite) {
      _wrongType(ctx, path, 'a number', json);
      return null;
    }
    final v = json.toDouble();
    if (v < min || v > max) {
      ctx.issues.error(
        path,
        'out_of_bounds',
        '${formatThemeNumber(v)} is outside '
            '${formatThemeNumber(min)}–${formatThemeNumber(max)}.',
      );
      return null;
    }
    return v;
  }

  @override
  JsonMap schema() => {
    'type': 'number',
    'minimum': normalizeJsonNumber(min),
    'maximum': normalizeJsonNumber(max),
  };
}

/// An integer within [min]…[max].
final class IntProp extends PropType {
  /// Creates an integer property.
  const IntProp(this.min, this.max);

  /// Inclusive bounds.
  final int min, max;

  @override
  int? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is! num || json != json.roundToDouble()) {
      _wrongType(ctx, path, 'an integer', json);
      return null;
    }
    final v = json.toInt();
    if (v < min || v > max) {
      ctx.issues.error(path, 'out_of_bounds', '$v is outside $min–$max.');
      return null;
    }
    return v;
  }

  @override
  JsonMap schema() => {'type': 'integer', 'minimum': min, 'maximum': max};
}

/// A boolean.
final class BoolProp extends PropType {
  /// Creates a boolean property.
  const BoolProp();

  @override
  bool? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is! bool) {
      _wrongType(ctx, path, 'a boolean', json);
      return null;
    }
    return json;
  }

  @override
  JsonMap schema() => {'type': 'boolean'};
}

/// One of a fixed set of strings.
final class EnumProp extends PropType {
  /// Creates an enum property.
  const EnumProp(this.values);

  /// Allowed values.
  final List<String> values;

  @override
  String? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is! String || !values.contains(json)) {
      ctx.issues.error(
        path,
        'invalid_value',
        'Expected one of ${values.map((v) => '"$v"').join(', ')}.',
      );
      return null;
    }
    return json;
  }

  @override
  JsonMap schema() => {'enum': values};
}

/// A free string of at most [maxLength] UTF-16 units.
final class StringProp extends PropType {
  /// Creates a string property.
  const StringProp({this.maxLength = 80});

  /// Maximum length.
  final int maxLength;

  @override
  String? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is! String) {
      _wrongType(ctx, path, 'a string', json);
      return null;
    }
    if (json.length > maxLength) {
      ctx.issues.error(path, 'too_long', 'At most $maxLength characters.');
      return null;
    }
    return json;
  }

  @override
  JsonMap schema() => {'type': 'string', 'maxLength': maxLength};
}

/// A [BorderSpec] `{width, style, color}`.
final class BorderProp extends PropType {
  /// Creates a border property.
  const BorderProp();

  static const _width = LengthProp(LengthKind.stroke);
  static const _style = EnumProp(['none', 'solid', 'dashed', 'dotted', 'double']);
  static const _color = ColorProp();

  @override
  BorderSpec? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is! Map) {
      _wrongType(ctx, path, 'a border object', json);
      return null;
    }
    for (final k in json.keys) {
      if (k != 'width' && k != 'style' && k != 'color') {
        ctx.issues.warning(
          '$path.$k',
          'unknown_property',
          'Unknown property "$k" dropped.',
        );
      }
    }
    final style = _style.parse(json['style'], '$path.style', ctx);
    final b = BorderSpec(
      width: _width.parse(json['width'], '$path.width', ctx),
      style: style == null ? null : enumFromJson(LineStyle.values, style),
      color: _color.parse(json['color'], '$path.color', ctx),
    );
    return b;
  }

  @override
  JsonMap schema() => {r'$ref': '#/\$defs/border'};
}

/// `Edges<T>`: a single value or `{top, right, bottom, left}`.
final class EdgesProp extends PropType {
  /// Edges of lengths of [kind].
  const EdgesProp.lengths(LengthKind this.kind);

  /// Edges of borders.
  const EdgesProp.borders() : kind = null;

  /// Units and bounds of length edges; `null` for border edges.
  final LengthKind? kind;

  /// The per-side type.
  PropType get side => kind == null ? const BorderProp() : LengthProp(kind!);

  static const _sides = ['top', 'right', 'bottom', 'left'];

  @override
  Edges<Object>? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    final isBorderMap =
        side is BorderProp &&
        json is Map &&
        json.keys.any((k) => k == 'width' || k == 'style' || k == 'color');
    if (json is! Map || isBorderMap) {
      final v = side.parse(json, path, ctx);
      return v == null ? null : _edges(v, v, v, v);
    }
    for (final k in json.keys) {
      if (!_sides.contains(k)) {
        ctx.issues.warning(
          '$path.$k',
          'unknown_property',
          'Unknown property "$k" dropped.',
        );
      }
    }
    final e = _edges(
      side.parse(json['top'], '$path.top', ctx),
      side.parse(json['right'], '$path.right', ctx),
      side.parse(json['bottom'], '$path.bottom', ctx),
      side.parse(json['left'], '$path.left', ctx),
    );
    return e.isEmpty ? null : e;
  }

  Edges<Object> _edges(Object? t, Object? r, Object? b, Object? l) {
    if (kind != null) {
      return Edges<Length>(
        top: t as Length?,
        right: r as Length?,
        bottom: b as Length?,
        left: l as Length?,
      );
    }
    return Edges<BorderSpec>(
      top: t as BorderSpec?,
      right: r as BorderSpec?,
      bottom: b as BorderSpec?,
      left: l as BorderSpec?,
    );
  }

  @override
  JsonMap schema() => {
    r'$ref': kind == null ? '#/\$defs/borderEdges' : '#/\$defs/lengthEdges',
  };
}

/// A fixed-length list of [item] values (bullets / numbering per level).
final class ListProp extends PropType {
  /// Creates a list property of exactly [length] items.
  const ListProp(this.item, {this.length = 9});

  /// Item type ([StringProp] or [EnumProp]).
  final PropType item;

  /// Required number of entries.
  final int length;

  @override
  List<String>? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is! List) {
      _wrongType(ctx, path, 'an array', json);
      return null;
    }
    if (json.length != length) {
      ctx.issues.error(
        path,
        'wrong_count',
        'Expected exactly $length entries, got ${json.length}.',
      );
      return null;
    }
    final out = <String>[];
    for (var i = 0; i < json.length; i++) {
      final v = item.parse(json[i], '$path.$i', ctx);
      if (v is! String) {
        if (json[i] == null) {
          ctx.issues.error('$path.$i', 'wrong_type', 'Entry must be set.');
        }
        return null;
      }
      out.add(v);
    }
    return List.unmodifiable(out);
  }

  @override
  JsonMap schema() => {
    'type': 'array',
    'items': item.schema(),
    'minItems': length,
    'maxItems': length,
  };
}

/// OpenType feature tags (`["onum", "liga"]`).
final class FeatureListProp extends PropType {
  /// Creates a feature list property.
  const FeatureListProp();

  static final _tag = RegExp(r'^[a-zA-Z0-9]{4}$');

  @override
  List<String>? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is! List) {
      _wrongType(ctx, path, 'an array of feature tags', json);
      return null;
    }
    final out = <String>[];
    for (var i = 0; i < json.length; i++) {
      final v = json[i];
      if (v is! String || !_tag.hasMatch(v)) {
        ctx.issues.error(
          '$path.$i',
          'invalid_value',
          'OpenType feature tags have 4 characters, e.g. "onum".',
        );
        return null;
      }
      if (!out.contains(v)) out.add(v);
    }
    return List.unmodifiable(out);
  }

  @override
  JsonMap schema() => {
    'type': 'array',
    'items': {'type': 'string', 'pattern': '^[a-zA-Z0-9]{4}\$'},
  };
}

/// A nested object of named properties; parses to a [PropertyBag].
final class ObjectProp extends PropType {
  /// Creates an object property with [fields].
  const ObjectProp(this.fields);

  /// The allowed properties.
  final Map<String, PropType> fields;

  @override
  PropertyBag? parse(Object? json, String path, PropParseContext ctx) {
    if (json == null) return null;
    if (json is! Map) {
      _wrongType(ctx, path, 'an object', json);
      return null;
    }
    final p = path.isEmpty ? '' : '$path.';
    for (final k in json.keys) {
      if (!fields.containsKey(k)) {
        ctx.issues.warning(
          '$p$k',
          'unknown_property',
          'Unknown property "$k" dropped.',
        );
      }
    }
    var child = ctx;
    final familyJson = json['fontFamily'];
    if (fields['fontFamily'] is FontProp && familyJson is String) {
      final ref = FontRef.tryParse(familyJson);
      final family = ref?.family != null
          ? FontRegistry.canonicalName(ref!.family!)
          : ref?.role != null
          ? ctx.roleFamilies[ref!.role!]
          : null;
      if (family != null) child = ctx.copyWith(weightFamily: family);
    }
    final values = <String, Object>{};
    for (final e in fields.entries) {
      if (!json.containsKey(e.key)) continue;
      final v = e.value.parse(json[e.key], '$p${e.key}', child);
      if (v == null) continue;
      if (v is PropertyBag && v.isEmpty) continue;
      values[e.key] = v;
    }
    return PropertyBag(values);
  }

  @override
  JsonMap schema() => {
    'type': 'object',
    'additionalProperties': false,
    'properties': {for (final e in fields.entries) e.key: e.value.schema()},
  };
}

/// An immutable bag of parsed, typed property values.
///
/// Values are [Length], [ColorRef], [FontRef], [BorderSpec],
/// `Edges<Length>`, `Edges<BorderSpec>`, `double`, `int`, `bool`, `String`,
/// `List<String>` or nested [PropertyBag]s. Absent keys inherit.
final class PropertyBag {
  /// Creates a bag over [values] (copied).
  PropertyBag(Map<String, Object> values) : _values = Map.unmodifiable(values);

  const PropertyBag._empty() : _values = const {};

  /// The empty bag.
  static const empty = PropertyBag._empty();

  final Map<String, Object> _values;

  /// The raw typed values.
  Map<String, Object> get values => _values;

  /// Whether no property is set.
  bool get isEmpty => _values.isEmpty;

  /// Whether a property is set.
  bool get isNotEmpty => _values.isNotEmpty;

  /// The set property keys.
  Iterable<String> get keys => _values.keys;

  /// The raw value of [key].
  Object? operator [](String key) => _values[key];

  /// Whether [key] is set.
  bool has(String key) => _values.containsKey(key);

  /// Typed accessors (return `null` when absent or of another type).
  Length? length(String key) => _as<Length>(key);

  /// See [length].
  ColorRef? color(String key) => _as<ColorRef>(key);

  /// See [length].
  FontRef? font(String key) => _as<FontRef>(key);

  /// See [length].
  BorderSpec? border(String key) => _as<BorderSpec>(key);

  /// See [length].
  Edges<Length>? lengthEdges(String key) => _as<Edges<Length>>(key);

  /// See [length].
  Edges<BorderSpec>? borderEdges(String key) => _as<Edges<BorderSpec>>(key);

  /// See [length].
  double? number(String key) => switch (_values[key]) {
    final num n => n.toDouble(),
    _ => null,
  };

  /// See [length].
  int? integer(String key) => _as<int>(key);

  /// See [length].
  bool? boolean(String key) => _as<bool>(key);

  /// See [length].
  String? string(String key) => _as<String>(key);

  /// See [length].
  List<String>? strings(String key) => _as<List<String>>(key);

  /// See [length].
  PropertyBag? bag(String key) => _as<PropertyBag>(key);

  T? _as<T>(String key) {
    final v = _values[key];
    return v is T ? v : null;
  }

  /// A bag with [over]'s values applied on top of this one; nested bags,
  /// borders and edges are merged, everything else replaced.
  PropertyBag merge(PropertyBag? over) {
    if (over == null || over.isEmpty) return this;
    if (isEmpty) return over;
    final out = Map<String, Object>.of(_values);
    for (final e in over._values.entries) {
      final mine = out[e.key];
      final theirs = e.value;
      out[e.key] = switch ((mine, theirs)) {
        (PropertyBag a, PropertyBag b) => a.merge(b),
        (BorderSpec a, BorderSpec b) => a.merge(b),
        (Edges<Length> a, Edges<Length> b) => a.merge(b),
        (Edges<BorderSpec> a, Edges<BorderSpec> b) => a.merge(b),
        _ => theirs,
      };
    }
    return PropertyBag(out);
  }

  /// A copy with [key] set to [value] (or removed when `null`).
  PropertyBag withValue(String key, Object? value) {
    final out = Map<String, Object>.of(_values);
    if (value == null) {
      out.remove(key);
    } else {
      out[key] = value;
    }
    return PropertyBag(out);
  }

  /// The JSON form.
  JsonMap toJson() => {
    for (final e in _values.entries) e.key: propertyValueToJson(e.value),
  };

  @override
  bool operator ==(Object other) =>
      other is PropertyBag &&
      const DeepCollectionEquality().equals(other._values, _values);

  @override
  int get hashCode => const DeepCollectionEquality().hash(_values);

  @override
  String toString() => 'PropertyBag(${toJson()})';
}

/// Encodes a typed property value (see [PropertyBag]) as JSON.
Object? propertyValueToJson(Object? v) => switch (v) {
  null => null,
  Length() => v.toJson(),
  ColorRef() => v.toJson(),
  FontRef() => v.toJson(),
  BorderSpec() => v.toJson(),
  Edges<Object>() => v.toJson(propertyValueToJson),
  num() => normalizeJsonNumber(v),
  bool() || String() => v,
  List<Object?>() => [for (final x in v) propertyValueToJson(x)],
  PropertyBag() => v.toJson(),
  _ => throw ArgumentError.value(v, 'v', 'Not a theme property value'),
};
