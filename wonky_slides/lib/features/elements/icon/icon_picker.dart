import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_slides_core/icons.dart';
import 'package:wonky_slides_core/themes.dart' show ResolvedTheme;
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/slides_l10n.dart';
import '../style/element_style.dart';

/// What the icon picker chose.
class IconPickerResult {
  const IconPickerResult(this.name, {this.strokeWidth = 2, this.color});

  /// The Lucide icon name.
  final String name;

  /// 1–3 (02 §6.6).
  final double strokeWidth;

  /// The icon color (`ColorRef`), or null for the theme's icon style.
  final String? color;
}

/// Stable widget keys of the icon picker.
abstract final class IconPickerKeys {
  static const dialog = ValueKey<String>('slides.dialog.iconPicker');
  static const search = ValueKey<String>('slides.iconPicker.search');
  static const grid = ValueKey<String>('slides.iconPicker.grid');
  static const insert = ValueKey<String>('slides.iconPicker.insert');
  static const cancel = ValueKey<String>('slides.iconPicker.cancel');
  static const categorySelect = ValueKey<String>(
    'slides.iconPicker.categorySelect',
  );

  /// The grid cell of icon [name].
  static ValueKey<String> cell(String name) =>
      ValueKey<String>('slides.iconPicker.cell.$name');

  /// The sidebar entry of category [id] (`all`, `recent`, a category).
  static ValueKey<String> category(String id) =>
      ValueKey<String>('slides.iconPicker.category.$id');

  /// The stroke width option [w].
  static ValueKey<String> stroke(double w) =>
      ValueKey<String>('slides.iconPicker.stroke.$w');

  /// The color swatch of [ref] (`default` for the theme style).
  static ValueKey<String> color(String ref) =>
      ValueKey<String>('slides.iconPicker.color.$ref');
}

/// Recently inserted icons (per user and device, newest first, ≤ 24).
abstract final class RecentIcons {
  static const storeKey = 'slides.icons.recent';
  static const max = 24;

  static Future<List<String>> read(LocalStore store) async {
    final v = await store.read(storeKey);
    return v is List ? v.whereType<String>().toList() : const [];
  }

  static Future<void> add(LocalStore store, String name) async {
    final list = [name, ...(await read(store)).where((n) => n != name)];
    await store.write(storeKey, list.take(max).toList());
  }
}

/// The icon category key of the ARB select (`time` is reserved by ICU).
String iconCategoryKey(LucideCategory c) =>
    c == LucideCategory.time ? 'clock' : c.name;

/// Shows the icon picker (Slides 04 §13.6): search over the Lucide set,
/// categories with *Recently used*, stroke width 1–3, color from the theme
/// colors, [Cancel] [Insert] (double-click inserts). MCP-operable through
/// `ui.get_dialog` / `ui.fill_dialog`. Returns the choice or null.
Future<IconPickerResult?> showIconPicker(
  BuildContext context, {
  required ShellServices services,
  ResolvedTheme? theme,
  String? initialName,
  double strokeWidth = LucideGlyphs.defaultStrokeWidth,
  String? color,
  bool replace = false,
}) async {
  final r = await showShadDialog<IconPickerResult>(
    context: context,
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      return ShadDialog(
        key: IconPickerKeys.dialog,
        semanticLabel: replace
            ? slidesL10n(ctx).iconPickerReplaceTitle
            : slidesL10n(ctx).iconPickerTitle,
        closeIcon: const SizedBox.shrink(),
        padding: EdgeInsets.zero,
        scrollable: false,
        constraints: const BoxConstraints(maxWidth: 720),
        child: SizedBox(
          width: math.min(720, size.width - 32),
          height: math.min(520, size.height - 48),
          child: IconPicker(
            services: services,
            theme: theme,
            initialName: initialName,
            strokeWidth: strokeWidth,
            color: color,
            replace: replace,
            onDone: (r) => Navigator.of(ctx).pop(r),
          ),
        ),
      );
    },
  );
  if (r != null) unawaited(RecentIcons.add(services.userStore, r.name));
  return r;
}

