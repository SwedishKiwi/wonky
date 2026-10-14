import 'dart:convert';

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart'
    show FormulaLocale, FunctionRegistry, validateFormula;
import 'package:wonky_sheets_core/model.dart';

import '../features/named_ranges/import_named_functions_dialog.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _data(SheetsLocalizations l) => l.categoryData;

/// Panel ids (04 §10).
const namedRangesPanelId = 'sheets.panel.namedRanges';
const namedFunctionsPanelId = 'sheets.panel.namedFunctions';

/// A named function definition (07 §9.1 `metaJson`).
class NamedFunctionMeta {
  const NamedFunctionMeta({
    this.params = const [],
    this.descriptions = const {},
    this.examples = const {},
  });

  factory NamedFunctionMeta.parse(String? json) {
    if (json == null || json.isEmpty) return const NamedFunctionMeta();
    try {
      final d = jsonDecode(json);
      if (d is! Map) return const NamedFunctionMeta();
      final ps = d['params'];
      final params = <String>[];
      final desc = <String, String>{};
      final ex = <String, String>{};
      if (ps is List) {
        for (final p in ps) {
          if (p is! Map || p['name'] is! String) continue;
          final n = p['name'] as String;
          params.add(n);
          if (p['description'] is String) desc[n] = p['description'] as String;
          if (p['example'] is String) ex[n] = p['example'] as String;
        }
      }
      return NamedFunctionMeta(
        params: params,
        descriptions: desc,
        examples: ex,
      );
    } on FormatException {
      return const NamedFunctionMeta();
    }
  }

  final List<String> params;
  final Map<String, String> descriptions;
  final Map<String, String> examples;

  String encode() => jsonEncode({
    'kind': 'function',
    'params': [
      for (final p in params)
        {
          'name': p,
          if (descriptions[p] != null) 'description': descriptions[p],
          if (examples[p] != null) 'example': examples[p],
        },
    ],
  });
}

/// Named functions of the spreadsheet (named ranges with a formula and no
/// range), by name.
List<NamedRangeRecord> namedFunctionsOf(WorkbookModel m) =>
    m.namedRanges.where((n) => n.isFormula).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

/// Named ranges (with a range), by name (case-insensitive).
List<NamedRangeRecord> namedRangesOf(WorkbookModel m) =>
    m.namedRanges.where((n) => n.rangeJson != null).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

/// The A1 text (`'Sheet 1'!A1:B10`) of a named range, or null (`#REF!`).
String? namedRangeA1(WorkbookModel m, NamedRangeRecord n) {
  final g = GridRange.tryParse(n.rangeJson);
  if (g == null) return null;
  final rr = m.resolve(g);
  if (rr == null) return null;
  return m.a1Of(rr);
}

/// Validates a named function [name] (07 §9.3) against built-ins and the
/// other names; [current] is the name being edited.
String? namedFunctionNameError(
  WorkbookModel m,
  String name, {
  String? current,
}) => NameRules.validateFunctionName(
  name,
  existing: [for (final n in m.namedRanges) n.name],
  current: current,
  isBuiltIn: FunctionRegistry.standard.has,
);

/// The stored `=LAMBDA(params, definition)` of a named function.
String lambdaFormula(
  SheetEditorController ed,
  List<String> params,
  String definition,
) {
  var body = definition.trim();
  if (body.startsWith('=')) body = body.substring(1);
  final a1 = '=LAMBDA(${[...params, body].join(', ')})';
  return ed.hooks.toStored(
    a1,
    sheetId: ed.activeSheetId,
    row: 0,
    col: 0,
    locale: ed.locale,
  );
}

