import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/charts.dart' show SlideChartMotion;
import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/snapping.dart' show FrameTransforms;
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;
import 'package:wonky_sync_models/ids.dart' show Base62Uuid;

import '../config/menus/context_menu_specs.dart';
import '../config/panels/slides_panels.dart';
import '../config/slides_features.dart';
import '../features/builds/animate_view.dart';
import '../features/canvas/slide_canvas_controller.dart';
import '../features/editor_screen/deck_document_controller.dart';
import '../features/editor_screen/deck_editor_controller.dart';
import '../features/motion/render/motion_scenes.dart';
import '../features/navigator/deck_renderer.dart';
import '../features/present/active_presentation.dart';
import '../features/stage/slide_stage.dart' show recordScene;
import '../features/text_editing/text_editing_host.dart' show textEditingOf;
import '../l10n/slides_l10n.dart';
import 'agent_flash.dart';

/// Wonky Slides' UI-bridge tools (`ui.slides.*`, Slides 11 §5; SL-42;
/// definitions in `wonky_core`'s `UiSlidesTools`), executed in the live
/// window on the open presentation.
///
/// Every state change goes through the `CommandDispatcher` (source `mcp`,
/// except [openDialog], which runs a command the way the user does so that
/// it shows its dialog), so permissions, feature switches
/// ([SlidesFeatures]) and the undo stack apply as for the user; reads and
/// navigation (current slide, navigator selection) use the editor state
/// directly. Slides and elements an agent targets flash with its name
/// ([SlidesAgentFlash]). Nothing opens a window (single window, 03).
abstract final class UiSlidesToolHandlers {
  static Map<String, UiToolHandler> all(ShellServices services) => {
    'ui.slides.get_selection': getSelection,
    'ui.slides.select': select,
    'ui.slides.go_to_slide': goToSlide,
    'ui.slides.get_view': getView,
    'ui.slides.set_view': setView,
    'ui.slides.screenshot_slide': screenshotSlide,
    'ui.slides.preview_animation': previewAnimation,
    'ui.slides.present': present,
    'ui.slides.present_control': presentControl,
    'ui.slides.highlight_element': highlightElement,
    'ui.slides.open_panel': openPanel,
    'ui.slides.close_panel': closePanel,
    'ui.slides.describe_panel': describePanel,
    'ui.slides.set_panel_field': setPanelField,
    'ui.slides.press_panel_button': pressPanelButton,
    'ui.slides.open_dialog': openDialog,
    'ui.slides.get_context_menu': getContextMenu,
  };

  /// The panel names of `ui.slides.open_panel` → (command, args, panel id,
  /// feature). Inspector tabs have no panel id.
  static final panels =
      <String, (String?, Map<String, Object?>, String?, SlidesFeature?)>{
        'inspector_format': (
          'slides.inspector.open',
          {'tab': 'format'},
          null,
          null,
        ),
        'inspector_animate': (
          'slides.panel.animate',
          const {},
          null,
          SlidesFeature.animations,
        ),
        'inspector_slide': (
          'slides.inspector.open',
          {'tab': 'slide'},
          null,
          null,
        ),
        'inspector_theme': (
          'slides.inspector.open',
          {'tab': 'theme'},
          null,
          SlidesFeature.masters,
        ),
        'layers': (
          'slides.panel.layers',
          const {},
          SlidesPanels.layers,
          SlidesFeature.layers,
        ),
        'themes': ('slides.panel.themes', const {}, SlidesPanels.themes, null),
        'accessibility': (
          'slides.panel.accessibility',
          const {},
          SlidesPanels.accessibility,
          SlidesFeature.accessibilityChecker,
        ),
        'linked_objects': (
          'slides.panel.linkedObjects',
          const {},
          SlidesPanels.linkedObjects,
          SlidesFeature.charts,
        ),
        'design_ideas': (
          'slides.ai.suggestLayouts',
          const {},
          'slides.panel.designIdeas',
          SlidesFeature.assistant,
        ),
        'comments': (
          null,
          const {},
          ShellPanels.comments,
          SlidesFeature.comments,
        ),
        'history': (
          null,
          const {},
          ShellPanels.history,
          SlidesFeature.versionHistory,
        ),
        'assistant': (
          null,
          const {},
          ShellPanels.assistant,
          SlidesFeature.assistant,
        ),
      };

