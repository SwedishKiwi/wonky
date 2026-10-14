import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../data_tools/data_tools.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import '../toolbar/command_ui.dart';
import 'filter_controller.dart';
import 'filter_layers.dart';
import '../../theme/sheets_tokens.dart';

/// The filter view bar above the column headers while a filter view is
/// active (07 §4.2): `Name: [Filter 1]  Range: [A1:F2000]  ⋮  ✕`, dark like
/// the headers of the view.
class FilterViewBar extends StatelessWidget {
  const FilterViewBar({super.key, required this.editor});

  final SheetEditorController editor;

  @override
  Widget build(BuildContext context) {
    final filters = DataTools.of(editor).filters;
    return ListenableBuilder(
      listenable: Listenable.merge([filters, editor]),
      builder: (context, _) {
        final sid = editor.activeSheetId;
        final id = filters.activeViewId(sid);
        final view = id == null ? null : filters.view(sid, id);
        if (view == null) return const SizedBox.shrink();
        return _Bar(
          key: ValueKey<String>('sheets.filterViewBar.${view.viewId}'),
          editor: editor,
          view: view,
        );
      },
    );
  }
}

class _Bar extends StatefulWidget {
  const _Bar({super.key, required this.editor, required this.view});

  final SheetEditorController editor;
  final EffectiveFilter view;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> {
  late final _name = TextEditingController(text: widget.view.name ?? '');
  late final _range = TextEditingController(text: widget.view.range.a1);
  final _nameFocus = FocusNode(debugLabel: 'filterView.name');
  final _rangeFocus = FocusNode(debugLabel: 'filterView.range');

  @override
  void didUpdateWidget(_Bar old) {
    super.didUpdateWidget(old);
    if (!_nameFocus.hasFocus && _name.text != (widget.view.name ?? '')) {
      _name.text = widget.view.name ?? '';
    }
    if (!_rangeFocus.hasFocus && _range.text != widget.view.range.a1) {
      _range.text = widget.view.range.a1;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _range.dispose();
    _nameFocus.dispose();
    _rangeFocus.dispose();
    super.dispose();
  }

  void _invoke(String id, [Map<String, Object?> args = const {}]) =>
      unawaited(widget.editor.invokeCommand(id, args));

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final s = ShellScope.of(context);
    final tokens = GridPaintTokens.ofContext(context);
    final colors = FilterColors.viewHeaders(tokens);
    final theme = ShadTheme.of(context);
    final v = widget.view;
    final id = v.viewId!;
    final label = theme.textTheme.small.copyWith(color: colors.fg);
    return Container(
      key: const ValueKey<String>('sheets.filterViewBar'),
      color: colors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Icon(LucideIcons.listFilter, size: 16, color: colors.fg),
          const SizedBox(width: 8),
          Text(l.filterViewName, style: label),
          const SizedBox(width: 6),
          Flexible(
            flex: 3,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: ShadInput(
                key: const ValueKey<String>('sheets.filterViewBar.name'),
                controller: _name,
                focusNode: _nameFocus,
                style: theme.textTheme.small.copyWith(color: colors.fg),
                decoration: ShadDecoration(
                  color: colors.selectedBg,
                  border: ShadBorder.all(color: colors.border),
                ),
                onSubmitted: (t) => _invoke('sheets.filterView.rename', {
                  'viewId': id,
                  'name': t,
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(l.filterViewRange, style: label),
          const SizedBox(width: 6),
          Flexible(
            flex: 2,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: ShadInput(
                key: const ValueKey<String>('sheets.filterViewBar.range'),
                controller: _range,
                focusNode: _rangeFocus,
                style: theme.textTheme.small.copyWith(color: colors.fg),
                decoration: ShadDecoration(
                  color: colors.selectedBg,
                  border: ShadBorder.all(color: colors.border),
                ),
                onSubmitted: (t) => _invoke('sheets.filterView.setRange', {
                  'viewId': id,
                  'range': t,
                }),
              ),
            ),
          ),
          if (v.temporary) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                l.filterViewTemporary,
                overflow: TextOverflow.ellipsis,
                style: label.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const Spacer(),
          WonkyDropdownMenu(
            entries: () {
              final ui = CommandUi(context, s);
              return [
                ui.item(
                  'sheets.filterView.duplicate',
                  args: {'viewId': id},
                  keyName: 'filterViewBar.duplicate',
                ),
                ui.item(
                  'sheets.filterView.copyLink',
                  args: {'viewId': id},
                  keyName: 'filterViewBar.copyLink',
                ),
                if (v.temporary)
                  ui.item(
                    'sheets.filterView.save',
                    args: {'tempId': id},
                    keyName: 'filterViewBar.save',
                  ),
                ui.item(
                  'sheets.filterView.openPanel',
                  keyName: 'filterViewBar.manage',
                ),
                const WonkyMenuSeparator(),
                ui.item(
                  'sheets.filterView.delete',
                  args: {'viewId': id},
                  keyName: 'filterViewBar.delete',
                ),
              ];
            },
            builder: (context, c) => ShadIconButton.ghost(
              key: const ValueKey<String>('sheets.filterViewBar.more'),
              width: 30,
              height: 30,
              icon: Icon(
                LucideIcons.ellipsisVertical,
                size: 16,
                color: colors.fg,
              ),
              onPressed: c.toggle,
            ),
          ),
          ShadTooltip(
            builder: (_) => Text(l.filterViewClose),
            child: ShadIconButton.ghost(
              key: const ValueKey<String>('sheets.filterViewBar.close'),
              width: 30,
              height: 30,
              icon: Icon(LucideIcons.x, size: 16, color: colors.fg),
              onPressed: () =>
                  _invoke('sheets.filterView.activate', {'viewId': null}),
            ),
          ),
        ],
      ),
    );
  }
}
