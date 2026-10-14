import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import 'menu_entry.dart';

/// Renders [entries] as shad context-menu items (for `ShadContextMenu`,
/// `ShadContextMenuRegion` and `ShadMenubarItem`).
///
/// The returned list contains a single body widget that adds **type-ahead**:
/// typing letters moves focus to the next item whose label starts with the
/// typed text.
///
/// With [requestFocus], the menu takes keyboard focus when it opens (↑/↓,
/// Home/End move between items; Enter activates).
List<Widget> buildWonkyMenuItems(
  BuildContext context,
  List<WonkyMenuEntry> entries, {
  VoidCallback? onClose,
  bool requestFocus = false,
}) {
  final tidy = entries.tidy();
  if (tidy.isEmpty) return const [];
  return [
    _TypeAheadMenuBody(
      entries: tidy,
      onClose: onClose,
      requestFocus: requestFocus,
    ),
  ];
}

class _TypeAheadMenuBody extends StatefulWidget {
  const _TypeAheadMenuBody({
    required this.entries,
    this.onClose,
    this.requestFocus = false,
  });

  final List<WonkyMenuEntry> entries;
  final VoidCallback? onClose;
  final bool requestFocus;

  @override
  State<_TypeAheadMenuBody> createState() => _TypeAheadMenuBodyState();
}

