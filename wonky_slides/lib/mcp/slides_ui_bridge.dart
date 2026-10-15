import 'package:wonky_app/wonky_app.dart';

import '../features/canvas/canvas_interactions.dart';
import '../features/collab/slides_collab.dart';
import '../features/collab/soft_locks.dart';
import '../features/editor_screen/deck_editor_controller.dart';
import '../l10n/slides_l10n.dart';
import 'agent_flash.dart';
import 'agent_writes.dart';

/// The per-deck parts of the Slides UI bridge (Slides 11 §5; SL-42),
/// attached by the deck editor screen when the deck is ready: the agent
/// highlights ([SlidesAgentFlash], drawn by [AgentFlashLayer]), the flash
/// of headless agent writes ([SlidesAgentWrites]) and the soft-lock
/// popover as an MCP-describable dialog ([SoftLockDialog], 04 §13.11).
class SlidesUiBridge {
  SlidesUiBridge._(this.editor, {DeckChangeLogSource? changeLogs})
    : flash = SlidesAgentFlash.of(editor) {
    writes = SlidesAgentWrites(editor, source: changeLogs, flash: flash);
    final locks = SlidesCollab.of(editor)?.locks;
    _locks = locks;
    locks?.prompt.addListener(_onPrompt);
    _onPrompt();
  }

  static final Expando<SlidesUiBridge> _of = Expando('slidesUiBridge');

  /// The bridge of [editor] (null when not attached).
  static SlidesUiBridge? of(DeckEditorController editor) => _of[editor];

  /// Attaches (or returns) the bridge of [editor]; [changeLogs] overrides
  /// the replica's change log (tests).
  static SlidesUiBridge attach(
    DeckEditorController editor, {
    DeckChangeLogSource? changeLogs,
  }) {
    CanvasInteractions.register(AgentFlashLayer.new);
    return _of[editor] ??= SlidesUiBridge._(editor, changeLogs: changeLogs);
  }

  final DeckEditorController editor;
  final SlidesAgentFlash flash;
  late final SlidesAgentWrites writes;
  SlidesSoftLocks? _locks;
  SoftLockDialog? _dialog;

  ShellServices get services => editor.services;

  void _onPrompt() {
    final p = _locks?.prompt.value;
    final current = _dialog;
    if (current != null && !identical(current.prompt, p)) {
      services.openDialogs.remove(current);
      _dialog = null;
    }
    if (p != null && _dialog == null && !p.answered) {
      final d = SoftLockDialog(p, _locks!, services);
      _dialog = d;
      services.openDialogs.add(d);
    }
  }

  void dispose() {
    _locks?.prompt.removeListener(_onPrompt);
    final d = _dialog;
    if (d != null) services.openDialogs.remove(d);
    _dialog = null;
    writes.dispose();
    flash.dispose();
    if (_of[editor] == this) _of[editor] = null;
  }
}

/// The soft-lock popover (04 §13.11, *custom*) for `ui.get_dialog` /
/// `ui.press_dialog_button`: *"Anna is editing this text."* with the
/// buttons `no` (Cancel / Stop editing) and `yes` (Edit anyway / Keep
/// editing) — the popover's own keys (`slides.softLock.no` / `.yes`).
class SoftLockDialog implements McpDescribableDialog {
  SoftLockDialog(this.prompt, this.locks, this.services);

  final SoftLockPrompt prompt;
  final SlidesSoftLocks locks;
  final ShellServices services;

  @override
  Map<String, Object?> describe() {
    final l = slidesL10nOf(services);
    final names = locks.namesOf(prompt.holders);
    return {
      'title': prompt.race
          ? l.softLockRaceMessage(names)
          : prompt.target.kind == 'notes'
          ? l.softLockNotesMessage(names)
          : l.softLockMessage(names),
      'kind': 'softLock',
      'target': {
        'kind': prompt.target.kind,
        'slide_id': ?prompt.target.slideId,
        'element_id': ?prompt.target.elementId,
      },
      'fields': const <Object?>[],
      'buttons': [
        {'id': 'no', 'label': prompt.race ? l.softLockStop : l.softLockCancel},
        {
          'id': 'yes',
          'label': prompt.race ? l.softLockKeep : l.softLockEditAnyway,
        },
      ],
    };
  }

  @override
  bool setField(String id, Object? value) => false;

  @override
  bool press(String buttonId) {
    switch (buttonId) {
      case 'yes':
        prompt.answer(true);
      case 'no' || 'cancel':
        prompt.answer(false);
      default:
        return false;
    }
    return true;
  }
}
