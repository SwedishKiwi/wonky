/// A small, immutable JSON-schema model (draft 2020-12 subset) used to describe
/// command arguments and MCP tool inputs/outputs.
///
/// Schemas serialize with [toJson] (for MCP `tools/list`, `ui.list_commands`
/// and the AI assistant) and validate decoded JSON with [validate].
sealed class JsonSchema {
  const JsonSchema({this.description, this.title});

  /// Human/LLM-facing description.
  final String? description;

  /// Optional short title.
  final String? title;

  /// `{"type": "object", …}`.
  const factory JsonSchema.object({
    Map<String, JsonSchema> properties,
    List<String> required,
    bool additionalProperties,
    String? description,
    String? title,
  }) = ObjectSchema;

  /// `{"type": "string", …}`.
  const factory JsonSchema.string({
    List<String>? enumValues,
    int? minLength,
    int? maxLength,
    String? pattern,
    String? format,
    String? defaultValue,
    String? description,
    String? title,
  }) = StringSchema;

  /// `{"type": "integer", …}`.
  const factory JsonSchema.integer({
    int? minimum,
    int? maximum,
    int? defaultValue,
    String? description,
    String? title,
  }) = IntegerSchema;

  /// `{"type": "number", …}`.
  const factory JsonSchema.number({
    num? minimum,
    num? maximum,
    num? defaultValue,
    String? description,
    String? title,
  }) = NumberSchema;

  /// `{"type": "boolean"}`.
  const factory JsonSchema.boolean({
    bool? defaultValue,
    String? description,
    String? title,
  }) = BooleanSchema;

  /// `{"type": "array", "items": …}`.
  const factory JsonSchema.array(
    JsonSchema items, {
    int? minItems,
    int? maxItems,
    String? description,
    String? title,
  }) = ArraySchema;

  /// Accepts `null` in addition to [inner].
  const factory JsonSchema.nullable(JsonSchema inner) = NullableSchema;

  /// `{"anyOf": [...]}`.
  const factory JsonSchema.anyOf(
    List<JsonSchema> options, {
    String? description,
    String? title,
  }) = AnyOfSchema;

  /// Accepts any value (`{}`).
  const factory JsonSchema.any({String? description, String? title}) =
      AnySchema;

  /// The empty-object schema used by commands without arguments.
  static const JsonSchema empty = ObjectSchema();

  /// The JSON form of this schema.
  Map<String, Object?> toJson();

  /// Validates [value]; returns all violations (empty when valid).
  List<JsonSchemaViolation> validate(Object? value, [String path = r'$']);

  /// Whether [value] is valid.
  bool accepts(Object? value) => validate(value).isEmpty;

  Map<String, Object?> _meta() => {
    if (title != null) 'title': title,
    if (description != null) 'description': description,
  };
}

/// One validation failure.
class JsonSchemaViolation {
  const JsonSchemaViolation(this.path, this.message);

  /// JSONPath-like location (`$.rows[2].name`).
  final String path;

  /// What is wrong.
  final String message;

  @override
  String toString() => '$path: $message';

  @override
  bool operator ==(Object other) =>
      other is JsonSchemaViolation &&
      other.path == path &&
      other.message == message;

  @override
  int get hashCode => Object.hash(path, message);
}

/// Object schema.
class ObjectSchema extends JsonSchema {
  const ObjectSchema({
    this.properties = const {},
    this.required = const [],
    this.additionalProperties = false,
    super.description,
    super.title,
  });

  final Map<String, JsonSchema> properties;
  final List<String> required;
  final bool additionalProperties;

  @override
  Map<String, Object?> toJson() => {
    'type': 'object',
    ..._meta(),
    'properties': {
      for (final e in properties.entries) e.key: e.value.toJson(),
    },
    if (required.isNotEmpty) 'required': required,
    'additionalProperties': additionalProperties,
  };

  @override
  List<JsonSchemaViolation> validate(Object? value, [String path = r'$']) {
    if (value is! Map) {
      return [JsonSchemaViolation(path, 'expected an object')];
    }
    final out = <JsonSchemaViolation>[];
    for (final key in required) {
      if (!value.containsKey(key)) {
        out.add(JsonSchemaViolation(path, 'missing required property "$key"'));
      }
    }
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        out.add(JsonSchemaViolation(path, 'property names must be strings'));
        continue;
      }
      final schema = properties[key];
      if (schema == null) {
        if (!additionalProperties) {
          out.add(JsonSchemaViolation(path, 'unknown property "$key"'));
        }
        continue;
      }
      out.addAll(schema.validate(entry.value, '$path.$key'));
    }
    return out;
  }
}

/// String schema.
class StringSchema extends JsonSchema {
  const StringSchema({
    this.enumValues,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.format,
    this.defaultValue,
    super.description,
    super.title,
  });

  final List<String>? enumValues;
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final String? format;
  final String? defaultValue;

  @override
  Map<String, Object?> toJson() => {
    'type': 'string',
    ..._meta(),
    if (enumValues != null) 'enum': enumValues,
    if (minLength != null) 'minLength': minLength,
    if (maxLength != null) 'maxLength': maxLength,
    if (pattern != null) 'pattern': pattern,
    if (format != null) 'format': format,
    if (defaultValue != null) 'default': defaultValue,
  };

