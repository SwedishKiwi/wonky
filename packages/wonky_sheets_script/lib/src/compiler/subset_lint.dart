import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'diagnostics.dart';

/// Imports scripts may use (09 §4).
const allowedDartImports = {
  'dart:core',
  'dart:math',
  'dart:convert',
  'dart:collection',
  'dart:async',
};

/// The "Wonky Dart" subset lint (09 §9.3): reports constructs dart_eval does
/// not support with friendly messages before the compiler sees them.
final class SubsetLint extends RecursiveAstVisitor<void> {
  /// Creates the lint for [file]; [projectFiles] are the importable files.
  SubsetLint({
    required this.file,
    required this.lineInfo,
    required this.projectFiles,
    this.isBuiltinFunction,
  });

  /// File name (`main.dart`).
  final String file;

  /// Line table of the file.
  final LineInfo lineInfo;

  /// File names of the project.
  final Set<String> projectFiles;

  /// Whether a formula name is a built-in function.
  final bool Function(String upperName)? isBuiltinFunction;

  /// Findings.
  final List<ScriptDiagnostic> diagnostics = [];

  int _loopDepth = 0;

  void _report(
    AstNode node,
    String code,
    String message, {
    String? fix,
    DiagnosticSeverity severity = DiagnosticSeverity.error,
    int? offset,
    int? length,
  }) {
    final start = offset ?? node.offset;
    final end = start + (length ?? node.length);
    final s = lineInfo.getLocation(start);
    final e = lineInfo.getLocation(end);
    diagnostics.add(
      ScriptDiagnostic(
        severity: severity,
        code: code,
        message: message,
        file: file,
        line: s.lineNumber,
        column: s.columnNumber,
        endLine: e.lineNumber,
        endColumn: e.columnNumber,
        fix: fix,
      ),
    );
  }

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue ?? '';
    if (node.configurations.isNotEmpty || node.deferredKeyword != null) {
      _report(
        node,
        'wonky_import',
        'Conditional and deferred imports are not supported in scripts.',
      );
    } else if (uri == 'dart:isolate') {
      _report(
        node,
        'wonky_isolate',
        'Isolates are not available in scripts.',
        fix: 'Scripts run in their own sandbox; remove the import.',
      );
    } else if (uri.startsWith('dart:')) {
      if (!allowedDartImports.contains(uri)) {
        _report(
          node,
          'wonky_import',
          'Import not allowed in scripts: $uri',
          fix:
              'Allowed: ${allowedDartImports.join(', ')}, '
              'package:wonky/wonky.dart and files of this project.',
        );
      }
    } else if (uri.startsWith('package:')) {
      final ok =
          uri == 'package:wonky/wonky.dart' ||
          (uri.startsWith('package:script/') &&
              projectFiles.contains(uri.substring('package:script/'.length)));
      if (!ok) {
        _report(node, 'wonky_import', 'Import not allowed in scripts: $uri');
      }
    } else if (!projectFiles.contains(uri)) {
      _report(node, 'wonky_import', 'There is no file "$uri" in this project.');
    }
    super.visitImportDirective(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    final uri = node.uri.stringValue ?? '';
    if (!projectFiles.contains(uri) && uri != 'package:wonky/wonky.dart') {
      _report(node, 'wonky_import', 'Export not allowed in scripts: $uri');
    }
    super.visitExportDirective(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _report(
      node,
      'wonky_mixin',
      'Mixins are not supported in Wonky scripts.',
      fix: 'Use a base class or composition instead.',
      offset: node.mixinKeyword.offset,
      length: node.name.end - node.mixinKeyword.offset,
    );
    super.visitMixinDeclaration(node);
  }

  @override
  void visitWithClause(WithClause node) {
    _report(
      node,
      'wonky_mixin',
      'Mixins (`with`) are not supported in Wonky scripts.',
      fix: 'Use a base class or composition instead.',
    );
    super.visitWithClause(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    _report(
      node,
      'wonky_extension',
      'Extension methods are not supported in Wonky scripts.',
      fix: 'Use a top-level function instead.',
    );
    super.visitExtensionDeclaration(node);
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    _report(
      node,
      'wonky_extension',
      'Extension types are not supported in Wonky scripts.',
      fix: 'Use a class instead.',
    );
    super.visitExtensionTypeDeclaration(node);
  }

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    final late = node.lateKeyword;
    if (late != null) {
      _report(
        node,
        'wonky_late',
        '`late` is not supported in Wonky scripts.',
        fix: 'Make the variable nullable and initialize it before use.',
        offset: late.offset,
        length: late.length,
      );
    }
    super.visitVariableDeclarationList(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    _report(
      node,
      'wonky_typedef',
      'Typedefs are not supported in Wonky scripts.',
      fix: 'Write the function type out where you use it.',
    );
    super.visitGenericTypeAlias(node);
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    _report(
      node,
      'wonky_typedef',
      'Typedefs are not supported in Wonky scripts.',
      fix: 'Write the function type out where you use it.',
    );
    super.visitFunctionTypeAlias(node);
  }

  @override
  void visitBlockFunctionBody(BlockFunctionBody node) {
    if (node.isGenerator) {
      _report(
        node,
        'wonky_generator',
        'Generators (`sync*`, `async*`) are not supported in Wonky scripts.',
        fix: 'Build and return a List instead.',
        offset: node.keyword?.offset ?? node.offset,
        length:
            (node.star?.end ?? node.offset + 1) -
            (node.keyword?.offset ?? node.offset),
      );
    }
    super.visitBlockFunctionBody(node);
  }

  @override
  void visitYieldStatement(YieldStatement node) {
    _report(
      node,
      'wonky_generator',
      '`yield` is not supported in Wonky scripts.',
      fix: 'Add the value to a List and return the list.',
    );
    super.visitYieldStatement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    if (node.awaitKeyword != null) {
      _report(
        node,
        'wonky_await_for',
        '`await for` is not supported in Wonky scripts.',
        offset: node.awaitKeyword!.offset,
        length: node.forKeyword.end - node.awaitKeyword!.offset,
      );
    }
    _loopDepth++;
    super.visitForStatement(node);
    _loopDepth--;
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _loopDepth++;
    super.visitWhileStatement(node);
    _loopDepth--;
  }

  @override
  void visitDoStatement(DoStatement node) {
    _loopDepth++;
    super.visitDoStatement(node);
    _loopDepth--;
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    _report(
      node,
      'wonky_switch_expression',
      'Switch expressions are not supported in Wonky scripts.',
      fix: 'Use a switch statement or if/else.',
    );
    super.visitSwitchExpression(node);
  }

  void _pattern(AstNode node) => _report(
    node,
    'wonky_records_patterns',
    'Records and patterns are only partly supported in Wonky scripts and may '
        'not work.',
    fix: 'Use classes, lists or maps.',
    severity: DiagnosticSeverity.warning,
  );

  @override
  void visitRecordLiteral(RecordLiteral node) {
    _pattern(node);
    super.visitRecordLiteral(node);
  }

  @override
  void visitRecordTypeAnnotation(RecordTypeAnnotation node) {
    _pattern(node);
    super.visitRecordTypeAnnotation(node);
  }

  @override
  void visitPatternVariableDeclaration(PatternVariableDeclaration node) {
    _pattern(node);
    super.visitPatternVariableDeclaration(node);
  }

  @override
  void visitPatternAssignment(PatternAssignment node) {
    _pattern(node);
    super.visitPatternAssignment(node);
  }

  @override
  void visitCaseClause(CaseClause node) {
    _pattern(node);
    super.visitCaseClause(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    final v = node.variables;
    if (!v.isFinal && !v.isConst) {
      _report(
        node,
        'wonky_top_level_state',
        'Top-level variables are reset between executions; use '
            'PropertiesService to keep state.',
        severity: DiagnosticSeverity.warning,
      );
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_loopDepth > 0) {
      final name = node.methodName.name;
      if (name == 'getRange' || name == 'getRangeAt' || name == 'cell') {
        _report(
          node,
          'wonky_loop_read',
          'Reading cells one by one in a loop is slow.',
          fix:
              'Read the whole range once with `values` and loop over the '
              'list.',
          severity: DiagnosticSeverity.info,
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final name = node.name.lexeme;
    final isPublic = !name.startsWith('_');
    if (node.parent is CompilationUnit &&
        isPublic &&
        !node.isGetter &&
        !node.isSetter) {
      _checkEntryPoint(node, name);
    }
    super.visitFunctionDeclaration(node);
  }

  void _checkEntryPoint(FunctionDeclaration node, String name) {
    if (name == 'wonkyInvoke' || name == 'wonkyEvent') {
      _report(
        node,
        'wonky_reserved_name',
        '"$name" is reserved; please rename the function.',
        offset: node.name.offset,
        length: node.name.length,
      );
    }
    final params =
        node.functionExpression.parameters?.parameters ??
        const <FormalParameter>[];
    if (const {
      'onOpen',
      'onEdit',
      'onSelectionChange',
      'onChange',
    }.contains(name)) {
      if (params.length > 1 || params.any((p) => p.isNamed)) {
        _report(
          node,
          'wonky_trigger_signature',
          '$name takes at most one parameter: the event object.',
          offset: node.name.offset,
          length: node.name.length,
        );
      }
    }
    final doc = node.documentationComment;
    final isCustom =
        doc != null &&
        doc.tokens.any((t) => t.lexeme.contains('@customfunction'));
    if (!isCustom) return;
    final upper = name.toUpperCase();
    if (!RegExp(r'^[A-Z_][A-Z0-9_.]*$').hasMatch(upper)) {
      _report(
        node,
        'wonky_custom_function_signature',
        'Custom function names may only use letters, digits and "_".',
        offset: node.name.offset,
        length: node.name.length,
      );
    }
    if (node.functionExpression.body.isAsynchronous) {
      _report(
        node,
        'wonky_custom_function_signature',
        'Custom functions must be synchronous.',
        offset: node.name.offset,
        length: node.name.length,
      );
    }
    for (final p in params) {
      final normal = p is DefaultFormalParameter ? p.parameter : p;
      final type = normal is SimpleFormalParameter ? normal.type : null;
      final text = type?.toSource();
      if (text != null && text != 'Object?' && text != 'dynamic') {
        _report(
          p,
          'wonky_custom_function_signature',
          'Custom function parameters must be `Object?` (a value or a '
              '`List<List<Object?>>` for ranges).',
          fix:
              'Declare the parameter as `Object? ${p.name?.lexeme ?? 'value'}`.',
        );
      }
      if (p.isNamed) {
        _report(
          p,
          'wonky_custom_function_signature',
          'Custom functions cannot have named parameters.',
        );
      }
    }
    if (isBuiltinFunction?.call(upper) == true) {
      _report(
        node,
        'wonky_builtin_shadowed',
        '$upper is a built-in function; formulas will use the built-in.',
        fix: 'Rename the function.',
        severity: DiagnosticSeverity.warning,
        offset: node.name.offset,
        length: node.name.length,
      );
    }
  }
}
