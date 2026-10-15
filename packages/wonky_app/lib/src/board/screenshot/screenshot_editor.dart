import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_core/wonky_core.dart' show KeyBinding;
import 'package:wonky_ui/wonky_ui.dart'
    show
        InkStroke,
        InkTool,
        OneEuroFilter,
        ToolbarButton,
        ToolbarCustom,
        ToolbarGroup,
        ToolbarToggleButton,
        ToolbarTooltipContent,
        WonkyColors,
        WonkyMenuRadioItem,
        WonkyToolbar;

import '../../bootstrap/platform.dart';
import '../../core/l10n_or_english.dart';
import '../../data/api.dart';
import '../../l10n/wonky_app_localizations.dart';
import '../../mcp_bridge/app_screenshot.dart' show EncodedScreenshot;
import '../../shell/form_dialog.dart';
import 'jpeg_encoder.dart';
import 'screenshot_annotations.dart';

/// Stable keys of the screenshot editor (specs/16 §5.2).
abstract final class ScreenshotEditorKeys {
  static const dialog = 'dialog.board.screenshot';
  static const warning = '$dialog.warning';
  static const canvas = '$dialog.canvas';
  static const undo = '$dialog.undo';
  static const redo = '$dialog.redo';
  static const delete = '$dialog.delete';
  static const clear = '$dialog.clear';
  static const done = '$dialog.done';
  static const cancel = '$dialog.cancel';
  static const error = '$dialog.error';
  static String tool(ScreenshotTool t) => '$dialog.tool.${t.name}';
  static String color(ScreenshotColor c) => '$dialog.color.${c.name}';
}

/// The default [ScreenshotFinisher]: flatten and encode, JPEG through the
/// browser on the web.
Future<EncodedScreenshot> _defaultFinish(
  ui.Image source,
  List<ScreenshotAnnotation> annotations,
) => flattenAndEncodeScreenshot(
  source,
  annotations,
  jpegEncoder: platformJpegEncoder,
);

/// Opens the screenshot editor (specs/16 §5.2) on [image], a full-screen
/// dialog (`dialog.board.screenshot`) with a warning banner that cannot be
/// dismissed. [initial] are annotations from an earlier *Done* (still
/// editable). *Done* flattens the image and the annotations at the source
/// resolution with [finish] (default: [flattenAndEncodeScreenshot] with
/// the platform's JPEG encoder); *Cancel* returns null. [image] is not
/// disposed.
Future<AnnotatedScreenshot?> showScreenshotEditor(
  BuildContext context,
  ui.Image image, {
  List<ScreenshotAnnotation> initial = const [],
  ScreenshotFinisher? finish,
}) => showShadDialog<AnnotatedScreenshot>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ScreenshotEditor(
    image: image,
    initial: initial,
    finish: finish ?? _defaultFinish,
  ),
);

/// The screenshot editor's page. Tools: Cover (`C`, default), Highlight
/// (`H`), Arrow (`A`), Pen (`P`); colors `1`–`3` for the accent tools; a
/// click selects an annotation, a drag on the selected one moves it,
/// `Delete` removes it; `Mod+Z` / `Mod+Shift+Z` undo and redo on the
/// editor's own stack (the shell's undo stack is untouched); `Mod+Enter` is
/// *Done*, `Esc` clears the selection or cancels.
class ScreenshotEditor extends StatefulWidget {
  const ScreenshotEditor({
    super.key,
    required this.image,
    this.initial = const [],
    required this.finish,
  });

  final ui.Image image;
  final List<ScreenshotAnnotation> initial;
  final ScreenshotFinisher finish;

  @override
  State<ScreenshotEditor> createState() => ScreenshotEditorState();
}

enum _DragKind { pending, drawing, moving }

class _Drag {
  _Drag(this.kind, this.start, this.startLocal);

  _DragKind kind;
  final Offset start;
  final Offset startLocal;
  ScreenshotAnnotation? hit;
  List<ScreenshotAnnotation>? before;
  OneEuroFilter? filter;
  bool moved = false;
}

