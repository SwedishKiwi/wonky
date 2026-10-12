import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_ui_localizations.dart';
import '../../theme/wonky_theme.dart';
import '../menu/dropdown_menu.dart';
import '../menu/menu_entry.dart';
import '../number_stepper/number_stepper.dart';
import 'overflow_layout.dart';

/// One item of a [WonkyToolbar] (suite 02 §4.1).
///
/// [priority]: lower numbers are more important; when the toolbar is too
/// narrow, items with the highest number move into the "⋯" overflow menu
/// first. [pinned] items never overflow.
abstract class ToolbarItem {
  const ToolbarItem({this.id, this.priority = 3, this.pinned = false});

  /// Stable id; also used as the widget key (`write.toolbar.bold`).
  final String? id;
  final int priority;
  final bool pinned;

  /// The inline control.
  Widget build(BuildContext context);

  /// How the item appears in the overflow menu.
  List<WonkyMenuEntry> overflowEntries(BuildContext context);
}

/// A group of items, separated from its neighbours by a vertical separator.
class ToolbarGroup {
  const ToolbarGroup(this.items, {this.id});

  final String? id;
  final List<ToolbarItem> items;
}

/// Tooltip content: title plus the shortcut in `ShadKbd`s.
class ToolbarTooltipContent extends StatelessWidget {
  const ToolbarTooltipContent({super.key, required this.label, this.shortcut});

  final String label;
  final List<String>? shortcut;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (shortcut != null && shortcut!.isNotEmpty) ...[
          const SizedBox(width: 8),
          ShadKbd.group(shortcut!, height: 18),
        ],
      ],
    );
  }
}

/// A plain icon button.
class ToolbarButton extends ToolbarItem {
  const ToolbarButton({
    super.id,
    super.priority,
    super.pinned,
    required this.icon,
    required this.label,
    this.shortcut,
    this.onPressed,
    this.onLongPress,
    this.onSecondaryTap,
    this.enabled = true,
    this.disabledReason,
  });

  final IconData icon;
  final String label;
  final List<String>? shortcut;
  final VoidCallback? onPressed;

  /// E.g. press-and-hold Undo opens the history popover.
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final bool enabled;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final size = WonkyThemeScope.of(context).toolbarButtonSize;
    return ShadTooltip(
      builder: (_) => ToolbarTooltipContent(
        label: enabled ? label : (disabledReason ?? label),
        shortcut: enabled ? shortcut : null,
      ),
      child: ToolbarEscapeScope(
        child: ShadIconButton.ghost(
          key: id == null ? null : ValueKey<String>(id!),
          icon: Icon(icon, size: 16),
          width: size,
          height: size,
          semanticLabel: label,
          enabled: enabled && onPressed != null,
          onPressed: onPressed,
          onLongPress: onLongPress,
          longPressDuration: const Duration(milliseconds: 500),
          onSecondaryTapUp: onSecondaryTap == null
              ? null
              : (_) => onSecondaryTap!(),
        ),
      ),
    );
  }

  @override
  List<WonkyMenuEntry> overflowEntries(BuildContext context) => [
    WonkyMenuItem(
      label: label,
      icon: icon,
      shortcut: shortcut,
      enabled: enabled && onPressed != null,
      disabledReason: disabledReason,
      onSelected: onPressed,
    ),
  ];
}

