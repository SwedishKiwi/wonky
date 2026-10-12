import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_ui_localizations.dart';
import '../../theme/wonky_theme.dart';

/// A side panel that can be hosted by [WonkySplitView] (suite 02 §4.5).
class SidePanelSpec {
  const SidePanelSpec({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
    this.minWidth = 280,
    this.defaultWidth = 340,
    this.maxWidth = 720,
    this.headerActions,
  });

  /// Stable id (`comments`, `outline`, `history`, `assistant`, …).
  final String id;
  final String title;
  final IconData icon;
  final double minWidth;
  final double defaultWidth;
  final double maxWidth;
  final WidgetBuilder builder;

  /// Extra buttons in the panel header (before collapse/close).
  final WidgetBuilder? headerActions;
}

/// State of the panel host: the active panel, recently open panels (tabs),
/// rail-collapsed state and per-panel widths.
class WonkySplitViewController extends ChangeNotifier {
  WonkySplitViewController({
    Map<String, double>? widths,
    this.maxRecent = 4,
    this.onWidthChanged,
  }) : _widths = {...?widths};

  final int maxRecent;

  /// Called after the user finishes resizing a panel (persist it).
  final void Function(String panelId, double width)? onWidthChanged;

  String? _active;
  bool _collapsed = false;
  final List<String> _recent = [];
  final Map<String, double> _widths;

  /// The open panel id, or null when the host is closed.
  String? get activePanelId => _active;

  /// Recently open panels, most recent first (shown as header tabs).
  List<String> get recentPanelIds => List.unmodifiable(_recent);

  /// Whether the host is collapsed to an icon rail.
  bool get collapsed => _collapsed;

  bool isOpen(String id) => _active == id && !_collapsed;

  double? widthOf(String id) => _widths[id];

  /// Opens (and expands) [id].
  void open(String id) {
    _active = id;
    _collapsed = false;
    _recent
      ..remove(id)
      ..insert(0, id);
    if (_recent.length > maxRecent) _recent.removeRange(maxRecent, _recent.length);
    notifyListeners();
  }

  /// Closes [id] (or whatever is open when null).
  void close([String? id]) {
    if (id != null && id != _active) {
      if (_recent.remove(id)) notifyListeners();
      return;
    }
    if (_active == null) return;
    _recent.remove(_active);
    _active = null;
    _collapsed = false;
    notifyListeners();
  }

  /// Opens [id], or closes it when it is the open panel.
  void toggle(String id) => isOpen(id) ? close(id) : open(id);

  /// Collapses the host to the icon rail.
  void collapse() {
    if (_active == null || _collapsed) return;
    _collapsed = true;
    notifyListeners();
  }

  /// Expands from the rail.
  void expand() {
    if (!_collapsed) return;
    _collapsed = false;
    notifyListeners();
  }

  /// Moves to the next/previous of the recent panels.
  void cycle(int delta, {List<String>? available}) {
    final ids = available ?? _recent;
    if (ids.isEmpty) return;
    final current = _active == null ? -1 : ids.indexOf(_active!);
    final next = ((current + delta) % ids.length + ids.length) % ids.length;
    final id = ids[next];
    _active = id;
    _collapsed = false;
    if (!_recent.contains(id)) {
      _recent.insert(0, id);
      if (_recent.length > maxRecent) _recent.removeLast();
    }
    notifyListeners();
  }

  void setWidth(String id, double width, {bool commit = false}) {
    _widths[id] = width;
    notifyListeners();
    if (commit) onWidthChanged?.call(id, width);
  }
}

/// Main content plus a right-side panel host. On narrow windows (< md) the
/// panel opens as a sheet over the content. Esc inside the panel closes it.
class WonkySplitView extends StatefulWidget {
  const WonkySplitView({
    super.key,
    required this.child,
    required this.panels,
    required this.controller,
    this.narrowBreakpoint = 768,
  });

  final Widget child;
  final List<SidePanelSpec> panels;
  final WonkySplitViewController controller;
  final double narrowBreakpoint;

  @override
  State<WonkySplitView> createState() => _WonkySplitViewState();
}

class _WonkySplitViewState extends State<WonkySplitView> {
  double? _dragWidth;

  SidePanelSpec? _spec(String? id) {
    if (id == null) return null;
    for (final p in widget.panels) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final c = widget.controller;
          final spec = _spec(c.activePanelId);
          final narrow = constraints.maxWidth < widget.narrowBreakpoint;
          if (spec == null) return widget.child;
          if (c.collapsed && !narrow) {
            return Row(
              children: [
                Expanded(child: widget.child),
                _Rail(controller: c, panels: widget.panels),
              ],
            );
          }
          final panel = _PanelFrame(
            key: ValueKey<String>('panel.${spec.id}'),
            spec: spec,
            controller: c,
            panels: widget.panels,
            narrow: narrow,
          );
          if (narrow) {
            final w = constraints.maxWidth < 420 ? constraints.maxWidth : 380.0;
            return Stack(
              children: [
                Positioned.fill(child: widget.child),
                Positioned.fill(
                  child: GestureDetector(
                    onTap: c.close,
                    child: const ColoredBox(color: Color(0x66000000)),
                  ),
                ),
                Positioned(top: 0, bottom: 0, right: 0, width: w, child: panel),
              ],
            );
          }
          final maxAllowed = (constraints.maxWidth - 320).clamp(
            spec.minWidth,
            spec.maxWidth,
          );
          final width = (_dragWidth ?? c.widthOf(spec.id) ?? spec.defaultWidth)
              .clamp(spec.minWidth, maxAllowed)
              .toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: widget.child),
              _ResizeHandle(
                onDrag: (dx) => setState(() {
                  _dragWidth = ((_dragWidth ?? width) - dx)
                      .clamp(spec.minWidth, maxAllowed)
                      .toDouble();
                }),
                onEnd: () {
                  final w = _dragWidth;
                  _dragWidth = null;
                  if (w != null) c.setWidth(spec.id, w, commit: true);
                },
                onKeyResize: (delta) => c.setWidth(
                  spec.id,
                  (width + delta).clamp(spec.minWidth, maxAllowed).toDouble(),
                  commit: true,
                ),
              ),
              SizedBox(width: width, child: panel),
            ],
          );
        },
      ),
    );
  }
}

