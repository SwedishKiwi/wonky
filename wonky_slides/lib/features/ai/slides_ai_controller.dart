import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_slides_core/markdown.dart' show SlidesMarkdownCodec;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_sync_models/ids.dart' show Base62Uuid;

import '../../l10n/slides_l10n.dart';
import '../canvas/slide_canvas_controller.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../text_editing/text_editing_host.dart' show textEditingOf;
import '../undo/server_change_undo.dart';
import 'ai_preview_dialog.dart';
import 'slides_ai_api.dart';
import 'slides_assistant_adapter.dart';

/// The AI features of one open presentation (Slides 11 §6, suite 10): the
/// assistant adapter, one undo step per assistant run, the Suggest-mode
/// preview, Show, and the helpers of the `slides.ai.*` commands (text as
/// Markdown, box capacity). One per editor ([of]); disposed with the
/// editor screen.
class SlidesAiController extends ChangeNotifier {
  SlidesAiController._(this.editor) {
    adapter = SlidesAssistantAdapter(this);
  }

  static final Expando<SlidesAiController> _of = Expando('slidesAi');

  /// The controller of [editor] (created on first use).
  static SlidesAiController of(DeckEditorController editor) =>
      _of[editor] ??= SlidesAiController._(editor);

  /// The controller of [editor] when it exists.
  static SlidesAiController? maybeOf(DeckEditorController editor) =>
      _of[editor];

  final DeckEditorController editor;
  late final SlidesAssistantAdapter adapter;

  bool _disposed = false;

  ShellServices get services => editor.services;
  SlidesLocalizations get l10n => slidesL10nOf(services);
  UuidValue get itemUuid => editor.session.itemUuid;
  DeckModel get model => editor.model;

  /// The Slides AI endpoints.
  SlidesAiApi get api => SlidesAiApis.of(services);

  ShellAssistant? get assistant => ShellAssistant.of(services);

  /// Whether AI UI is shown at all (installed, not switched off on the
  /// server or by the user).
  bool get shown => services.prefs.aiEnabled && (assistant?.available ?? false);

  /// Whether AI requests can be sent now.
  bool get available =>
      services.prefs.aiEnabled && (assistant?.usable ?? false);

  /// Why AI can't be used now (null when [available]).
  String? get unavailableReason {
    if (available) return null;
    if (!services.prefs.aiEnabled) return l10n.aiTurnedOff;
    final s = assistant?.status.value;
    final la = services.l10n;
    if (s != null && la != null) return assistantStatusMessage(la, s);
    return s?.message ?? l10n.aiUnavailable;
  }

  /// The panel controller of this presentation.
  AssistantController? get chat => assistant?.controllerFor(adapter);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---------------------------------------------------------------- show

  /// Shows [slideId] (Normal view) and selects [elementId] on it.
  void show({String? slideId, String? elementId}) {
    final m = model;
    final el = elementId == null ? null : m.element(elementId);
    final slide = slideId ?? el?.slideId;
    if (slide == null || m.slide(slide) == null) return;
    if (editor.mode != DeckViewMode.normal) editor.setMode(DeckViewMode.normal);
    textEditingOf(editor).commit();
    editor.setCurrentSlide(slide);
    if (el != null && el.slideId == slide) {
      editor.selectElements([el.id]);
    } else {
      editor.clearElementSelection();
    }
    editor.canvasFocus.requestFocus();
  }

  // ------------------------------------------------------------- text

  /// The text of element [id] as Markdown (slide links as base-62 ids).
  String? markdownOf(String id) {
    final e = model.element(id);
    if (e == null || e.text == null) return null;
    return SlidesMarkdownCodec.toMarkdown(e.text);
  }

  /// [markdown] as a body Delta (JSON); [notes] uses the notes schema.
  static String deltaOf(String markdown, {bool notes = false}) =>
      SlidesMarkdownCodec.toDelta(
        markdown,
        notes: notes,
        slideLink: (t) =>
            RegExp(r'^[0-9A-Za-z]{22}$').hasMatch(t) ? 'slide:$t' : null,
      ).deltaJson;

  /// The element a text command targets: [id], else the body being
  /// edited, else the single selected element with text.
  String? textTarget([String? id]) {
    final m = model;
    bool hasText(String x) =>
        !SlidesText.isBlank(m.element(x)?.text) &&
        m.element(x)?.slideId == editor.currentSlideId;
    if (id != null) return m.element(id)?.text == null ? null : id;
    final editing = textEditingOf(editor).active?.elementId;
    if (editing != null && hasText(editing)) return editing;
    final sel = editor.selectedElementIds;
    if (sel.length == 1 && hasText(sel.single)) return sel.single;
    return null;
  }

