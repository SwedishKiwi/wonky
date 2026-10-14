import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/formula.dart' show ColumnLetters;
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';
import '../common/range_input.dart';
import '../formatting/panel_widgets.dart';
import '../formatting/sheets_colors.dart';
import '../objects/objects_controller.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'slicer_controller.dart';
import 'slicer_spec.dart';

/// Panel id of the slicer editor (07 §5).
const slicerPanelId = 'sheets.panel.slicer';

/// The slicer editor panel (07 §5): *Data* (range, column, apply to pivot
/// tables) and *Customize* (title, colors, font size, bold) of the selected
/// slicer. Every change is one `sheets.slicer.update` step.
class SlicerPanel extends StatefulWidget {
  const SlicerPanel({super.key, required this.editor});

  final SheetEditorController editor;

  @override
  State<SlicerPanel> createState() => _SlicerPanelState();
}

class _SlicerPanelState extends State<SlicerPanel> {
  final _title = TextEditingController();
  String? _titleFor;

  SheetEditorController get ed => widget.editor;
  ObjectsController get objects => ObjectsController.of(ed);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  EmbeddedObjectRecord? get _record {
    final o = objects.selected;
    if (o != null && o.kind == EmbeddedObjectKind.slicer) return o;
    final list = SlicerController.of(ed).slicersOn(ed.activeSheetId);
    return list.isEmpty ? null : list.last;
  }