  /// The key of the docked inspector (`DeckInspector`).
  static const inspectorKey = ValueKey<String>('slides.inspector');

  // --------------------------------------------------------------- helpers

  static DeckEditorController _editor(UiToolContext c) {
    final d = c.services.activeDocument.value;
    final ed = d is DeckDocumentController ? d.editor : null;
    if (ed == null) {
      throw const UiToolException(
        'no_document',
        'No Wonky Slides presentation is open (or it is still loading) in '
            'this window. Open one with ui.navigate {"open_item_uuid": …}.',
      );
    }
    return ed;
  }

  static String _agent(UiToolContext c) => c.agentName ?? 'MCP agent';

  /// The slide id of a `SlideRef` (id or 1-based position).
  static String slideIdOf(DeckEditorController ed, Object? ref) {
    final entries = ed.order.entries;
    if (ref is num) {
      final i = ref.toInt();
      if (i >= 1 && i <= entries.length) return entries[i - 1].id;
      throw UiToolException(
        'not_found',
        'There is no slide $i (the presentation has ${entries.length}).',
      );
    }
    if (ref is String) {
      final t = ref.trim();
      if (ed.order.entry(t) != null) return t;
      final id = _canonical(t);
      if (id != null && ed.order.entry(id) != null) return id;
      final n = int.tryParse(t);
      if (n != null) return slideIdOf(ed, n);
    }
    throw UiToolException(
      'not_found',
      'Slide "$ref" not found. Use a slide id from ui.slides.get_selection '
          'or slides.get_deck, or a 1-based position.',
    );
  }

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _b62 = RegExp(r'^[0-9A-Za-z]{22}$');

  static String? _canonical(String raw) {
    if (_b62.hasMatch(raw)) {
      try {
        return Base62Uuid.decode(raw);
      } on Object {
        return null;
      }
    }
    return _uuid.hasMatch(raw) ? raw.toLowerCase() : null;
  }

  /// The element id of an `ElementRef` (id, `{slide, placeholder, index}`
  /// or `{slide, name}`).
  static String elementIdOf(DeckEditorController ed, Object? ref) {
    final m = ed.model;
    if (ref is String) {
      final t = ref.trim();
      if (m.element(t) != null) return t;
      final id = _canonical(t);
      if (id != null && m.element(id) != null) return id;
    } else if (ref is Map) {
      final slide = slideIdOf(ed, ref['slide']);
      final type = ref['placeholder'];
      if (type is String) {
        final t = SlidePlaceholderType.fromName(type);
        if (t == null) {
          throw UiToolException(
            'invalid_args',
            'Unknown placeholder type "$type".',
          );
        }
        final list = [
          for (final e in m.elementsOf(slide))
            if (e.placeholderType == t) e,
        ]..sort((a, b) => a.zKey.compareTo(b.zKey));
        final index = (ref['index'] as num?)?.toInt() ?? 1;
        if (index >= 1 && index <= list.length) return list[index - 1].id;
        throw UiToolException(
          'not_found',
          'Slide ${ed.order.indexOf(slide) + 1} has '
              '${list.isEmpty ? 'no' : 'only ${list.length}'} $type '
              'placeholder${list.length == 1 ? '' : 's'}.',
        );
      }
      final name = ref['name'];
      if (name is String) {
        final wanted = name.trim().toLowerCase();
        for (final e in m.allElementsOf(slide)) {
          final layoutName = e.placeholderOf == null
              ? null
              : m.element(e.placeholderOf!)?.name;
          if ((e.name ?? layoutName)?.trim().toLowerCase() == wanted) {
            return e.id;
          }
        }
      }
    }
    throw UiToolException(
      'not_found',
      'Element ${ref is String ? '"$ref" ' : ''}not found (slides.get_slide '
          'lists the elements).',
    );
  }