  @override
  List<JsonSchemaViolation> validate(Object? value, [String path = r'$']) {
    if (value is! String) return [JsonSchemaViolation(path, 'expected a string')];
    final out = <JsonSchemaViolation>[];
    if (enumValues != null && !enumValues!.contains(value)) {
      out.add(
        JsonSchemaViolation(path, 'must be one of ${enumValues!.join(', ')}'),
      );
    }
    if (minLength != null && value.length < minLength!) {
      out.add(JsonSchemaViolation(path, 'shorter than $minLength'));
    }
    if (maxLength != null && value.length > maxLength!) {
      out.add(JsonSchemaViolation(path, 'longer than $maxLength'));
    }
    if (pattern != null && !RegExp(pattern!).hasMatch(value)) {
      out.add(JsonSchemaViolation(path, 'does not match $pattern'));
    }
    if (format == 'uuid' &&
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(value)) {
      out.add(JsonSchemaViolation(path, 'not a uuid'));
    }
    if (format == 'date-time' && DateTime.tryParse(value) == null) {
      out.add(JsonSchemaViolation(path, 'not a date-time'));
    }
    return out;
  }
}

/// Integer schema.
class IntegerSchema extends JsonSchema {
  const IntegerSchema({
    this.minimum,
    this.maximum,
    this.defaultValue,
    super.description,
    super.title,
  });

  final int? minimum;
  final int? maximum;
  final int? defaultValue;

  @override
  Map<String, Object?> toJson() => {
    'type': 'integer',
    ..._meta(),
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    if (defaultValue != null) 'default': defaultValue,
  };

  @override
  List<JsonSchemaViolation> validate(Object? value, [String path = r'$']) {
    final isInt = value is int || (value is double && value == value.truncate());
    if (!isInt) return [JsonSchemaViolation(path, 'expected an integer')];
    final v = (value as num).toInt();
    return [
      if (minimum != null && v < minimum!)
        JsonSchemaViolation(path, 'less than $minimum'),
      if (maximum != null && v > maximum!)
        JsonSchemaViolation(path, 'greater than $maximum'),
    ];
  }
}

/// Number schema.
class NumberSchema extends JsonSchema {
  const NumberSchema({
    this.minimum,
    this.maximum,
    this.defaultValue,
    super.description,
    super.title,
  });

  final num? minimum;
  final num? maximum;
  final num? defaultValue;

  @override
  Map<String, Object?> toJson() => {
    'type': 'number',
    ..._meta(),
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    if (defaultValue != null) 'default': defaultValue,
  };

  @override
  List<JsonSchemaViolation> validate(Object? value, [String path = r'$']) {
    if (value is! num) return [JsonSchemaViolation(path, 'expected a number')];
    return [
      if (minimum != null && value < minimum!)
        JsonSchemaViolation(path, 'less than $minimum'),
      if (maximum != null && value > maximum!)
        JsonSchemaViolation(path, 'greater than $maximum'),
    ];
  }
}

/// Boolean schema.
class BooleanSchema extends JsonSchema {
  const BooleanSchema({this.defaultValue, super.description, super.title});

  final bool? defaultValue;

  @override
  Map<String, Object?> toJson() => {
    'type': 'boolean',
    ..._meta(),
    if (defaultValue != null) 'default': defaultValue,
  };

  @override
  List<JsonSchemaViolation> validate(Object? value, [String path = r'$']) =>
      value is bool ? const [] : [JsonSchemaViolation(path, 'expected a boolean')];
}

/// Array schema.
class ArraySchema extends JsonSchema {
  const ArraySchema(
    this.items, {
    this.minItems,
    this.maxItems,
    super.description,
    super.title,
  });

  final JsonSchema items;
  final int? minItems;
  final int? maxItems;

  @override
  Map<String, Object?> toJson() => {
    'type': 'array',
    ..._meta(),
    'items': items.toJson(),
    if (minItems != null) 'minItems': minItems,
    if (maxItems != null) 'maxItems': maxItems,
  };

  @override
  List<JsonSchemaViolation> validate(Object? value, [String path = r'$']) {
    if (value is! List) return [JsonSchemaViolation(path, 'expected an array')];
    final out = <JsonSchemaViolation>[
      if (minItems != null && value.length < minItems!)
        JsonSchemaViolation(path, 'fewer than $minItems items'),
      if (maxItems != null && value.length > maxItems!)
        JsonSchemaViolation(path, 'more than $maxItems items'),
    ];
    for (var i = 0; i < value.length; i++) {
      out.addAll(items.validate(value[i], '$path[$i]'));
    }
    return out;
  }
}

/// `inner` or `null`.
class NullableSchema extends JsonSchema {
  const NullableSchema(this.inner)
    : super(description: null, title: null);

  final JsonSchema inner;

  @override
  String? get description => inner.description;

  @override
  Map<String, Object?> toJson() {
    final json = Map<String, Object?>.of(inner.toJson());
    final type = json['type'];
    if (type is String) {
      json['type'] = [type, 'null'];
      return json;
    }
    return {
      'anyOf': [json, {'type': 'null'}],
    };
  }

  @override
  List<JsonSchemaViolation> validate(Object? value, [String path = r'$']) =>
      value == null ? const [] : inner.validate(value, path);
}

/// Any of several schemas.
class AnyOfSchema extends JsonSchema {
  const AnyOfSchema(this.options, {super.description, super.title});

  final List<JsonSchema> options;

  @override
  Map<String, Object?> toJson() => {
    ..._meta(),
    'anyOf': [for (final o in options) o.toJson()],
  };

  @override
  List<JsonSchemaViolation> validate(Object? value, [String path = r'$']) {
    for (final o in options) {
      if (o.validate(value, path).isEmpty) return const [];
    }
    return [JsonSchemaViolation(path, 'matches none of the allowed shapes')];
  }
}

/// Accepts any value.
class AnySchema extends JsonSchema {
  const AnySchema({super.description, super.title});

  @override
  Map<String, Object?> toJson() => {..._meta()};

  @override
  List<JsonSchemaViolation> validate(Object? value, [String path = r'$']) =>
      const [];
}