  /// Characters that fit element [id] before auto-fit shrinks its text
  /// below 80 % (11 §6.5), from the scene's text fit; null when the text
  /// isn't shrunk (no known limit).
  int? capacityOf(String id) {
    final e = model.element(id);
    final slide = e?.slideId;
    if (e == null || slide == null) return null;
    final canvas = SlideCanvasController.of(editor);
    final scene = canvas?.renderer.scene(slide);
    if (scene == null) return null;
    double? fit;
    void walk(List<SceneNode> nodes) {
      for (final n in nodes) {
        switch (n) {
          case TextNode(:final layout, :final elementId) when elementId == id:
            fit = layout.fitScale;
          case GroupNode(:final children):
            walk(children);
          default:
        }
      }
    }

    walk(scene.nodes);
    final s = fit;
    if (s == null || s >= 1) return null;
    final length = SlidesText.plainText(e.text).length;
    // Characters scale with the area of the glyphs: at 80 % the box holds
    // (s / 0.8)² of the text that fits at s.
    return (length * (s / 0.8) * (s / 0.8)).floor().clamp(1, length);
  }

  // ------------------------------------------------------------ runs

  final Map<String, String> _runSteps = {};

  /// An Edit-mode assistant run committed [changeId]: one undo step
  /// "AI: …" on the deck's stack (`slides.serverChange`).
  void runCommitted(String runId, String changeId, String summary) {
    if (_runSteps.containsKey(runId)) return;
    final label = l10n.aiUndoLabel(
      summary.trim().isEmpty ? l10n.aiUndoDefault : summary.trim(),
    );
    _runSteps[runId] = pushSlidesServerChangeStep(
      services,
      changeId: changeId,
      label: label,
    );
  }

  /// Undoes the run's step when it is the latest one; otherwise reverts
  /// [changeId] on the server directly. False when neither is possible.
  Future<bool> undoRun(String runId, {String? changeId}) async {
    final step = _runSteps[runId];
    final key = services.undo.activeDocumentStack;
    if (step != null && key != null) {
      final steps = services.undo.undoStepsOf(key);
      if (steps.isNotEmpty && steps.last.id == step) {
        await services.undo.undo();
        return true;
      }
    }
    if (changeId == null) return false;
    try {
      await api.revertChange(UuidValue.fromString(changeId));
      return true;
    } on Object catch (e) {
      services.toasts.error(l10n.aiFailed, description: errorMessage(e));
      return false;
    }
  }

  // ---------------------------------------------------------- previews

  final Map<String, String> _outcomes = {};

  /// `applied` / `discarded` once the user decided on [previewId].
  String? previewOutcome(String previewId) => _outcomes[previewId];

  /// The latest preview of this deck that is still open (commands).
  String? pendingPreview;

  /// A Suggest-mode run recorded [previewId].
  void previewReady(String previewId) {
    pendingPreview = previewId;
    _notify();
  }

  /// Opens the AI changes preview [previewId]; applying pushes one undo
  /// step. Returns the outcome (null when closed without a choice).
  Future<AiPreviewOutcome?> openPreview(
    String previewId, {
    BuildContext? context,
  }) async {
    final c = context ?? services.navigatorContext;
    if (c == null || !c.mounted) return null;
    final outcome = await showAiPreviewDialog(
      c,
      ai: this,
      previewId: previewId,
    );
    if (outcome != null) recordOutcome(previewId, outcome);
    return outcome;
  }

  /// Records the user's choice on [previewId] (and the undo step of an
  /// apply).
  void recordOutcome(String previewId, AiPreviewOutcome outcome) {
    switch (outcome) {
      case AiPreviewApplied(:final result):
        _outcomes[previewId] = 'applied';
        final id = result.changeId;
        if (id != null) {
          pushSlidesServerChangeStep(
            services,
            changeId: id,
            label: result.label,
          );
        }
        if (result.skipped > 0) {
          services.toasts.show(l10n.aiPreviewSkipped(result.skipped));
        }
      case AiPreviewDiscarded():
        _outcomes[previewId] = 'discarded';
    }
    if (pendingPreview == previewId) pendingPreview = null;
    _notify();
  }

  /// The base-62 id of [slideId] (slide links).
  static String b62(String slideId) => Base62Uuid.encode(slideId);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _of[editor] = null;
    assistant?.release(adapter);
    adapter.dispose();
    super.dispose();
  }
}
