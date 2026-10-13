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
    this.headerActions,
    this.showAsTab = true,
  });

  /// Stable id (`comments`, `outline`, `history`, `assistant`, …).
  final String id;

  /// Tooltip of its icon and semantics label of the panel (not shown as a
  /// heading).
  final String title;
  final IconData icon;
  final WidgetBuilder builder;

  /// Extra buttons in the panel header (before collapse).
  final WidgetBuilder? headerActions;

  /// Whether the panel is one of the icons that switch between panels (in
  /// the header and the collapsed rail); false for panels opened only by
  /// their command (e.g. file details).
  final bool showAsTab;
}

/// State of the panel host: the open panel (or none: collapsed to the icon
/// rail), recently open panels and the panel width, shared by every panel.
class WonkySplitViewController extends ChangeNotifier {
  WonkySplitViewController({
    double? width,
    this.maxRecent = 4,
    this.onWidthChanged,
  }) {
    _width = width;
  }

  /// Width of a panel unless resized (every panel has the same width).
  static const double defaultWidth = 360;
  static const double minWidth = 300;
  static const double maxWidth = 640;

  final int maxRecent;

  /// Called after the user finishes resizing the panel (persist it).
  final void Function(double width)? onWidthChanged;

  String? _active;
  final List<String> _recent = [];
  double? _width;

  /// The open panel id, or null when the host is collapsed.
  String? get activePanelId => _active;

  /// Recently open panels, most recent first.
  List<String> get recentPanelIds => List.unmodifiable(_recent);

  bool isOpen(String id) => _active == id;

  /// The panel width (all panels).
  double get width => _width ?? defaultWidth;

  /// Opens [id].
  void open(String id) {
    _active = id;
    _recent
      ..remove(id)
      ..insert(0, id);
    if (_recent.length > maxRecent) {
      _recent.removeRange(maxRecent, _recent.length);
    }
    notifyListeners();
  }

  /// Collapses [id] (or whatever is open when null) to the icon rail.
  void close([String? id]) {
    if (id != null && id != _active) {
      if (_recent.remove(id)) notifyListeners();
      return;
    }
    if (_active == null) return;
    _recent.remove(_active);
    _active = null;
    notifyListeners();
  }

  /// Opens [id], or collapses it when it is the open panel.
  void toggle(String id) => isOpen(id) ? close(id) : open(id);

  /// Moves to the next/previous of the recent panels.
  void cycle(int delta, {List<String>? available}) {
    final ids = available ?? _recent;
    if (ids.isEmpty) return;
    final current = _active == null ? -1 : ids.indexOf(_active!);
    final next = ((current + delta) % ids.length + ids.length) % ids.length;
    final id = ids[next];
    _active = id;
    if (!_recent.contains(id)) {
      _recent.insert(0, id);
      if (_recent.length > maxRecent) _recent.removeLast();
    }
    notifyListeners();
  }

  void setWidth(double width, {bool commit = false}) {
    _width = width;
    notifyListeners();
    if (commit) onWidthChanged?.call(width);
  }
}

/// Main content plus a right-side panel host (suite 02 §4.5). A panel is
/// open next to the content or collapsed: with [rail], collapsed panels show
/// as a vertical column of icons at the right edge (one click opens one);
/// without it (a single panel, e.g. the drive's details), collapsed means
/// hidden. On narrow windows (< [narrowBreakpoint]) the open panel is a
/// sheet over the content. Esc inside the panel collapses it.
class WonkySplitView extends StatefulWidget {
  const WonkySplitView({
    super.key,
    required this.child,
    required this.panels,
    required this.controller,
    this.narrowBreakpoint = 768,
    this.rail = true,
  });

  final Widget child;
  final List<SidePanelSpec> panels;
  final WonkySplitViewController controller;
  final double narrowBreakpoint;

