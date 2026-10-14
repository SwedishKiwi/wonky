import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../../theme/sheets_tokens.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'slicer_controller.dart';
import 'slicer_spec.dart';

/// The slicer object on the grid (07 §5): title, the current filter
/// summary and a funnel button opening the values popover.
class SlicerView extends StatefulWidget {
  const SlicerView({
    super.key,
    required this.editor,
    required this.record,
    required this.zoom,
  });

  final SheetEditorController editor;
  final EmbeddedObjectRecord record;
  final double zoom;

  @override
  State<SlicerView> createState() => _SlicerViewState();
}

class _SlicerViewState extends State<SlicerView> {
  final _popover = ShadPopoverController();

  @override
  void dispose() {
    _popover.dispose();
    super.dispose();
  }

  SlicerController get slicers => SlicerController.of(widget.editor);

  String _title(SheetsLocalizations l, SlicerSpec? spec) {
    final t = spec?.title?.trim() ?? '';
    if (t.isNotEmpty) return t;
    final ed = widget.editor;
    final f = slicers.find(widget.record.id);
    final colId = spec?.colId;
    if (f == null || spec == null || colId == null) return l.slicerUntitled;
    final rect = slicers.rectOf(f.$1, spec);
    final col = f.$1.columns.indexOf(colId);
    if (rect == null || col < 0) return l.slicerUntitled;
    final text = ed.cells.displayAt(f.$1.id, rect.top, col)?.text ?? '';
    return text.isEmpty ? l.slicerUntitled : text;
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    return ListenableBuilder(
      listenable: slicers,
      builder: (context, _) {
        final spec = SlicerSpec.tryParse(widget.record.specJson);
        final criteria = slicers.criteriaOf(widget.record);
        final local = slicers.hasOverride(widget.record.id);
        final t = widget.editor.model.theme;
        final bg =
            hexToColor(t.resolveColor(spec?.style.backgroundColor)) ?? cs.card;
        final fg =
            hexToColor(t.resolveColor(spec?.style.textColor)) ?? cs.foreground;
        final size = (spec?.style.fontSize ?? 10) * 1.3 * widget.zoom;
        final hidden = criteria?.hiddenValues.length ?? 0;
        final summary = criteria == null || criteria.isEmpty
            ? l.slicerAll
            : criteria.condition != null
            ? l.slicerByCondition
            : l.slicerHiddenCount(hidden);
        return Container(
          key: ValueKey<String>('slicer.${widget.record.id}'),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: cs.border),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: EdgeInsets.symmetric(horizontal: 8 * widget.zoom),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(l, spec),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: size,
                        fontWeight: (spec?.style.bold ?? false)
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    Text(
                      local ? l.slicerLocal(summary) : summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.7),
                        fontSize: size * 0.85,
                      ),
                    ),
                  ],
                ),
              ),
              ShadPopover(
                controller: _popover,
                popover: (context) => SlicerValuesPopover(
                  editor: widget.editor,
                  objectId: widget.record.id,
                  onClose: _popover.hide,
                ),
                child: ShadIconButton.ghost(
                  key: ValueKey<String>('slicer.open.${widget.record.id}'),
                  width: 28 * widget.zoom.clamp(0.75, 1.5),
                  height: 28 * widget.zoom.clamp(0.75, 1.5),
                  iconSize: 16 * widget.zoom.clamp(0.75, 1.5),
                  semanticLabel: l.slicerOpen,
                  icon: Icon(
                    criteria == null || criteria.isEmpty
                        ? LucideIcons.funnel
                        : LucideIcons.funnelPlus,
                    color: criteria == null || criteria.isEmpty
                        ? fg
                        : cs.primary,
                  ),
                  onPressed: _popover.toggle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The values checklist of a slicer (07 §5 `SlicerPopover`): search,
/// *Select all* / *Clear*, OK commits `sheets.slicer.setCriteria`.
class SlicerValuesPopover extends StatefulWidget {
  const SlicerValuesPopover({
    super.key,
    required this.editor,
    required this.objectId,
    required this.onClose,
  });

  final SheetEditorController editor;
  final String objectId;
  final VoidCallback onClose;

  @override
  State<SlicerValuesPopover> createState() => _SlicerValuesPopoverState();
}

class _SlicerValuesPopoverState extends State<SlicerValuesPopover> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  late List<ChecklistEntry> _entries;
  late Set<String> _hidden;

  SlicerController get slicers => SlicerController.of(widget.editor);

  @override
  void initState() {
    super.initState();
    final f = slicers.find(widget.objectId);
    _entries = f == null ? const [] : slicers.checklist(f.$1, f.$2);
    _hidden = {...?(f == null ? null : slicers.criteriaOf(f.$2))?.hiddenValues};
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<ChecklistEntry> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    return [
      for (final e in _entries)
        if (e.text.toLowerCase().contains(q)) e,
    ];
  }

  void _ok() {
    widget.onClose();
    unawaited(
      widget.editor.invokeCommand('sheets.slicer.setCriteria', {
        'objectId': widget.objectId,
        'criteria': _hidden.isEmpty
            ? null
            : ColumnCriteria(hiddenValues: _hidden).toJson(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final visible = _visible;
    return SizedBox(
      width: 260,
      child: Column(
        key: const ValueKey<String>('slicer.popover'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadInput(
            key: const ValueKey<String>('slicer.popover.search'),
            controller: _search,
            placeholder: Text(l.slicerSearch),
            leading: const Icon(LucideIcons.search, size: 14),
            onChanged: (_) => setState(() {}),
          ),
          Row(
            children: [
              ShadButton.link(
                key: const ValueKey<String>('slicer.popover.all'),
                size: ShadButtonSize.sm,
                onPressed: () => setState(() {
                  for (final e in visible) {
                    _hidden.remove(e.text);
                  }
                }),
                child: Text(l.slicerSelectAll),
              ),
              ShadButton.link(
                key: const ValueKey<String>('slicer.popover.clear'),
                size: ShadButtonSize.sm,
                onPressed: () => setState(() {
                  for (final e in visible) {
                    _hidden.add(e.text);
                  }
                }),
                child: Text(l.slicerClear),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: WonkyScrollArea(
              controller: _scroll,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in visible)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: ShadCheckbox(
                        key: ValueKey<String>('slicer.popover.value.${e.text}'),
                        value: !_hidden.contains(e.text),
                        onChanged: (v) => setState(
                          () =>
                              v ? _hidden.remove(e.text) : _hidden.add(e.text),
                        ),
                        label: Text(
                          e.text.isEmpty ? l.slicerBlanks : e.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        sublabel: Text(
                          '${e.count}',
                          style: theme.textTheme.muted.copyWith(fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 6,
            children: [
              ShadButton.outline(
                key: const ValueKey<String>('slicer.popover.cancel'),
                size: ShadButtonSize.sm,
                onPressed: widget.onClose,
                child: Text(l.slicerCancel),
              ),
              ShadButton(
                key: const ValueKey<String>('slicer.popover.ok'),
                size: ShadButtonSize.sm,
                onPressed: _ok,
                child: Text(l.slicerOk),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
