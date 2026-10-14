import 'dart:async';

import 'package:flutter/gestures.dart' show PointerEnterEvent;
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';
import 'package:wonky_ui/wonky_ui.dart';

import 'problems.dart';

// ---------------------------------------------------------------- completion

/// One proposal in `re_editor`'s autocomplete.
class ScriptCodePrompt extends CodePrompt {
  ScriptCodePrompt(this.item) : super(word: item.label);

  final CompletionItem item;

  @override
  CodeAutocompleteResult get autocomplete => CodeAutocompleteResult(
    input: '',
    word: item.insertText,
    selection: TextSelection.collapsed(
      offset: item.cursorOffset ?? item.insertText.length,
    ),
  );

  @override
  bool match(String input) => true;
}

/// Feeds `re_editor`'s autocomplete from [ScriptCompletion] (09 §14.4):
/// the whole text of the file and the cursor offset.
class ScriptPromptsBuilder implements CodeAutocompletePromptsBuilder {
  ScriptPromptsBuilder({required this.controller, required this.completion});

  final CodeLineEditingController Function() controller;
  final ScriptCompletion Function() completion;

  /// Whether completion is on (the editor's setting).
  bool enabled = true;

  @override
  CodeAutocompleteEditingValue? build(
    BuildContext context,
    CodeLine codeLine,
    CodeLineSelection selection,
  ) {
    if (!enabled) return null;
    final c = controller();
    final lines = c.codeLines;
    var offset = 0;
    for (var i = 0; i < selection.extentIndex && i < lines.length; i++) {
      offset += lines[i].text.length + 1;
    }
    offset += selection.extentOffset;
    final r = completion().complete(c.text, offset);
    if (r == null || r.items.isEmpty) return null;
    // Nothing to add when the only proposal is what was typed.
    if (r.items.length == 1 && r.items.single.insertText == r.prefix) {
      return null;
    }
    return CodeAutocompleteEditingValue(
      input: r.prefix,
      prompts: [for (final i in r.items) ScriptCodePrompt(i)],
      index: 0,
    );
  }
}

/// Icon of a completion kind.
IconData completionIcon(CompletionKind k) => switch (k) {
  CompletionKind.type => LucideIcons.box,
  CompletionKind.method => LucideIcons.squareFunction,
  CompletionKind.property => LucideIcons.tag,
  CompletionKind.constructor => LucideIcons.hammer,
  CompletionKind.variable => LucideIcons.variable,
  CompletionKind.projectFunction => LucideIcons.code,
  CompletionKind.keyword => LucideIcons.key,
};

/// The autocomplete popup (shad styling): icon by kind, name, signature,
/// and the first doc paragraph of the selected proposal. Enter accepts.
class ScriptCompletionView extends StatefulWidget
    implements PreferredSizeWidget {
  const ScriptCompletionView({
    super.key,
    required this.notifier,
    required this.onSelected,
  });

  final ValueNotifier<CodeAutocompleteEditingValue> notifier;
  final ValueChanged<CodeAutocompleteResult> onSelected;

  static const width = 440.0;
  static const rowHeight = 26.0;
  static const maxRows = 8;
  static const docHeight = 64.0;

  @override
  Size get preferredSize {
    final n = notifier.value.prompts.length.clamp(1, maxRows);
    return Size(width, n * rowHeight + docHeight + 10);
  }

  @override
  State<ScriptCompletionView> createState() => _ScriptCompletionViewState();
}