/// The definition (A1, without the LAMBDA wrapper) of a stored named
/// function formula.
String definitionOf(SheetEditorController ed, NamedRangeRecord n) {
  final a1 = ed.hooks.toA1(
    n.formula ?? '',
    sheetId: ed.activeSheetId,
    row: 0,
    col: 0,
    locale: ed.locale,
  );
  final m = RegExp(
    r'^=\s*LAMBDA\s*\((.*)\)\s*$',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(a1);
  if (m == null) return a1;
  final inner = m.group(1)!;
  final params = NamedFunctionMeta.parse(n.metaJson).params;
  var rest = inner;
  for (final p in params) {
    final i = rest.indexOf(',');
    if (i < 0) break;
    if (rest.substring(0, i).trim().toLowerCase() != p.toLowerCase()) break;
    rest = rest.substring(i + 1);
  }
  return '=${rest.trim()}';
}

NamedRangeRecord? _byId(SheetEditorController ed, String id) {
  for (final n in ed.model.namedRanges) {
    if (n.id == id) return n;
  }
  return null;
}

/// Named range and named function commands (07 §8–9).
List<Command<CommandArgs>> namedCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.namedRanges.openPanel',
    label: (l) => l.cmdNamedRangesOpenPanel,
    icon: LucideIcons.bookmark,
    categoryName: _data,
    run: (ctx, ed, a) {
      s.panels.open(namedRangesPanelId);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.namedRanges.add',
    label: (l) => l.cmdNamedRangesAdd,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'name': JsonSchema.string(),
        'range': JsonSchema.string(),
        'comment': JsonSchema.string(),
      },
      required: ['name'],
    ),
    run: (ctx, ed, a) {
      final plan = ed.apply(
        ctx,
        AddNamedRange(
          a.requireString('name').trim(),
          range: rangeArg(ed, a),
          comment: a.string('comment'),
        ),
      );
      return ok({'id': plan.result['namedRangeId']});
    },
  ),
  SheetsCommand(
    'sheets.namedRanges.update',
    label: (l) => l.cmdNamedRangesUpdate,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'id': JsonSchema.string(),
        'name': JsonSchema.string(),
        'range': JsonSchema.string(),
        'comment': JsonSchema.string(),
      },
      required: ['id'],
    ),
    run: (ctx, ed, a) {
      final r = a.string('range');
      ed.apply(
        ctx,
        UpdateNamedRange(
          a.requireString('id'),
          name: a.string('name')?.trim(),
          range: r == null
              ? null
              : ed.model.parseA1(r.trim(), contextSheetId: ed.activeSheetId),
          comment: a.string('comment'),
        ),
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.namedRanges.delete',
    label: (l) => l.cmdNamedRangesDelete,
    icon: LucideIcons.trash2,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'id': JsonSchema.string()},
      required: ['id'],
    ),
    run: (ctx, ed, a) {
      ed.apply(ctx, DeleteNamedRange(a.requireString('id')));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.namedRanges.goTo',
    label: (l) => l.cmdNamedRangesGoTo,
    categoryName: _data,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'name': JsonSchema.string()},
      required: ['name'],
    ),
    run: (ctx, ed, a) {
      final name = a.requireString('name');
      return ed.goTo(name)
          ? ok({'selection': ed.selection.describe()})
          : CommandResult.failed(ed.l10n.toastInvalidRange(name));
    },
  ),
  // ---- Named functions (07 §9) ----
  SheetsCommand(
    'sheets.namedFunctions.openPanel',
    label: (l) => l.cmdNamedFunctionsOpenPanel,
    icon: LucideIcons.squareFunction,
    categoryName: _data,
    run: (ctx, ed, a) {
      s.panels.open(namedFunctionsPanelId);
      return ok();
    },
  ),
  for (final update in [false, true])
    SheetsCommand(
      update ? 'sheets.namedFunctions.update' : 'sheets.namedFunctions.create',
      label: (l) =>
          update ? l.cmdNamedFunctionsUpdate : l.cmdNamedFunctionsCreate,
      categoryName: _data,
      mutates: true,
      showInPalette: false,
      argsSchema: JsonSchema.object(
        properties: {
          if (update) 'id': const JsonSchema.string(),
          'name': const JsonSchema.string(),
          'description': const JsonSchema.string(),
          'params': const JsonSchema.array(JsonSchema.string()),
          'definition': const JsonSchema.string(
            description: 'Formula definition, e.g. "=price*(1+rate)".',
          ),
          'paramDescriptions': const JsonSchema.object(
            additionalProperties: true,
          ),
          'paramExamples': const JsonSchema.object(additionalProperties: true),
        },
        required: update ? const ['id'] : const ['name', 'definition'],
      ),
      run: (ctx, ed, a) {
        final cur = update ? _byId(ed, a.requireString('id')) : null;
        if (update && cur == null) {
          return const CommandResult.failed('Named function not found');
        }
        final oldMeta = NamedFunctionMeta.parse(cur?.metaJson);
        final name = (a.string('name') ?? cur!.name).trim().toUpperCase();
        final nameErr = namedFunctionNameError(
          ed.model,
          name,
          current: cur?.name,
        );
        if (nameErr != null) return CommandResult.failed(nameErr);
        final params = a.values.containsKey('params')
            ? [for (final p in a.strings('params')) p.trim()]
            : oldMeta.params;
        final paramErr = NameRules.validateParams(params);
        if (paramErr != null) return CommandResult.failed(paramErr);
        final def =
            a.string('definition') ??
            (cur == null ? '' : definitionOf(ed, cur));
        if (def.trim().isEmpty || def.trim() == '=') {
          return CommandResult.failed(ed.l10n.namedFunctionNeedsDefinition);
        }
        final defErr = namedFunctionDefinitionError(ed, params, def);
        if (defErr != null) return CommandResult.failed(defErr);
        Map<String, String> strMap(String key, Map<String, String> dflt) {
          final v = a.values[key];
          if (v is! Map) return dflt;
          return {
            for (final e in v.entries)
              if (e.value is String) e.key.toString(): e.value as String,
          };
        }

        final meta = NamedFunctionMeta(
          params: params,
          descriptions: strMap('paramDescriptions', oldMeta.descriptions),
          examples: strMap('paramExamples', oldMeta.examples),
        );
        final formula = lambdaFormula(ed, params, def);
        if (cur == null) {
          final plan = ed.apply(
            ctx,
            AddNamedRange(
              name,
              formula: formula,
              comment: a.string('description') ?? '',
              metaJson: meta.encode(),
            ),
          );
          return ok({'id': plan.result['namedRangeId']});
        }
        ed.apply(
          ctx,
          UpdateNamedRange(
            cur.id,
            name: name,
            formula: formula,
            comment: a.string('description'),
            metaJson: meta.encode(),
          ),
        );
        return ok({'id': cur.id});
      },
    ),
  SheetsCommand(
    'sheets.namedFunctions.import',
    label: (l) => l.cmdNamedFunctionsImport,
    icon: LucideIcons.import,
    categoryName: _data,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'sourceItemUuid': JsonSchema.string(
          description: 'Drive item of the spreadsheet to import from.',
        ),
        'names': JsonSchema.array(JsonSchema.string()),
        'replace': JsonSchema.boolean(
          description: 'Replace functions with the same name (else skip).',
        ),
      },
    ),
    undoLabelOf: (l, a) => l.cmdNamedFunctionsImport,
    run: (ctx, ed, a) async {
      final client = ed.services.client;
      if (client == null) {
        return CommandResult.failed(ed.l10n.importFunctionsOffline);
      }
      Future<List<ImportableFunction>> load(UuidValue item) async =>
          ImportableFunction.parseList(
            await client.sheets.namedFunctions(item),
          );
      UuidValue source;
      List<String> names;
      bool replace;
      List<ImportableFunction>? fns;
      final src = a.string('sourceItemUuid');
      if (src == null) {
        final dc = ctx.dialogContext;
        if (dc == null || !dc.mounted) return const CommandResult.cancelled();
        final r = await showImportNamedFunctionsDialog(
          dc,
          services: ed.services,
          currentItem: ed.session.itemUuid,
          load: (item) async => fns = await load(item),
        );
        if (r == null) return const CommandResult.cancelled();
        (source: source, names: names, replace: replace) = r;
      } else {
        source = UuidValue.fromString(src);
        names = a.strings('names');
        replace = a.boolean('replace') ?? false;
      }
      try {
        fns ??= await load(source);
      } catch (e) {
        return CommandResult.failed(ed.l10n.importFunctionsOffline);
      }
      final all = fns!;
      final wanted = ImportableFunction.withDependencies(
        names.isEmpty ? [for (final f in all) f.name] : names,
        all,
      );
      var imported = 0;
      var skipped = 0;
      for (final f in all) {
        if (!wanted.contains(f.name.toUpperCase())) continue;
        final existing = ed.model.namedRanges
            .where((n) => n.name.toUpperCase() == f.name.toUpperCase())
            .firstOrNull;
        if (existing != null) {
          final isFunction = existing.rangeJson == null;
          if (!replace || !isFunction) {
            skipped++;
            continue;
          }
          ed.apply(
            ctx,
            UpdateNamedRange(
              existing.id,
              formula: f.formula,
              comment: f.comment ?? '',
              metaJson: f.metaJson,
            ),
          );
        } else {
          ed.apply(
            ctx,
            AddNamedRange(
              f.name,
              formula: f.formula,
              comment: f.comment ?? '',
              metaJson: f.metaJson,
            ),
          );
        }
        imported++;
      }
      if (!ctx.source.isAgent) {
        ed.services.toasts.show(ed.l10n.importFunctionsDone(imported, skipped));
      }
      return ok({'imported': imported, 'skipped': skipped});
    },
  ),
  SheetsCommand(
    'sheets.namedFunctions.delete',
    label: (l) => l.cmdNamedFunctionsDelete,
    icon: LucideIcons.trash2,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'id': JsonSchema.string()},
      required: ['id'],
    ),
    run: (ctx, ed, a) {
      ed.apply(ctx, DeleteNamedRange(a.requireString('id')));
      return ok();
    },
  ),
];

/// Validates a named function definition (07 §9.3): it must parse and may
/// not contain cell or range references. Returns the message or null.
String? namedFunctionDefinitionError(
  SheetEditorController ed,
  List<String> params,
  String definition,
) {
  var body = definition.trim();
  if (body.startsWith('=')) body = body.substring(1);
  final probe = '=LAMBDA(${[...params, body].join(', ')})';
  final v = validateFormula(probe, locale: FormulaLocale.forId(ed.locale));
  if (!v.ok) return v.error?.message ?? NameRules.rangeReferences;
  if (v.references.isNotEmpty) return NameRules.rangeReferences;
  return null;
}