/// A toggle (bold, italic …) — wraps `ShadToggle`, 28×28.
class ToolbarToggleButton extends ToolbarItem {
  const ToolbarToggleButton({
    super.id,
    super.priority,
    super.pinned,
    required this.icon,
    required this.label,
    required this.value,
    this.onChanged,
    this.shortcut,
    this.enabled = true,
    this.disabledReason,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final List<String>? shortcut;
  final bool enabled;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final size = WonkyThemeScope.of(context).toolbarButtonSize;
    return ShadTooltip(
      builder: (_) => ToolbarTooltipContent(
        label: enabled ? label : (disabledReason ?? label),
        shortcut: enabled ? shortcut : null,
      ),
      child: ToolbarEscapeScope(
        child: ShadToggle(
          key: id == null ? null : ValueKey<String>(id!),
          value: value,
          enabled: enabled && onChanged != null,
          onChanged: onChanged,
          width: size,
          height: size,
          padding: EdgeInsets.zero,
          semanticLabel: label,
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }

  @override
  List<WonkyMenuEntry> overflowEntries(BuildContext context) => [
    WonkyMenuCheckItem(
      label: label,
      checked: value,
      shortcut: shortcut,
      enabled: enabled && onChanged != null,
      disabledReason: disabledReason,
      onSelected: onChanged == null ? null : () => onChanged!(!value),
    ),
  ];
}

/// Label + chevron that opens a dropdown menu (styles, zoom, insert …).
class ToolbarDropdownButton extends ToolbarItem {
  const ToolbarDropdownButton({
    super.id,
    super.priority,
    super.pinned,
    required this.label,
    required this.entries,
    this.icon,
    this.tooltip,
    this.minWidth,
    this.enabled = true,
  });

  /// The current value shown in the button ("Normal text", "100%").
  final String label;
  final IconData? icon;

  /// Accessible name / tooltip ("Styles"); defaults to [label].
  final String? tooltip;
  final List<WonkyMenuEntry> Function() entries;
  final double? minWidth;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final size = WonkyThemeScope.of(context).toolbarButtonSize;
    return WonkyDropdownMenu(
      entries: entries,
      builder: (context, controller) => ShadTooltip(
        builder: (_) => Text(tooltip ?? label),
        child: ToolbarEscapeScope(
          child: ShadButton.ghost(
            key: id == null ? null : ValueKey<String>(id!),
            height: size,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            enabled: enabled,
            onPressed: controller.toggle,
            leading: icon == null ? null : Icon(icon, size: 16),
            trailing: Icon(
              LucideIcons.chevronDown,
              size: 14,
              color: theme.colorScheme.mutedForeground,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth ?? 0),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  List<WonkyMenuEntry> overflowEntries(BuildContext context) => [
    WonkyMenuSubmenu(
      label: tooltip ?? label,
      icon: icon,
      enabled: enabled,
      children: entries(),
    ),
  ];
}

/// An action button with an attached chevron that opens a menu or a custom
/// popover (text color, borders, insert chart).
class ToolbarSplitButton extends ToolbarItem {
  const ToolbarSplitButton({
    super.id,
    super.priority,
    super.pinned,
    required this.icon,
    required this.label,
    this.onPressed,
    required this.entries,
    this.indicatorColor,
    this.shortcut,
    this.enabled = true,
  });

  final IconData icon;
  final String label;

  /// Repeats the last choice (e.g. apply the last used color).
  final VoidCallback? onPressed;
  final List<WonkyMenuEntry> Function() entries;

  /// A color bar under the icon (current text / fill color).
  final Color? indicatorColor;
  final List<String>? shortcut;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final size = WonkyThemeScope.of(context).toolbarButtonSize;
    Widget iconWidget = Icon(icon, size: 16);
    if (indicatorColor != null) {
      iconWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: 1),
          Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
              color: indicatorColor,
              border: Border.all(color: theme.colorScheme.border, width: 0.5),
            ),
          ),
        ],
      );
    }
    return Row(
      key: id == null ? null : ValueKey<String>(id!),
      mainAxisSize: MainAxisSize.min,
      children: [
        ShadTooltip(
          builder: (_) =>
              ToolbarTooltipContent(label: label, shortcut: shortcut),
          child: ToolbarEscapeScope(
            child: ShadButton.ghost(
              width: size,
              height: size,
              padding: EdgeInsets.zero,
              enabled: enabled && onPressed != null,
              onPressed: onPressed,
              child: Semantics(label: label, child: iconWidget),
            ),
          ),
        ),
        WonkyDropdownMenu(
          entries: entries,
          builder: (context, controller) => ToolbarEscapeScope(
            child: ShadButton.ghost(
              width: 16,
              height: size,
              padding: EdgeInsets.zero,
              enabled: enabled,
              onPressed: controller.toggle,
              child: Semantics(
                label: label,
                button: true,
                child: Icon(
                  LucideIcons.chevronDown,
                  size: 12,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  List<WonkyMenuEntry> overflowEntries(BuildContext context) => [
    WonkyMenuSubmenu(
      label: label,
      icon: icon,
      enabled: enabled,
      children: entries(),
    ),
  ];
}

/// Font-size style field: − / input / +.
class ToolbarNumberField extends ToolbarItem {
  const ToolbarNumberField({
    super.id,
    super.priority,
    super.pinned,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 400,
    this.step = 1,
    this.fractionDigits = 0,
    this.enabled = true,
  });

  final String label;
  final num? value;
  final ValueChanged<num> onChanged;
  final num min;
  final num max;
  final num step;
  final int fractionDigits;
  final bool enabled;

  @override
  Widget build(BuildContext context) => WonkyNumberStepper(
    key: id == null ? null : ValueKey<String>(id!),
    value: value,
    min: min,
    max: max,
    step: step,
    fractionDigits: fractionDigits,
    enabled: enabled,
    dense: true,
    semanticLabel: label,
    onChanged: onChanged,
  );

  @override
  List<WonkyMenuEntry> overflowEntries(BuildContext context) => [
    WonkyMenuLabel(label),
    WonkyMenuCustom(
      label: label,
      builder: (context, close) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: WonkyNumberStepper(
          value: value,
          min: min,
          max: max,
          step: step,
          fractionDigits: fractionDigits,
          enabled: enabled,
          dense: true,
          semanticLabel: label,
          onChanged: onChanged,
        ),
      ),
    ),
  ];
}

/// A compact select (zoom, styles) with typed options.
class ToolbarSelect<T> extends ToolbarItem {
  const ToolbarSelect({
    super.id,
    super.priority,
    super.pinned,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.minWidth = 72,
    this.enabled = true,
  });

  final String label;
  final T value;

  /// value → display label.
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final double minWidth;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final size = WonkyThemeScope.of(context).toolbarButtonSize;
    return Semantics(
      label: label,
      child: SizedBox(
        height: size + 4,
        child: ShadSelect<T>(
          key: id == null ? null : ValueKey<String>(id!),
          minWidth: minWidth,
          enabled: enabled,
          initialValue: value,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          options: [
            for (final e in options.entries)
              ShadOption<T>(value: e.key, child: Text(e.value)),
          ],
          selectedOptionBuilder: (context, v) => Text(options[v] ?? '$v'),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  @override
  List<WonkyMenuEntry> overflowEntries(BuildContext context) => [
    WonkyMenuSubmenu(
      label: label,
      enabled: enabled,
      children: [
        for (final e in options.entries)
          WonkyMenuRadioItem(
            label: e.value,
            selected: e.key == value,
            onSelected: () => onChanged(e.key),
          ),
      ],
    ),
  ];
}

/// Any custom control.
class ToolbarCustom extends ToolbarItem {
  const ToolbarCustom({
    super.id,
    super.priority,
    super.pinned,
    required this.builder,
    this.overflow = const [],
  });

  final WidgetBuilder builder;
  final List<WonkyMenuEntry> overflow;

  @override
  Widget build(BuildContext context) => builder(context);

  @override
  List<WonkyMenuEntry> overflowEntries(BuildContext context) => overflow;
}

/// Controls focus of a [WonkyToolbar] (`Alt+/` focuses it, Esc returns).
class WonkyToolbarController {
  _WonkyToolbarState? _state;

  /// Moves focus to the first visible toolbar control.
  void focus() => _state?._focusFirst();

  /// Whether focus is inside the toolbar.
  bool get hasFocus => _state?._scope.hasFocus ?? false;
}

/// Horizontal formatting toolbar with overflow handling (suite 02 §4.1).
///
/// Arrow keys move between controls; Esc calls [onEscape] (return focus to
/// the editor). Height 40 px (36 when compact).
class WonkyToolbar extends StatefulWidget {
  const WonkyToolbar({
    super.key,
    required this.groups,
    this.trailing = const [],
    this.controller,
    this.onEscape,
    this.semanticLabel,
    this.padding = const EdgeInsets.symmetric(horizontal: 6),
  });

  final List<ToolbarGroup> groups;

  /// Items right-aligned outside the overflow area (never overflow).
  final List<ToolbarItem> trailing;
  final WonkyToolbarController? controller;
  final VoidCallback? onEscape;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  State<WonkyToolbar> createState() => _WonkyToolbarState();
}

class _WonkyToolbarState extends State<WonkyToolbar> {
  final _scope = FocusScopeNode(debugLabel: 'WonkyToolbar');
  Set<int> _hidden = const {};

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(WonkyToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _scope.dispose();
    super.dispose();
  }

  void _focusFirst() {
    final ctx = _scope.context;
    if (ctx == null) return;
    final policy =
        FocusTraversalGroup.maybeOf(ctx) ?? ReadingOrderTraversalPolicy();
    final first = policy.findFirstFocus(_scope);
    first?.requestFocus();
  }

  void _onHiddenChanged(Set<int> hidden) {
    if (!mounted) return;
    setState(() => _hidden = hidden);
  }

  @override
  Widget build(BuildContext context) {
    final ext = WonkyThemeScope.of(context);
    final l10n = WonkyUiLocalizations.of(context);
    final flat = <(ToolbarItem, int)>[];
    for (var g = 0; g < widget.groups.length; g++) {
      for (final item in widget.groups[g].items) {
        flat.add((item, g));
      }
    }

    final children = <Widget>[];
    for (var i = 0; i < flat.length; i++) {
      final (item, group) = flat[i];
      children.add(
        ToolbarOverflowChild(
          slot: ToolbarSlot.item,
          priority: item.priority,
          group: group,
          index: i,
          pinned: item.pinned,
          child: ExcludeFocus(
            excluding: _hidden.contains(i),
            child: item.build(context),
          ),
        ),
      );
      final lastOfGroup = i == flat.length - 1 || flat[i + 1].$2 != group;
      if (lastOfGroup && i != flat.length - 1) {
        children.add(
          ToolbarOverflowChild(
            slot: ToolbarSlot.separator,
            group: group,
            child: const SizedBox(
              height: 20,
              child: ShadSeparator.vertical(
                margin: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        );
      }
    }
    children.add(
      ToolbarOverflowChild(
        slot: ToolbarSlot.overflowButton,
        child: ExcludeFocus(
          excluding: _hidden.isEmpty,
          child: WonkyDropdownMenu(
            anchor: const ShadAnchor(
              childAlignment: AlignmentDirectional.bottomEnd,
              overlayAlignment: AlignmentDirectional.topEnd,
              offset: Offset(0, 4),
            ),
            entries: () {
              final out = <WonkyMenuEntry>[];
              int? lastGroup;
              for (var i = 0; i < flat.length; i++) {
                if (!_hidden.contains(i)) continue;
                final (item, group) = flat[i];
                if (lastGroup != null && lastGroup != group) {
                  out.add(const WonkyMenuSeparator());
                }
                lastGroup = group;
                out.addAll(item.overflowEntries(context));
              }
              return out;
            },
            builder: (context, controller) => ShadTooltip(
              builder: (_) => Text(l10n.toolbarMore),
              child: ToolbarEscapeScope(
                child: ShadIconButton.ghost(
                  key: const ValueKey<String>('toolbar.overflow'),
                  width: ext.toolbarButtonSize,
                  height: ext.toolbarButtonSize,
                  semanticLabel: l10n.toolbarMore,
                  icon: const Icon(LucideIcons.ellipsis, size: 16),
                  onPressed: controller.toggle,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return _ToolbarScope(
      onEscape: widget.onEscape,
      child: Semantics(
        container: true,
        label: widget.semanticLabel ?? l10n.toolbarLabel,
        child: FocusScope(
          node: _scope,
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.arrowRight):
                    NextFocusIntent(),
                SingleActivator(LogicalKeyboardKey.arrowLeft):
                    PreviousFocusIntent(),
                SingleActivator(LogicalKeyboardKey.escape):
                    _ToolbarEscapeIntent(),
              },
              child: Actions(
                actions: {
                  _ToolbarEscapeIntent: CallbackAction<_ToolbarEscapeIntent>(
                    onInvoke: (_) {
                      widget.onEscape?.call();
                      return null;
                    },
                  ),
                },
                child: SizedBox(
                  height: ext.effectiveToolbarHeight,
                  child: Padding(
                    padding: widget.padding,
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: ToolbarOverflowLayout(
                              onHiddenChanged: _onHiddenChanged,
                              children: children,
                            ),
                          ),
                        ),
                        for (final t in widget.trailing) t.build(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarScope extends InheritedWidget {
  const _ToolbarScope({required this.onEscape, required super.child});

  final VoidCallback? onEscape;

  @override
  bool updateShouldNotify(_ToolbarScope oldWidget) =>
      oldWidget.onEscape != onEscape;
}

/// Routes Esc from a toolbar control to the toolbar's `onEscape`.
///
/// shad's tooltip and popover consume Esc even when closed, so controls of
/// custom [ToolbarItem]s should wrap their focusable child (inside any
/// `ShadTooltip`) with this widget.
class ToolbarEscapeScope extends StatelessWidget {
  const ToolbarEscapeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ToolbarScope>();
    final onEscape = scope?.onEscape;
    if (onEscape == null) return child;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onEscape},
      child: child,
    );
  }
}

class _ToolbarEscapeIntent extends Intent {
  const _ToolbarEscapeIntent();
}
