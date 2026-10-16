import 'dart:convert';
import 'dart:typed_data';

/// A parameter of an exported function (09 §5.1).
final class ScriptParamInfo {
  /// Creates the info.
  const ScriptParamInfo({
    required this.name,
    required this.type,
    this.optional = false,
    this.doc,
  });

  /// Parameter name.
  final String name;

  /// Declared type (source text), `dynamic` when omitted.
  final String type;

  /// Whether the parameter is optional.
  final bool optional;

  /// `@param` doc.
  final String? doc;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'name': name,
    'type': type,
    'optional': optional,
    'doc': ?doc,
  };

  /// From [toJson].
  static ScriptParamInfo fromJson(Map<String, Object?> j) => ScriptParamInfo(
    name: j['name']! as String,
    type: j['type'] as String? ?? 'dynamic',
    optional: j['optional'] == true,
    doc: j['doc'] as String?,
  );
}

/// Custom function metadata (`@customfunction`).
final class CustomFunctionInfo {
  /// Creates the info.
  const CustomFunctionInfo({
    required this.formulaName,
    this.examples = const [],
    this.returnDoc,
  });

  /// Upper-case name used in formulas.
  final String formulaName;

  /// `@example` lines.
  final List<String> examples;

  /// `@return` doc.
  final String? returnDoc;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'formulaName': formulaName,
    'examples': examples,
    'returns': ?returnDoc,
  };

  /// From [toJson].
  static CustomFunctionInfo fromJson(Map<String, Object?> j) =>
      CustomFunctionInfo(
        formulaName: j['formulaName']! as String,
        examples: [for (final e in (j['examples'] as List? ?? const [])) '$e'],
        returnDoc: j['returns'] as String?,
      );
}

/// An exported (public top-level) function of a build.
final class ScriptFunctionInfo {
  /// Creates the info.
  const ScriptFunctionInfo({
    required this.name,
    required this.library,
    required this.line,
    this.endLine,
    this.params = const [],
    this.returns = 'dynamic',
    this.isAsync = false,
    this.doc,
    this.customFunction,
    this.runnable = true,
  });

  /// Function name.
  final String name;

  /// Library URI (`package:script/main.dart`).
  final String library;

  /// 1-based line of the declaration.
  final int line;

  /// 1-based last line of the declaration.
  final int? endLine;

  /// Parameters.
  final List<ScriptParamInfo> params;

  /// Return type (source text).
  final String returns;

  /// Whether the function is `async`.
  final bool isAsync;

  /// First paragraph of the doc comment.
  final String? doc;

  /// Custom function metadata.
  final CustomFunctionInfo? customFunction;

  /// No required parameters: runnable from menus, the editor and triggers.
  final bool runnable;

  /// File name (`main.dart`).
  String get file => library.substring(library.lastIndexOf('/') + 1);

  /// JSON form.
  Map<String, Object?> toJson() => {
    'name': name,
    'library': library,
    'line': line,
    'endLine': ?endLine,
    'params': [for (final p in params) p.toJson()],
    'returns': returns,
    'async': isAsync,
    'doc': ?doc,
    'customFunction': customFunction?.toJson(),
    'runnable': runnable,
  };

  /// From [toJson].
  static ScriptFunctionInfo fromJson(Map<String, Object?> j) =>
      ScriptFunctionInfo(
        name: j['name']! as String,
        library: j['library']! as String,
        line: j['line'] as int? ?? 0,
        endLine: j['endLine'] as int?,
        params: [
          for (final p in (j['params'] as List? ?? const []))
            ScriptParamInfo.fromJson((p as Map).cast()),
        ],
        returns: j['returns'] as String? ?? 'dynamic',
        isAsync: j['async'] == true,
        doc: j['doc'] as String?,
        customFunction: j['customFunction'] == null
            ? null
            : CustomFunctionInfo.fromJson((j['customFunction']! as Map).cast()),
        runnable: j['runnable'] != false,
      );
}

/// Simple trigger names (09 §5).
const simpleTriggerNames = [
  'onOpen',
  'onEdit',
  'onSelectionChange',
  'onChange',
];

