import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import 'menu_entry.dart';
import 'menu_items.dart';

/// Builds the trigger of a [WonkyDropdownMenu].
typedef WonkyDropdownTriggerBuilder =
    Widget Function(BuildContext context, ShadContextMenuController controller);

/// A dropdown menu anchored below its trigger (toolbar dropdowns, ⋮ menus,
/// account menu) — a thin wrapper over `ShadContextMenu` with a controller
/// and an anchor (suite 02 §4.2).
///
/// [entries] is evaluated each time the menu builds so enabled/checked
/// states are always current.
class WonkyDropdownMenu extends StatefulWidget {
  const WonkyDropdownMenu({
    super.key,
    required this.entries,
    required this.builder,
    this.controller,
    this.anchor,
    this.constraints,
    this.onOpenChanged,
  });

  final List<WonkyMenuEntry> Function() entries;
  final WonkyDropdownTriggerBuilder builder;
  final ShadContextMenuController? controller;

  /// Defaults to below the trigger, start-aligned.
  final ShadAnchorBase? anchor;
  final BoxConstraints? constraints;
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<WonkyDropdownMenu> createState() => _WonkyDropdownMenuState();
}

class _WonkyDropdownMenuState extends State<WonkyDropdownMenu> {
  ShadContextMenuController? _own;
  bool _wasOpen = false;

  ShadContextMenuController get _controller =>
      widget.controller ?? (_own ??= ShadContextMenuController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(WonkyDropdownMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)?.removeListener(_onChanged);
      _controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _own?.dispose();
    super.dispose();
  }

  void _onChanged() {
    final open = _controller.isOpen;
    if (open != _wasOpen) {
      _wasOpen = open;
      widget.onOpenChanged?.call(open);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = _controller.isOpen
        ? buildWonkyMenuItems(
            context,
            widget.entries(),
            onClose: _controller.hide,
            requestFocus: true,
          )
        : const <Widget>[SizedBox.shrink()];
    return ShadContextMenu(
      controller: _controller,
      anchor:
          widget.anchor ??
          const ShadAnchor(
            childAlignment: AlignmentDirectional.bottomStart,
            overlayAlignment: AlignmentDirectional.topStart,
            offset: Offset(0, 4),
          ),
      constraints: widget.constraints ?? const BoxConstraints(minWidth: 200),
      items: items,
      onTapOutside: (_) => _controller.hide(),
      child: Builder(
        builder: (context) => widget.builder(context, _controller),
      ),
    );
  }
}

/// Wraps [child] so right-click / long-press opens a context menu built from
/// [entries] (suite 02 §3 `ShadContextMenuRegion`).
class WonkyContextMenuRegion extends StatelessWidget {
  const WonkyContextMenuRegion({
    super.key,
    required this.entries,
    required this.child,
    this.enabled = true,
    this.onOpen,
  });

  final List<WonkyMenuEntry> Function() entries;
  final Widget child;
  final bool enabled;

  /// Called before the menu opens (e.g. to select the row under the pointer).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return _LazyContextMenuRegion(
      entries: entries,
      onOpen: onOpen,
      child: child,
    );
  }
}

class _LazyContextMenuRegion extends StatefulWidget {
  const _LazyContextMenuRegion({
    required this.entries,
    required this.child,
    this.onOpen,
  });

  final List<WonkyMenuEntry> Function() entries;
  final Widget child;
  final VoidCallback? onOpen;

  @override
  State<_LazyContextMenuRegion> createState() => _LazyContextMenuRegionState();
}

class _LazyContextMenuRegionState extends State<_LazyContextMenuRegion> {
  final _controller = ShadContextMenuController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadContextMenuRegion(
      controller: _controller,
      constraints: const BoxConstraints(minWidth: 220),
      items: [
        if (_controller.isOpen)
          ...buildWonkyMenuItems(
            context,
            widget.entries(),
            onClose: _controller.hide,
          )
        else
          const SizedBox.shrink(),
      ],
      child: Listener(
        onPointerDown: (e) {
          if (e.buttons == 2) widget.onOpen?.call();
        },
        child: widget.child,
      ),
    );
  }
}