  /// Runs command [id] through the dispatcher as the agent (source `mcp`)
  /// and maps its failures to tool errors.
  static Future<CommandResult> run(
    UiToolContext c,
    String id, [
    Map<String, Object?> args = const {},
    InvocationSource source = InvocationSource.mcp,
  ]) async {
    final s = c.services;
    if (!SlidesFeatures.offers(id, args)) {
      throw UiToolException(
        'unsupported',
        '$id is not available in this version of Wonky Slides.',
      );
    }
    try {
      final r = await s.dispatcher.invoke(
        id,
        args: args,
        source: source,
        context: c.context,
      );
      if (r.status == CommandStatus.failed) {
        throw UiToolException('failed', r.message ?? '$id failed.');
      }
      return r;
    } on UnknownCommand {
      throw UiToolException(
        'unsupported',
        '$id is not available in this window (ui.list_commands lists the '
            'commands).',
      );
    } on InvalidCommandArgs catch (e) {
      throw UiToolException(
        'invalid_args',
        e.message,
        details: [for (final v in e.violations) v.toString()],
      );
    } on CommandForbidden catch (e) {
      throw UiToolException('forbidden', e.reason);
    } on CommandDisabled catch (e) {
      throw UiToolException(
        'disabled',
        e.reason ?? '$id is disabled right now.',
      );
    } on CommandException catch (e) {
      throw UiToolException(e.code, e.message);
    }
  }

