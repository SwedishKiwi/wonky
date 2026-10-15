import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart' show UndoService;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart' show SlidesTables;

import '../../editor_screen/deck_editor_controller.dart';
import '../../text_editing/slide_text_editor.dart' show recordTypingStep;

/// The code block view state of an open deck (Slides 07 §3.2, §7, A-07-5):
/// per-user, not synced and not undoable.
///
/// - the **edit state** of each code element (the state the canvas shows
///   and the field edits; the state strip selects it, `Alt+Shift+←/→`);
/// - the **previewed step** (the line step selected in the inspector is
///   shown on the canvas);
/// - the diff gutter toggle (*Show changes*);
/// - the running in-place edit ([editing], [CodeEditSession]);
/// - the running transition preview ([preview], ▶ in the state strip);
/// - recently used languages (picker order, 07 §2.4).
///
/// Changes notify the editor, so the canvas, toolbar and inspector follow.
class CodeBlockView extends ChangeNotifier {
  CodeBlockView._(this.editor) {
    editor.session.model.addListener(_onBatch);
  }

  static final Expando<CodeBlockView> _registry = Expando('slidesCodeView');

  /// The view state of [ed].
  static CodeBlockView of(DeckEditorController ed) =>
      _registry[ed] ??= CodeBlockView._(ed);

  /// The view state of [ed] if it was ever created (no allocation).
  static CodeBlockView? maybeOf(DeckEditorController ed) => _registry[ed];

  final DeckEditorController editor;

  final Map<String, int> _states = {};
  final Map<String, int> _steps = {};
  bool _diffGutter = false;
  CodeEditSession? _editing;
  CodePreviewRequest? _preview;

  /// Recently used languages, newest first (max 5; shared by the session's
  /// pickers).
  static final List<String> recentLanguages = [];

  /// Remembers [language] as recently used.
  static void useLanguage(String language) {
    if (language.isEmpty) return;
    recentLanguages
      ..remove(language)
      ..insert(0, language);
    if (recentLanguages.length > 5) recentLanguages.removeLast();
  }

  DeckModel get model => editor.session.model;

  /// The `CodeState` rows of [elementId] in order.
  List<CodeStateRec> statesOf(String elementId) =>
      model.codeStatesOf(elementId);

  /// The edit state index of [elementId] (clamped to its states).
  int stateIndexOf(String elementId) {
    final n = statesOf(elementId).length;
    if (n == 0) return 0;
    return (_states[elementId] ?? 0).clamp(0, n - 1);
  }

  /// The edit state row of [elementId], or null.
  CodeStateRec? stateOf(String elementId) {
    final states = statesOf(elementId);
    if (states.isEmpty) return null;
    return states[stateIndexOf(elementId)];
  }

  /// Selects state [index] of [elementId] as the edit state (clears the
  /// step preview).
  void selectState(String elementId, int index) {
    final n = statesOf(elementId).length;
    final i = index.clamp(0, n == 0 ? 0 : n - 1);
    if (stateIndexOf(elementId) == i && !_steps.containsKey(elementId)) {
      return;
    }
    _editing?.commit();
    _states[elementId] = i;
    _steps.remove(elementId);
    _changed();
  }

  /// The previewed highlight step (0-based) of [elementId], or null.
  int? stepOf(String elementId) => _steps[elementId];

  /// Shows step [step] (0-based; null = none) of the edit state on the
  /// canvas.
  void previewStep(String elementId, int? step) {
    if (_steps[elementId] == step) return;
    if (step == null) {
      _steps.remove(elementId);
    } else {
      _steps[elementId] = step;
    }
    _changed();
  }

  /// Edit states that aren't the first (the canvas scene's `codeStates`).
  Map<String, int> get stateMap => {
    for (final e in _states.entries)
      if (model.element(e.key) != null) e.key: stateIndexOf(e.key),
  };

  /// Previewed steps (the canvas scene's `codeSteps`).
  Map<String, int> get stepMap => Map.unmodifiable(_steps);

  /// Whether the edit mode gutter marks changes against the previous state
  /// (07 §7 *Show changes*).
  bool get diffGutter => _diffGutter;

  void toggleDiffGutter() {
    _diffGutter = !_diffGutter;
    _changed();
  }

  // ------------------------------------------------------------- editing

  /// The running in-place edit, or null.
  CodeEditSession? get editing => _editing;

  /// Starts editing the edit state of [elementId] (ends another edit).
  CodeEditSession? beginEdit(
    String elementId, {
    required UndoService? undo,
    required String undoLabel,
  }) {
    final state = stateOf(elementId);
    if (state == null) return null;
    final cur = _editing;
    if (cur != null) {
      if (cur.elementId == elementId && cur.stateId == state.id) return cur;
      endEdit();
    }
    _preview = null;
    _editing = CodeEditSession(
      editor: editor,
      elementId: elementId,
      stateId: state.id,
      undo: undo,
      undoLabel: undoLabel,
    );
    _changed();
    return _editing;
  }

