import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'api_index.dart';
import 'api_source.dart';

/// Builds the [ApiIndex] from the API source (`wonkyApiSource`) with the
/// analyzer: public classes, their public members with signatures and doc
/// comments, and public top-level functions. Used by
/// `tool/gen_api_index.dart` (server/tooling only: imports the analyzer).
abstract final class ApiIndexBuilder {
  /// Builds the index of [source] (default: the API source).
  static ApiIndex build([String source = wonkyApiSource]) {
    final unit = parseString(content: source, throwIfDiagnostics: false).unit;
    final classes = <ApiClass>[_cellError];
    final functions = <ApiMember>[];
    for (final d in unit.declarations) {
      if (d is ClassDeclaration) {
        final name = d.name.lexeme;
        if (name.startsWith('_')) continue;
        classes.add(
          ApiClass(
            name: name,
            superclass: d.extendsClause?.superclass.name.lexeme,
            doc: _doc(d.documentationComment),
            members: _members(d),
          ),
        );
      } else if (d is FunctionDeclaration) {
        final name = d.name.lexeme;
        if (name.startsWith('_') || name.startsWith('wonky')) continue;
        functions.add(
          ApiMember(
            name: name,
            kind: ApiMemberKind.function,
            type: d.returnType?.toSource() ?? 'void',
            params: _params(d.functionExpression.parameters, const {}),
            doc: _doc(d.documentationComment),
          ),
        );
      }
    }
    return ApiIndex(classes: classes, functions: functions);
  }

  /// `CellError` is a bridged class of `package:wonky/src/host.dart`.
  static const _cellError = ApiClass(
    name: 'CellError',
    doc:
        'A cell error value such as `#N/A` or `#DIV/0!` (read from cells, '
        'returned by custom functions).',
    members: [
      ApiMember(
        name: '',
        kind: ApiMemberKind.constructor,
        type: 'CellError',
        params: [
          ApiParam(name: 'code', type: 'String'),
          ApiParam(name: 'message', type: 'String?', optional: true),
        ],
        doc: 'An error value with [code] (`#N/A`, `#VALUE!`, …).',
      ),
      ApiMember(
        name: 'code',
        kind: ApiMemberKind.getter,
        type: 'String',
        doc: 'The error code, e.g. `#N/A`.',
      ),
      ApiMember(
        name: 'message',
        kind: ApiMemberKind.getter,
        type: 'String?',
        doc: 'The explanation shown in the cell tooltip.',
      ),
    ],
  );

  static List<ApiMember> _members(ClassDeclaration d) {
    final className = d.name.lexeme;
    final fieldTypes = <String, String>{};
    for (final m in d.members) {
      if (m is FieldDeclaration) {
        for (final v in m.fields.variables) {
          fieldTypes[v.name.lexeme] = m.fields.type?.toSource() ?? 'Object?';
        }
      }
    }
    final out = <ApiMember>[];
    for (final m in d.members) {
      switch (m) {
        case ConstructorDeclaration():
          final name = m.name?.lexeme ?? '';
          if (name.startsWith('_')) continue;
          out.add(
            ApiMember(
              name: name,
              kind: ApiMemberKind.constructor,
              type: className,
              params: _params(m.parameters, fieldTypes),
              doc: _doc(m.documentationComment),
            ),
          );
        case FieldDeclaration():
          final type = m.fields.type?.toSource() ?? 'Object?';
          final readOnly = m.fields.isFinal || m.fields.isConst;
          for (final v in m.fields.variables) {
            final name = v.name.lexeme;
            if (name.startsWith('_')) continue;
            out.add(
              ApiMember(
                name: name,
                kind: readOnly ? ApiMemberKind.getter : ApiMemberKind.field,
                type: type,
                isStatic: m.isStatic,
                doc: _doc(m.documentationComment),
              ),
            );
          }
        case MethodDeclaration():
          final name = m.name.lexeme;
          if (name.startsWith('_') || m.isOperator) continue;
          if (name == 'toString' || name == 'hashCode') continue;
          final ApiMemberKind kind;
          var type = m.returnType?.toSource() ?? 'dynamic';
          if (m.isGetter) {
            kind = ApiMemberKind.getter;
          } else if (m.isSetter) {
            kind = ApiMemberKind.setter;
            final p = m.parameters?.parameters.firstOrNull;
            type = p == null ? 'Object?' : _paramType(p, fieldTypes);
          } else {
            kind = ApiMemberKind.method;
          }
          out.add(
            ApiMember(
              name: name,
              kind: kind,
              type: type,
              isStatic: m.isStatic,
              params: kind == ApiMemberKind.method
                  ? _params(m.parameters, fieldTypes)
                  : const [],
              doc: _doc(m.documentationComment),
            ),
          );
      }
    }
    // A getter followed by a setter of the same name reads as a field.
    final merged = <ApiMember>[];
    for (final m in out) {
      if (m.kind == ApiMemberKind.setter) {
        final i = merged.indexWhere(
          (x) => x.kind == ApiMemberKind.getter && x.name == m.name,
        );
        if (i >= 0) {
          final g = merged[i];
          merged[i] = ApiMember(
            name: g.name,
            kind: ApiMemberKind.field,
            type: g.type,
            isStatic: g.isStatic,
            doc: g.doc.isNotEmpty ? g.doc : m.doc,
          );
          continue;
        }
      }
      merged.add(m);
    }
    return merged;
  }

  static List<ApiParam> _params(
    FormalParameterList? list,
    Map<String, String> fieldTypes,
  ) => [
    for (final p in list?.parameters ?? const <FormalParameter>[])
      if (!(p.name?.lexeme.startsWith('_') ?? true))
        ApiParam(
          name: p.name!.lexeme,
          type: _paramType(p, fieldTypes),
          named: p.isNamed,
          optional: p.isOptional,
          defaultValue: p is DefaultFormalParameter
              ? p.defaultValue?.toSource()
              : null,
        ),
  ];

  static String _paramType(FormalParameter p, Map<String, String> fields) {
    final inner = p is DefaultFormalParameter ? p.parameter : p;
    return switch (inner) {
      SimpleFormalParameter(:final type) => type?.toSource() ?? 'Object?',
      FieldFormalParameter(:final type, :final name) =>
        type?.toSource() ?? fields[name.lexeme] ?? 'Object?',
      SuperFormalParameter(:final type) => type?.toSource() ?? 'Object?',
      _ => 'Object?',
    };
  }

  static String _doc(Comment? c) {
    if (c == null) return '';
    final lines = [
      for (final t in c.tokens)
        t.lexeme.startsWith('/// ')
            ? t.lexeme.substring(4)
            : t.lexeme.replaceFirst(RegExp('^///'), ''),
    ];
    return lines.join('\n').trim();
  }
}
