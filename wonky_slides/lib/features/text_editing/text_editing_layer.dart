import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../../commands/slides_command.dart' show SlidesKeyScopes;
import '../editor_screen/deck_editor_controller.dart';
import 'slide_text_editor.dart';
import 'text_editing_host.dart';

/// The text editing layer of the canvas (03 §6.1): the super_editor overlay
/// of the body being edited, in the stage's coordinate space (a full-slide
/// box at the slide origin, logical px = su × [zoom]), inside the
/// `slidesText` key scope.
///
/// Keys: the editor's own (typing, IME, selection, Enter, Shift+Enter)
/// first, except Mod+C/X/V, which run the Slides clipboard commands
/// (SL-18); then the host keys — Esc and Mod+Enter end editing,
/// Tab / Shift+Tab run `slides.format.indent` / `outdent`, Mod+Z / Mod+Shift+Z
/// write pending typing and run the shell's undo/redo; then the `slidesText`
/// bindings and chords with Mod/Alt of the global scope (format commands,
/// links, comments). Nothing else bubbles to the canvas scope, so arrows,
/// Delete and letters never nudge, delete or arm tools while typing.
class SlideTextEditingLayer extends StatelessWidget {
  const SlideTextEditingLayer({
    super.key,
    required this.editor,
    required this.zoom,
    this.caretColor = const Color(0xFF2563EB),
    this.selectionColor = const Color(0x552563EB),
  });

  final DeckEditorController editor;

  /// Logical px per su.
  final double zoom;
  final Color caretColor;
  final Color selectionColor;

  /// Key of the layer (tests, driver).
  static const layerKey = ValueKey<String>('slides.canvas.textEditing');

  @override
  Widget build(BuildContext context) {
    final host = textEditingOf(editor);
    final c = host.active;
    if (c == null) return const SizedBox.shrink();
    WidgetsBinding.instance.addPostFrameCallback((_) => host.afterLayout());
    final keymap = editor.services.keymap;
    return Focus(
      key: layerKey,
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) => _scopeKey(context, keymap, event),
      child: SlideTextEditorOverlay(
        key: ObjectKey(c),
        controller: c,
        zoom: zoom,
        caretColor: caretColor,
        selectionColor: selectionColor,
        focusNode: host.editorFocus,
        documentLayoutKey: host.documentLayoutKey,
        onExit: () => _exit(host),
        onUndo: () => _invoke('shell.edit.undo'),
        onRedo: () => _invoke('shell.edit.redo'),
        onHostKey: (e) => _hostKey(host, e),
      ),
    );
  }

  void _invoke(String id, [Map<String, Object?> args = const {}]) => unawaited(
    editor.services.dispatcher.invoke(
      id,
      args: args,
      source: InvocationSource.shortcut,
    ),
  );

  bool get _mod => defaultTargetPlatform == TargetPlatform.macOS
      ? HardwareKeyboard.instance.isMetaPressed
      : HardwareKeyboard.instance.isControlPressed;

  /// Esc: a table cell becomes the cell selection (SL-15), other bodies
  /// end editing with the element selected.
  void _exit(SlideTextEditing host) {
    final cell = host.cell;
    final id = host.elementId;
    final onCell = SlideTextEditing.onCellExit;
    if (cell == null || id == null || onCell == null) {
      host.end();
      return;
    }
    onCell(host, id, cell.rowId, cell.columnId);
  }

  bool _hostKey(SlideTextEditing host, KeyEvent e) {
    if (host.cell != null &&
        (SlideTextEditing.cellKeys?.call(host, e) ?? false)) {
      return true;
    }
    final key = e.logicalKey;
    final k = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.tab && !_mod && !k.isAltPressed) {
      final id = k.isShiftPressed
          ? 'slides.format.outdent'
          : 'slides.format.indent';
      if (editor.services.dispatcher.stateOf(id).enabled) _invoke(id);
      return true;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        _mod) {
      host.end();
      return true;
    }
    // Clipboard (SL-18, 03 §12): rich Slides/Write/HTML content, one undo
    // step per paste or cut.
    if (_mod && !k.isAltPressed) {
      final id = switch (key) {
        LogicalKeyboardKey.keyC => 'slides.edit.copy',
        LogicalKeyboardKey.keyX => 'slides.edit.cut',
        LogicalKeyboardKey.keyV => 'slides.edit.paste',
        _ => null,
      };
      if (id != null) {
        if (editor.services.dispatcher.stateOf(id).enabled) {
          _invoke(id, {
            if (id == 'slides.edit.paste' && k.isShiftPressed)
              'plainText': true,
          });
        }
        return true;
      }
    }
    return false;
  }

  KeyEventResult _scopeKey(
    BuildContext context,
    KeymapService keymap,
    KeyEvent event,
  ) {
    final r = keymap.handle(event, SlidesKeyScopes.text, context: context);
    if (r != KeyEventResult.ignored) return r;
    final k = HardwareKeyboard.instance;
    final chord = k.isMetaPressed || k.isControlPressed || k.isAltPressed;
    if (chord) {
      final g = keymap.handle(event, KeyScope.global, context: context);
      if (g != KeyEventResult.ignored) return g;
    }
    // The platform (IME) gets the key; the canvas scope never sees it.
    return KeyEventResult.skipRemainingHandlers;
  }
}
