import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import '../../drive/drive_format.dart';
import '../../l10n/wonky_app_localizations.dart';
import '../../shell/shell_services.dart';
import '../command.dart';
import 'palette_list.dart';

/// The command palette (suite 08 §1.3, `Mod+Shift+P`): fuzzy search over
/// titles, descriptions, aliases and menu paths; sections Recent / All
/// commands; extra providers "Go to document…" (drive search). With
/// [menusOnly] it is Help › Search the menus.
Future<void> showCommandPalette(BuildContext context, ShellServices s, {bool menusOnly = false}) {
  final menuPaths = s.menuPaths(context);
  return showShadDialog<void>(
    context: context,
    builder: (context) => ShadDialog(
      key: const ValueKey<String>('palette'),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 620),
      child: SizedBox(
        width: 600,
        child: _CommandPaletteBody(services: s, menusOnly: menusOnly, menuPaths: menuPaths),
      ),
    ),
  );
}

class _CommandPaletteBody extends StatefulWidget {
  const _CommandPaletteBody({required this.services, required this.menusOnly, required this.menuPaths});

  final ShellServices services;
  final bool menusOnly;
  final Map<String, List<String>> menuPaths;

  @override
  State<_CommandPaletteBody> createState() => _CommandPaletteBodyState();
}

class _CommandPaletteBodyState extends State<_CommandPaletteBody> {
  List<DriveItemView> _docs = const [];
  String _docQuery = '';
  Timer? _debounce;

  ShellServices get s => widget.services;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _searchDocs(String q, PaletteListState state) {
    if (q == _docQuery) return;
    _docQuery = q;
    _debounce?.cancel();
    if (q.trim().length < 2 || widget.menusOnly) {
      _docs = const [];
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final page = await s.drive.search(q, filters: DriveSearchFilters(), limit: 6);
        if (!mounted || _docQuery != q) return;
        _docs = page.items;
        state.refresh();
      } catch (_) {}
    });
  }

  List<PaletteRow> _rows(BuildContext context, String q, PaletteListState state) {
    final l = WonkyAppLocalizations.of(context);
    final commands = [
      for (final c in s.registry.all)
        if (c.showInPalette && (!widget.menusOnly || widget.menuPaths.containsKey(c.id.value))) c,
    ];
    PaletteRow rowOf(Command<CommandArgs> c, {String? section}) {
      final id = c.id.value;
      final state = s.dispatcher.stateOf(id);
      final path = widget.menuPaths[id];
      return PaletteRow(
        id: id,
        title: c.title(context),
        subtitle: path == null ? c.description(context) : path.join(' › '),
        icon: c.icon,
        shortcut: s.keymap.labelsOf(id),
        enabled: state.enabled,
        disabledReason: state.disabledReason,
        section: section,
        onSelected: () {
          s.noteRecentCommand(id);
          unawaited(
            s.dispatcher
                .invoke(id, source: InvocationSource.palette, context: s.navigatorContext)
                .catchError((Object e) {
                  s.toasts.error(l.commandFailed(id), description: '$e');
                  return const CommandResult.failed('error');
                }),
          );
        },
      );
    }

    if (q.trim().isEmpty) {
      final recent = [
        for (final id in s.recentCommands)
          if (commands.any((c) => c.id.value == id)) commands.firstWhere((c) => c.id.value == id),
      ];
      final rest = [...commands]..sort((a, b) => a.title(context).compareTo(b.title(context)));
      return [
        for (final c in recent) rowOf(c, section: l.paletteRecent),
        for (final c in rest) rowOf(c, section: l.paletteAllCommands),
      ];
    }
    _searchDocs(q, state);
    final ranked = Fuzzy.rank(q, commands, (c) => [
      c.title(context),
      ...?widget.menuPaths[c.id.value]?.let((p) => [p.join(' › ')]),
      ...c.aliases(context),
      ?c.description(context),
      c.id.value,
    ]);
    return [
      for (final c in ranked) rowOf(c, section: widget.menusOnly ? l.paletteMenus : l.paletteCommands),
      for (final d in _docs)
        PaletteRow(
          id: 'doc.${d.uuid.uuid}',
          title: d.name,
          subtitle: l.paletteGoToFile,
          icon: kindIcon(d.kind),
          iconColor: kindColor(d.kind, ShadTheme.of(context).colorScheme),
          section: l.paletteFiles,
          onSelected: () => s.openItem(d),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    return PaletteList(
      placeholder: widget.menusOnly ? l.paletteSearchMenus : l.palettePlaceholder,
      emptyText: l.paletteEmpty,
      rows: (q, state) => _rows(context, q, state),
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
