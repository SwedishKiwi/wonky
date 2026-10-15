import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_slides_core/clipboard.dart';

import '../clipboard/system_clipboard.dart';
import '../editor_screen/deck_editor_controller.dart';

/// The in-app Slides clipboard (Slides 04 §5.8, 03 §12.1, 02 §7
/// `slides.clipboard`): the last copied payload (03 §12.2: slides, groups,
/// elements or text) kept in memory for this window — so it pastes into
/// any deck opened later, the cross-deck paste of 04 AC-4 — and in the
/// user's local store (it survives a reload; offline too). [put] also
/// writes the system clipboard (SL-18): `text/plain` (outline or text),
/// `text/html` with the payload embedded (other tabs, decks and the other
/// Wonky Work apps paste it) and, when given, `image/png`.
abstract final class SlidesSlideClipboard {
  static const storeKey = 'slides.clipboard';

  static Map<String, Object?>? _payload;

  /// The in-memory payload (tests, enabled states).
  static Map<String, Object?>? get current => _payload;

  /// Whether a slides/groups payload is ready to paste.
  static bool get hasSlides {
    final kind = _payload?['kind'];
    return kind == SlidesClipboardCodec.kindSlides ||
        kind == SlidesClipboardCodec.kindGroups;
  }

  /// Whether an elements payload is ready to paste.
  static bool get hasElements =>
      _payload?['kind'] == SlidesClipboardCodec.kindElements;

  /// The `text/plain` written with the current payload (a system clipboard
  /// holding exactly this text and no HTML holds this payload).
  static String? get currentPlainText {
    final p = _payload;
    return p == null ? null : SlidesClipboardCodec.plainText(p);
  }

  /// Makes [payload] the current one without writing anything (a payload
  /// read from the system clipboard).
  static void adopt(Map<String, Object?> payload) => _payload = payload;

  /// Stores [payload] (memory, local store) and writes the system
  /// clipboard (plain text, HTML with the embedded payload, [png]).
  static Future<void> put(
    LocalStore store,
    Map<String, Object?> payload, {
    Uint8List? png,
  }) async {
    _payload = payload;
    try {
      await store.write(storeKey, SlidesClipboardCodec.encode(payload));
    } catch (_) {
      // Best effort: the in-memory payload still pastes in this window.
    }
    try {
      await SlidesSystemClipboard.instance.write(
        SlidesClipboardData(
          plainText: SlidesClipboardCodec.plainText(payload),
          html: SlidesHtml.ofPayload(payload),
          image: png,
          imageType: png == null ? null : 'image/png',
        ),
      );
    } catch (_) {
      // No system clipboard (tests, denied permission).
    }
  }

  /// The payload to paste: memory first, else the local store.
  static Future<Map<String, Object?>?> read(LocalStore store) async {
    if (_payload != null) return _payload;
    try {
      final raw = await store.read(storeKey);
      if (raw is! String) return null;
      final p = SlidesClipboardCodec.decode(raw);
      if (p != null) _payload = p;
      return p;
    } catch (_) {
      return null;
    }
  }

  /// Loads the stored payload into memory (after a reload).
  static void warm(LocalStore store) {
    if (_payload != null) return;
    unawaited(read(store));
  }

  /// Clears the in-memory payload (tests).
  static void debugClear() => _payload = null;

  /// The payload as a decoded JSON copy (pastes never share maps).
  static Map<String, Object?> copyOf(Map<String, Object?> p) =>
      (jsonDecode(jsonEncode(p)) as Map).cast<String, Object?>();
}

/// Whether the navigator selection owns the clipboard and Select all of
/// [editor] (04 §5.8): the navigator or grid view has focus, or nothing is
/// selected on the canvas and no text (body or speaker notes) is being
/// edited.
bool navigatorOwnsClipboard(DeckEditorController editor) {
  if (editor.mode == DeckViewMode.grid) return true;
  if (editor.mode != DeckViewMode.normal) return false;
  if (editor.navigatorFocus.hasFocus) return true;
  if (editor.notesFocus.hasFocus) return false;
  return editor.selectedElementIds.isEmpty && !editor.textEditing;
}
