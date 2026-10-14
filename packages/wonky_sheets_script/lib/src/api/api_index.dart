import 'dart:convert';

import 'api_index_data.dart';

/// Kind of an [ApiMember].
enum ApiMemberKind {
  /// A constructor (`ConditionalFormatRuleBuilder()`).
  constructor,

  /// A method.
  method,

  /// A getter (or a final field).
  getter,

  /// A setter.
  setter,

  /// A field with a getter and a setter.
  field,

  /// A top-level function.
  function;

  /// Whether the member is read like a property.
  bool get isProperty => this == getter || this == field;
}

/// A parameter of an [ApiMember].
final class ApiParam {
  /// Creates a parameter.
  const ApiParam({
    required this.name,
    required this.type,
    this.named = false,
    this.optional = false,
    this.defaultValue,
  });

  /// Decodes [json].
  factory ApiParam.fromJson(Map<String, Object?> json) => ApiParam(
    name: json['name']! as String,
    type: json['type']! as String,
    named: json['named'] == true,
    optional: json['optional'] == true,
    defaultValue: json['default'] as String?,
  );

  /// Parameter name.
  final String name;

  /// Type as written (`String`, `List<List<Object?>>`).
  final String type;

  /// Named parameter.
  final bool named;

  /// Optional (named without `required`, or in `[...]`).
  final bool optional;

  /// Default value source, if any.
  final String? defaultValue;

  /// JSON.
  Map<String, Object?> toJson() => {
    'name': name,
    'type': type,
    if (named) 'named': true,
    if (optional) 'optional': true,
    'default': ?defaultValue,
  };

  /// `String name`, `{bool ascending = true}` parts without braces.
  String get source =>
      '${named && !optional ? 'required ' : ''}$type $name'
      '${defaultValue == null ? '' : ' = $defaultValue'}';
}

/// A member of an [ApiClass] (or a top-level function).
final class ApiMember {
  /// Creates a member.
  const ApiMember({
    required this.name,
    required this.kind,
    required this.type,
    this.isStatic = false,
    this.params = const [],
    this.doc = '',
  });

  /// Decodes [json].
  factory ApiMember.fromJson(Map<String, Object?> json) => ApiMember(
    name: json['name']! as String,
    kind: ApiMemberKind.values.byName(json['kind']! as String),
    type: json['type'] as String? ?? '',
    isStatic: json['static'] == true,
    params: [
      for (final p in (json['params'] as List?) ?? const [])
        ApiParam.fromJson((p as Map).cast()),
    ],
    doc: json['doc'] as String? ?? '',
  );

  /// Member name (empty for an unnamed constructor).
  final String name;

  /// Kind.
  final ApiMemberKind kind;

  /// Return type (methods, getters, functions), value type (fields,
  /// setters) or the class (constructors).
  final String type;

  /// Static member.
  final bool isStatic;

  /// Parameters (methods, constructors, functions).
  final List<ApiParam> params;

  /// Doc comment (Markdown, without `///`).
  final String doc;

  /// First sentence/paragraph of [doc].
  String get summary {
    final para = doc.split('\n\n').first.replaceAll('\n', ' ').trim();
    return para;
  }

  /// Whether the member has parameters a caller must pass.
  bool get hasRequiredParams =>
      params.any((p) => !p.optional && !(p.named && p.defaultValue != null));

  /// The signature as shown in completions and docs:
  /// `Range getRange(String a1Notation)`, `String get name`.
  String signature([String? className]) {
    String list() {
      final positional = params.where((p) => !p.named && !p.optional);
      final optional = params.where((p) => !p.named && p.optional);
      final named = params.where((p) => p.named);
      final parts = [
        for (final p in positional) p.source,
        if (optional.isNotEmpty)
          '[${optional.map((p) => p.source).join(', ')}]',
        if (named.isNotEmpty) '{${named.map((p) => p.source).join(', ')}}',
      ];
      return parts.join(', ');
    }

    final prefix = isStatic ? 'static ' : '';
    return switch (kind) {
      ApiMemberKind.constructor =>
        '${className ?? type}${name.isEmpty ? '' : '.$name'}(${list()})',
      ApiMemberKind.getter => '$prefix$type get $name',
      ApiMemberKind.setter => '${prefix}set $name($type value)',
      ApiMemberKind.field => '$prefix$type $name',
      ApiMemberKind.method ||
      ApiMemberKind.function => '$prefix$type $name(${list()})',
    };
  }

