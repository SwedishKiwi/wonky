import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import 'animate_controls.dart';

/// One tile of an effect grid (06 §5.3, §7.2).
class EffectTileData {
  const EffectTileData({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    this.enabled = true,
    this.disabledReason,
    this.selected = false,
    this.color,
  });

  final String id;
  final String label;

  /// The accessible description ("Rise: the object moves up a short
  /// distance while fading in", 06 §17).
  final String description;
  final IconData icon;
  final bool enabled;
  final String? disabledReason;
  final bool selected;

  /// Accent of the glyph (build kind color).
  final Color? color;
}

/// A titled group of tiles.
class EffectTileSection {
  const EffectTileSection(this.title, this.tiles);

  final String title;
  final List<EffectTileData> tiles;
}

/// The effect grid of the Build and Transition tabs (06 §5.3): tiles of
/// ≥ 76 × 60 px in as many columns as fit (2 at 260 px), grouped under
/// headings; hover (or keyboard focus) for 400 ms starts a live preview
/// ([onPreview]; [previewBuilder] may draw it inside the tile); arrows
/// move between tiles, Enter/Space applies, Alt-click applies "with
/// previous" ([onSelected]'s `alt`).
class EffectTileGrid extends StatefulWidget {
  const EffectTileGrid({
    super.key,
    required this.keyPrefix,
    required this.sections,
    required this.onSelected,
    this.onPreview,
    this.previewBuilder,
    this.previewDelay = const Duration(milliseconds: 400),
  });

  final String keyPrefix;
  final List<EffectTileSection> sections;
  final void Function(String id, {required bool alt}) onSelected;

  /// The hovered/focused tile after [previewDelay] (null when it ends).
  final ValueChanged<String?>? onPreview;

  /// Draws a running preview inside the tile (transitions).
  final Widget Function(String id)? previewBuilder;
  final Duration previewDelay;

  @override
  State<EffectTileGrid> createState() => _EffectTileGridState();
}

class _EffectTileGridState extends State<EffectTileGrid> {
  final Map<String, FocusNode> _focus = {};
  Timer? _timer;
  String? _pending;
  String? _previewing;

  FocusNode _node(String id) =>
      _focus.putIfAbsent(id, () => FocusNode(debugLabel: 'tile.$id'));

  @override
  void dispose() {
    _timer?.cancel();
    if (_previewing != null) widget.onPreview?.call(null);
    for (final n in _focus.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _enter(String id) {
    if (_pending == id || _previewing == id) return;
    _timer?.cancel();
    _pending = id;
    _timer = Timer(widget.previewDelay, () {
      if (!mounted || _pending != id) return;
      setState(() => _previewing = id);
      widget.onPreview?.call(id);
    });
  }

  void _exit(String id) {
    if (_pending == id) {
      _timer?.cancel();
      _pending = null;
    }
    if (_previewing == id) {
      setState(() => _previewing = null);
      widget.onPreview?.call(null);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 6.0;
      final w = box.maxWidth.isFinite ? box.maxWidth : 260.0;
      final cols = math.max(2, ((w + gap) / (76 + gap)).floor());
      final tileW = (w - gap * (cols - 1)) / cols;
      final all = [for (final s in widget.sections) ...s.tiles];
      final theme = ShadTheme.of(context);
      var index = 0;
      final children = <Widget>[];
      for (final s in widget.sections) {
        if (s.tiles.isEmpty) continue;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Semantics(
              header: true,
              child: Text(
                s.title,
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ),
          ),
        );
        final start = index;
        children.add(
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final (i, t) in s.tiles.indexed)
                _tile(context, t, tileW, start + i, all, cols),
            ],
          ),
        );
        index += s.tiles.length;
      }
      return FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    },
  );

  Widget _tile(
    BuildContext context,
    EffectTileData t,
    double width,
    int index,
    List<EffectTileData> all,
    int cols,
  ) {
    final theme = ShadTheme.of(context);
    final focus = _node(t.id);
    final previewing = _previewing == t.id;
    final preview = previewing ? widget.previewBuilder?.call(t.id) : null;
    final fg = t.enabled
        ? (t.selected
              ? theme.colorScheme.primary
              : theme.colorScheme.foreground)
        : theme.colorScheme.mutedForeground.withValues(alpha: 0.5);
    void apply() {
      if (!t.enabled) return;
      widget.onSelected(t.id, alt: HardwareKeyboard.instance.isAltPressed);
    }

    final body = Container(
      width: width,
      height: 64,
      decoration: BoxDecoration(
        color: t.selected
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : theme.colorScheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: t.selected || focus.hasFocus
              ? theme.colorScheme.primary
              : theme.colorScheme.border,
          width: t.selected || focus.hasFocus ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: preview != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                preview,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ColoredBox(
                    color: theme.colorScheme.background.withValues(alpha: 0.8),
                    child: Text(
                      t.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.small.copyWith(fontSize: 11),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t.icon, size: 20, color: t.enabled ? (t.color ?? fg) : fg),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    t.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.small.copyWith(
                      fontSize: 12,
                      color: fg,
                      fontWeight: t.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
    );
    return Semantics(
      key: ValueKey<String>('${widget.keyPrefix}.${t.id}'),
      button: true,
      selected: t.selected,
      enabled: t.enabled,
      label: t.label,
      hint: t.enabled ? t.description : (t.disabledReason ?? t.description),
      onTap: t.enabled ? apply : null,
      excludeSemantics: true,
      child: ShadTooltip(
        builder: (_) => Text(
          t.enabled ? t.description : (t.disabledReason ?? t.description),
        ),
        child: Focus(
          focusNode: focus,
          onFocusChange: (f) {
            setState(() {});
            if (f) {
              _enter(t.id);
            } else {
              _exit(t.id);
            }
          },
          onKeyEvent: (node, e) {
            if (e is KeyDownEvent &&
                (e.logicalKey == LogicalKeyboardKey.enter ||
                    e.logicalKey == LogicalKeyboardKey.space)) {
              apply();
              return KeyEventResult.handled;
            }
            return gridArrowKey(
              e,
              index: index,
              count: all.length,
              columns: cols,
              focus: (i) => _node(all[i].id).requestFocus(),
            );
          },
          child: MouseRegion(
            cursor: t.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            onEnter: (_) => _enter(t.id),
            onExit: (_) => _exit(t.id),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                focus.requestFocus();
                apply();
              },
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