  /// Polls [done] every 20 ms until it holds or [timeout] passes (on the
  /// `clock`, so widget tests drive it with pumps).
  static Future<bool> _until(
    bool Function() done, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final sw = clock.stopwatch()..start();
    while (!done()) {
      if (sw.elapsed > timeout) return false;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return true;
  }

  static Map<String, Object?> _slideJson(DeckEditorController ed, String id) {
    final e = ed.order.entry(id);
    final s = ed.model.slide(id);
    return {
      'slide_id': id,
      'position': e == null ? null : e.index + 1,
      'number': ?e?.number,
      'skipped': s?.skipped ?? false,
      'group_id': ?s?.groupId,
    };
  }

  static Map<String, Object?> _elementJson(DeckModel m, String id) {
    final e = m.element(id);
    return {
      'element_id': id,
      'kind': e?.kind.name,
      'name': ?e?.name,
      'placeholder': ?e?.placeholderType?.name,
    };
  }

  // ----------------------------------------------------------------- state

  /// The selection JSON of [ed] (`ui.slides.get_selection`).
  static Map<String, Object?> selectionOfEditor(DeckEditorController ed) {
    final cur = ed.currentSlideId;
    final text = textEditingOf(ed).active;
    Map<String, Object?>? editing;
    if (text != null) {
      final range = text.selectionRange;
      String? selected;
      if (range != null) {
        final plain = text.mapper
            .bodyOf(text.document)
            .ops
            .map((op) => op['insert'] is String ? op['insert'] as String : '')
            .join();
        final (a, b) = range;
        selected = plain.substring(
          math.min(a, plain.length),
          math.min(b, plain.length),
        );
      }
      editing = {
        'element_id': text.elementId,
        if (text.isCell)
          'cell': {'row_id': text.cellRowId, 'column_id': text.cellColumnId},
        if (range != null)
          'text_selection': {
            'start': range.$1,
            'length': range.$2 - range.$1,
            'text': selected,
          },
      };
    }
    return {
      'deck_uuid': ed.session.itemUuid.uuid,
      'current_slide': cur == null ? null : _slideJson(ed, cur),
      'slide_count': ed.order.length,
      'selected_slides': [
        for (final id in ed.order.entries.map((e) => e.id))
          if (ed.selectedSlideIds.contains(id)) _slideJson(ed, id),
      ],
      'selected_groups': [...ed.selectedGroupIds],
      'selected_elements': [
        for (final id in ed.selectedElementIds) _elementJson(ed.model, id),
      ],
      'selection_kind': ed.selectionKind.name,
      'editing': ?editing,
      'view_mode': ed.mode.name,
      if (ed.editsMasters) 'master_target_id': ed.surfaceId,
      'inspector_tab': ed.inspectorVisible ? ed.inspectorTab.name : null,
      'can_edit': ed.canEdit,
      'role': ed.role.name,
    };
  }

  static Future<UiToolResult> getSelection(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final s = selectionOfEditor(ed);
    return UiToolResult(s, text: ed.describeSelection());
  }

  /// The running presentation (`get_view`, `present_control`), or null.
  static Map<String, Object?>? presentationJson() {
    final h = activePresentation.value;
    if (h == null) return null;
    final p = h.controller;
    final pos = p?.position;
    return {
      'view': h.view.name,
      'slide_id': pos?.slideId,
      'position': p == null || pos == null ? null : p.counter.$1,
      'slide_count': p?.counter.$2,
      'step': pos?.step,
      'step_count': pos == null ? null : p!.timelineOf(pos.slideId).stepCount,
      'blank': p?.blank.name,
      'end_screen': p?.endScreen ?? false,
      'ended': p?.ended ?? false,
      'shared': h.link != null,
    };
  }

  static Future<UiToolResult> getView(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final s = c.services;
    final dialog = s.openDialogs.isEmpty ? null : s.openDialogs.last;
    final presenting = presentationJson();
    final cur = ed.currentSlideId;
    return UiToolResult({
      'view_mode': ed.mode.name,
      'zoom': (ed.zoom * 100).round(),
      'zoom_fit': ed.zoomFit,
      'visible_slide': cur == null ? null : _slideJson(ed, cur),
      if (ed.editsMasters) 'master_target_id': ed.surfaceId,
      'inspector': {
        'open': ed.inspectorVisible,
        'tab': ed.inspectorTab.name,
        'section': ?ed.inspectorSection,
      },
      'panel': s.panels.activePanelId,
      'navigator': ed.navigatorVisible,
      'notes': ed.notesVisible,
      'mode': ed.viewMode ? 'viewing' : 'editing',
      'dialog': dialog?.describe(),
      'presenting': presenting,
      'previewing': AnimateView.maybeOf(ed)?.preview.active ?? false,
    }, text: '${ed.mode.name} · ${ed.describeSelection()}');
  }

  // ------------------------------------------------------------ navigation

  static Future<UiToolResult> goToSlide(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final id = slideIdOf(ed, a['slide']);
    await run(c, 'slides.nav.goToSlide', {'slideId': id});
    SlidesAgentFlash.of(ed).flash(
      label: _agent(c),
      slideId: id,
      duration: const Duration(seconds: 2),
    );
    await uiSettle();
    return UiToolResult({
      'current_slide': _slideJson(ed, id),
    }, text: 'Slide ${ed.order.indexOf(id) + 1}');
  }

  static Future<UiToolResult> select(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final slides = a['slides'];
    final elements = a['elements'];
    if ((slides is! List || slides.isEmpty) &&
        (elements is! List || elements.isEmpty)) {
      throw const UiToolException('invalid_args', 'Pass slides or elements.');
    }
    if (elements is List && elements.isNotEmpty) {
      final ids = {for (final r in elements) elementIdOf(ed, r)}.toList();
      final owners = {for (final id in ids) ed.model.element(id)!.ownerId};
      final owner = owners.single;
      if (owners.length > 1 || owner == null) {
        throw const UiToolException(
          'invalid_args',
          'Elements must be on one slide.',
        );
      }
      final slideArg = a['slide'];
      if (slideArg != null && slideIdOf(ed, slideArg) != owner) {
        throw const UiToolException(
          'invalid_args',
          'The elements are not on that slide.',
        );
      }
      if (ed.model.slide(owner) == null) {
        if (!ed.editsMasters || ed.surfaceId != owner) {
          throw const UiToolException(
            'invalid_args',
            'The elements are on a layout or master; open it in masters '
                'mode first (slides.view.setMode {"mode": "masters", '
                '"layoutId": …}).',
          );
        }
      } else {
        if (ed.mode != DeckViewMode.normal) {
          await run(c, 'slides.view.setMode', {'mode': 'normal'});
        }
        if (ed.currentSlideId != owner) {
          await run(c, 'slides.nav.goToSlide', {'slideId': owner});
        }
      }
      final parent = ed.model.element(ids.first)!.parentId;
      await run(c, 'slides.select.elements', {
        'ids': ids,
        'enteredGroupId': ?parent,
      });
      final canvas = SlideCanvasController.of(ed);
      if (canvas != null) {
        final box = FrameTransforms.boundsOf([
          for (final id in ids) ?canvas.frameOf(id),
        ]);
        if (box != null) canvas.viewport.reveal(box);
      }
      SlidesAgentFlash.of(
        ed,
      ).flash(label: _agent(c), slideId: owner, elementIds: ids);
    } else {
      final ids = {for (final r in slides! as List) slideIdOf(ed, r)}.toList();
      if (!ids.contains(ed.currentSlideId)) {
        await run(c, 'slides.nav.goToSlide', {'slideId': ids.last});
      }
      ed.selectSlides(ids);
      for (final id in ids.take(10)) {
        SlidesAgentFlash.of(ed).flash(
          label: _agent(c),
          slideId: id,
          duration: const Duration(seconds: 2),
        );
      }
    }
    await uiSettle();
    final s = selectionOfEditor(ed);
    return UiToolResult(s, text: ed.describeSelection());
  }

  static Future<UiToolResult> setView(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final mode = a['view_mode'] as String?;
    final zoom = a['zoom'];
    if (mode == null && zoom == null) {
      throw const UiToolException(
        'invalid_args',
        'Pass view_mode and/or zoom.',
      );
    }
    if (mode != null && mode != ed.mode.name) {
      await run(c, 'slides.view.setMode', {'mode': mode});
    }
    if (zoom == 'fit') {
      await run(c, 'slides.view.zoomFit');
    } else if (zoom is num) {
      await run(c, 'slides.view.zoom', {'percent': zoom.toInt()});
    }
    await uiSettle();
    return UiToolResult({
      'view_mode': ed.mode.name,
      'zoom': (ed.zoom * 100).round(),
      'zoom_fit': ed.zoomFit,
    }, text: '${ed.mode.name} ${(ed.zoom * 100).round()} %');
  }

  // ------------------------------------------------------------ screenshot

  static Future<UiToolResult> screenshotSlide(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final id = a['slide'] == null
        ? (ed.currentSlideId ??
              (throw const UiToolException(
                'not_found',
                'The presentation has no slides.',
              )))
        : slideIdOf(ed, a['slide']);
    final step = a['step'] ?? 'edit';
    final scale = ((a['scale'] as num?) ?? 1).toDouble().clamp(0.5, 2.0);
    final renderer = DeckThumbnails.acquire(ed);
    try {
      final size = renderer.slideSize;
      final w = math.max(1, (size.width * scale).round());
      final h = math.max(1, (size.height * scale).round());
      SlideScene? shown;
      var frame = SlideFrame.edit;
      int? stepIndex;
      if (step == 'edit') {
        // The thumbnail's scene (11 AC 12: the in-app thumbnail).
        shown = renderer.scene(id, purpose: ScenePurpose.thumbnail);
      } else {
        final base = renderer.scene(id, purpose: ScenePurpose.present);
        if (base != null) {
          final tl = SlideTimelineCompiler.compile(
            SlideMotionInput.fromDeck(
              ed.model,
              id,
              scene: base,
              chartShapeOf: SlideChartMotion.shapes(ed.model),
            ),
          );
          if (step is num) {
            stepIndex = step.toInt().clamp(0, tl.stepCount);
            frame = tl.endOfStep(stepIndex);
          } else {
            frame = tl.finalFrame;
          }
          shown = MotionScenes(renderer).apply(base, frame);
        }
      }
      if (shown == null) {
        throw UiToolException('not_found', 'Slide $id cannot be drawn.');
      }
      await renderer.images.preload(shown);
      final picture = recordScene(
        shown,
        scale: w / size.width,
        images: renderer.images,
        frame: frame,
      );
      final image = await picture.toImage(w, h);
      picture.dispose();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) {
        throw const UiToolException('failed', 'Could not encode the image.');
      }
      SlidesAgentFlash.of(ed).flash(
        label: _agent(c),
        slideId: id,
        duration: const Duration(seconds: 2),
      );
      final pos = ed.order.indexOf(id) + 1;
      return UiToolResult(
        {
          'slide_id': id,
          'position': pos,
          'step': stepIndex ?? step,
          'width': w,
          'height': h,
        },
        text: 'Slide $pos ($w×$h)',
        imageBase64: base64Encode(bytes.buffer.asUint8List()),
      );
    } finally {
      DeckThumbnails.release(ed, renderer);
    }
  }