class ScreenshotEditorState extends State<ScreenshotEditor>
    with McpDialogRegistration<ScreenshotEditor> {
  static int _seq = 0;

  late List<ScreenshotAnnotation> _items = List.unmodifiable(widget.initial);
  final List<List<ScreenshotAnnotation>> _undo = [];
  final List<List<ScreenshotAnnotation>> _redo = [];
  ScreenshotTool _tool = ScreenshotTool.cover;
  ScreenshotColor _color = ScreenshotColor.red;
  String? _selected;
  ScreenshotAnnotation? _draft;
  _Drag? _drag;
  double _scale = 1;
  bool _busy = false;
  String? _error;
  final FocusNode _focus = FocusNode(debugLabel: 'ScreenshotEditor');

  /// The annotations, bottom first.
  List<ScreenshotAnnotation> get annotations => _items;

  ScreenshotTool get tool => _tool;
  ScreenshotColor get color => _color;
  String? get selectedId => _selected;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  Size get _imageSize =>
      Size(widget.image.width.toDouble(), widget.image.height.toDouble());

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  // ---- Edits (the editor's local undo stack) ----

  void _commit(List<ScreenshotAnnotation> next, {String? select}) {
    setState(() {
      _undo.add(_items);
      _redo.clear();
      _items = List.unmodifiable(next);
      _selected = select ?? (_has(_selected) ? _selected : null);
    });
  }

  bool _has(String? id) => id != null && _items.any((a) => a.id == id);

  void undo() {
    if (_undo.isEmpty || _busy) return;
    setState(() {
      _redo.add(_items);
      _items = _undo.removeLast();
      if (!_has(_selected)) _selected = null;
    });
  }

  void redo() {
    if (_redo.isEmpty || _busy) return;
    setState(() {
      _undo.add(_items);
      _items = _redo.removeLast();
      if (!_has(_selected)) _selected = null;
    });
  }

  void clear() {
    if (_items.isEmpty || _busy) return;
    _commit(const []);
    setState(() => _selected = null);
  }

  void deleteSelected() {
    final id = _selected;
    if (id == null || _busy) return;
    _commit([
      for (final a in _items)
        if (a.id != id) a,
    ]);
    setState(() => _selected = null);
  }

  void setTool(ScreenshotTool tool) => setState(() => _tool = tool);

  /// Sets the accent color; a selected accent annotation takes it too (an
  /// undoable change).
  void setColor(ScreenshotColor color) {
    setState(() => _color = color);
    final id = _selected;
    if (id == null) return;
    final sel = _items.firstWhere((a) => a.id == id);
    if (!sel.tool.accent) return;
    _commit([for (final a in _items) a.id == id ? a.recolor(color.color) : a]);
  }

  void select(String? id) => setState(() => _selected = _has(id) ? id : null);

  Future<void> done() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final encoded = await widget.finish(widget.image, _items);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(AnnotatedScreenshot(annotations: _items, encoded: encoded));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorMessage(e);
      });
    }
  }

  void cancel() {
    if (_busy) return;
    Navigator.of(context).pop();
  }

  // ---- Pointer ----

  Offset _toImage(Offset local) {
    final p = local / _scale;
    return Offset(
      p.dx.clamp(0.0, _imageSize.width),
      p.dy.clamp(0.0, _imageSize.height),
    );
  }

  ScreenshotAnnotation? _hitAt(Offset p) {
    final tolerance = 8 / _scale;
    for (final a in _items.reversed) {
      if (a.hits(p, tolerance)) return a;
    }
    return null;
  }

  void _onDown(PointerDownEvent e) {
    if (_busy || e.buttons & kPrimaryButton == 0) return;
    _focus.requestFocus();
    final p = _toImage(e.localPosition);
    final hit = _hitAt(p);
    if (hit != null && hit.id == _selected) {
      _drag = _Drag(_DragKind.moving, p, e.localPosition)
        ..hit = hit
        ..before = _items;
    } else {
      _drag = _Drag(_DragKind.pending, p, e.localPosition)..hit = hit;
    }
  }

  void _onMove(PointerMoveEvent e) {
    final d = _drag;
    if (d == null) return;
    final p = _toImage(e.localPosition);
    switch (d.kind) {
      case _DragKind.moving:
        final delta = p - d.start;
        final original = d.hit!;
        d.moved = true;
        setState(() {
          _items = List.unmodifiable([
            for (final a in d.before!)
              a.id == original.id ? original.translate(delta) : a,
          ]);
        });
      case _DragKind.pending:
        if ((e.localPosition - d.startLocal).distance < 4) return;
        d.kind = _DragKind.drawing;
        if (_tool == ScreenshotTool.pen) {
          d.filter = OneEuroFilter();
          final t = e.timeStamp.inMilliseconds;
          final unit = screenshotStrokeUnit(_imageSize);
          setState(() {
            _selected = null;
            _draft = PenAnnotation(
              InkStroke(
                id: 'shot${_seq++}',
                tool: InkTool.pen,
                color: _color.color.toARGB32(),
                width: 4 * unit,
                points: [d.filter!.filter(d.start, t - 16)],
              ),
            );
          });
        } else {
          setState(() {
            _selected = null;
            _draft = _shape('shot${_seq++}', d.start, p);
          });
        }
        _extend(d, p, e.timeStamp);
      case _DragKind.drawing:
        _extend(d, p, e.timeStamp);
    }
  }

  void _extend(_Drag d, Offset p, Duration time) {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _draft = switch (draft) {
        PenAnnotation(:final stroke) => PenAnnotation(
          stroke.extend(d.filter!.filter(p, time.inMilliseconds)),
        ),
        _ => _shape(draft.id, d.start, p),
      };
    });
  }

  ScreenshotAnnotation _shape(String id, Offset a, Offset b) => switch (_tool) {
    ScreenshotTool.cover => CoverAnnotation(id, Rect.fromPoints(a, b)),
    ScreenshotTool.highlight => HighlightAnnotation(
      id,
      Rect.fromPoints(a, b),
      _color.color,
    ),
    ScreenshotTool.arrow => ArrowAnnotation(id, a, b, _color.color),
    ScreenshotTool.pen => throw StateError('Pen strokes are not shapes.'),
  };

  void _onUp(PointerUpEvent e) {
    final d = _drag;
    _drag = null;
    if (d == null) return;
    switch (d.kind) {
      case _DragKind.moving:
        if (d.moved) {
          setState(() {
            _undo.add(d.before!);
            _redo.clear();
          });
        }
      case _DragKind.pending:
        select(d.hit?.id);
      case _DragKind.drawing:
        final draft = _draft;
        setState(() => _draft = null);
        if (draft != null && _valid(draft)) _commit([..._items, draft]);
    }
  }

  void _onCancel(PointerCancelEvent e) {
    final d = _drag;
    _drag = null;
    if (d == null) return;
    setState(() {
      if (d.kind == _DragKind.moving) _items = d.before!;
      _draft = null;
    });
  }

  bool _valid(ScreenshotAnnotation a) => switch (a) {
    CoverAnnotation(:final rect) ||
    HighlightAnnotation(:final rect) => rect.width >= 2 && rect.height >= 2,
    ArrowAnnotation(:final from, :final to) => (to - from).distance >= 4,
    PenAnnotation() => true,
  };

  // ---- Keyboard ----

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final hw = HardwareKeyboard.instance;
    final mac = currentKeyPlatform.isMac;
    final mod = mac ? hw.isMetaPressed : hw.isControlPressed;
    final k = e.logicalKey;
    if (mod && !hw.isAltPressed) {
      if (k == LogicalKeyboardKey.keyZ) {
        hw.isShiftPressed ? redo() : undo();
        return KeyEventResult.handled;
      }
      if (!mac && k == LogicalKeyboardKey.keyY) {
        redo();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter) {
        done();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (hw.isMetaPressed || hw.isControlPressed || hw.isAltPressed) {
      return KeyEventResult.ignored;
    }
    if (k == LogicalKeyboardKey.escape) {
      if (_selected != null) {
        select(null);
      } else {
        cancel();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) {
      if (_selected == null) return KeyEventResult.ignored;
      deleteSelected();
      return KeyEventResult.handled;
    }
    if (e is KeyRepeatEvent) return KeyEventResult.ignored;
    final tool = switch (k) {
      LogicalKeyboardKey.keyC => ScreenshotTool.cover,
      LogicalKeyboardKey.keyH => ScreenshotTool.highlight,
      LogicalKeyboardKey.keyA => ScreenshotTool.arrow,
      LogicalKeyboardKey.keyP => ScreenshotTool.pen,
      _ => null,
    };
    if (tool != null) {
      setTool(tool);
      return KeyEventResult.handled;
    }
    final color = switch (k) {
      LogicalKeyboardKey.digit1 ||
      LogicalKeyboardKey.numpad1 => ScreenshotColor.red,
      LogicalKeyboardKey.digit2 ||
      LogicalKeyboardKey.numpad2 => ScreenshotColor.yellow,
      LogicalKeyboardKey.digit3 ||
      LogicalKeyboardKey.numpad3 => ScreenshotColor.blue,
      _ => null,
    };
    if (color != null) {
      setColor(color);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- MCP (`ui.get_dialog`) ----

  @override
  Map<String, Object?> describe() {
    final l = wonkyAppL10nOrEnglish(context);
    return {
      'title': l.screenshotEditorTitle,
      'kind': 'screenshotEditor',
      'warning': l.screenshotEditorWarning,
      'fields': [
        {
          'id': 'tool',
          'label': l.screenshotToolsLabel,
          'type': 'select',
          'value': _tool.name,
          'options': [for (final t in ScreenshotTool.values) t.name],
        },
        {
          'id': 'color',
          'label': l.screenshotColorsLabel,
          'type': 'select',
          'value': _color.name,
          'options': [for (final c in ScreenshotColor.values) c.name],
        },
      ],
      'annotations': [
        for (final a in _items)
          {
            'id': a.id,
            'tool': a.tool.name,
            'bounds': [
              a.bounds.left,
              a.bounds.top,
              a.bounds.right,
              a.bounds.bottom,
            ],
          },
      ],
      'buttons': [
        {'id': 'undo', 'label': l.screenshotUndo, 'enabled': canUndo},
        {'id': 'redo', 'label': l.screenshotRedo, 'enabled': canRedo},
        {'id': 'clear', 'label': l.screenshotClear},
        {'id': 'cancel', 'label': l.actionCancel},
        {'id': 'done', 'label': l.screenshotDone},
      ],
    };
  }

  @override
  bool setField(String id, Object? value) {
    switch (id) {
      case 'tool':
        final t = ScreenshotTool.values.where((t) => t.name == value);
        if (t.isEmpty) return false;
        setTool(t.first);
        return true;
      case 'color':
        final c = ScreenshotColor.values.where((c) => c.name == value);
        if (c.isEmpty) return false;
        setColor(c.first);
        return true;
    }
    return false;
  }

  @override
  bool press(String buttonId) {
    switch (buttonId) {
      case 'undo':
        undo();
      case 'redo':
        redo();
      case 'clear':
        clear();
      case 'cancel' || 'close':
        cancel();
      case 'done':
        done();
      default:
        return false;
    }
    return true;
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l.screenshotEditorTitle,
        child: SizedBox.expand(
          key: const ValueKey<String>(ScreenshotEditorKeys.dialog),
          child: ColoredBox(
            color: cs.background,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(l, theme),
                  _warning(l, theme),
                  _toolbar(l, theme),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        l.screenshotEncodeFailed(_error!),
                        key: const ValueKey<String>(ScreenshotEditorKeys.error),
                        style: theme.textTheme.small.copyWith(
                          color: cs.destructive,
                        ),
                      ),
                    ),
                  Expanded(child: _canvas(l, cs)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The top bar of a full-screen view (the version history's): 56 px, the
  /// title in `large`, a bottom border, Cancel and the primary *Done*.
  Widget _header(WonkyAppLocalizations l, ShadThemeData theme) {
    final platform = currentKeyPlatform;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l.screenshotEditorTitle,
                style: theme.textTheme.large,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          ShadButton.outline(
            key: const ValueKey<String>(ScreenshotEditorKeys.cancel),
            onPressed: _busy ? null : cancel,
            child: Text(l.actionCancel),
          ),
          const SizedBox(width: 8),
          ShadTooltip(
            builder: (_) => ToolbarTooltipContent(
              label: l.screenshotDone,
              shortcut: const KeyBinding('Enter', mod: true).labels(platform),
            ),
            child: ShadButton(
              key: const ValueKey<String>(ScreenshotEditorKeys.done),
              onPressed: _busy ? null : done,
              leading: _busy
                  ? const SizedBox.square(dimension: 14, child: ShadSpinner())
                  : null,
              child: Text(l.screenshotDone),
            ),
          ),
        ],
      ),
    );
  }

  /// The public-screenshot warning: a `ShadAlert` like the app's other
  /// callouts; it cannot be dismissed.
  Widget _warning(WonkyAppLocalizations l, ShadThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: ShadAlert(
          key: const ValueKey<String>(ScreenshotEditorKeys.warning),
          icon: const Icon(LucideIcons.triangleAlert, size: 16),
          iconColor: theme.colorScheme.warning,
          titleStyle: theme.textTheme.small,
          title: Text(l.screenshotEditorWarning),
        ),
      ),
    );
  }

  /// The tools in a `WonkyToolbar` (the editors' toolbar: icon toggles with
  /// tooltips and shortcuts, groups split by separators, overflow into "⋯"),
  /// in the editors' rounded toolbar strip.
  Widget _toolbar(WonkyAppLocalizations l, ShadThemeData theme) {
    final cs = theme.colorScheme;
    String toolLabel(ScreenshotTool t) => switch (t) {
      ScreenshotTool.cover => l.screenshotToolCover,
      ScreenshotTool.highlight => l.screenshotToolHighlight,
      ScreenshotTool.arrow => l.screenshotToolArrow,
      ScreenshotTool.pen => l.screenshotToolPen,
    };
    IconData toolIcon(ScreenshotTool t) => switch (t) {
      ScreenshotTool.cover => LucideIcons.eyeOff,
      ScreenshotTool.highlight => LucideIcons.square,
      ScreenshotTool.arrow => LucideIcons.moveUpRight,
      ScreenshotTool.pen => LucideIcons.pencil,
    };
    String toolKey(ScreenshotTool t) => switch (t) {
      ScreenshotTool.cover => 'C',
      ScreenshotTool.highlight => 'H',
      ScreenshotTool.arrow => 'A',
      ScreenshotTool.pen => 'P',
    };
    String colorLabel(ScreenshotColor c) => switch (c) {
      ScreenshotColor.red => l.screenshotColorRed,
      ScreenshotColor.yellow => l.screenshotColorYellow,
      ScreenshotColor.blue => l.screenshotColorBlue,
    };
    final platform = currentKeyPlatform;
    final colorsEnabled = _tool.accent || _selectedIsAccent;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: cs.muted.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: WonkyToolbar(
        semanticLabel: l.screenshotEditorTitle,
        onEscape: _focus.requestFocus,
        groups: [
          ToolbarGroup([
            for (final t in ScreenshotTool.values)
              ToolbarToggleButton(
                id: ScreenshotEditorKeys.tool(t),
                pinned: true,
                icon: toolIcon(t),
                label: toolLabel(t),
                shortcut: [toolKey(t)],
                value: _tool == t,
                onChanged: (_) => setTool(t),
              ),
          ], id: 'tools'),
          ToolbarGroup([
            for (final (i, c) in ScreenshotColor.values.indexed)
              ToolbarCustom(
                id: ScreenshotEditorKeys.color(c),
                priority: 2,
                overflow: [
                  WonkyMenuRadioItem(
                    label: colorLabel(c),
                    selected: _color == c,
                    enabled: colorsEnabled,
                    onSelected: () => setColor(c),
                  ),
                ],
                builder: (context) => ShadTooltip(
                  builder: (_) => ToolbarTooltipContent(
                    label: colorLabel(c),
                    shortcut: ['${i + 1}'],
                  ),
                  child: MergeSemantics(
                    child: Semantics(
                      selected: _color == c,
                      child: ShadIconButton.ghost(
                        key: ValueKey<String>(ScreenshotEditorKeys.color(c)),
                        semanticLabel: colorLabel(c),
                        width: 28,
                        height: 28,
                        enabled: colorsEnabled,
                        onPressed: () => setColor(c),
                        icon: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: c.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == c ? cs.foreground : cs.border,
                              width: _color == c ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ], id: 'colors'),
          ToolbarGroup([
            ToolbarButton(
              id: ScreenshotEditorKeys.undo,
              pinned: true,
              icon: LucideIcons.undo2,
              label: l.screenshotUndo,
              shortcut: const KeyBinding('Z', mod: true).labels(platform),
              onPressed: canUndo ? undo : null,
            ),
            ToolbarButton(
              id: ScreenshotEditorKeys.redo,
              priority: 1,
              icon: LucideIcons.redo2,
              label: l.screenshotRedo,
              shortcut: const KeyBinding(
                'Z',
                mod: true,
                shift: true,
              ).labels(platform),
              onPressed: canRedo ? redo : null,
            ),
          ], id: 'history'),
          ToolbarGroup([
            ToolbarButton(
              id: ScreenshotEditorKeys.delete,
              priority: 3,
              icon: LucideIcons.trash2,
              label: l.screenshotDelete,
              onPressed: _selected == null ? null : deleteSelected,
            ),
            ToolbarButton(
              id: ScreenshotEditorKeys.clear,
              priority: 3,
              icon: LucideIcons.eraser,
              label: l.screenshotClear,
              onPressed: _items.isEmpty ? null : clear,
            ),
          ], id: 'edit'),
        ],
      ),
    );
  }

  bool get _selectedIsAccent {
    final id = _selected;
    if (id == null) return false;
    return _items.any((a) => a.id == id && a.tool.accent);
  }

  // The area around the image is the `canvas` token, like the area behind
  // a document page.
  Widget _canvas(WonkyAppLocalizations l, ShadColorScheme cs) => ColoredBox(
    color: cs.canvas,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = _imageSize;
        final avail = Size(
          math.max(1, constraints.maxWidth - 32),
          math.max(1, constraints.maxHeight - 32),
        );
        _scale = math.min(
          1.0,
          math.min(avail.width / size.width, avail.height / size.height),
        );
        final selected = _selected == null
            ? null
            : _items.where((a) => a.id == _selected).firstOrNull;
        return Center(
          child: Semantics(
            label: l.screenshotCanvasLabel,
            image: true,
            child: SizedBox(
              key: const ValueKey<String>(ScreenshotEditorKeys.canvas),
              width: size.width * _scale,
              height: size.height * _scale,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onDown,
                onPointerMove: _onMove,
                onPointerUp: _onUp,
                onPointerCancel: _onCancel,
                child: MouseRegion(
                  cursor: SystemMouseCursors.precise,
                  child: CustomPaint(
                    painter: _EditorPainter(
                      image: widget.image,
                      items: [..._items, ?_draft],
                      selection: selected?.bounds,
                      scale: _scale,
                      selectionColor: cs.ring,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _EditorPainter extends CustomPainter {
  _EditorPainter({
    required this.image,
    required this.items,
    required this.selection,
    required this.scale,
    required this.selectionColor,
  });

  final ui.Image image;
  final List<ScreenshotAnnotation> items;
  final Rect? selection;
  final double scale;
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(
      image,
      Offset.zero & imageSize,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    paintScreenshotAnnotations(canvas, items, imageSize);
    canvas.restore();
    final sel = selection;
    if (sel != null) {
      final r = Rect.fromLTRB(
        sel.left * scale,
        sel.top * scale,
        sel.right * scale,
        sel.bottom * scale,
      ).inflate(4);
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xffffffff),
      );
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = selectionColor,
      );
    }
  }

  @override
  bool shouldRepaint(_EditorPainter old) =>
      old.image != image ||
      old.scale != scale ||
      old.selection != selection ||
      old.selectionColor != selectionColor ||
      old.items.length != items.length ||
      !_same(old.items, items);

  static bool _same(
    List<ScreenshotAnnotation> a,
    List<ScreenshotAnnotation> b,
  ) {
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }
}
