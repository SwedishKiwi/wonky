import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../commands/named_commands.dart';
import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// The Named ranges panel (`sheets.panel.namedRanges`, 07 §8.1): the list
/// (click selects the range), search above 10 items, *+ Add a range* and an
/// inline edit form with *Remove*.
class NamedRangesPanel extends StatefulWidget {
  const NamedRangesPanel({super.key, required this.editor});

  final SheetEditorController editor;

  @override
  State<NamedRangesPanel> createState() => _NamedRangesPanelState();
}

class _NamedRangesPanelState extends State<NamedRangesPanel> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  /// The id being edited, `''` for a new range, null for the list.
  String? _editing;

  SheetEditorController get ed => widget.editor;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _invoke(String id, [Map<String, Object?> args = const {}]) =>
      unawaited(ed.invokeCommand(id, args));

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: ed,
      builder: (context, _) {
        final all = namedRangesOf(ed.model);
        final q = _search.text.trim().toLowerCase();
        final list = [
          for (final n in all)
            if (q.isEmpty || n.name.toLowerCase().contains(q)) n,
        ];
        final editing = _editing;
        return Column(
          key: const ValueKey<String>('sheets.panel.namedRanges'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l.cmdNamedRangesOpenPanel,
                style: theme.textTheme.large,
              ),
            ),
            if (all.length > 10 && editing == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: ShadInput(
                  key: const ValueKey<String>('namedRanges.search'),
                  controller: _search,
                  placeholder: Text(l.filterSearch),
                  leading: const Icon(LucideIcons.search, size: 14),
                ),
              ),
            Expanded(
              child: WonkyScrollArea(
                controller: _scroll,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (editing != null)
                        _NamedRangeForm(
                          key: ValueKey<String>('namedRanges.form.$editing'),
                          editor: ed,
                          record: editing.isEmpty
                              ? null
                              : all.where((n) => n.id == editing).firstOrNull,
                          onDone: () => setState(() => _editing = null),
                        )
                      else ...[
                        if (all.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              l.namedRangesEmpty,
                              style: theme.textTheme.muted,
                            ),
                          ),
                        for (final n in list) _row(context, n),
                        if (ed.canEdit)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: ShadButton.ghost(
                                key: const ValueKey<String>('namedRanges.add'),
                                size: ShadButtonSize.sm,
                                leading: const Icon(LucideIcons.plus, size: 16),
                                onPressed: () => setState(() => _editing = ''),
                                child: Text(l.namedRangesAdd),
                              ),
                            ),
                          ),
                      ],
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

  Widget _row(BuildContext context, NamedRangeRecord n) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final a1 = namedRangeA1(ed.model, n);
    return _HoverRow(
      key: ValueKey<String>('namedRanges.row.${n.name}'),
      onTap: () => _invoke('sheets.namedRanges.goTo', {'name': n.name}),
      semanticsLabel: '${n.name} ${a1 ?? '#REF!'}',
      actions: ed.canEdit
          ? [
              ShadIconButton.ghost(
                key: ValueKey<String>('namedRanges.edit.${n.name}'),
                width: 28,
                height: 28,
                icon: const Icon(LucideIcons.pencil, size: 14),
                onPressed: () => setState(() => _editing = n.id),
              ),
              ShadIconButton.ghost(
                key: ValueKey<String>('namedRanges.delete.${n.name}'),
                width: 28,
                height: 28,
                icon: const Icon(LucideIcons.trash2, size: 14),
                onPressed: () =>
                    _invoke('sheets.namedRanges.delete', {'id': n.id}),
              ),
            ]
          : const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n.name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          a1 == null
              ? ShadBadge.destructive(child: Text(l.namedRangesRefError))
              : Text(
                  a1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                ),
        ],
      ),
    );
  }
}

