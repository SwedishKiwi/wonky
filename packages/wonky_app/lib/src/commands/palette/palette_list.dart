import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// One row of a [PaletteList].
class PaletteRow {
  const PaletteRow({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.shortcut,
    this.enabled = true,
    this.disabledReason,
    this.section,
    required this.onSelected,
  });

  final String id;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final List<String>? shortcut;
  final bool enabled;
  final String? disabledReason;

  /// Section header shown before the first row of a new section.
  final String? section;
  final VoidCallback onSelected;
}

/// The search dialog body shared by the command palette and the quick
/// switcher: input, sectioned list, ↑/↓/Enter/Esc.
class PaletteList extends StatefulWidget {
  const PaletteList({
    super.key,
    required this.placeholder,
    required this.rows,
    this.emptyText,
    this.initialQuery = '',
    this.keyPrefix = 'palette',
  });

  final String placeholder;

  /// Rows for a query (sync; may also kick off async loads and call
  /// [PaletteListState.refresh]).
  final List<PaletteRow> Function(String query, PaletteListState state) rows;
  final String? emptyText;
  final String initialQuery;
  final String keyPrefix;

  @override
  State<PaletteList> createState() => PaletteListState();
}

class PaletteListState extends State<PaletteList> {
  late final _query = TextEditingController(text: widget.initialQuery);
  final _scroll = ScrollController();
  int _index = 0;

  String get query => _query.text;

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _move(List<PaletteRow> rows, int delta) {
    if (rows.isEmpty) return;
    setState(() => _index = (_index + delta) % rows.length);
    final top = _index * 40.0;
    if (_scroll.hasClients) {
      final p = _scroll.position;
      if (top < p.pixels) _scroll.jumpTo(top);
      if (top + 40 > p.pixels + p.viewportDimension) {
        _scroll.jumpTo(top + 40 - p.viewportDimension);
      }
    }
  }

  void _run(PaletteRow r) {
    if (!r.enabled) return;
    Navigator.of(context).pop();
    r.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final rows = widget.rows(_query.text, this);
    if (_index >= rows.length) _index = rows.isEmpty ? 0 : rows.length - 1;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _move(rows, 1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _move(rows, -1),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (rows.isNotEmpty) _run(rows[_index]);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadInput(
            key: ValueKey<String>('${widget.keyPrefix}.input'),
            controller: _query,
            autofocus: true,
            placeholder: Text(widget.placeholder),
            leading: const Icon(LucideIcons.search, size: 16),
            onChanged: (_) => setState(() => _index = 0),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400, minHeight: 80),
            child: rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        widget.emptyText ?? '',
                        style: theme.textTheme.muted,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      final header =
                          r.section != null &&
                          (i == 0 || rows[i - 1].section != r.section);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (header)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                              child: Text(
                                r.section!,
                                style: theme.textTheme.muted.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          _Row(
                            key: ValueKey<String>(
                              '${widget.keyPrefix}.row.${r.id}',
                            ),
                            row: r,
                            highlighted: i == _index,
                            onTap: () => _run(r),
                            onHover: () => setState(() => _index = i),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.row,
    required this.highlighted,
    required this.onTap,
    required this.onHover,
  });

  final PaletteRow row;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final fg = row.enabled
        ? theme.colorScheme.foreground
        : theme.colorScheme.mutedForeground;
    Widget content = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: highlighted ? theme.colorScheme.accent : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: row.icon == null
                ? null
                : Icon(row.icon, size: 16, color: row.iconColor ?? fg),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    color: fg,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                if (row.subtitle != null)
                  Text(
                    row.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.muted.copyWith(fontSize: 11),
                  ),
              ],
            ),
          ),
          if (row.shortcut != null && row.shortcut!.isNotEmpty)
            ShadKbd.group(row.shortcut!, height: 20),
        ],
      ),
    );
    if (!row.enabled && row.disabledReason != null) {
      content = ShadTooltip(
        builder: (_) => Text(row.disabledReason!),
        child: content,
      );
    }
    return Semantics(
      button: true,
      enabled: row.enabled,
      selected: highlighted,
      label: row.title,
      child: MouseRegion(
        onHover: (_) => onHover(),
        cursor: row.enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(onTap: onTap, child: content),
      ),
    );
  }
}
