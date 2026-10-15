import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

import '../../l10n/slides_l10n.dart';
import '../canvas/slide_canvas_controller.dart';
import '../editor_screen/deck_editor_controller.dart';

/// The paste modes of *Paste special* and the paste options chip (03
/// §12.3, 04 §13.12).
abstract final class PasteModes {
  /// *Use destination theme* (default of cross-deck slide pastes).
  static const useDestination = 'useDestination';

  /// *Keep source formatting* (brings the source theme along).
  static const keepSource = 'keepSource';

  /// *Paste chart unlinked* (a Sheets chart as a static chart).
  static const unlinked = 'unlinked';

  /// A linked Sheets chart (the default of chart pastes).
  static const linked = 'linked';

  static const all = [useDestination, keepSource, unlinked];
}

/// What the chip can re-run.
@immutable
class PasteOptionsState {
  const PasteOptionsState({
    required this.kind,
    required this.modes,
    required this.current,
    required this.source,
    this.bounds,
  });

  /// `slides` (cross-deck slides/groups) or `sheetsChart`.
  final String kind;

  /// The modes the chip offers (`PasteModes`).
  final List<String> modes;

  /// The mode the paste used.
  final String current;

  /// What was pasted (re-run by `slides.edit.pasteSpecial`): the Slides
  /// payload, or the Sheets objects items.
  final Object source;

  /// The pasted range on the slide (su; null = the canvas corner).
  final SuRect? bounds;
}

/// The paste options chip of an open deck (04 §13.12): shown after a
/// cross-deck slide paste or a Sheets chart paste, not modal; it
/// disappears after [lifetime] or on the next edit (another undo step).
/// Its options run `slides.edit.pasteSpecial`, which replaces the paste's
/// undo step.
class PasteOptions extends ChangeNotifier {
  PasteOptions._(this.editor) {
    editor.services.undo.addListener(_onUndo);
  }

  static final Expando<PasteOptions> _registry = Expando('slidesPasteChip');

  /// The chip of [ed].
  static PasteOptions of(DeckEditorController ed) =>
      _registry[ed] ??= PasteOptions._(ed);

  /// How long the chip stays.
  static const lifetime = Duration(seconds: 10);

  final DeckEditorController editor;

  PasteOptionsState? _state;
  Timer? _timer;
  String? _stepId;
  bool _awaitStep = false;

  /// The chip's state (null = hidden).
  PasteOptionsState? get state => _state;

  /// Whether the paste's undo step is still the newest one (a re-run
  /// replaces it).
  bool get isTopStep {
    final id = _stepId;
    return id != null && _topStepId() == id;
  }

  String? _topStepId() {
    final undo = editor.services.undo;
    final stack = undo.activeDocumentStack;
    if (stack == null) return null;
    final steps = undo.undoStepsOf(stack);
    return steps.isEmpty ? null : steps.last.id;
  }

  /// Shows the chip for a paste that is being recorded now.
  void show(PasteOptionsState state) {
    _state = state;
    _stepId = null;
    _awaitStep = true;
    _timer?.cancel();
    _timer = Timer(lifetime, hide);
    notifyListeners();
  }

  /// Hides the chip.
  void hide() {
    _timer?.cancel();
    _timer = null;
    if (_state == null) return;
    _state = null;
    _stepId = null;
    _awaitStep = false;
    notifyListeners();
  }

  /// Takes the state and hides the chip (before a re-run).
  PasteOptionsState? take() {
    final s = _state;
    hide();
    return s;
  }

  void _onUndo() {
    if (_state == null) return;
    final top = _topStepId();
    if (_awaitStep) {
      // The paste's own step was just committed.
      _awaitStep = false;
      _stepId = top;
      return;
    }
    if (top != _stepId) hide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    editor.services.undo.removeListener(_onUndo);
    if (_registry[editor] == this) _registry[editor] = null;
    super.dispose();
  }
}

/// The floating paste options chip (04 §13.12) at the bottom-right of the
/// pasted range (or of the canvas): the current mode with a check and the
/// other options; each runs `slides.edit.pasteSpecial {mode}`.
class PasteOptionsChip extends StatelessWidget {
  const PasteOptionsChip({super.key, required this.editor});

  final DeckEditorController editor;

  static const chipKey = ValueKey<String>('slides.pasteOptions');

  static String labelOf(SlidesLocalizations l, String mode) => switch (mode) {
    PasteModes.keepSource => l.pasteKeepSource,
    PasteModes.unlinked => l.pasteChartUnlinked,
    PasteModes.linked => l.pasteChartLinked,
    _ => l.pasteUseDestination,
  };

  @override
  Widget build(BuildContext context) {
    final chip = PasteOptions.of(editor);
    return ListenableBuilder(
      listenable: chip,
      builder: (context, _) {
        final s = chip.state;
        if (s == null) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, c) =>
              Stack(children: [_positioned(context, c.biggest, s)]),
        );
      },
    );
  }

  Widget _positioned(BuildContext context, Size size, PasteOptionsState s) {
    const w = 300.0, h = 40.0, pad = 12.0;
    var right = pad, bottom = pad;
    final b = s.bounds;
    final canvas = SlideCanvasController.of(editor);
    if (b != null && canvas != null) {
      final p = canvas.viewport.toViewport(Offset(b.right, b.bottom));
      right = (size.width - p.dx - w + 8).clamp(pad, math.max(pad, size.width));
      bottom = (size.height - p.dy - h - 8).clamp(
        pad,
        math.max(pad, size.height - h - pad),
      );
      if (size.width - right - w < pad) right = pad;
    }
    return Positioned(
      right: right,
      bottom: bottom,
      child: _Chip(editor: editor, state: s),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.editor, required this.state});

  final DeckEditorController editor;
  final PasteOptionsState state;

  void _run(String mode) => unawaited(
    editor.services.dispatcher.invoke(
      'slides.edit.pasteSpecial',
      args: {'mode': mode},
      source: InvocationSource.ui,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final options = [
      for (final m in state.modes)
        ShadOption<String>(
          value: m,
          child: Text(PasteOptionsChip.labelOf(l, m)),
        ),
    ];
    return Semantics(
      container: true,
      label: l.pasteOptionsLabel,
      child: Container(
        key: PasteOptionsChip.chipKey,
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        decoration: BoxDecoration(
          color: cs.popover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.clipboardPaste, size: 15, color: cs.foreground),
            const SizedBox(width: 6),
            Flexible(
              child: ShadSelect<String>(
                key: const ValueKey<String>('slides.pasteOptions.select'),
                initialValue: state.current,
                minWidth: 200,
                options: options,
                selectedOptionBuilder: (context, v) => Text(
                  PasteOptionsChip.labelOf(l, v),
                  overflow: TextOverflow.ellipsis,
                ),
                onChanged: (v) {
                  if (v != null && v != state.current) _run(v);
                },
              ),
            ),
            ShadIconButton.ghost(
              key: const ValueKey<String>('slides.pasteOptions.close'),
              width: 28,
              height: 28,
              icon: const Icon(LucideIcons.x, size: 14),
              onPressed: () => PasteOptions.of(editor).hide(),
            ),
          ],
        ),
      ),
    );
  }
}