  // ------------------------------------------------------------- animation

  static Future<UiToolResult> previewAnimation(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final slide = a['slide'] == null ? null : slideIdOf(ed, a['slide']);
    final from = a['from_build'] as String?;
    if (from != null && ed.model.build(from) == null) {
      throw UiToolException('not_found', 'Build "$from" not found.');
    }
    final r = await run(c, 'slides.animate.preview', {
      'slideId': ?slide,
      'fromBuildId': ?from,
      'includeTransition': ?(a['include_transition'] as bool?),
    });
    final preview = AnimateView.of(ed).preview;
    final sw = clock.stopwatch()..start();
    final done = await _until(
      () => !preview.active,
      timeout: const Duration(seconds: 60),
    );
    if (!done) preview.stop();
    final data = (r.data as Map?)?.cast<String, Object?>() ?? const {};
    return UiToolResult({
      'slide_id': data['slideId'],
      'steps': data['steps'],
      'played_ms': sw.elapsedMilliseconds,
      'completed': done,
    }, text: done ? 'Preview played' : 'Preview stopped after 60 s');
  }

  // ------------------------------------------------------------ presenting

  static Future<UiToolResult> present(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    if (activePresentation.value != null) {
      throw const UiToolException(
        'disabled',
        'A presentation is already running; use '
            'ui.slides.present_control.',
      );
    }
    final from = a['from'] ?? 'current';
    final presenter = a['presenter_view'] == true;
    if (presenter) {
      if (from != 'current' && from != 'start') {
        await run(c, 'slides.nav.goToSlide', {'slideId': slideIdOf(ed, from)});
      }
      await run(c, 'slides.present.presenterView', {
        'from': from == 'start' ? 'start' : 'current',
      });
    } else if (from == 'start') {
      await run(c, 'slides.present.fromStart');
    } else if (from == 'current') {
      await run(c, 'slides.present.fromCurrent');
    } else {
      await run(c, 'slides.present.fromSlide', {
        'slideId': slideIdOf(ed, from),
      });
    }
    await _until(() => activePresentation.value?.controller != null);
    await uiSettle();
    final p = presentationJson();
    return UiToolResult({
      'presenting': p != null,
      ...?p,
    }, text: p == null ? 'Opening the presentation' : 'Presenting');
  }

