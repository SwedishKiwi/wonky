import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../data_tools/data_tools.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// The Filter views panel (`sheets.panel.filterViews`, 07 §4.2): the sheet's
/// saved and temporary views with search, creator, *Open*, *Duplicate*,
/// *Delete*, and *Create filter view*.
class FilterViewsPanel extends StatefulWidget {
  const FilterViewsPanel({super.key, required this.editor});

  final SheetEditorController editor;

  @override
  State<FilterViewsPanel> createState() => _FilterViewsPanelState();
}

class _FilterViewsPanelState extends State<FilterViewsPanel> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

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
    final filters = DataTools.of(ed).filters;
    return ListenableBuilder(
      listenable: Listenable.merge([ed, filters]),
      builder: (context, _) {
        final sid = ed.activeSheetId;
        final active = filters.activeViewId(sid);
        final q = _search.text.trim().toLowerCase();
        final views = <(String, String, bool, String?)>[
          for (final v in filters.savedViews(sid))
            (v.id, v.name ?? '', false, v.createdBy),
          for (final t in filters.temporaryViews)
            if (t.sheetId == sid) (t.id, t.name, true, null),
        ].where((v) => q.isEmpty || v.$2.toLowerCase().contains(q)).toList();
        return Column(
          key: const ValueKey<String>('sheets.panel.filterViews'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(l.filterViewsTitle, style: theme.textTheme.large),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: ShadInput(
                key: const ValueKey<String>('filterViews.search'),
                controller: _search,
                placeholder: Text(l.filterSearch),
                leading: const Icon(LucideIcons.search, size: 14),
              ),
            ),
            Expanded(
              child: WonkyScrollArea(
                controller: _scroll,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (views.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            l.filterViewsEmpty,
                            style: theme.textTheme.muted,
                          ),
                        ),
                      for (final (id, name, temp, by) in views)
                        _row(context, id, name, temp, by, active == id),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ShadButton.outline(
                          key: const ValueKey<String>('filterViews.create'),
                          size: ShadButtonSize.sm,
                          leading: const Icon(LucideIcons.plus, size: 16),
                          onPressed: () => _invoke('sheets.filterView.create'),
                          child: Text(l.cmdFilterViewCreate),
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

  Widget _row(
    BuildContext context,
    String id,
    String name,
    bool temporary,
    String? createdBy,
    bool active,
  ) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    return Container(
      key: ValueKey<String>('filterViews.row.$name'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: active ? cs.accent : null,
        border: Border.all(color: active ? cs.primary : cs.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.listFilter, size: 16, color: cs.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (temporary)
                  Text(
                    l.filterViewTemporaryShort,
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
              ],
            ),
          ),
          ShadButton.ghost(
            key: ValueKey<String>('filterViews.open.$name'),
            size: ShadButtonSize.sm,
            onPressed: () => _invoke('sheets.filterView.activate', {
              'viewId': active ? null : id,
            }),
            child: Text(active ? l.filterViewClose : l.filterViewOpen),
          ),
          WonkyDropdownMenu(
            entries: () => [
              WonkyMenuItem(
                key: ValueKey<String>('filterViews.duplicate.$name'),
                label: l.cmdFilterViewDuplicate,
                icon: LucideIcons.copy,
                onSelected: () =>
                    _invoke('sheets.filterView.duplicate', {'viewId': id}),
              ),
              WonkyMenuItem(
                key: ValueKey<String>('filterViews.delete.$name'),
                label: l.cmdFilterViewDelete,
                icon: LucideIcons.trash2,
                enabled: temporary || ed.canEdit,
                onSelected: () =>
                    _invoke('sheets.filterView.delete', {'viewId': id}),
              ),
            ],
            builder: (context, c) => ShadIconButton.ghost(
              key: ValueKey<String>('filterViews.more.$name'),
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
