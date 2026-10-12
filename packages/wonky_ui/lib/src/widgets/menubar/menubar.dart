import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../menu/menu_entry.dart';
import '../menu/menu_items.dart';

/// One top-level menu of a [WonkyMenubar].
class WonkyMenubarMenu {
  const WonkyMenubarMenu({
    required this.id,
    required this.label,
    required this.entries,
    this.mnemonic,
  });

  /// Stable id (`file`, `edit`) — key `menubar.<id>`.
  final String id;
  final String label;

  /// Accelerator letter (Alt+letter on Win/Linux, Ctrl+Alt+letter on macOS);
  /// defaults to the first letter of [label].
  final String? mnemonic;

  /// Evaluated when the menu opens, so states are current.
  final List<WonkyMenuEntry> Function() entries;

  String get effectiveMnemonic =>
      (mnemonic ?? (label.isEmpty ? '' : label[0])).toUpperCase();
}

/// Opens menus of a [WonkyMenubar] programmatically (keyboard accelerators,
/// MCP).
class WonkyMenubarController extends ChangeNotifier {
  final ShadMenubarController _shad = ShadMenubarController();
  List<WonkyMenubarMenu> _menus = const [];
  final Map<int, FocusNode> _focus = {};
  bool _keyboard = false;

  /// The open menu id, or null.
  String? get openMenuId {
    final i = _shad.selectedIndex;
    return i == null || i >= _menus.length ? null : _menus[i].id;
  }

  /// Opens the menu [id] and focuses its trigger. Returns false when absent.
  bool open(String id) {
    final i = _menus.indexWhere((m) => m.id == id);
    if (i < 0) return false;
    _keyboard = true;
    _shad.selectedIndex = i;
    _focus[i]?.requestFocus();
    notifyListeners();
    return true;
  }

  /// Opens the menu whose mnemonic is [letter].
  bool openByMnemonic(String letter) {
    final up = letter.toUpperCase();
    for (final m in _menus) {
      if (m.effectiveMnemonic == up) return open(m.id);
    }
    return false;
  }

  /// Closes any open menu.
  void close() {
    _keyboard = false;
    _shad.selectedIndex = null;
    notifyListeners();
  }

  FocusNode _focusAt(int i) =>
      _focus.putIfAbsent(i, () => FocusNode(debugLabel: 'menubar-$i'));

  @override
  void dispose() {
    _shad.dispose();
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }
}

/// A `ShadMenubar` built from declarative menus (suite 02 §4.3). In
/// `wonky_app`, the menus come from a `MenuSpec` tree resolved against the
/// command registry.
class WonkyMenubar extends StatefulWidget {
  const WonkyMenubar({
    super.key,
    required this.menus,
    this.controller,
    this.height = 32,
  });

  final List<WonkyMenubarMenu> menus;
  final WonkyMenubarController? controller;
  final double height;

  @override
  State<WonkyMenubar> createState() => _WonkyMenubarState();
}

class _WonkyMenubarState extends State<WonkyMenubar> {
  WonkyMenubarController? _own;

  WonkyMenubarController get _controller =>
      widget.controller ?? (_own ??= WonkyMenubarController());

  @override
  void initState() {
    super.initState();
    _controller._shad.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(WonkyMenubar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)?._shad.removeListener(_rebuild);
      _controller._shad.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _controller._shad.removeListener(_rebuild);
    _own?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller.._menus = widget.menus;
    final selected = controller._shad.selectedIndex;
    final theme = ShadTheme.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: ShadMenubar(
        controller: controller._shad,
        border: ShadBorder.none,
        padding: EdgeInsets.zero,
        backgroundColor: const Color(0x00000000),
        items: [
          for (var i = 0; i < widget.menus.length; i++)
            ShadMenubarItem(
              key: ValueKey<String>('menubar.${widget.menus[i].id}'),
              focusNode: controller._focusAt(i),
              height: widget.height - 4,
              buttonPadding: const EdgeInsets.symmetric(horizontal: 8),
              constraints: const BoxConstraints(minWidth: 240),
              items: selected == i
                  ? buildWonkyMenuItems(
                      context,
                      widget.menus[i].entries(),
                      onClose: controller.close,
                      requestFocus: controller._keyboard,
                    )
                  : const [SizedBox.shrink()],
              child: Text(
                widget.menus[i].label,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