class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.onDrag,
    required this.onEnd,
    required this.onKeyResize,
  });

  final ValueChanged<double> onDrag;
  final VoidCallback onEnd;
  final ValueChanged<double> onKeyResize;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l10n = WonkyUiLocalizations.of(context);
    final active = _hover || _focused;
    return Semantics(
      label: l10n.panelResize,
      slider: true,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        mouseCursor: SystemMouseCursors.resizeColumn,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft): _ResizeIntent(24),
          SingleActivator(LogicalKeyboardKey.arrowRight): _ResizeIntent(-24),
        },
        actions: {
          _ResizeIntent: CallbackAction<_ResizeIntent>(
            onInvoke: (i) {
              widget.onKeyResize(i.delta);
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
          onHorizontalDragEnd: (_) => widget.onEnd(),
          onHorizontalDragCancel: widget.onEnd,
          child: SizedBox(
            width: 6,
            child: Center(
              child: Container(
                width: active ? 2 : 1,
                color: active ? theme.colorScheme.ring : theme.colorScheme.border,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResizeIntent extends Intent {
  const _ResizeIntent(this.delta);
  final double delta;
}

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({
    super.key,
    required this.spec,
    required this.controller,
    required this.panels,
    required this.narrow,
  });

  final SidePanelSpec spec;
  final WonkySplitViewController controller;
  final List<SidePanelSpec> panels;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l10n = WonkyUiLocalizations.of(context);
    final recent = [
      for (final id in controller.recentPanelIds)
        for (final p in panels)
          if (p.id == id) p,
    ];
    final motion = WonkyThemeScope.of(context).motion(context);
    Widget content = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        border: narrow
            ? Border(left: BorderSide(color: theme.colorScheme.border))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  if (recent.length > 1)
                    for (final p in recent)
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: ShadTooltip(
                          builder: (_) => Text(p.title),
                          child: ShadIconButton.ghost(
                            key: ValueKey<String>('panel.tab.${p.id}'),
                            width: 30,
                            height: 30,
                            iconSize: 16,
                            semanticLabel: p.title,
                            backgroundColor: p.id == spec.id
                                ? theme.colorScheme.accent
                                : null,
                            icon: Icon(p.icon),
                            onPressed: () => controller.open(p.id),
                          ),
                        ),
                      ),
                  if (recent.length > 1) const SizedBox(width: 6),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        spec.title,
                        style: theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (spec.headerActions != null) spec.headerActions!(context),
                  if (!narrow)
                    ShadTooltip(
                      builder: (_) => Text(l10n.panelCollapse),
                      child: ShadIconButton.ghost(
                        width: 30,
                        height: 30,
                        iconSize: 16,
                        semanticLabel: l10n.panelCollapse,
                        icon: const Icon(LucideIcons.panelRightClose),
                        onPressed: controller.collapse,
                      ),
                    ),
                  ShadTooltip(
                    builder: (_) => Text(l10n.panelClose),
                    child: ShadIconButton.ghost(
                      key: const ValueKey<String>('panel.close'),
                      width: 30,
                      height: 30,
                      iconSize: 16,
                      semanticLabel: l10n.panelClose,
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => controller.close(spec.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ShadSeparator.horizontal(margin: EdgeInsets.zero),
          Expanded(
            child: KeyedSubtree(
              key: PageStorageKey<String>('panel-body-${spec.id}'),
              child: spec.builder(context),
            ),
          ),
        ],
      ),
    );
    content = Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              controller.close(spec.id);
              return null;
            },
          ),
        },
        child: FocusScope(child: content),
      ),
    );
    if (motion == Duration.zero) return content;
    return content.animate().fadeIn(duration: motion).slideX(
      begin: 0.04,
      end: 0,
      duration: motion,
      curve: Curves.easeOut,
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.controller, required this.panels});

  final WonkySplitViewController controller;
  final List<SidePanelSpec> panels;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l10n = WonkyUiLocalizations.of(context);
    final ids = controller.recentPanelIds;
    return Container(
      width: 44,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          ShadTooltip(
            builder: (_) => Text(l10n.panelExpand),
            child: ShadIconButton.ghost(
              width: 32,
              height: 32,
              iconSize: 16,
              semanticLabel: l10n.panelExpand,
              icon: const Icon(LucideIcons.panelRightOpen),
              onPressed: controller.expand,
            ),
          ),
          const SizedBox(height: 4),
          for (final id in ids)
            for (final p in panels)
              if (p.id == id)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: ShadTooltip(
                    builder: (_) => Text(p.title),
                    child: ShadIconButton.ghost(
                      key: ValueKey<String>('panel.rail.${p.id}'),
                      width: 32,
                      height: 32,
                      iconSize: 16,
                      semanticLabel: p.title,
                      icon: Icon(p.icon),
                      onPressed: () => controller.open(p.id),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
