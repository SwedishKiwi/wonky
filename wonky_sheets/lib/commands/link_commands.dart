import 'package:flutter/services.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';

import '../features/formatting/rich_text_editing.dart';
import '../features/links/link_dialog.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _edit(SheetsLocalizations l) => l.categoryEditing;

/// Normalizes a typed link (03 §14.4): `www.…` → `https://www.…`, e-mail
/// addresses → `mailto:`; internal links (`#sheet=…&range=…`) and URLs with
/// a scheme stay. Null when [text] isn't a link.
String? normalizeLink(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  if (t.startsWith('#')) return t;
  if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(t)) {
    final scheme = t.substring(0, t.indexOf(':')).toLowerCase();
    // No script URLs.
    if (scheme == 'javascript' || scheme == 'data' || scheme == 'vbscript') {
      return null;
    }
    return t;
  }
  if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)) return 'mailto:$t';
  if (RegExp(r'^[^\s/]+\.[^\s/]{2,}(/.*)?$').hasMatch(t)) return 'https://$t';
  return null;
}

/// An internal link `#sheet=<sheetId>&range=A1:B2` (or `#range=…`, `#gid=`).
({String? sheetId, String? range})? parseInternalLink(String url) {
  if (!url.startsWith('#')) return null;
  final params = Uri.splitQueryString(url.substring(1));
  final sheet = params['sheet'] ?? params['gid'];
  final range = params['range'];
  if (sheet == null && range == null) return null;
  return (sheetId: sheet, range: range);
}

/// Links (03 §14.4): insert/edit (Mod+K), remove, open and copy.
List<Command<CommandArgs>> linkCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.insert.link',
    label: (l) => l.cmdInsertLink,
    icon: LucideIcons.link,
    categoryName: _edit,
    mutates: true,
    keyScope: KeyScope.global,
    defaultBindings: const [KeyBinding('K', mod: true)],
    argsSchema: const JsonSchema.object(
      properties: {
        'url': JsonSchema.string(
          description:
              'https://…, an e-mail address or #sheet=<id>&range=A1; '
              'empty removes the link.',
        ),
        'text': JsonSchema.string(description: 'Text of the cell.'),
      },
    ),
    run: (ctx, ed, a) async {
      // A text selection in the cell editor becomes a link run (06 §11).
      if (RichTextEditing.hasRunSelection(ed.editor)) {
        return RichTextEditing.linkSelection(
          ctx,
          ed,
          url: a.string('url'),
          text: a.string('text'),
          normalize: normalizeLink,
        );
      }
      var url = a.string('url');
      var text = a.string('text');
      final d = ed.activeDisplay();
      if (url == null) {
        final dc = ctx.dialogContext;
        if (dc == null || !dc.mounted) return const CommandResult.cancelled();
        final r = await showLinkEditorDialog(
          dc,
          model: ed.model,
          activeSheetId: ed.activeSheetId,
          text: d?.text ?? '',
          url: d?.linkUrl ?? '',
        );
        if (r == null) return const CommandResult.cancelled();
        (text, url) = r;
      }
      final link = url.trim().isEmpty ? null : normalizeLink(url);
      if (url.trim().isNotEmpty && link == null) {
        return CommandResult.failed(ed.l10n.linkInvalid);
      }
      final range = ed.activeRange;
      final current = d?.text ?? '';
      final shown = link == null
          ? url
          : (linkTargetLabel(ed.model, link) ?? url);
      await ed.applyConfirmed(
        ctx,
        SetLink(
          [range],
          link,
          text: text != null && text.isNotEmpty && text != current
              ? text
              : (current.isEmpty && range.rect.isSingleCell ? shown : null),
        ),
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.link.remove',
    label: (l) => l.cmdLinkRemove,
    icon: LucideIcons.unlink,
    categoryName: _edit,
    mutates: true,
    argsSchema: Schemas.ranges,
    run: (ctx, ed, a) {
      ed.apply(ctx, SetLink(rangesArg(ed, a), null));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.link.open',
    label: (l) => l.cmdLinkOpen,
    icon: LucideIcons.externalLink,
    categoryName: _edit,
    argsSchema: const JsonSchema.object(
      properties: {
        'url': JsonSchema.string(description: 'Default: the active cell.'),
      },
    ),
    enabled: (ed, a) => a.string('url') != null || _activeLink(ed) != null,
    run: (ctx, ed, a) async {
      final url = a.string('url') ?? _activeLink(ed);
      if (url == null) return const CommandResult.cancelled();
      final internal = parseInternalLink(url);
      if (internal != null) {
        // Navigates within the spreadsheet (single window).
        final sid = internal.sheetId;
        if (sid != null && ed.model.sheet(sid) != null) {
          ed.activateSheet(sid);
        }
        final range = internal.range;
        if (range != null && !ed.goTo(range)) {
          return CommandResult.failed(ed.l10n.toastInvalidRange(range));
        }
        ed.gridFocus.requestFocus();
        return ok({'navigated': true});
      }
      // External links open in the system browser after a confirm (suite
      // 03 §1).
      final dc = ctx.dialogContext;
      if (dc == null || !dc.mounted) return const CommandResult.cancelled();
      final l = ed.l10n;
      final uri = Uri.tryParse(url);
      final confirmed = await confirmDialog(
        dc,
        title: l.linkOpenExternalTitle,
        description: uri != null && uri.host.isNotEmpty
            ? '${uri.host}\n$url'
            : url,
        confirmLabel: l.linkOpenExternalConfirm,
      );
      if (!confirmed) return const CommandResult.cancelled();
      await s.crossApp.openExternal(url);
      return ok({'opened': url});
    },
  ),
  SheetsCommand(
    'sheets.link.copy',
    label: (l) => l.cmdLinkCopy,
    icon: LucideIcons.copy,
    categoryName: _edit,
    argsSchema: const JsonSchema.object(
      properties: {
        'url': JsonSchema.string(description: 'Default: the active cell.'),
      },
    ),
    enabled: (ed, a) => a.string('url') != null || _activeLink(ed) != null,
    run: (ctx, ed, a) async {
      final url = a.string('url') ?? _activeLink(ed);
      if (url == null) return const CommandResult.cancelled();
      await Clipboard.setData(ClipboardData(text: url));
      s.toasts.show(ed.l10n.toastLinkCopied);
      return ok({'url': url});
    },
  ),
];

String? _activeLink(SheetEditorController ed) => ed.activeDisplay()?.linkUrl;
