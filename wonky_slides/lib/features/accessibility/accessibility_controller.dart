import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_slides_core/model.dart' show DeckChangeBatch;

import '../editor_screen/deck_editor_controller.dart';
import 'accessibility_checker.dart';

/// The accessibility checker of [editor] (one per open deck).
AccessibilityController accessibilityOf(DeckEditorController editor) =>
    AccessibilityController._of[editor] ??= AccessibilityController._(editor);

/// The checker state of one open deck (03 §17.4): the last report, kept
/// current while the Accessibility panel is open (re-checked [delay] after
/// the deck changes).
class AccessibilityController extends ChangeNotifier {
  AccessibilityController._(this.editor);

  static final Expando<AccessibilityController> _of = Expando('a11yCheck');

  final DeckEditorController editor;

  /// How long after a change the open panel re-checks.
  static const delay = Duration(milliseconds: 400);

  AccessibilityReport? _report;
  int _watchers = 0;
  Timer? _timer;
  bool _disposed = false;

  /// The last report (null before the first check).
  AccessibilityReport? get report => _report;

  /// Checks the deck now.
  AccessibilityReport check() {
    _timer?.cancel();
    final r = AccessibilityChecker.check(
      editor.model,
      resolver: editor.resolver,
    );
    _report = r;
    if (!_disposed) notifyListeners();
    return r;
  }

  /// The panel is showing: re-check after changes until [unwatch].
  void watch() {
    if (_watchers++ == 0) editor.model.addListener(_onBatch);
    if (_report == null) check();
  }

  void unwatch() {
    if (_watchers == 0) return;
    if (--_watchers == 0) {
      editor.model.removeListener(_onBatch);
      _timer?.cancel();
    }
  }

  void _onBatch(DeckChangeBatch batch) {
    _timer?.cancel();
    _timer = Timer(delay, check);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_watchers > 0) editor.model.removeListener(_onBatch);
    super.dispose();
  }
}