/// The icon picker body (see [showIconPicker]).
class IconPicker extends StatefulWidget {
  const IconPicker({
    super.key,
    required this.services,
    required this.onDone,
    this.theme,
    this.initialName,
    this.strokeWidth = LucideGlyphs.defaultStrokeWidth,
    this.color,
    this.replace = false,
  });

  final ShellServices services;
  final ResolvedTheme? theme;
  final String? initialName;
  final double strokeWidth;
  final String? color;
  final bool replace;

  /// Called with the choice (null = cancelled).
  final ValueChanged<IconPickerResult?> onDone;

  @override
  State<IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<IconPicker>
    implements McpDescribableDialog {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  final _sideScroll = ScrollController();
  final _searchFocus = FocusNode(debugLabel: 'slides.iconPicker.search');
  String _category = 'all';
  String? _selected;
  late double _stroke = LucideGlyphs.snapStrokeWidth(widget.strokeWidth);
  late String? _color = widget.color;
  List<String> _recent = const [];
  List<LucideIcon> _results = LucideCatalog.icons;
  String? _lastTap;
  DateTime _lastTapAt = DateTime(0);
  ShellServices? _registeredIn;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialName == null
        ? null
        : LucideCatalog.of(widget.initialName!);
    _selected = initial?.name;
    _query.addListener(_search);
    unawaited(
      RecentIcons.read(widget.services.userStore).then((r) {
        if (!mounted) return;
        setState(() => _recent = r);
        if (_category == 'recent') _search();
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ShellScope.maybeOf(context) ?? widget.services;
    _registeredIn = s;
    if (!s.openDialogs.contains(this)) s.openDialogs.add(this);
  }

  @override
  void dispose() {
    _registeredIn?.openDialogs.remove(this);
    _query.dispose();
    _scroll.dispose();
    _sideScroll.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _search() {
    final q = _query.text;
    final List<LucideIcon> r;
    if (_category == 'recent') {
      final recent = [for (final n in _recent) ?LucideCatalog.of(n)];
      final match = LucideCatalog.search(q).toSet();
      r = [
        for (final i in recent)
          if (q.trim().isEmpty || match.contains(i)) i,
      ];
    } else {
      final c = _categoryOf(_category);
      r = LucideCatalog.search(q, category: c);
    }
    setState(() => _results = r);
  }

  static LucideCategory? _categoryOf(String id) {
    for (final c in LucideCategory.values) {
      if (c.name == id) return c;
    }
    return null;
  }

  void _setCategory(String id) {
    _category = id;
    _search();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _done() {
    final name = _selected ?? (_results.isEmpty ? null : _results.first.name);
    if (name == null) return;
    widget.onDone(IconPickerResult(name, strokeWidth: _stroke, color: _color));
  }

  void _tap(String name) {
    final now = DateTime.now();
    final dbl =
        _lastTap == name && now.difference(_lastTapAt).inMilliseconds < 400;
    _lastTap = name;
    _lastTapAt = now;
    setState(() => _selected = name);
    if (dbl) _done();
  }

  // ------------------------------------------------------------------ MCP

  @override
  Map<String, Object?> describe() {
    final l = slidesL10n(context);
    final shown = _results.take(200).toList();
    return {
      'title': widget.replace ? l.iconPickerReplaceTitle : l.iconPickerTitle,
      'fields': [
        {
          'id': 'query',
          'label': l.iconPickerSearch,
          'type': 'text',
          'value': _query.text,
        },
        {
          'id': 'category',
          'label': l.iconPickerCategory,
          'type': 'select',
          'value': _category,
          'options': _categoryIds,
          'optionLabels': {for (final c in _categoryIds) c: _label(l, c)},
        },
        {
          'id': 'icon',
          'label': l.styleLabelIcon,
          'type': 'select',
          'value': _selected,
          'options': [for (final i in shown) i.name],
          'optionLabels': {for (final i in shown) i.name: i.label},
        },
        {
          'id': 'strokeWidth',
          'label': l.iconPickerStroke,
          'type': 'select',
          'value': '$_stroke',
          'options': [for (final w in LucideGlyphs.strokeWidths) '$w'],
        },
        {
          'id': 'color',
          'label': l.iconPickerColor,
          'type': 'text',
          'value': _color,
        },
      ],
      'buttons': [
        {
          'id': 'cancel',
          'label': WonkyAppLocalizations.of(context).actionCancel,
        },
        {
          'id': 'insert',
          'label': widget.replace ? l.iconPickerReplace : l.iconPickerInsert,
        },
      ],
    };
  }

  @override
  bool setField(String id, Object? value) {
    switch (id) {
      case 'query':
        _query.text = '${value ?? ''}';
      case 'category':
        if (!_categoryIds.contains(value)) return false;
        _setCategory(value! as String);
      case 'icon':
        final i = value is String ? LucideCatalog.of(value) : null;
        if (i == null) return false;
        setState(() => _selected = i.name);
      case 'strokeWidth':
        final w = double.tryParse('$value');
        if (w == null) return false;
        setState(() => _stroke = LucideGlyphs.snapStrokeWidth(w));
      case 'color':
        if (value != null && !ElementStyle.validColor(value)) return false;
        setState(() => _color = value as String?);
      default:
        return false;
    }
    return true;
  }

  @override
  bool press(String buttonId) {
    switch (buttonId) {
      case 'cancel':
        widget.onDone(null);
      case 'insert':
        _done();
      default:
        return false;
    }
    return true;
  }

  // ---------------------------------------------------------------- build

  static final _categoryIds = [
    'all',
    'recent',
    for (final c in LucideCategory.values) c.name,
  ];

  String _label(SlidesLocalizations l, String id) {
    final c = _categoryOf(id);
    return l.iconCategory(c == null ? id : iconCategoryKey(c));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final la = WonkyAppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                widget.onDone(null),
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.replace ? l.iconPickerReplaceTitle : l.iconPickerTitle,
                  style: theme.textTheme.h4,
                ),
                const SizedBox(height: 12),
                ShadInput(
                  key: IconPickerKeys.search,
                  controller: _query,
                  focusNode: _searchFocus,
                  autofocus: true,
                  placeholder: Text(l.iconPickerSearch),
                  leading: const Icon(LucideIcons.search, size: 16),
                  onSubmitted: (_) => _done(),
                ),
                const SizedBox(height: 12),
                if (narrow) ...[
                  ShadSelect<String>(
                    key: IconPickerKeys.categorySelect,
                    initialValue: _category,
                    minWidth: double.infinity,
                    options: [
                      for (final c in _categoryIds)
                        ShadOption(value: c, child: Text(_label(l, c))),
                    ],
                    selectedOptionBuilder: (_, v) => Text(_label(l, v)),
                    onChanged: (v) {
                      if (v != null) _setCategory(v);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!narrow) ...[
                        SizedBox(width: 168, child: _sidebar(context, l)),
                        Container(width: 1, color: theme.colorScheme.border),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: _grid(context, l)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _options(context, l, narrow),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.iconPickerCount(_results.length),
                        style: theme.textTheme.muted,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ShadButton.outline(
                      key: IconPickerKeys.cancel,
                      onPressed: () => widget.onDone(null),
                      child: Text(la.actionCancel),
                    ),
                    const SizedBox(width: 8),
                    ShadButton(
                      key: IconPickerKeys.insert,
                      enabled: _selected != null || _results.isNotEmpty,
                      onPressed: _done,
                      child: Text(
                        widget.replace
                            ? l.iconPickerReplace
                            : l.iconPickerInsert,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sidebar(BuildContext context, SlidesLocalizations l) {
    final theme = ShadTheme.of(context);
    return WonkyScrollArea(
      controller: _sideScroll,
      child: ListView(
        controller: _sideScroll,
        padding: const EdgeInsets.only(right: 8),
        children: [
          for (final id in _categoryIds)
            Semantics(
              selected: id == _category,
              child: ShadButton.ghost(
                key: IconPickerKeys.category(id),
                height: 28,
                mainAxisAlignment: MainAxisAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: id == _category
                    ? theme.colorScheme.accent
                    : null,
                onPressed: () => _setCategory(id),
                child: Flexible(
                  child: Text(
                    _label(l, id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, SlidesLocalizations l) {
    final theme = ShadTheme.of(context);
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _category == 'recent' && _query.text.trim().isEmpty
              ? l.iconPickerRecentEmpty
              : l.iconPickerEmpty(_query.text.trim()),
          style: theme.textTheme.muted,
          textAlign: TextAlign.center,
        ),
      );
    }
    final family = LucideGlyphs.assetFamilyFor(_stroke);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(
          TraversalDirection.left,
        ),
        SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(
          TraversalDirection.right,
        ),
        SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
          TraversalDirection.up,
        ),
        SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
          TraversalDirection.down,
        ),
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: WonkyScrollArea(
          controller: _scroll,
          child: GridView.builder(
            key: IconPickerKeys.grid,
            controller: _scroll,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 48,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: _results.length,
            itemBuilder: (context, i) {
              final icon = _results[i];
              final on = icon.name == _selected;
              return Semantics(
                label: icon.label,
                selected: on,
                child: ShadTooltip(
                  builder: (_) => Text(icon.label),
                  child: ShadButton.ghost(
                    key: IconPickerKeys.cell(icon.name),
                    width: 46,
                    height: 46,
                    padding: EdgeInsets.zero,
                    backgroundColor: on ? theme.colorScheme.accent : null,
                    onPressed: () => _tap(icon.name),
                    child: ExcludeSemantics(
                      child: Text(
                        String.fromCharCode(icon.codePoint),
                        style: TextStyle(
                          fontFamily: family,
                          fontSize: 24,
                          height: 1,
                          color: theme.colorScheme.foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _options(BuildContext context, SlidesLocalizations l, bool narrow) {
    final theme = ShadTheme.of(context);
    final stroke = Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l.iconPickerStroke, style: theme.textTheme.small),
        const SizedBox(width: 4),
        for (final w in LucideGlyphs.strokeWidths)
          Semantics(
            selected: w == _stroke,
            child: w == _stroke
                ? ShadButton.secondary(
                    key: IconPickerKeys.stroke(w),
                    size: ShadButtonSize.sm,
                    onPressed: () => setState(() => _stroke = w),
                    child: Text(_fmt(w)),
                  )
                : ShadButton.ghost(
                    key: IconPickerKeys.stroke(w),
                    size: ShadButtonSize.sm,
                    onPressed: () => setState(() => _stroke = w),
                    child: Text(_fmt(w)),
                  ),
          ),
      ],
    );
    final swatches = ElementStyle.swatches(widget.theme, l);
    final colors = Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l.iconPickerColor, style: theme.textTheme.small),
        const SizedBox(width: 4),
        _swatch(
          context,
          'default',
          l.colorThemeDefault,
          theme.colorScheme.foreground,
          _color == null,
          () => setState(() => _color = null),
          outlined: true,
        ),
        for (final s in swatches)
          _swatch(
            context,
            s.color.themeRef!,
            s.name,
            s.color.toColor(),
            _color == s.color.themeRef,
            () => setState(() => _color = s.color.themeRef),
          ),
      ],
    );
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [stroke, const SizedBox(height: 8), colors],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stroke,
              const SizedBox(width: 16),
              Expanded(child: colors),
            ],
          );
  }

  Widget _swatch(
    BuildContext context,
    String ref,
    String name,
    Color color,
    bool selected,
    VoidCallback onTap, {
    bool outlined = false,
  }) {
    final theme = ShadTheme.of(context);
    return Semantics(
      label: name,
      selected: selected,
      button: true,
      child: ShadTooltip(
        builder: (_) => Text(name),
        child: ShadButton.ghost(
          key: IconPickerKeys.color(ref),
          width: 26,
          height: 26,
          padding: EdgeInsets.zero,
          onPressed: onTap,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: outlined ? null : color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? theme.colorScheme.ring
                    : theme.colorScheme.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: outlined
                ? Icon(LucideIcons.ban, size: 12, color: color)
                : null,
          ),
        ),
      ),
    );
  }

  static String _fmt(double w) =>
      w == w.roundToDouble() ? '${w.toInt()}' : '$w';
}