  /// Ends the in-place edit (pending text is written).
  void endEdit() {
    final s = _editing;
    if (s == null) return;
    _editing = null;
    s.close();
    _changed();
  }

  /// Writes pending code now (before undo/redo).
  SlidesPlan? commitEdit() => _editing?.commit();

  // ------------------------------------------------------------- preview

  /// The running transition preview, or null.
  CodePreviewRequest? get preview => _preview;

  /// Plays the change into state [to] (from the state before it, or from
  /// empty for the first: the type-in) on the canvas.
  void startPreview(String elementId, int to) {
    endEdit();
    _preview = CodePreviewRequest(elementId, to - 1, to, _previewSerial++);
    _changed();
  }

  int _previewSerial = 0;

  /// Stops the preview.
  void stopPreview() {
    if (_preview == null) return;
    _preview = null;
    _changed();
  }

  void _onBatch(DeckChangeBatch batch) {
    final e = _editing;
    if (e != null && model.record(SlidesTables.codeState, e.stateId) == null) {
      _editing = null;
      e.close(write: false);
    }
    _states.removeWhere((id, _) => model.element(id) == null);
    _steps.removeWhere((id, _) => model.element(id) == null);
    final p = _preview;
    if (p != null && model.element(p.elementId) == null) _preview = null;
  }

  void _changed() {
    notifyListeners();
    editor.notifyListeners();
  }

  @override
  void dispose() {
    editor.session.model.removeListener(_onBatch);
    _editing?.close();
    super.dispose();
  }
}

/// A transition preview: the change of [elementId] from state [from] (−1 =
/// empty, the type-in) to [to]; [serial] restarts it.
@immutable
class CodePreviewRequest {
  const CodePreviewRequest(this.elementId, this.from, this.to, this.serial);

  final String elementId;
  final int from;
  final int to;
  final int serial;
}

/// One in-place edit of a code state (07 §3.5): the field's text is
/// written with `SetCode` after [commitDelay] of idle typing and when the
/// edit ends; each write is a `slides.rows` undo step coalescing per state
/// (`slides.code:<stateId>`, one step per typing burst, suite 08 §3.1).
/// Undo, redo and collaborators' changes reach the field through [text]
/// when no local edit is pending.
class CodeEditSession extends ChangeNotifier {
  CodeEditSession({
    required this.editor,
    required this.elementId,
    required this.stateId,
    required this.undo,
    required this.undoLabel,
    this.commitDelay = const Duration(milliseconds: 300),
  }) {
    _stored = _read();
    editor.session.model.addListener(_onBatch);
  }

  final DeckEditorController editor;
  final String elementId;
  final String stateId;
  final UndoService? undo;
  final String undoLabel;
  final Duration commitDelay;

  String _stored = '';
  String? _pending;
  Timer? _timer;
  bool _closed = false;
  bool _writing = false;

  /// The undo coalescing key of this state's typing.
  String get coalesceKey => 'slides.code:$stateId';

  /// The code being edited.
  String get text => _pending ?? _stored;

  /// Whether edits wait to be written.
  bool get hasPendingEdits => _pending != null;

  String _read() {
    final rec = editor.session.model.record(SlidesTables.codeState, stateId);
    return rec is CodeStateRec ? rec.code.replaceAll('\r\n', '\n') : '';
  }

  /// The field changed (whole text).
  void edit(String text) {
    if (_closed) return;
    final next = text.replaceAll('\r\n', '\n');
    if (next == text && next == (_pending ?? _stored)) return;
    _pending = next;
    _timer?.cancel();
    _timer = Timer(commitDelay, commit);
    notifyListeners();
  }

  /// Writes pending edits now.
  SlidesPlan? commit() {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    if (pending == null) return null;
    _pending = null;
    if (pending == _read()) return null;
    final SlidesPlan plan;
    try {
      _writing = true;
      plan = editor.session.execute(SetCode(stateId, pending));
    } on PlanException {
      return null;
    } finally {
      _writing = false;
    }
    _stored = _read();
    final u = undo;
    if (!plan.isEmpty && u != null) {
      recordTypingStep(u, plan, coalesceKey: coalesceKey, label: undoLabel);
    }
    notifyListeners();
    return plan;
  }

  void _onBatch(DeckChangeBatch batch) {
    if (_writing || _closed) return;
    final now = _read();
    if (now == _stored) return;
    _stored = now;
    // Local edits that weren't written yet win (02 §4.4).
    if (_pending != null) return;
    notifyListeners();
  }

  /// Ends the session ([write]: pending text is written first).
  void close({bool write = true}) {
    if (_closed) return;
    if (write) commit();
    _closed = true;
    _timer?.cancel();
    editor.session.model.removeListener(_onBatch);
    notifyListeners();
  }

  @override
  void dispose() {
    close(write: false);
    super.dispose();
  }
}
