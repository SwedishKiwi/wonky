import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../common/range_input.dart';
import '../formatting/panel_widgets.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'file_editors.dart';
import 'protection_controller.dart';
import 'protection_dialogs.dart';
import 'protection_panel_state.dart';

/// The *Protected sheets & ranges* side panel (07 §10.2).
SidePanelSpec protectionPanelSpec(
  BuildContext context,
  ShellServices services,
  SheetEditorController editor,
) => SidePanelSpec(
  id: protectionPanelId,
  title: sheetsL10n(context).cmdProtectOpenPanel,
  icon: LucideIcons.lock,
  builder: (context) => ProtectionPanel(services: services, editor: editor),
);

/// Body of the protection panel: the list of protections, or the editor of
/// a draft (Range | Sheet, description, ranges, *Set permissions*).
class ProtectionPanel extends StatelessWidget {
  const ProtectionPanel({
    super.key,
    required this.services,
    required this.editor,
  });

  final ShellServices services;
  final SheetEditorController editor;

  @override
  Widget build(BuildContext context) {
    final state = ProtectionPanelState.of(editor);
    final protection = ProtectionController.of(editor);
    return ListenableBuilder(
      listenable: Listenable.merge([state, protection, editor]),
      builder: (context, _) {
        final draft = state.draft;
        if (draft == null) {
          return _ProtectionList(
            editor: editor,
            protection: protection,
            state: state,
          );
        }
        return _ProtectionEditor(
          key: ValueKey<String>('protection.editor.${state.generation}'),
          services: services,
          editor: editor,
          protection: protection,
          state: state,
          draft: draft,
        );
      },
    );
  }
}

class _ProtectionList extends StatelessWidget {
  const _ProtectionList({
    required this.editor,
    required this.protection,
    required this.state,
  });

  final SheetEditorController editor;
  final ProtectionController protection;
  final ProtectionPanelState state;

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final entries = protection.entries;
    return FormatPanelFrame(
      title: l.cmdProtectOpenPanel,
      children: [
        Text(
          l.protectAdvisory,
          style: theme.textTheme.muted.copyWith(fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  LucideIcons.lock,
                  size: 24,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(height: 8),
                Text(l.protectPanelEmpty, style: theme.textTheme.small),
                const SizedBox(height: 4),
                Text(
                  l.protectPanelEmptyHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.muted.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          )
        else
          for (final e in entries)
            _EntryRow(editor: editor, protection: protection, entry: e),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ShadButton.outline(
            key: const ValueKey<String>('protection.add'),
            size: ShadButtonSize.sm,
            enabled: editor.canEdit,
            leading: const Icon(LucideIcons.plus, size: 16),
            onPressed: () =>
                state.startNew(rangeText: editor.activeRange.rect.a1),
            child: Text(l.protectAdd),
          ),
        ),
      ],
    );
  }
}

/// Summary of who may edit [e] ("Only you", "3 editors", "Warning only").
String protectionWhoLabel(
  SheetsLocalizations l,
  ProtectionController p,
  ProtectionEntry e,
) {
  if (e.record.warningOnly) return l.protectWarningOnly;
  final n = e.editors.length;
  if (n > 0) return l.protectEditorsCount(n);
  return e.record.createdBy.toLowerCase() == p.userId.toLowerCase()
      ? l.protectOnlyYou
      : l.protectRestricted;
}

/// Where [e] applies ("Sheet1!F2:F40", 'Sheet “Config” except B2:B5').
String protectionWhereLabel(SheetsLocalizations l, ProtectionEntry e) {
  if (e.isSheet) {
    final base = l.protectSheetName(e.sheet.name);
    if (e.except.isEmpty) return base;
    return '$base ${l.protectExceptSummary(e.except.map((r) => r.a1).join(', '))}';
  }
  final rect = e.rects.isEmpty ? null : e.rects.first;
  return rect == null ? e.sheet.name : '${e.sheet.name}!${rect.a1}';
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.editor,
    required this.protection,
    required this.entry,
  });

  final SheetEditorController editor;
  final ProtectionController protection;
  final ProtectionEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final manage = editor.canEdit && protection.canManage(entry.record);
    final where = protectionWhereLabel(l, entry);
    final title = (entry.record.description?.trim().isNotEmpty ?? false)
        ? entry.record.description!.trim()
        : where;
    final row = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            entry.isSheet ? LucideIcons.sheet : LucideIcons.lock,
            size: 16,
            color: cs.mutedForeground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (title != where)
                  Text(
                    where,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                Text(
                  protectionWhoLabel(l, protection, entry),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (manage)
            ShadTooltip(
              builder: (_) => Text(l.protectRemove),
              child: ShadIconButton.ghost(
                key: ValueKey<String>('protection.remove.${entry.id}'),
                width: 28,
                height: 28,
                iconSize: 15,
                semanticLabel: l.protectRemove,
                icon: const Icon(LucideIcons.trash2),
                onPressed: () => unawaited(
                  editor.invokeCommand('sheets.protect.delete', {
                    'id': entry.id,
                  }),
                ),
              ),
            )
          else
            ShadTooltip(
              builder: (_) => Text(l.protectCantEdit),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  LucideIcons.lockKeyhole,
                  size: 15,
                  color: cs.mutedForeground,
                  semanticLabel: l.protectCantEdit,
                ),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: manage,
      label: '$title, $where, ${protectionWhoLabel(l, protection, entry)}',
      child: ShadFocusable(
        builder: (context, focused, child) => child!,
        child: GestureDetector(
          key: ValueKey<String>('protection.entry.${entry.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: manage
              ? () => ProtectionPanelState.of(editor).edit(entry)
              : null,
          child: MouseRegion(
            cursor: manage
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: row,
          ),
        ),
      ),
    );
  }
}