  /// Whether collapsed panels show as an icon rail.
  final bool rail;

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
          final tabs = [
            for (final p in widget.panels)
              if (p.showAsTab) p,
          ];
          final rail = widget.rail && tabs.isNotEmpty;
          final collapsed = rail
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: widget.child),
                    _Rail(controller: c, panels: tabs),
                  ],
                )
              : widget.child;
          if (spec == null) return collapsed;
          final panel = _PanelFrame(
            key: ValueKey<String>('panel.${spec.id}'),
            spec: spec,
            controller: c,
            tabs: tabs,
            narrow: narrow,
            collapsible: rail,
          );
          if (narrow) {
            final w = constraints.maxWidth < 420 ? constraints.maxWidth : 380.0;
            return Stack(
              children: [
                Positioned.fill(child: collapsed),
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
            WonkySplitViewController.minWidth,
            WonkySplitViewController.maxWidth,
          );
          final width = (_dragWidth ?? c.width)
              .clamp(WonkySplitViewController.minWidth, maxAllowed)
              .toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: widget.child),
              _ResizeHandle(
                onDrag: (dx) => setState(() {
                  _dragWidth = ((_dragWidth ?? width) - dx)
                      .clamp(WonkySplitViewController.minWidth, maxAllowed)
                      .toDouble();
                }),
                onEnd: () {
                  final w = _dragWidth;
                  _dragWidth = null;
                  if (w != null) c.setWidth(w, commit: true);
                },
                onKeyResize: (delta) => c.setWidth(
                  (width + delta)
                      .clamp(WonkySplitViewController.minWidth, maxAllowed)
                      .toDouble(),
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
          // The panel's single left border: the line sits at the handle's
          // left edge and the rest of the hit area is panel background (a
          // centered line read as a double border against the canvas).
          child: Container(
            width: 6,
            color: theme.colorScheme.background,
            alignment: Alignment.centerLeft,
            child: Container(
              width: active ? 2 : 1,
              color: active ? theme.colorScheme.ring : theme.colorScheme.border,
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
    required this.tabs,
    required this.narrow,
    required this.collapsible,
  });

  final SidePanelSpec spec;
  final WonkySplitViewController controller;
  final List<SidePanelSpec> tabs;
  final bool narrow;

  /// Collapses to the rail (otherwise the button closes the panel).
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l10n = WonkyUiLocalizations.of(context);
    final motion = WonkyThemeScope.of(context).motion(context);
    final closeLabel = collapsible ? l10n.panelCollapse : l10n.panelClose;
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
          // Icons only: the open panel's icon is highlighted; its name is
          // the icon's tooltip (no heading).
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  for (final p
                      in tabs.length > 1 || !tabs.contains(spec)
                          ? tabs
                          : const <SidePanelSpec>[])
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: _PanelIconButton(
                        key: ValueKey<String>('panel.tab.${p.id}'),
                        spec: p,
                        active: p.id == spec.id,
                        onPressed: () => controller.open(p.id),
                      ),
                    ),
                  const Spacer(),
                  if (spec.headerActions != null) spec.headerActions!(context),
                  ShadTooltip(
                    builder: (_) => Text(closeLabel),
                    child: ShadIconButton.ghost(
                      key: ValueKey<String>(
                        collapsible ? 'panel.collapse' : 'panel.close',
                      ),
                      width: 30,
                      height: 30,
                      iconSize: 16,
                      semanticLabel: closeLabel,
                      icon: Icon(
                        collapsible
                            ? LucideIcons.panelRightClose
                            : LucideIcons.x,
                      ),
                      onPressed: () => controller.close(spec.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ShadSeparator.horizontal(margin: EdgeInsets.zero),
          Expanded(
            child: Semantics(
              container: true,
              label: spec.title,
              child: KeyedSubtree(
                key: PageStorageKey<String>('panel-body-${spec.id}'),
                child: spec.builder(context),
              ),
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
    return content
        .animate()
        .fadeIn(duration: motion)
        .slideX(begin: 0.04, end: 0, duration: motion, curve: Curves.easeOut);
  }
}

/// A panel's icon button (header and rail); highlighted when it is open.
class _PanelIconButton extends StatelessWidget {
  const _PanelIconButton({
    super.key,
    required this.spec,
    required this.active,
    required this.onPressed,
  });

  final SidePanelSpec spec;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadTooltip(
      builder: (_) => Text(spec.title),
      child: ShadIconButton.ghost(
        width: 32,
        height: 32,
        iconSize: 16,
        semanticLabel: spec.title,
        backgroundColor: active ? theme.colorScheme.accent : null,
        icon: Icon(spec.icon),
        onPressed: onPressed,
      ),
    );
  }
}

/// The collapsed panels: one icon per panel in a column at the right edge.
class _Rail extends StatelessWidget {
  const _Rail({required this.controller, required this.panels});

  final WonkySplitViewController controller;
  final List<SidePanelSpec> panels;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      key: const ValueKey<String>('panel.rail'),
      width: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        border: Border(left: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          for (final p in panels)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _PanelIconButton(
                key: ValueKey<String>('panel.rail.${p.id}'),
                spec: p,
                active: false,
                onPressed: () => controller.open(p.id),
              ),
            ),
        ],
      ),
    );
  }
}