  static Future<UiToolResult> presentControl(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final h = activePresentation.value;
    final pc = h?.controller;
    if (h == null || pc == null) {
      throw const UiToolException(
        'disabled',
        'Not presenting. Start with ui.slides.present.',
      );
    }
    final action = a['action']! as String;
    switch (action) {
      case 'next':
        await run(c, 'slides.present.next');
      case 'previous':
        await run(c, 'slides.present.previous');
      case 'next_slide':
        await run(c, 'slides.present.nextSlide');
      case 'previous_slide':
        await run(c, 'slides.present.previousSlide');
      case 'go_to':
        final ref = a['slide'];
        if (ref == null) {
          throw const UiToolException('invalid_args', 'go_to needs slide.');
        }
        await run(c, 'slides.present.goTo', {
          'slideId': slideIdOf(ed, ref),
          'step': ?(a['step'] as num?)?.toInt(),
        });
      case 'black' || 'white' || 'unblank':
        final color = action == 'unblank' ? 'none' : action;
        // The command toggles: only run it when the screen changes.
        if (pc.blank.name != color) {
          await run(c, 'slides.present.blank', {'color': color});
        }
      case 'end':
        await run(c, 'slides.present.end');
      default:
        throw UiToolException('invalid_args', 'Unknown action "$action".');
    }
    await uiSettle();
    final p = presentationJson() ?? {'ended': true};
    return UiToolResult(
      p,
      text: p['slide_id'] == null
          ? action
          : 'Slide ${p['position']}, step ${p['step']}',
    );
  }

  // ------------------------------------------------------------- highlight

  static Future<UiToolResult> highlightElement(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final raw = a['element_ids'];
    final ids = raw is List
        ? [for (final r in raw) elementIdOf(ed, r)]
        : const <String>[];
    final ms = (a['duration_ms'] as num?)?.toInt() ?? 3000;
    String? slide = a['slide'] == null ? null : slideIdOf(ed, a['slide']);
    if (ids.isNotEmpty) {
      final owners = {for (final id in ids) ed.model.element(id)!.ownerId};
      if (owners.length > 1) {
        throw const UiToolException(
          'invalid_args',
          'Highlight elements of one slide at a time.',
        );
      }
      slide = owners.single;
    }
    slide ??= ed.currentSlideId;
    if (slide == null) {
      throw const UiToolException('not_found', 'Nothing to highlight.');
    }
    if (ed.model.slide(slide) != null && ed.currentSlideId != slide) {
      if (ed.mode != DeckViewMode.normal && ed.mode != DeckViewMode.grid) {
        await run(c, 'slides.view.setMode', {'mode': 'normal'});
      }
      await run(c, 'slides.nav.goToSlide', {'slideId': slide});
    }
    final e = SlidesAgentFlash.of(ed).flash(
      label: _agent(c),
      slideId: slide,
      elementIds: ids,
      duration: Duration(milliseconds: ms),
    );
    await uiSettle();
    return UiToolResult(
      {
        'slide_id': slide,
        'element_ids': e?.elementIds ?? const <String>[],
        'duration_ms': ms,
      },
      text:
          'Highlighted ${ids.isEmpty ? 'the slide' : '${ids.length} element(s)'}',
    );
  }

