import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../commands/named_commands.dart';
import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// The Named functions panel (`sheets.panel.namedFunctions`, 07 §9.2): the
/// list (signature, description, edit/remove), *Add new function* and the
/// two-step editor (Define → Preview).
class NamedFunctionsPanel extends StatefulWidget {
  const NamedFunctionsPanel({super.key, required this.editor});

  final SheetEditorController editor;

  @override
  State<NamedFunctionsPanel> createState() => _NamedFunctionsPanelState();
}

class _NamedFunctionsPanelState extends State<NamedFunctionsPanel> {
  final _scroll = ScrollController();

  /// The id being edited, `''` for a new function, null for the list.
  String? _editing;

  SheetEditorController get ed => widget.editor;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: ed,
      builder: (context, _) {
        final fns = namedFunctionsOf(ed.model);
        final editing = _editing;
        return Column(
          key: const ValueKey<String>('sheets.panel.namedFunctions'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l.cmdNamedFunctionsOpenPanel,
                style: theme.textTheme.large,
              ),
            ),
            Expanded(
              child: WonkyScrollArea(
                controller: _scroll,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: editing != null
                      ? _FunctionEditor(
                          key: ValueKey<String>('namedFunctions.form.$editing'),
                          editor: ed,
                          record: editing.isEmpty
                              ? null
                              : fns.where((n) => n.id == editing).firstOrNull,
                          onDone: () => setState(() => _editing = null),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (fns.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.namedFunctionsEmpty,
                                      style: theme.textTheme.muted,
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.muted,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'GROSS(price, rate)\n'
                                        '=price * (1 + rate)',
                                        style: theme.textTheme.small.copyWith(
                                          fontFamily: 'JetBrains Mono',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            for (final f in fns) _row(context, f),
                            if (ed.canEdit)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ShadButton.outline(
                                      key: const ValueKey<String>(
                                        'namedFunctions.add',
                                      ),
                                      size: ShadButtonSize.sm,
                                      leading: const Icon(
                                        LucideIcons.plus,
                                        size: 16,
                                      ),
                                      onPressed: () =>
                                          setState(() => _editing = ''),
                                      child: Text(l.namedFunctionsAdd),
                                    ),
                                    // Import function (07 §9.4, P2).
                                    ShadButton.ghost(
                                      key: const ValueKey<String>(
                                        'namedFunctions.import',
                                      ),
                                      size: ShadButtonSize.sm,
                                      leading: const Icon(
                                        LucideIcons.import,
                                        size: 16,
                                      ),
                                      onPressed: () => unawaited(
                                        ed.invokeCommand(
                                          'sheets.namedFunctions.import',
                                          const {},
                                        ),
                                      ),
                                      child: Text(l.namedFunctionsImport),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, NamedRangeRecord f) {
    final theme = ShadTheme.of(context);
    final l = sheetsL10n(context);
    final params = NamedFunctionMeta.parse(f.metaJson).params;
    return Container(
      key: ValueKey<String>('namedFunctions.row.${f.name}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${f.name}(${params.join(', ')})',
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((f.comment ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    f.comment!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (ed.canEdit)
            WonkyDropdownMenu(
              entries: () => [
                WonkyMenuItem(
                  key: ValueKey<String>('namedFunctions.edit.${f.name}'),
                  label: l.namedFunctionsEdit,
                  icon: LucideIcons.pencil,
                  onSelected: () => setState(() => _editing = f.id),
                ),
                WonkyMenuItem(
                  key: ValueKey<String>('namedFunctions.remove.${f.name}'),
                  label: l.namedRangesRemove,
                  icon: LucideIcons.trash2,
                  onSelected: () => unawaited(
                    ed.invokeCommand('sheets.namedFunctions.delete', {
                      'id': f.id,
                    }),
                  ),
                ),
              ],
              builder: (context, c) => ShadIconButton.ghost(
                key: ValueKey<String>('namedFunctions.more.${f.name}'),
                width: 28,
                height: 28,
                icon: const Icon(LucideIcons.ellipsisVertical, size: 16),
                onPressed: c.toggle,
              ),
            ),
        ],
      ),
    );
  }
}

class _FunctionEditor extends StatefulWidget {
  const _FunctionEditor({
    super.key,
    required this.editor,
    required this.record,
    required this.onDone,
  });

  final SheetEditorController editor;
  final NamedRangeRecord? record;
  final VoidCallback onDone;

  @override
  State<_FunctionEditor> createState() => _FunctionEditorState();
}

class _FunctionEditorState extends State<_FunctionEditor> {
  late final NamedFunctionMeta _meta = NamedFunctionMeta.parse(
    widget.record?.metaJson,
  );
  late final _name = TextEditingController(text: widget.record?.name ?? '');
  late final _desc = TextEditingController(text: widget.record?.comment ?? '');
  final _param = TextEditingController();
  late final _def = TextEditingController(
    text: widget.record == null
        ? '='
        : definitionOf(widget.editor, widget.record!),
  );
  late final List<String> _params = [..._meta.params];
  late final Map<String, TextEditingController> _paramDesc = {
    for (final p in _params)
      p: TextEditingController(text: _meta.descriptions[p] ?? ''),
  };
  late final Map<String, TextEditingController> _paramEx = {
    for (final p in _params)
      p: TextEditingController(text: _meta.examples[p] ?? ''),
  };
  bool _preview = false;
  String? _error;

  SheetEditorController get ed => widget.editor;

  @override
  void dispose() {
    for (final c in [
      _name,
      _desc,
      _param,
      _def,
      ..._paramDesc.values,
      ..._paramEx.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addParam() {
    final p = _param.text.trim();
    if (p.isEmpty) return;
    final err = NameRules.validateParams([..._params, p]);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _params.add(p);
      _paramDesc[p] = TextEditingController();
      _paramEx[p] = TextEditingController();
      _param.clear();
      _error = null;
    });
  }

  String? _validate() {
    final name = _name.text.trim().toUpperCase();
    return namedFunctionNameError(
          ed.model,
          name,
          current: widget.record?.name,
        ) ??
        NameRules.validateParams(_params) ??
        (_def.text.trim().replaceAll('=', '').isEmpty
            ? sheetsL10n(context).namedFunctionNeedsDefinition
            : namedFunctionDefinitionError(ed, _params, _def.text));
  }

  void _next() {
    final err = _validate();
    setState(() {
      _error = err;
      if (err == null) _preview = true;
    });
  }

  String _previewResult() {
    var body = _def.text.trim();
    if (body.startsWith('=')) body = body.substring(1);
    final args = [
      for (final p in _params)
        _paramEx[p]!.text.trim().isEmpty ? '0' : _paramEx[p]!.text.trim(),
    ];
    final f = '=LAMBDA(${[..._params, body].join(', ')})(${args.join(', ')})';
    try {
      final v = ed.engine.evaluate(f, sheetId: ed.activeSheetId);
      return FormatterDisplayText(
        locale: ed.locale,
      ).displayText(v.toCellValue(), null);
    } catch (e) {
      return '#ERROR!';
    }
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final rec = widget.record;
    final ok = await ed.invokeCommand(
      rec == null
          ? 'sheets.namedFunctions.create'
          : 'sheets.namedFunctions.update',
      {
        'id': ?rec?.id,
        'name': _name.text.trim().toUpperCase(),
        'description': _desc.text,
        'params': _params,
        'definition': _def.text,
        'paramDescriptions': {for (final p in _params) p: _paramDesc[p]!.text},
        'paramExamples': {for (final p in _params) p: _paramEx[p]!.text},
      },
    );
    if (ok) widget.onDone();
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Text(t, style: ShadTheme.of(context).textTheme.small),
  );

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final err = _error == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              key: const ValueKey<String>('namedFunctions.form.error'),
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.destructive,
              ),
            ),
          );
    if (_preview) {
      final name = _name.text.trim().toUpperCase();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$name(${_params.join(', ')})',
            style: theme.textTheme.large.copyWith(fontSize: 16),
          ),
          for (final p in _params) ...[
            _label(l.namedFunctionsArgDescription(p)),
            ShadInput(
              key: ValueKey<String>('namedFunctions.form.desc.$p'),
              controller: _paramDesc[p],
            ),
            _label(l.namedFunctionsArgExample(p)),
            ShadInput(
              key: ValueKey<String>('namedFunctions.form.example.$p'),
              controller: _paramEx[p],
              onChanged: (_) => setState(() {}),
            ),
          ],
          _label(l.namedFunctionsPreview),
          Container(
            key: const ValueKey<String>('namedFunctions.form.result'),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.muted,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '=$name(${[for (final p in _params) _paramEx[p]!.text].join(', ')})'
              '  →  ${_previewResult()}',
              style: theme.textTheme.small,
            ),
          ),
          ?err,
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ShadButton.outline(
                key: const ValueKey<String>('namedFunctions.form.back'),
                size: ShadButtonSize.sm,
                onPressed: () => setState(() => _preview = false),
                child: Text(la.actionBack),
              ),
              const SizedBox(width: 8),
              ShadButton(
                key: const ValueKey<String>('namedFunctions.form.save'),
                size: ShadButtonSize.sm,
                onPressed: () => unawaited(_save()),
                child: Text(
                  widget.record == null
                      ? la.actionCreate
                      : l.namedFunctionsUpdate,
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(l.namedFunctionsName),
        ShadInput(
          key: const ValueKey<String>('namedFunctions.form.name'),
          controller: _name,
          autofocus: true,
          placeholder: const Text('GROSS'),
          inputFormatters: [_UpperCase()],
        ),
        _label(l.namedFunctionsDescription),
        ShadTextarea(
          key: const ValueKey<String>('namedFunctions.form.description'),
          controller: _desc,
          minHeight: 60,
          maxHeight: 120,
        ),
        _label(l.namedFunctionsParams),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in _params)
              ShadBadge.secondary(
                key: ValueKey<String>('namedFunctions.form.param.$p'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() {
                        _params.remove(p);
                        _paramDesc.remove(p)?.dispose();
                        _paramEx.remove(p)?.dispose();
                      }),
                      child: const Icon(LucideIcons.x, size: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ShadInput(
          key: const ValueKey<String>('namedFunctions.form.paramInput'),
          controller: _param,
          placeholder: Text(l.namedFunctionsParamHint),
          onSubmitted: (_) => _addParam(),
        ),
        _label(l.namedFunctionsDefinition),
        ShadInput(
          key: const ValueKey<String>('namedFunctions.form.definition'),
          controller: _def,
          style: theme.textTheme.small.copyWith(fontFamily: 'JetBrains Mono'),
          placeholder: const Text('=price * (1 + rate)'),
        ),
        ?err,
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ShadButton.outline(
              key: const ValueKey<String>('namedFunctions.form.cancel'),
              size: ShadButtonSize.sm,
              onPressed: widget.onDone,
              child: Text(la.actionCancel),
            ),
            const SizedBox(width: 8),
            ShadButton(
              key: const ValueKey<String>('namedFunctions.form.next'),
              size: ShadButtonSize.sm,
              onPressed: _next,
              child: Text(l.namedFunctionsNext),
            ),
          ],
        ),
      ],
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
