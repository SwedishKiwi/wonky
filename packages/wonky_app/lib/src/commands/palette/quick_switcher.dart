import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';

import '../../branding/product_icon.dart';
import '../../drive/drive_format.dart';
import '../../l10n/wonky_app_localizations.dart';
import '../../shell/shell_services.dart';
import 'palette_list.dart';

/// Quick switcher (`Mod+O`, suite 03 §1): recent files of both kinds plus
/// drive search; Enter opens in the same window.
Future<void> showQuickSwitcher(BuildContext context, ShellServices s) =>
    showShadDialog<void>(
      context: context,
      builder: (context) => ShadDialog(
        key: const ValueKey<String>('quickSwitcher'),
        padding: const EdgeInsets.all(12),
        // Esc closes; a close button would overlap the search field.
        closeIcon: const SizedBox.shrink(),
        constraints: const BoxConstraints(maxWidth: 620),
        child: SizedBox(width: 600, child: _QuickSwitcher(services: s)),
      ),
    );

class _QuickSwitcher extends StatefulWidget {
  const _QuickSwitcher({required this.services});

  final ShellServices services;

  @override
  State<_QuickSwitcher> createState() => _QuickSwitcherState();
}

class _QuickSwitcherState extends State<_QuickSwitcher> {
  List<DriveItemView> _recent = const [];
  List<DriveItemView> _results = const [];
  String _q = '';
  Timer? _debounce;
  PaletteListState? _list;

  @override
  void initState() {
    super.initState();
    widget.services.drive
        .list(
          filter: DriveListFilter(view: DriveView.recent),
          sort: DriveSort(field: DriveSortField.lastOpenedByMe),
          limit: 20,
        )
        .then((p) {
          if (!mounted) return;
          _recent = [
            for (final i in p.items)
              if (i.kind != DriveItemKind.folder) i,
          ];
          _list?.refresh();
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String q) {
    if (q == _q) return;
    _q = q;
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      _results = const [];
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final p = await widget.services.drive.search(
          q,
          filters: DriveSearchFilters(),
          limit: 20,
        );
        if (!mounted || q != _q) return;
        _results = p.items;
        _list?.refresh();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    return PaletteList(
      keyPrefix: 'quickSwitcher',
      placeholder: l.quickSwitcherPlaceholder,
      emptyText: l.quickSwitcherEmpty,
      rows: (q, state) {
        _list = state;
        _search(q);
        final local = q.trim().isEmpty
            ? _recent
            : [
                for (final i in _recent)
                  if (i.name.toLowerCase().contains(q.toLowerCase())) i,
              ];
        final seen = <String>{};
        final items = [
          for (final i in [...local, ..._results])
            if (seen.add(i.uuid.uuid)) i,
        ];
        return [
          for (final i in items)
            PaletteRow(
              id: i.uuid.uuid,
              title: i.name,
              subtitle: '${describeKind(l, i.kind)} · ${i.owner.displayName}',
              leading: DriveKindIcon(i.kind, size: 18),
              section: q.trim().isEmpty
                  ? l.quickSwitcherRecent
                  : l.quickSwitcherResults,
              onSelected: () => widget.services.openItem(i),
            ),
        ];
      },
    );
  }
}
