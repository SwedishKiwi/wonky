import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';

/// Layout pieces shared by the formatting side panels (CF, alternating
/// colors, theme): a heading row, a scrolling body of sections and a footer
/// with *Cancel* / *Done* (04 §10 "Panel chrome").
class FormatPanelFrame extends StatefulWidget {
  const FormatPanelFrame({
    super.key,
    required this.title,
    required this.children,
    this.onBack,
    this.backLabel,
    this.footer,
    this.trailing,
  });

  final String title;
  final List<Widget> children;

  /// Shows a back arrow before the title.
  final VoidCallback? onBack;
  final String? backLabel;
  final Widget? footer;
  final Widget? trailing;

  @override
  State<FormatPanelFrame> createState() => _FormatPanelFrameState();
}

class _FormatPanelFrameState extends State<FormatPanelFrame> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final onBack = widget.onBack;
    final footer = widget.footer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              if (onBack != null)
                ShadIconButton.ghost(
                  key: const ValueKey<String>('formatPanel.back'),
                  width: 28,
                  height: 28,
                  iconSize: 16,
                  semanticLabel: widget.backLabel,
                  icon: const Icon(LucideIcons.arrowLeft),
                  onPressed: onBack,
                )
              else
                const SizedBox(width: 4),
              const SizedBox(width: 4),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.title,
                    style: theme.textTheme.large.copyWith(fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              ?widget.trailing,
            ],
          ),
        ),
        Expanded(
          child: WonkyScrollArea(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
          ),
        ),
        if (footer != null) ...[
          const ShadSeparator.horizontal(margin: EdgeInsets.zero),
          Padding(padding: const EdgeInsets.all(12), child: footer),
        ],
      ],
    );
  }
}

/// *Cancel* / *Done* footer of rule editors.
class PanelDoneFooter extends StatelessWidget {
  const PanelDoneFooter({
    super.key,
    required this.cancelLabel,
    required this.doneLabel,
    required this.onCancel,
    required this.onDone,
    this.keyPrefix = 'formatPanel',
    this.leading,
  });

  final String cancelLabel;
  final String doneLabel;
  final VoidCallback onCancel;

  /// Null disables *Done* (invalid draft).
  final VoidCallback? onDone;
  final String keyPrefix;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (leading != null) Flexible(child: leading!),
      const Spacer(),
      ShadButton.outline(
        key: ValueKey<String>('$keyPrefix.cancel'),
        size: ShadButtonSize.sm,
        onPressed: onCancel,
        child: Text(cancelLabel),
      ),
      const SizedBox(width: 8),
      ShadButton(
        key: ValueKey<String>('$keyPrefix.done'),
        size: ShadButtonSize.sm,
        enabled: onDone != null,
        onPressed: onDone,
        child: Text(doneLabel),
      ),
    ],
  );
}

/// A labeled block of a panel.
class PanelSection extends StatelessWidget {
  const PanelSection({
    super.key,
    required this.label,
    required this.child,
    this.top = 14,
  });

  final String label;
  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// A select over string values with labels (re-created when [value]
/// changes from outside so it always shows the current value).
class PanelSelect<T> extends StatelessWidget {
  const PanelSelect({
    super.key,
    required this.keyName,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.optionBuilder,
    this.minWidth,
    this.groups,
  });

  final String keyName;
  final T value;

  /// value → label, in order.
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

  /// Custom option rendering (icons…).
  final Widget Function(BuildContext context, T value, String label)?
  optionBuilder;
  final double? minWidth;

  /// Optional group headers: value → header shown before it.
  final Map<T, String>? groups;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    Widget item(T v, String label) =>
        optionBuilder?.call(context, v, label) ??
        Text(label, overflow: TextOverflow.ellipsis);
    return ShadSelect<T>(
      key: ValueKey<String>('$keyName.$value'),
      minWidth: minWidth,
      enabled: enabled,
      initialValue: value,
      maxHeight: 360,
      options: [
        for (final e in options.entries) ...[
          if (groups?[e.key] case final String g)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
              child: Text(
                g,
                style: theme.textTheme.muted.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ShadOption<T>(
            key: ValueKey<String>('$keyName.option.${e.key}'),
            value: e.key,
            child: item(e.key, e.value),
          ),
        ],
      ],
      selectedOptionBuilder: (context, v) =>
          item(v, options[v] ?? v.toString()),
      onChanged: (v) {
        if (v != null && v != value) onChanged(v);
      },
    );
  }
}

/// A small toggle icon button (B / I / U / S of format editors).
class PanelIconToggle extends StatelessWidget {
  const PanelIconToggle({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Semantics(
      toggled: value,
      button: true,
      label: label,
      child: ShadTooltip(
        builder: (_) => Text(label),
        child: ShadIconButton.ghost(
          width: 30,
          height: 30,
          iconSize: 15,
          backgroundColor: value ? theme.colorScheme.accent : null,
          foregroundColor: value ? theme.colorScheme.primary : null,
          icon: Icon(icon),
          onPressed: () => onChanged(!value),
        ),
      ),
    );
  }
}

/// Inline validation message.
class PanelError extends StatelessWidget {
  const PanelError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: theme.textTheme.small.copyWith(
            color: theme.colorScheme.destructive,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