  void _update(EmbeddedObjectRecord o, SlicerSpec spec) => unawaited(
    ed.invokeCommand('sheets.slicer.update', {
      'objectId': o.id,
      'spec': spec.toJson(),
    }),
  );

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([objects, SlicerController.of(ed), ed]),
      builder: (context, _) {
        final o = _record;
        final spec = o == null ? null : SlicerSpec.tryParse(o.specJson);
        if (o == null || spec == null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.slicerNone, style: theme.textTheme.muted),
          );
        }
        if (_titleFor != o.id) {
          _titleFor = o.id;
          _title.text = spec.title ?? '';
        }
        final sheet = ed.model.sheet(o.sheetId)!;
        final resolved = sheet.resolve(spec.dataRange);
        final rect = resolved?.rect;
        final columns = <String, String>{};
        if (rect != null) {
          for (var c = rect.left; c <= rect.right; c++) {
            final header = ed.cells.displayAt(sheet.id, rect.top, c)?.text;
            final letter = ColumnLetters.fromIndex(c);
            columns[sheet.columns.idAt(c)] = header == null || header.isEmpty
                ? letter
                : '$letter · $header';
          }
        }
        final enabled = ed.canEdit;
        return FormatPanelFrame(
          key: ValueKey<String>('slicer.panel.${o.id}'),
          title: l.slicerPanelTitle,
          children: [
            PanelSection(
              label: l.slicerDataRange,
              child: RangeInput(
                keyName: 'slicer.range',
                editor: ed,
                multiple: false,
                enabled: enabled,
                value: resolved == null
                    ? ''
                    : rangeToA1(ed.model, resolved, contextSheetId: sheet.id),
                onChanged: (t, ranges) {
                  if (ranges == null || ranges.isEmpty) return;
                  final r = ranges.first;
                  final s = ed.model.sheet(r.sheetId);
                  if (s == null || r.sheetId != o.sheetId) return;
                  final ci = spec.colId == null
                      ? -1
                      : s.columns.indexOf(spec.colId!);
                  final colIn = ci >= r.rect.left && ci <= r.rect.right;
                  _update(
                    o,
                    spec.copyWith(
                      dataRange: s.gridRange(r.rect),
                      colId: () =>
                          colIn ? spec.colId : s.columns.idAt(r.rect.left),
                      criteria: () => colIn ? spec.criteria : null,
                    ),
                  );
                },
              ),
            ),
            PanelSection(
              label: l.slicerColumn,
              child: PanelSelect<String>(
                keyName: 'slicer.column',
                enabled: enabled && columns.isNotEmpty,
                value: spec.colId != null && columns.containsKey(spec.colId)
                    ? spec.colId!
                    : (columns.keys.firstOrNull ?? ''),
                options: columns.isEmpty ? {'': '—'} : columns,
                onChanged: (id) {
                  if (id == spec.colId || id.isEmpty) return;
                  _update(
                    o,
                    spec.copyWith(colId: () => id, criteria: () => null),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ShadCheckbox(
                key: const ValueKey<String>('slicer.applyToPivots'),
                value: spec.applyToPivotTables,
                enabled: enabled,
                onChanged: (v) =>
                    _update(o, spec.copyWith(applyToPivotTables: v)),
                label: Text(l.slicerApplyToPivots),
              ),
            ),
            PanelSection(
              label: l.slicerTitle,
              child: ShadInput(
                key: const ValueKey<String>('slicer.title'),
                controller: _title,
                enabled: enabled,
                placeholder: Text(l.slicerTitlePlaceholder),
                onSubmitted: (v) => _update(
                  o,
                  spec.copyWith(title: () => v.trim().isEmpty ? null : v),
                ),
                onPressedOutside: (_) {
                  final v = _title.text;
                  if (v == (spec.title ?? '')) return;
                  _update(
                    o,
                    spec.copyWith(title: () => v.trim().isEmpty ? null : v),
                  );
                },
              ),
            ),
            PanelSection(
              label: l.slicerStyle,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SheetsColorButton(
                    key: const ValueKey<String>('slicer.background'),
                    compact: true,
                    icon: LucideIcons.paintBucket,
                    label: l.slicerBackground,
                    resetLabel: l.colorAutomatic,
                    theme: ed.model.theme,
                    enabled: enabled,
                    value: spec.style.backgroundColor,
                    onChanged: (c) => _update(
                      o,
                      spec.copyWith(
                        style: spec.style.copyWith(backgroundColor: () => c),
                      ),
                    ),
                  ),
                  SheetsColorButton(
                    key: const ValueKey<String>('slicer.textColor'),
                    compact: true,
                    icon: LucideIcons.baseline,
                    label: l.slicerTextColor,
                    resetLabel: l.colorAutomatic,
                    theme: ed.model.theme,
                    enabled: enabled,
                    value: spec.style.textColor,
                    onChanged: (c) => _update(
                      o,
                      spec.copyWith(
                        style: spec.style.copyWith(textColor: () => c),
                      ),
                    ),
                  ),
                  PanelIconToggle(
                    key: const ValueKey<String>('slicer.bold'),
                    icon: LucideIcons.bold,
                    label: l.cfBold,
                    value: spec.style.bold,
                    onChanged: (v) => _update(
                      o,
                      spec.copyWith(style: spec.style.copyWith(bold: v)),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: PanelSelect<double>(
                      keyName: 'slicer.fontSize',
                      enabled: enabled,
                      value: spec.style.fontSize,
                      options: {
                        for (final s in const <double>[
                          8,
                          9,
                          10,
                          11,
                          12,
                          14,
                          18,
                        ])
                          s: s.toInt().toString(),
                      },
                      onChanged: (v) => _update(
                        o,
                        spec.copyWith(style: spec.style.copyWith(fontSize: v)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (ed.canEdit)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ShadButton.outline(
                      key: const ValueKey<String>('slicer.setDefault'),
                      size: ShadButtonSize.sm,
                      enabled: SlicerController.of(ed).hasOverride(o.id),
                      onPressed: () => unawaited(
                        ed.invokeCommand('sheets.slicer.setDefault', {
                          'objectId': o.id,
                        }),
                      ),
                      child: Text(l.slicerSetDefault),
                    ),
                    ShadButton.ghost(
                      key: const ValueKey<String>('slicer.reset'),
                      size: ShadButtonSize.sm,
                      onPressed: () => unawaited(
                        ed.invokeCommand('sheets.slicer.reset', {
                          'objectId': o.id,
                        }),
                      ),
                      child: Text(l.slicerReset),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
