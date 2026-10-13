library syntax_highlight;

export 'src/highlighter.dart';
// WONKY PATCH SH-4: scope spans for Highlighter.parseScopes.
export 'src/span_parser.dart' show ScopeSpan;
// WONKY PATCH SH-1: `src/code_editor.dart` (CodeEditor) removed; it pulled in
// super_clipboard, which Wonky Write doesn't need.