class _ProtectionEditor extends StatefulWidget {
  const _ProtectionEditor({
    super.key,
    required this.services,
    required this.editor,
    required this.protection,
    required this.state,
    required this.draft,
  });

  final ShellServices services;
  final SheetEditorController editor;
  final ProtectionController protection;
  final ProtectionPanelState state;
  final ProtectionDraft draft;

  @override
  State<_ProtectionEditor> createState() => _ProtectionEditorState();
}

class _ProtectionEditorState extends State<_ProtectionEditor> {
  late ProtectionDraft d = widget.draft;
  late final TextEditingController _description = TextEditingController(
    text: d.description,
  );
  bool _rangeValid = true;
  bool _exceptValid = true;
  bool _busy = false;

  SheetEditorController get ed => widget.editor;

  @override
  void initState() {
    super.initState();
    _rangeValid = _parses(d.rangeText, multiple: false);
    _exceptValid = !d.exceptEnabled || _parses(d.exceptText, multiple: true);
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool _parses(String text, {required bool multiple}) {
    if (text.trim().isEmpty) return false;
    try {
      final list = parseRangeList(
        ed.model,
        text,
        contextSheetId: ed.activeSheetId,
      );
      return list.isNotEmpty && (multiple || list.length == 1);
    } catch (_) {
      return false;
    }
  }

  void _update(ProtectionDraft next) {
    setState(() => d = next);
    widget.state.draft = next;
  }

  bool get _valid => d.target == ProtectionTarget.range
      ? _rangeValid
      : (ed.model.sheet(d.sheetId) != null &&
            (!d.exceptEnabled || _exceptValid));

  Future<void> _setPermissions() async {
    if (!_valid || _busy) return;
    final l = sheetsL10n(context);
    setState(() => _busy = true);
    final loaded = await FileEditors.load(
      widget.services,
      ed.session.itemUuid,
      known: d.editors,
    );
    final editors = loaded.editors;
    if (!mounted) return;
    setState(() => _busy = false);
    final others = [
      for (final e in widget.protection.entries)
        if (e.id != d.id && !e.record.warningOnly && e.editors.isNotEmpty)
          (
            id: e.id,
            label: (e.record.description?.isNotEmpty ?? false)
                ? e.record.description!
                : protectionWhereLabel(l, e),
            editors: e.editors.toList(),
          ),
    ];
    final perms = await showProtectionPermissionsDialog(
      context,
      sheet: d.target == ProtectionTarget.sheet,
      initial: ProtectionPermissions(
        warningOnly: d.warningOnly,
        editors: d.editors,
      ),
      editors: [
        for (final e in editors)
          if (e.userId.toLowerCase() != widget.protection.userId.toLowerCase())
            e,
      ],
      copyFrom: others,
      offline: loaded.offline,
    );
    if (perms == null || !mounted) return;
    // Emails typed into "Add editors" must be editors of the file; others
    // can be invited (shared as editors) first.
    final byEmail = {
      for (final e in editors)
        if (e.email != null) e.email!.toLowerCase(): e.userId,
    };
    final chosen = {...perms.editors.map((e) => e.toLowerCase())};
    final missing = <String>[];
    for (final m in perms.addEmails) {
      final id = byEmail[m];
      if (id == null) {
        missing.add(m);
      } else {
        chosen.add(id.toLowerCase());
      }
    }
    if (missing.isNotEmpty) {
      final added = await _inviteMissing(missing, offline: loaded.offline);
      if (!mounted) return;
      chosen.addAll(added.map((e) => e.toLowerCase()));
    }
    await _commit(perms.warningOnly, chosen.toList()..sort());
  }

  /// Offers to share the spreadsheet with [emails] as editors (07 §10.2);
  /// returns the user ids that can be added to the protection. Sharing is
  /// not part of the undo step.
  Future<List<String>> _inviteMissing(
    List<String> emails, {
    required bool offline,
  }) async {
    final l = sheetsL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final s = widget.services;
    final names = emails.join(', ');
    void toastNoAccess() => s.toasts.show(
      l.protectPermNoAccess(names),
      actionLabel: la.actionShare,
      onAction: () => unawaited(
        s.dispatcher.invoke(
          'shell.sharing.open',
          source: InvocationSource.ui,
          context: s.navigatorContext,
        ),
      ),
    );
    if (offline) {
      toastNoAccess();
      return const [];
    }
    final share = await showProtectionInviteDialog(context, names);
    if (!share || !mounted) return const [];
    try {
      final r = await FileEditors.invite(s, ed.session.itemUuid, emails);
      if (r.invited.isNotEmpty) {
        s.toasts.show(l.protectInvitePending(r.invited.join(', ')));
      }
      return r.userIds.values.toList();
    } on Object {
      toastNoAccess();
      return const [];
    }
  }

  Future<void> _commit(bool warningOnly, List<String> editors) async {
    final isSheet = d.target == ProtectionTarget.sheet;
    final args = <String, Object?>{
      if (d.id != null) 'id': d.id,
      'description': _description.text.trim(),
      'warningOnly': warningOnly,
      'editors': editors,
      if (isSheet) ...{
        'sheetId': d.sheetId,
        'exceptRanges': d.exceptEnabled && d.exceptText.trim().isNotEmpty
            ? [d.exceptText]
            : <String>[],
      } else
        'range': d.rangeText,
    };
    final ok = await ed.invokeCommand(
      d.id == null ? 'sheets.protect.add' : 'sheets.protect.update',
      args,
    );
    if (ok && mounted) widget.state.close();
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final sheets = {for (final s in ed.model.sheets) s.id: s.name};
    final isSheet = d.target == ProtectionTarget.sheet;
    return FormatPanelFrame(
      title: d.isNew ? l.protectAdd : l.protectEdit,
      onBack: widget.state.close,
      backLabel: la.actionBack,
      footer: PanelDoneFooter(
        keyPrefix: 'protection',
        cancelLabel: la.actionCancel,
        doneLabel: l.protectSetPermissions,
        onCancel: widget.state.close,
        onDone: _valid && !_busy ? () => unawaited(_setPermissions()) : null,
        leading: d.isNew
            ? null
            : ShadButton.ghost(
                key: const ValueKey<String>('protection.delete'),
                size: ShadButtonSize.sm,
                leading: const Icon(LucideIcons.trash2, size: 15),
                onPressed: () => unawaited(
                  ed.invokeCommand('sheets.protect.delete', {'id': d.id}),
                ),
                child: Text(l.protectRemove, overflow: TextOverflow.ellipsis),
              ),
      ),
      children: [
        Row(
          children: [
            for (final (t, label) in [
              (ProtectionTarget.range, l.protectTabRange),
              (ProtectionTarget.sheet, l.protectTabSheet),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Semantics(
                  selected: d.target == t,
                  child: d.target == t
                      ? ShadButton.secondary(
                          key: ValueKey<String>('protection.tab.${t.name}'),
                          size: ShadButtonSize.sm,
                          onPressed: () {},
                          child: Text(label),
                        )
                      : ShadButton.ghost(
                          key: ValueKey<String>('protection.tab.${t.name}'),
                          size: ShadButtonSize.sm,
                          enabled: d.isNew,
                          onPressed: () => _update(d.copyWith(target: t)),
                          child: Text(label),
                        ),
                ),
              ),
          ],
        ),
        PanelSection(
          label: l.protectDescription,
          child: ShadInput(
            key: const ValueKey<String>('protection.description'),
            controller: _description,
            placeholder: Text(l.protectDescriptionPlaceholder),
            onChanged: (v) =>
                widget.state.draft = d = d.copyWith(description: v),
          ),
        ),
        if (!isSheet)
          PanelSection(
            label: l.protectRange,
            child: RangeInput(
              keyName: 'protection.range',
              editor: ed,
              value: d.rangeText,
              multiple: false,
              onChanged: (text, ranges) {
                _rangeValid = ranges != null && ranges.length == 1;
                _update(d.copyWith(rangeText: text));
              },
            ),
          )
        else ...[
          PanelSection(
            label: l.protectSheet,
            child: PanelSelect<String>(
              keyName: 'protection.sheet',
              value: sheets.containsKey(d.sheetId)
                  ? d.sheetId
                  : sheets.keys.first,
              options: sheets,
              enabled: d.isNew,
              onChanged: (v) => _update(d.copyWith(sheetId: v)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ShadCheckbox(
                key: const ValueKey<String>('protection.except'),
                value: d.exceptEnabled,
                onChanged: (v) {
                  _exceptValid = !v || _parses(d.exceptText, multiple: true);
                  _update(d.copyWith(exceptEnabled: v));
                },
                label: Text(l.protectExceptCells),
              ),
            ],
          ),
          if (d.exceptEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: RangeInput(
                keyName: 'protection.exceptRanges',
                editor: ed,
                value: d.exceptText,
                onChanged: (text, ranges) {
                  _exceptValid = ranges != null && ranges.isNotEmpty;
                  _update(d.copyWith(exceptText: text));
                },
              ),
            ),
        ],
      ],
    );
  }
}
