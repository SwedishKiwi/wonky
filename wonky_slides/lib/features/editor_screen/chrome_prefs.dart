import 'dart:async';
import 'dart:convert';

import 'package:wonky_app/wonky_app.dart' show LocalStore;

/// The editor chrome's per-user, per-device view preferences (Slides 04
/// §17 A-04-1: `navigatorVisible`, `notesVisible`, `inspectorVisible`,
/// `inspectorTab`, `navigatorWidth`, `inspectorWidth`, `notesHeight`,
/// plus the View › Show toggles that are not Slides
/// settings: rulers, guides, comment pins):
/// not synced, not undoable. Stored as one JSON value under
/// `slides.chrome` in the shell's user store.
class SlidesChromePrefs {
  SlidesChromePrefs({
    this.navigatorVisible = true,
    this.inspectorVisible = true,
    this.notesVisible = true,
    this.inspectorTab = 'format',
    this.rulers = false,
    this.guides = true,
    this.commentPins = true,
    this.navigatorWidth = 220,
    this.inspectorWidth = 300,
    this.notesHeight = 120,
  });

  static const storeKey = 'slides.chrome';

  bool navigatorVisible;
  bool inspectorVisible;
  bool notesVisible;
  String inspectorTab;
  bool rulers;
  bool guides;
  bool commentPins;

  /// Navigator width (160–400 px, 04 §5.1).
  double navigatorWidth;

  /// Inspector width (260–420 px, 04 §7.1).
  double inspectorWidth;

  /// Speaker notes height (≥ 48 px, 04 §8).
  double notesHeight;

  Map<String, Object?> toJson() => {
    'navigatorVisible': navigatorVisible,
    'inspectorVisible': inspectorVisible,
    'notesVisible': notesVisible,
    'inspectorTab': inspectorTab,
    'rulers': rulers,
    'guides': guides,
    'commentPins': commentPins,
    'navigatorWidth': navigatorWidth,
    'inspectorWidth': inspectorWidth,
    'notesHeight': notesHeight,
  };

  /// Parses [json] (a JSON string or map); invalid values keep defaults.
  static SlidesChromePrefs fromJson(Object? json) {
    final p = SlidesChromePrefs();
    Object? raw = json;
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        return p;
      }
    }
    if (raw is! Map) return p;
    bool b(String k, bool d) =>
        raw is Map && raw[k] is bool ? raw[k] as bool : d;
    p
      ..navigatorVisible = b('navigatorVisible', true)
      ..inspectorVisible = b('inspectorVisible', true)
      ..notesVisible = b('notesVisible', true)
      ..rulers = b('rulers', false)
      ..guides = b('guides', true)
      ..commentPins = b('commentPins', true);
    double n(String k, double d, double min, double max) {
      final v = raw is Map ? raw[k] : null;
      return v is num ? v.toDouble().clamp(min, max) : d;
    }

    p
      ..navigatorWidth = n('navigatorWidth', 220, 160, 400)
      ..inspectorWidth = n('inspectorWidth', 300, 260, 420)
      ..notesHeight = n('notesHeight', 120, 48, 2000);
    final tab = raw['inspectorTab'];
    if (tab is String && const {'format', 'animate', 'slide'}.contains(tab)) {
      p.inspectorTab = tab;
    }
    return p;
  }

  /// Reads the stored preferences (defaults when missing or unreadable).
  static Future<SlidesChromePrefs> read(LocalStore store) async {
    try {
      return fromJson(await store.read(storeKey));
    } catch (_) {
      return SlidesChromePrefs();
    }
  }

  /// Stores the preferences (best effort).
  void write(LocalStore store) {
    unawaited(
      store.write(storeKey, jsonEncode(toJson())).catchError((Object _) {}),
    );
  }
}