  // ---------------------------------------------------------------- panels

  static Future<UiToolResult> openPanel(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final name = a['panel']! as String;
    final entry = panels[name];
    if (entry == null) {
      throw UiToolException('invalid_args', 'Unknown panel "$name".');
    }
    final (command, args, panelId, feature) = entry;
    if (feature != null && !SlidesFeatures.isOn(feature)) {
      throw UiToolException(
        'unsupported',
        'The $name panel is not available in this version of Wonky Slides.',
      );
    }
    if (name == 'inspector_theme' && !ed.editsMasters) {
      throw const UiToolException(
        'disabled',
        'The Theme tab exists in masters mode (ui.slides.set_view '
            '{"view_mode": "masters"}).',
      );
    }
    final s = c.services;
    if (command != null && s.registry.byId(command) != null) {
      final section = a['section'] as String?;
      await run(c, command, {
        ...args,
        if (section != null && command == 'slides.inspector.open')
          'section': section,
      });
    } else if (panelId != null) {
      s.panels.open(panelId);
    }
    await uiSettle();
    final open = panelId == null
        ? ed.inspectorVisible
        : s.panels.isOpen(panelId);
    if (!open) {
      throw UiToolException(
        'unsupported',
        'The $name panel could not be opened here.',
      );
    }
    return UiToolResult({
      'panel': name,
      'panel_id': panelId,
      'inspector': {'open': ed.inspectorVisible, 'tab': ed.inspectorTab.name},
    }, text: 'Opened $name');
  }

  static Future<UiToolResult> closePanel(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final s = c.services;
    final name = a['panel'] as String?;
    String? closed;
    if (name != null && name.startsWith('inspector_')) {
      if (ed.inspectorVisible) {
        await run(c, 'slides.view.toggleInspector');
      }
      closed = 'inspector';
    } else {
      final id = name == null ? s.panels.activePanelId : panels[name]?.$3;
      if (id != null && s.panels.isOpen(id)) {
        s.panels.close(id);
        closed = id;
      }
    }
    await uiSettle();
    return UiToolResult({'closed': closed}, text: 'Closed ${closed ?? '—'}');
  }

  /// The panel the describe/set/press tools act on: `panel` (an
  /// `inspector_*` name = the inspector, a panel name or id), else the open
  /// side panel, else the inspector.
  static PanelDescriber _panel(UiToolContext c, Map<String, Object?> a) {
    final ed = _editor(c);
    final s = c.services;
    final name = a['panel'] as String?;
    PanelDescriber? inspector() => ed.inspectorVisible
        ? PanelDescriber.under(
            'inspector_${ed.inspectorTab.name}',
            inspectorKey,
          )
        : null;
    PanelDescriber? p;
    if (name != null && name.startsWith('inspector')) {
      p = inspector();
    } else if (name != null) {
      p = PanelDescriber.of(s, panelId: panels[name]?.$3 ?? name);
    } else {
      p = PanelDescriber.of(s) ?? inspector();
    }
    if (p == null) {
      throw UiToolException(
        'not_found',
        name == null
            ? 'No panel is open. Open one with ui.slides.open_panel.'
            : 'The panel "$name" is not open. Open it with '
                  'ui.slides.open_panel.',
      );
    }
    return p;
  }

  static Future<UiToolResult> describePanel(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    await uiSettle();
    final p = _panel(c, a);
    final d = p.describe();
    final fields = (d['fields']! as List).length;
    final buttons = (d['buttons']! as List).length;
    return UiToolResult(
      d,
      text: 'Panel ${p.panelId}: $fields fields, $buttons buttons',
    );
  }

  static Future<UiToolResult> setPanelField(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final p = _panel(c, a);
    final id = a['field_id']! as String;
    final error = p.setField(id, a['value']);
    if (error != null) {
      throw UiToolException(
        'invalid_args',
        error,
        details: {'panel': p.describe()},
      );
    }
    await uiSettle();
    return UiToolResult({
      'set': id,
      'panel': _describeAgain(c, a),
    }, text: 'Set $id');
  }