  /// JSON.
  Map<String, Object?> toJson() => {
    'name': name,
    'kind': kind.name,
    'type': type,
    if (isStatic) 'static': true,
    if (params.isNotEmpty) 'params': [for (final p in params) p.toJson()],
    if (doc.isNotEmpty) 'doc': doc,
  };
}

/// A class of the Wonky Script API.
final class ApiClass {
  /// Creates a class.
  const ApiClass({
    required this.name,
    this.superclass,
    this.doc = '',
    this.members = const [],
  });

  /// Decodes [json].
  factory ApiClass.fromJson(Map<String, Object?> json) => ApiClass(
    name: json['name']! as String,
    superclass: json['extends'] as String?,
    doc: json['doc'] as String? ?? '',
    members: [
      for (final m in (json['members'] as List?) ?? const [])
        ApiMember.fromJson((m as Map).cast()),
    ],
  );

  /// Class name.
  final String name;

  /// Superclass in the API, if any.
  final String? superclass;

  /// Doc comment.
  final String doc;

  /// Public members in source order.
  final List<ApiMember> members;

  /// First paragraph of [doc].
  String get summary => doc.split('\n\n').first.replaceAll('\n', ' ').trim();

  /// JSON.
  Map<String, Object?> toJson() => {
    'name': name,
    'extends': ?superclass,
    if (doc.isNotEmpty) 'doc': doc,
    'members': [for (final m in members) m.toJson()],
  };
}

/// The index of the Wonky Script API (`api_index.json`, 09 §14.4): classes,
/// members, signatures and docs, generated from the API source by
/// `tool/gen_api_index.dart`. Feeds the script editor's autocomplete, hover
/// docs and *Help › Script API reference*.
final class ApiIndex {
  /// Creates an index.
  ApiIndex({required this.classes, this.functions = const []})
    : _byName = {for (final c in classes) c.name: c};

  /// Decodes the JSON text of `api_index.json`.
  factory ApiIndex.decode(String json) {
    final m = (jsonDecode(json) as Map).cast<String, Object?>();
    return ApiIndex(
      classes: [
        for (final c in (m['classes'] as List?) ?? const [])
          ApiClass.fromJson((c as Map).cast()),
      ],
      functions: [
        for (final f in (m['functions'] as List?) ?? const [])
          ApiMember.fromJson((f as Map).cast()),
      ],
    );
  }

  /// The index of this build of the API.
  static final ApiIndex standard = ApiIndex.decode(wonkyApiIndexJson);

  /// Classes in source order.
  final List<ApiClass> classes;

  /// Public top-level functions.
  final List<ApiMember> functions;

  final Map<String, ApiClass> _byName;

  /// The class [name], or null.
  ApiClass? classNamed(String name) => _byName[name];

  /// Members of [className] including inherited ones (own members first).
  List<ApiMember> membersOf(String className, {bool? statics}) {
    final out = <ApiMember>[];
    final seen = <String>{};
    String? c = className;
    while (c != null) {
      final cls = _byName[c];
      if (cls == null) break;
      for (final m in cls.members) {
        if (statics != null && m.isStatic != statics) continue;
        if (m.kind == ApiMemberKind.constructor) continue;
        if (seen.add(
          '${m.kind == ApiMemberKind.setter ? 'set:' : ''}${m.name}',
        )) {
          out.add(m);
        }
      }
      c = cls.superclass;
    }
    return out;
  }

  /// The member [name] of [className] (getters before setters), or null.
  ApiMember? member(String className, String name) {
    String? c = className;
    ApiMember? setter;
    while (c != null) {
      final cls = _byName[c];
      if (cls == null) break;
      for (final m in cls.members) {
        if (m.name != name) continue;
        if (m.kind == ApiMemberKind.setter) {
          setter ??= m;
        } else if (m.kind != ApiMemberKind.constructor) {
          return m;
        }
      }
      c = cls.superclass;
    }
    return setter;
  }

  /// JSON text (what the generator writes).
  String encode() => const JsonEncoder.withIndent(' ').convert({
    'version': 1,
    'classes': [for (final c in classes) c.toJson()],
    'functions': [for (final f in functions) f.toJson()],
  });
}