/// A list row with hover actions (also reachable by keyboard).
class _HoverRow extends StatefulWidget {
  const _HoverRow({
    super.key,
    required this.child,
    required this.onTap,
    required this.actions,
    required this.semanticsLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final List<Widget> actions;
  final String semanticsLabel;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          label: widget.semanticsLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: _hover || _focus ? cs.accent : null,
                borderRadius: BorderRadius.circular(6),
                border: _focus ? Border.all(color: cs.ring) : null,
              ),
              child: Row(
                children: [
                  Expanded(child: widget.child),
                  if (_hover || _focus) ...widget.actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NamedRangeForm extends StatefulWidget {
  const _NamedRangeForm({
    super.key,
    required this.editor,
    required this.record,
    required this.onDone,
  });

  final SheetEditorController editor;
  final NamedRangeRecord? record;
  final VoidCallback onDone;

  @override
  State<_NamedRangeForm> createState() => _NamedRangeFormState();
}

class _NamedRangeFormState extends State<_NamedRangeForm> {
  late final _name = TextEditingController(text: widget.record?.name ?? '');
  late final _range = TextEditingController(
    text: widget.record == null
        ? widget.editor.model.a1Of(widget.editor.activeRange)
        : namedRangeA1(widget.editor.model, widget.record!) ?? '',
  );
  String? _error;

  SheetEditorController get ed => widget.editor;

  @override
  void dispose() {
    _name.dispose();
    _range.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final name = _name.text.trim();
    final rec = widget.record;
    final err = NameRules.validateRangeName(
      name,
      existing: [for (final n in ed.model.namedRanges) n.name],
      current: rec?.name,
    );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    try {
      ed.model.parseA1(_range.text.trim(), contextSheetId: ed.activeSheetId);
    } on InvalidRangeException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    final ok = await ed.invokeCommand(
      rec == null ? 'sheets.namedRanges.add' : 'sheets.namedRanges.update',
      {'id': ?rec?.id, 'name': name, 'range': _range.text.trim()},
    );
    if (ok) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.namedRangesName, style: theme.textTheme.small),
          const SizedBox(height: 4),
          ShadInput(
            key: const ValueKey<String>('namedRanges.form.name'),
            controller: _name,
            autofocus: true,
            placeholder: const Text('Sales'),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => unawaited(_done()),
          ),
          const SizedBox(height: 10),
          Text(l.namedRangesRange, style: theme.textTheme.small),
          const SizedBox(height: 4),
          ShadInput(
            key: const ValueKey<String>('namedRanges.form.range'),
            controller: _range,
            placeholder: const Text('A1:B10'),
            trailing: ShadTooltip(
              builder: (_) => Text(l.namedRangesUseSelection),
              child: ShadIconButton.ghost(
                key: const ValueKey<String>('namedRanges.form.pick'),
                width: 24,
                height: 24,
                icon: const Icon(LucideIcons.grid2x2, size: 14),
                onPressed: () =>
                    setState(() => _range.text = ed.model.a1Of(ed.activeRange)),
              ),
            ),
            onSubmitted: (_) => unawaited(_done()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              key: const ValueKey<String>('namedRanges.form.error'),
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.destructive,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.record != null)
                ShadButton.ghost(
                  key: const ValueKey<String>('namedRanges.form.remove'),
                  size: ShadButtonSize.sm,
                  onPressed: () async {
                    final ok = await ed.invokeCommand(
                      'sheets.namedRanges.delete',
                      {'id': widget.record!.id},
                    );
                    if (ok) widget.onDone();
                  },
                  child: Text(l.namedRangesRemove),
                ),
              const Spacer(),
              ShadButton.outline(
                key: const ValueKey<String>('namedRanges.form.cancel'),
                size: ShadButtonSize.sm,
                onPressed: widget.onDone,
                child: Text(la.actionCancel),
              ),
              const SizedBox(width: 8),
              ShadButton(
                key: const ValueKey<String>('namedRanges.form.done'),
                size: ShadButtonSize.sm,
                onPressed: () => unawaited(_done()),
                child: Text(la.actionDone),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