  static Future<UiToolResult> pressPanelButton(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final p = _panel(c, a);
    final id = a['button_id']! as String;
    final error = p.press(id);
    if (error != null) {
      throw UiToolException(
        'invalid_args',
        error,
        details: {'panel': p.describe()},
      );
    }
    await uiSettle();
    c.events.add('panel', {'pressed': id, 'panel': p.panelId});
    return UiToolResult({
      'pressed': id,
      'panel': _describeAgain(c, a),
    }, text: 'Pressed $id');
  }

  static Map<String, Object?>? _describeAgain(
    UiToolContext c,
    Map<String, Object?> a,
  ) {
    try {
      return _panel(c, a).describe();
    } on UiToolException {
      return null;
    }
  }

  // --------------------------------------------------------------- dialogs

  static Future<UiToolResult> openDialog(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    _editor(c);
    final s = c.services;
    final id = a['command_id']! as String;
    final raw = a['args'];
    final args = raw is Map ? raw.cast<String, Object?>() : <String, Object?>{};
    final before = s.openDialogs.toSet();
    // As the user (source ui): Slides commands skip their dialogs for
    // agents. The result arrives after the dialog closes.
    final pending = run(c, id, args, InvocationSource.ui);
    CommandResult? result;
    Object? error;
    var finished = false;
    unawaited(
      pending.then(
        (r) {
          result = r;
          finished = true;
        },
        onError: (Object e) {
          error = e;
          finished = true;
        },
      ),
    );
    await _until(
      () => finished || s.openDialogs.any((d) => !before.contains(d)),
      timeout: const Duration(seconds: 5),
    );
    await uiSettle();
    final err = error;
    if (err != null) throw err;
    final opened = [
      for (final d in s.openDialogs)
        if (!before.contains(d)) d,
    ];
    if (opened.isNotEmpty) {
      c.events.add('dialog', {'opened': id});
      final d = opened.last.describe();
      return UiToolResult({
        'command_id': id,
        'dialog': d,
      }, text: 'Dialog: ${d['title']}');
    }
    final r = result;
    return UiToolResult({
      'command_id': id,
      'dialog': null,
      'status': r?.status.name ?? 'running',
      'message': ?r?.message,
    }, text: '$id: ${r?.status.name ?? 'running'} (no dialog)');
  }

  // ---------------------------------------------------------- context menu

  static Future<UiToolResult> getContextMenu(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final s = c.services;
    final l = slidesL10nOf(s);
    final menu = (a['menu'] as String?) ?? _defaultMenu(ed);
    if (!SlidesContextMenuIds.all.contains(menu)) {
      throw UiToolException('invalid_args', 'Unknown context menu "$menu".');
    }
    final context = c.context;
    final items = contextMenuFor(l, menu, ed.selectionKind);
    final tree = MenuRoot(items).toJson(
      resolve: (item) {
        final command = s.registry.byId(item.commandId);
        final state = s.dispatcher.stateOf(item.commandId, item.args);
        return {
          'title':
              item.label ??
              (context != null && context.mounted
                  ? command?.title(context)
                  : null) ??
              item.commandId,
          'enabled': state.enabled,
          'checked': ?state.checked,
          'disabled_reason': ?state.disabledReason,
          'shortcut': ?s.keymap.shortcutTextOf(item.commandId),
        };
      },
    );
    return UiToolResult({
      'menu': menu,
      'items': tree,
    }, text: '$menu: ${items.length} items');
  }

  static String _defaultMenu(DeckEditorController ed) {
    if (textEditingOf(ed).active != null) return SlidesContextMenuIds.text;
    if (ed.mode == DeckViewMode.grid || ed.navigatorFocus.hasFocus) {
      return ed.selectedGroupIds.isNotEmpty
          ? SlidesContextMenuIds.navigatorGroup
          : SlidesContextMenuIds.navigatorSlide;
    }
    if (ed.editsMasters) {
      return ed.surfaceKind == ElementOwnerKind.layout
          ? SlidesContextMenuIds.mastersLayout
          : SlidesContextMenuIds.mastersMaster;
    }
    if (ed.selectionKind == DeckSelectionKind.table) {
      return SlidesContextMenuIds.table;
    }
    return ed.selectedElementIds.isEmpty
        ? SlidesContextMenuIds.slide
        : SlidesContextMenuIds.element;
  }
}