class _TypeAheadMenuBodyState extends State<_TypeAheadMenuBody> {
  final List<FocusNode> _wrappers = [];
  final List<String> _labels = [];
  final _root = FocusNode(debugLabel: 'menu-body', skipTraversal: true);
  String _typed = '';
  DateTime _lastTyped = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (widget.requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _root.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final n in _wrappers) {
      n.dispose();
    }
    _root.dispose();
    super.dispose();
  }

  bool _focusItem(int i) {
    if (i < 0 || i >= _labels.length || _labels[i].isEmpty) return false;
    final targets = _wrapperAt(i).traversalDescendants;
    if (targets.isEmpty) return false;
    targets.first.requestFocus();
    return true;
  }

  KeyEventResult _move(int delta, {bool fromEdge = false}) {
    final count = _labels.length;
    if (count == 0) return KeyEventResult.ignored;
    var i = fromEdge
        ? (delta > 0 ? -1 : count)
        : _wrappers.indexWhere((w) => w.hasFocus);
    if (i < 0 && !fromEdge) i = delta > 0 ? -1 : count;
    for (var k = 0; k < count; k++) {
      i += delta;
      if (i < 0 || i >= count) {
        // Wrap around.
        i = delta > 0 ? 0 : count - 1;
      }
      if (_focusItem(i)) return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  FocusNode _wrapperAt(int i) {
    while (_wrappers.length <= i) {
      _wrappers.add(
        FocusNode(
          canRequestFocus: false,
          skipTraversal: true,
          debugLabel: 'menu-item-$i',
        ),
      );
    }
    return _wrappers[i];
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) return _move(1);
    if (key == LogicalKeyboardKey.arrowUp) return _move(-1);
    if (key == LogicalKeyboardKey.home) return _move(1, fromEdge: true);
    if (key == LogicalKeyboardKey.end) return _move(-1, fromEdge: true);
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose?.call();
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = event.character;
    if (ch == null || ch.trim().isEmpty || ch.length != 1) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final now = DateTime.now();
    _typed = now.difference(_lastTyped) > const Duration(milliseconds: 800)
        ? ch.toLowerCase()
        : _typed + ch.toLowerCase();
    _lastTyped = now;

    final focusedIndex = _wrappers.indexWhere((w) => w.hasFocus);
    final count = _labels.length;
    // Repeating the same letter cycles through matches.
    final cycling = _typed.length > 1 && _typed.split('').toSet().length == 1;
    final query = cycling ? _typed[0] : _typed;
    final start = cycling || _typed.length == 1
        ? focusedIndex + 1
        : focusedIndex;
    for (var k = 0; k < count; k++) {
      final i = (start + k + count) % count;
      if (i < 0 || _labels[i].isEmpty) continue;
      if (_labels[i].toLowerCase().startsWith(query) && _focusItem(i)) {
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _labels.clear();
    final leading = widget.entries.hasLeading;
    final children = <Widget>[];
    for (var i = 0; i < widget.entries.length; i++) {
      final e = widget.entries[i];
      _labels.add(switch (e) {
        WonkyMenuItem(:final label) when e.enabled => label,
        WonkyMenuSubmenu(:final label) when e.enabled => label,
        _ => '',
      });
      children.add(
        Focus(
          focusNode: _wrapperAt(i),
          canRequestFocus: false,
          skipTraversal: true,
          child: _buildEntry(context, e, leading),
        ),
      );
    }
    return Focus(
      focusNode: _root,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildEntry(BuildContext context, WonkyMenuEntry e, bool leading) {
    final theme = ShadTheme.of(context);
    Widget? lead(IconData? icon) => leading
        ? SizedBox(width: 16, child: icon == null ? null : Icon(icon, size: 16))
        : null;
    switch (e) {
      case WonkyMenuSeparator():
        return const ShadSeparator.horizontal(
          margin: EdgeInsets.symmetric(vertical: 4),
        );
      case WonkyMenuLabel(:final text):
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.mutedForeground,
                fontSize: 12,
              ),
            ),
          ),
        );
      case WonkyMenuCustom(:final builder):
        return builder(context, () => widget.onClose?.call());
      case WonkyMenuSubmenu():
        return _stableEnabled(
          e.key,
          e.enabled,
          (key) => ShadContextMenuItem(
            key: key,
            enabled: e.enabled,
            leading: lead(e.icon),
            trailing: const Icon(LucideIcons.chevronRight, size: 16),
            items: buildWonkyMenuItems(
              context,
              e.children,
              onClose: widget.onClose,
            ),
            child: Text(e.label),
          ),
        );
      case WonkyMenuItem():
        final Widget? leadingWidget = switch (e) {
          WonkyMenuCheckItem(:final checked) => lead(
            checked ? LucideIcons.check : null,
          ),
          WonkyMenuRadioItem(:final selected) =>
            leading
                ? SizedBox(
                    width: 16,
                    child: selected
                        ? Center(
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.foreground,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  )
                : null,
          _ =>
            e.leading != null && leading
                ? SizedBox(width: 16, height: 16, child: e.leading)
                : lead(e.icon),
        };
        final shortcut = e.shortcut;
        Widget item = _stableEnabled(
          e.key,
          e.enabled,
          (key) => ShadContextMenuItem(
            key: key,
            enabled: e.enabled,
            destructive: e.destructive,
            leading: leadingWidget,
            trailing: shortcut == null || shortcut.isEmpty
                ? (e.trailing == null
                      ? null
                      : ExcludeSemantics(child: e.trailing!))
                : ExcludeSemantics(
                    child: ShadKbd.group([
                      for (final k in shortcut) keyCapLabel(k),
                    ], height: 20),
                  ),
            onPressed: e.onSelected,
            child: Text(e.label),
          ),
        );
        final checked = switch (e) {
          WonkyMenuCheckItem(:final checked) => checked,
          WonkyMenuRadioItem(:final selected) => selected,
          _ => null,
        };
        item = Semantics(
          label: e.semanticLabel,
          checked: checked,
          inMutuallyExclusiveGroup: e is WonkyMenuRadioItem ? true : null,
          child: item,
        );
        if (!e.enabled && e.disabledReason != null) {
          item = ShadTooltip(
            builder: (_) => Text(e.disabledReason!),
            child: item,
          );
        }
        return item;
    }
  }
}

/// Builds a shad menu item whose element is recreated when [enabled]
/// changes.
///
/// `ShadButton.didUpdateWidget` pushes a changed `enabled` into the item's
/// shared states controller, which notifies the trailing icon's listener (a
/// sibling, not a descendant) while the menu is being rebuilt — the
/// "setState() or markNeedsBuild() called during build" assertion when a
/// command's enabled state changes while its menu is open. A fresh state
/// applies the disabled state in a post-frame callback instead. [key] (the
/// entry's stable key, used by tests and MCP) stays on the outer subtree.
Widget _stableEnabled(Key? key, bool enabled, Widget Function(Key key) build) =>
    KeyedSubtree(
      key: key,
      child: build(ValueKey<(Key?, bool)>((key, enabled))),
    );

/// The key cap of a logical key name (`Backslash` → a backslash).
String keyCapLabel(String key) => switch (key) {
  'Backslash' => r'\',
  'Slash' => '/',
  'Equal' => '=',
  'Minus' => '−',
  'Period' => '.',
  'Comma' => ',',
  'Semicolon' => ';',
  'Quote' => "'",
  'BracketLeft' => '[',
  'BracketRight' => ']',
  'Backquote' => '`',
  _ => key,
};
