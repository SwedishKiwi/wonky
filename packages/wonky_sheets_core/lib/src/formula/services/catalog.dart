import '../external/external_data.dart';
import '../functions/registry.dart';
import '../model/workbook_view.dart';

/// One function in the UI catalog (Insert › Function, Function help dialog, 05 §18).
final class CatalogEntry {
  final String name;
  final FunctionCategory? category;
  final String syntax;
  final String summary;
  final List<ArgHelp> args;
  final List<String> examples;
  final List<String> seeAlso;
  final String? notes;
  final Priority? priority;
  final bool implemented;

  /// `builtin`, `namedFunction` or `customFunction`.
  final String source;

  const CatalogEntry({
    required this.name,
    required this.syntax,
    required this.summary,
    this.category,
    this.args = const [],
    this.examples = const [],
    this.seeAlso = const [],
    this.notes,
    this.priority,
    this.implemented = true,
    this.source = 'builtin',
  });

  factory CatalogEntry.of(FunctionSpec s) => CatalogEntry(
    name: s.name,
    category: s.category,
    syntax: s.help.syntax,
    summary: s.help.summary,
    args: s.help.args,
    examples: s.help.examples,
    seeAlso: s.help.seeAlso,
    notes: s.help.notes,
    priority: s.priority,
    implemented: s.implemented,
  );

  /// MCP `sheets.list_functions` row.
  Map<String, Object?> toSummaryJson() => {
    'name': name,
    'category': category?.name ?? source,
    'syntax': syntax,
    'summary': summary,
    if (priority != null) 'priority': priority!.name,
    'implemented': implemented,
  };

  /// MCP `sheets.get_function_help`.
  Map<String, Object?> toJson() => {
    'name': name,
    'category': category?.name ?? source,
    'syntax': syntax,
    'summary': summary,
    'args': [for (final a in args) a.toJson()],
    'examples': examples,
    'seeAlso': seeAlso,
    'notes': ?notes,
    'implemented': implemented,
    'source': source,
  };
}

/// A category section of the catalog.
final class CatalogSection {
  final String label;
  final FunctionCategory? category;
  final List<CatalogEntry> functions;
  const CatalogSection(this.label, this.category, this.functions);
}

/// Function catalog exports for the UI, MCP and the AI assistant (05 §14.3, §18, §20).
final class FunctionCatalog {
  final FunctionRegistry registry;
  FunctionCatalog([FunctionRegistry? registry])
    : registry = registry ?? FunctionRegistry.standard;

  /// Categories in §15 order plus "Named functions" and "Custom functions"; implemented only.
  List<CatalogSection> forUi({
    Iterable<NamedRangeView> namedFunctions = const [],
    CustomFunctionProvider? customFunctions,
    Iterable<String> customFunctionNames = const [],
  }) {
    final out = <CatalogSection>[];
    for (final cat in FunctionCategory.values) {
      final fns = [
        for (final s in registry.all)
          if (s.category == cat && s.implemented) CatalogEntry.of(s),
      ];
      if (fns.isNotEmpty) out.add(CatalogSection(cat.label, cat, fns));
    }
    final named = [
      for (final n in namedFunctions)
        if (n.formula != null && n.range == null)
          CatalogEntry(
            name: n.name,
            syntax: '${n.name}(…)',
            summary: n.comment ?? '',
            source: 'namedFunction',
          ),
    ];
    if (named.isNotEmpty) {
      out.add(CatalogSection('Named functions', null, named));
    }
    if (customFunctions != null) {
      final custom = [
        for (final name in customFunctionNames)
          if (customFunctions.has(name.toUpperCase()))
            () {
              final h = customFunctions.help(name.toUpperCase());
              return CatalogEntry(
                name: name.toUpperCase(),
                syntax: h.syntax,
                summary: h.summary,
                args: h.args,
                examples: h.examples,
                source: 'customFunction',
              );
            }(),
      ];
      if (custom.isNotEmpty) {
        out.add(CatalogSection('Custom functions', null, custom));
      }
    }
    return out;
  }

  /// MCP `sheets.list_functions {category?, query?, include_unimplemented?}`.
  List<Map<String, Object?>> list({
    String? category,
    String? query,
    bool includeUnimplemented = false,
  }) {
    final q = query?.toLowerCase();
    return [
      for (final s in registry.all)
        if ((includeUnimplemented || s.implemented) &&
            (category == null ||
                s.category.name == category ||
                s.category.label.toLowerCase() == category.toLowerCase()) &&
            (q == null ||
                s.name.toLowerCase().contains(q) ||
                s.help.summary.toLowerCase().contains(q)))
          CatalogEntry.of(s).toSummaryJson(),
    ];
  }

  /// MCP `sheets.get_function_help {name}` (aliases resolve to the canonical entry).
  Map<String, Object?>? help(String name) {
    final s = registry.lookup(name.toUpperCase());
    if (s == null) return null;
    return {
      ...CatalogEntry.of(s).toJson(),
      if (s.aliases.isNotEmpty) 'aliases': s.aliases,
    };
  }

  /// Compact catalog for the AI assistant system prompt: `NAME(syntax) — summary` per line.
  String compact() {
    final b = StringBuffer();
    for (final s in registry.all) {
      if (!s.implemented) continue;
      b
        ..write(s.help.syntax)
        ..write(' — ')
        ..writeln(s.help.summary);
    }
    return b.toString();
  }

  /// Implemented / stub counts per priority and category (CI parity dashboard, 05 §15).
  Map<String, Map<String, int>> parityCounts() {
    final out = <String, Map<String, int>>{};
    for (final s in registry.all) {
      final key = '${s.category.name}/${s.priority.name}';
      final m = out.putIfAbsent(key, () => {'implemented': 0, 'stub': 0});
      m[s.implemented ? 'implemented' : 'stub'] =
          m[s.implemented ? 'implemented' : 'stub']! + 1;
    }
    return out;
  }
}