/// `ScriptBuild.exportsJson` (09 §5.1) plus line tables for stack traces
/// (patch DE-1; stored in the exports instead of a separate positions file).
final class ScriptExports {
  /// Creates exports.
  const ScriptExports({
    required this.apiVersion,
    this.functions = const [],
    this.triggers = const {},
    this.scopes = const [],
    this.customFunctionScopes = const [],
    this.warnings = 0,
    this.lineStarts = const {},
  });

  /// Empty exports (no build).
  static const empty = ScriptExports(apiVersion: 1);

  /// API version the build was compiled against.
  final int apiVersion;

  /// Exported functions.
  final List<ScriptFunctionInfo> functions;

  /// Simple trigger name → library (or null).
  final Map<String, String?> triggers;

  /// Scopes the build needs (09 §11.1).
  final List<String> scopes;

  /// Scopes reachable from custom functions.
  final List<String> customFunctionScopes;

  /// Number of warnings of the build.
  final int warnings;

  /// File name → offsets of line starts.
  final Map<String, List<int>> lineStarts;

  /// The function [name], or null.
  ScriptFunctionInfo? function(String name) {
    for (final f in functions) {
      if (f.name == name) return f;
    }
    return null;
  }

  /// Custom functions by formula name.
  Map<String, ScriptFunctionInfo> get customFunctions => {
    for (final f in functions)
      if (f.customFunction != null) f.customFunction!.formulaName: f,
  };

  /// Functions that menus, the editor and triggers can run.
  List<ScriptFunctionInfo> get runnableFunctions => [
    for (final f in functions)
      if (f.runnable && f.customFunction == null) f,
  ];

  /// Whether the simple trigger [name] exists.
  bool hasTrigger(String name) => triggers[name] != null;

  /// 1-based (line, column) of [offset] in [file].
  (int, int)? position(String file, int offset) {
    final starts = lineStarts[file];
    if (starts == null || starts.isEmpty || offset < 0) return null;
    var lo = 0, hi = starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return (lo + 1, offset - starts[lo] + 1);
  }

  /// JSON form (`exportsJson`).
  Map<String, Object?> toJson() => {
    'apiVersion': apiVersion,
    'functions': [for (final f in functions) f.toJson()],
    'triggers': triggers,
    'scopes': scopes,
    'customFunctionScopes': customFunctionScopes,
    'warnings': warnings,
    'lineStarts': lineStarts,
  };

  /// Encoded [toJson].
  String encode() => jsonEncode(toJson());

  /// From [toJson].
  static ScriptExports fromJson(Map<String, Object?> j) => ScriptExports(
    apiVersion: j['apiVersion'] as int? ?? 1,
    functions: [
      for (final f in (j['functions'] as List? ?? const []))
        ScriptFunctionInfo.fromJson((f as Map).cast()),
    ],
    triggers: {
      for (final e in ((j['triggers'] as Map?) ?? const {}).entries)
        '${e.key}': e.value as String?,
    },
    scopes: [for (final s in (j['scopes'] as List? ?? const [])) '$s'],
    customFunctionScopes: [
      for (final s in (j['customFunctionScopes'] as List? ?? const [])) '$s',
    ],
    warnings: j['warnings'] as int? ?? 0,
    lineStarts: {
      for (final e in ((j['lineStarts'] as Map?) ?? const {}).entries)
        '${e.key}': [for (final o in e.value as List) o as int],
    },
  );

  /// Parses `exportsJson`.
  static ScriptExports decode(String json) =>
      fromJson((jsonDecode(json) as Map).cast());
}

/// A runnable build: bytecode plus exports (from `ScriptBuild.lastGood*`).
final class ScriptProgram {
  /// Creates a program.
  const ScriptProgram({
    required this.buildHash,
    required this.bytecode,
    required this.exports,
  });

  /// `ScriptBuild.sourceHash` of the build.
  final String buildHash;

  /// EVC bytecode.
  final Uint8List bytecode;

  /// Exports and line tables.
  final ScriptExports exports;
}