class _ScriptCompletionViewState extends State<ScriptCompletionView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_changed);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final i = widget.notifier.value.index;
    const h = ScriptCompletionView.rowHeight;
    if (!_scroll.hasClients) return;
    final view = _scroll.position.viewportDimension;
    final top = i * h;
    if (top < _scroll.offset) {
      _scroll.jumpTo(top);
    } else if (top + h > _scroll.offset + view) {
      _scroll.jumpTo(top + h - view);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final v = widget.notifier.value;
    final items = [
      for (final p in v.prompts)
        if (p is ScriptCodePrompt) p.item,
    ];
    final selected = items.isEmpty
        ? null
        : items[v.index.clamp(0, items.length - 1)];
    final rows = items.length.clamp(1, ScriptCompletionView.maxRows);
    final mono = TextStyle(
      fontFamily: WonkyTheme.monoFamily,
      fontSize: 12.5,
      color: cs.popoverForeground,
    );
    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: const ValueKey<String>('script.completion'),
        width: ScriptCompletionView.width,
        decoration: BoxDecoration(
          color: cs.popover,
          border: Border.all(color: cs.border),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: rows * ScriptCompletionView.rowHeight,
              child: ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.zero,
                itemExtent: ScriptCompletionView.rowHeight,
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final on = i == v.index;
                  return GestureDetector(
                    key: ValueKey<String>('script.completion.${item.label}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onSelected(
                      widget.notifier.value.copyWith(index: i).autocomplete,
                    ),
                    child: Container(
                      color: on ? cs.accent : null,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(
                            completionIcon(item.kind),
                            size: 14,
                            color: cs.mutedForeground,
                          ),
                          const SizedBox(width: 8),
                          Text(item.label, style: mono),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.detail,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: mono.copyWith(
                                fontSize: 11.5,
                                color: cs.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(height: 1, color: cs.border),
            SizedBox(
              height: ScriptCompletionView.docHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                child: Text(
                  selected == null
                      ? ''
                      : (selected.doc.isEmpty ? selected.detail : selected.doc),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    color: cs.popoverForeground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------- squiggles and hover

/// Decorates the highlighted spans of one code line (09 §14.1): wavy
/// underlines under diagnostics (squiggles) and hover targets on API
/// identifiers (hover docs).
class ScriptSpanDecorator {
  ScriptSpanDecorator({
    required this.colors,
    required this.problems,
    required this.onHoverEnter,
    required this.onHoverExit,
  });

  /// Current color scheme (theme changes rebuild the decorator).
  ShadColorScheme Function() colors;

  /// Diagnostics of the file by 0-based line.
  Map<int, List<ScriptDiagnostic>> Function() problems;

  /// Hover on the identifier at (line, column) with its screen rects.
  void Function(int line, int column, Rect rect) onHoverEnter;
  VoidCallback onHoverExit;

  static final _ident = RegExp(r'[A-Za-z_$][\w$]*');

  /// Names worth a hover target (API classes and members).
  static final Set<String> _apiNames = {
    for (final c in ApiIndex.standard.classes) ...[
      c.name,
      for (final m in c.members) m.name,
    ],
  }..remove('');

  /// `CodeLineSpanBuilder`.
  TextSpan build({
    required BuildContext context,
    required int index,
    required CodeLine codeLine,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    final text = codeLine.text;
    if (text.isEmpty) return textSpan;
    final cs = colors();
    final underline = <(int, int, Color)>[];
    for (final d in problems()[index] ?? const <ScriptDiagnostic>[]) {
      final col = ((d.column ?? 1) - 1).clamp(0, text.length);
      var end = col;
      final m = _ident.matchAsPrefix(text, col);
      if (m != null) {
        end = m.end;
      } else {
        end = text.indexOf(RegExp(r'\s'), col);
        if (end < 0) end = text.length;
      }
      if (end <= col) {
        // Past the end of the line: underline the last token.
        final start = text.trimRight().lastIndexOf(RegExp(r'\s')) + 1;
        underline.add((
          start,
          text.trimRight().length,
          problemColor(cs, d.severity),
        ));
      } else {
        underline.add((col, end, problemColor(cs, d.severity)));
      }
    }
    final hovers = <(int, int)>[];
    final comment = text.indexOf('//');
    for (final m in _ident.allMatches(text)) {
      if (comment >= 0 && m.start > comment) break;
      if (_apiNames.contains(m.group(0))) hovers.add((m.start, m.end));
    }
    if (underline.isEmpty && hovers.isEmpty) return textSpan;
    // Flatten the highlighted tree into styled leaves.
    final leaves = <(String, TextStyle?)>[];
    void walk(InlineSpan s, TextStyle? inherited) {
      if (s is! TextSpan) return;
      final st = inherited == null ? s.style : inherited.merge(s.style);
      if (s.text != null && s.text!.isNotEmpty) leaves.add((s.text!, st));
      for (final c in s.children ?? const <InlineSpan>[]) {
        walk(c, st);
      }
    }

    walk(textSpan, null);
    final cuts = <int>{0, text.length};
    for (final (a, b, _) in underline) {
      cuts
        ..add(a)
        ..add(b);
    }
    for (final (a, b) in hovers) {
      cuts
        ..add(a)
        ..add(b);
    }
    var pos = 0;
    final children = <InlineSpan>[];
    for (final (t, st) in leaves) {
      final leafEnd = pos + t.length;
      final inner = [
        for (final c in cuts)
          if (c > pos && c < leafEnd) c,
      ]..sort();
      var start = pos;
      for (final c in [...inner, leafEnd]) {
        final segment = t.substring(start - pos, c - pos);
        Color? wave;
        for (final (a, b, color) in underline) {
          if (start >= a && c <= b) wave = color;
        }
        final segStyle = wave == null
            ? st
            : (st ?? const TextStyle()).copyWith(
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.wavy,
                decorationColor: wave,
                decorationThickness: 1.6,
              );
        final hover = hovers.where((h) => start >= h.$1 && c <= h.$2);
        if (hover.isNotEmpty) {
          final col = hover.first.$1;
          children.add(
            MouseTrackerAnnotationTextSpan(
              text: segment,
              style: segStyle,
              onEnterWithRect:
                  (PointerEnterEvent e, int id, List<Rect> rects) =>
                      onHoverEnter(
                        index,
                        col,
                        rects.isEmpty ? Rect.zero : rects.first,
                      ),
              onExitWithRect: (_, _, _) => onHoverExit(),
            ),
          );
        } else {
          children.add(TextSpan(text: segment, style: segStyle));
        }
        start = c;
      }
      pos = leafEnd;
    }
    return TextSpan(style: textSpan.style, children: children);
  }
}

/// The hover docs popup (09 §14.4 P1): signature in mono and the doc
/// comment, shown after a short delay next to the hovered identifier.
class ScriptHoverPopup {
  ScriptHoverPopup(this.context);

  final BuildContext context;
  OverlayEntry? _entry;
  Timer? _show;
  Timer? _hide;
  bool _inside = false;

  /// Shows [info] below [rect] (global) after 450 ms.
  void schedule(HoverInfo info, Rect rect) {
    _hide?.cancel();
    _show?.cancel();
    _show = Timer(const Duration(milliseconds: 450), () => _open(info, rect));
  }

  /// Hides soon (the pointer may move into the popup).
  void leave() {
    _show?.cancel();
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 250), () {
      if (!_inside) close();
    });
  }

  void close() {
    _show?.cancel();
    _hide?.cancel();
    _entry?.remove();
    _entry = null;
    _inside = false;
  }

  void _open(HoverInfo info, Rect rect) {
    close();
    if (!context.mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final size = MediaQuery.sizeOf(context);
    const width = 420.0;
    final left = rect.left.clamp(
      8.0,
      (size.width - width - 8).clamp(8.0, size.width),
    );
    final below = rect.bottom + 4;
    final showAbove = below + 160 > size.height;
    _entry = OverlayEntry(
      builder: (ctx) {
        final theme = ShadTheme.of(ctx);
        final cs = theme.colorScheme;
        return Positioned(
          left: left,
          top: showAbove ? null : below,
          bottom: showAbove ? size.height - rect.top + 4 : null,
          child: MouseRegion(
            onEnter: (_) => _inside = true,
            onExit: (_) {
              _inside = false;
              leave();
            },
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                key: const ValueKey<String>('script.hover'),
                constraints: const BoxConstraints(
                  maxWidth: width,
                  maxHeight: 240,
                ),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.popover,
                  border: Border.all(color: cs.border),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: TextStyle(
                          fontFamily: WonkyTheme.monoFamily,
                          fontSize: 12.5,
                          color: cs.popoverForeground,
                        ),
                      ),
                      if (info.doc.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          info.doc,
                          style: theme.textTheme.small.copyWith(
                            color: cs.popoverForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
  }

  void dispose() => close();
}
