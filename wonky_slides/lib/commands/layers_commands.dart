import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_slides_core/ops.dart';

import '../config/panels/slides_panels.dart';
import '../features/canvas/slide_canvas_controller.dart' show selectionOf;
import '../features/editor_screen/deck_editor_controller.dart';
import '../features/layers/layers_controller.dart';
import 'slides_command.dart';

/// The Layers panel's commands (Slides 03 §8.1, §17.2; SL-34):
///
/// - `slides.panel.layers {tab?}` opens the Layers panel (`layers` or
///   `readingOrder`).
/// - `slides.arrange.setZ {ids?, aboveId? | belowId? | groupId?}` moves
///   elements (default: the selection) in front of / behind a sibling, or
///   on top of an element group's children (into and out of groups,
///   `MoveElementsZ`); one undo step.
/// - `slides.a11y.setReadingOrder {ids, slideId?}` sets the custom reading
///   order of the current slide (or [slideId]); `slides.a11y.
///   resetReadingOrder {slideId?}` returns to the automatic order.
List<Command<CommandArgs>> layersCommands(ShellServices s) => [
  SlidesCommand(
    'slides.panel.layers',
    label: (l) => l.cmdPanelLayers,
    icon: LucideIcons.layers,
    categoryOf: SlidesCategory.view,
    argsSchema: JsonSchema.object(
      properties: {
        'tab': JsonSchema.string(
          enumValues: [for (final t in LayersTab.values) t.name],
        ),
      },
    ),
    checked: (ed, a) => s.panels.isOpen(SlidesPanels.layers),
    run: (ctx, ed, a) {
      final tab = LayersTab.fromName(a.string('tab'));
      if (tab != null) layersOf(ed).tab = tab;
      s.panels.open(SlidesPanels.layers);
      return ok({'tab': layersOf(ed).tab.name});
    },
  ),
  SlidesCommand(
    'slides.arrange.setZ',
    label: (l) => l.cmdArrangeSetZ,
    icon: LucideIcons.layers,
    categoryOf: SlidesCategory.arrange,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'ids': JsonSchema.array(
          JsonSchema.string(),
          description: 'The elements (default: the selection).',
        ),
        'aboveId': JsonSchema.string(description: 'In front of this one.'),
        'belowId': JsonSchema.string(description: 'Behind this one.'),
        'groupId': JsonSchema.string(
          description: 'On top of this element group’s children.',
        ),
      },
    ),
    enabled: (ed, a) => _zTarget(ed, a) != null,
    reason: (l, ed) => l.reasonSelectObject,
    run: (ctx, ed, a) {
      final op = _zTarget(ed, a)!;
      final wasSelected = op.elementIds.every(ed.selectedElementIds.contains);
      final plan = ed.apply(ctx, op);
      final ids = (plan.result['elementIds'] as List?)?.cast<String>();
      // Keep the moved elements selected (their parent may have changed).
      if (wasSelected && ids != null) selectionOf(ed).select(ids);
      return ok({'elementIds': ids});
    },
  ),
  SlidesCommand(
    'slides.a11y.setReadingOrder',
    label: (l) => l.cmdA11ySetReadingOrder,
    icon: LucideIcons.listOrdered,
    categoryOf: SlidesCategory.arrange,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'ids': JsonSchema.array(
          JsonSchema.string(),
          description: 'The elements in reading order.',
        ),
        'slideId': JsonSchema.string(
          description: 'Default: the current slide.',
        ),
      },
      required: ['ids'],
    ),
    enabled: (ed, a) => _owner(ed, a) != null,
    reason: (l, ed) => l.reasonNoSlides,
    run: (ctx, ed, a) {
      final ids = (a.values['ids'] as List).whereType<String>().toList();
      ed.apply(ctx, SetReadingOrder(_owner(ed, a)!, ids));
      return ok();
    },
  ),
  SlidesCommand(
    'slides.a11y.resetReadingOrder',
    label: (l) => l.cmdA11yResetReadingOrder,
    icon: LucideIcons.listRestart,
    categoryOf: SlidesCategory.arrange,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'slideId': JsonSchema.string(
          description: 'Default: the current slide.',
        ),
      },
    ),
    enabled: (ed, a) {
      final owner = _owner(ed, a);
      return owner != null &&
          ed.model.allElementsOf(owner).any((e) => e.readingKey != null);
    },
    reason: (l, ed) => l.reasonReadingOrderAutomatic,
    run: (ctx, ed, a) {
      ed.apply(ctx, SetReadingOrder(_owner(ed, a)!, const []));
      return ok();
    },
  ),
];

/// The owner a reading-order command acts on.
String? _owner(DeckEditorController ed, JsonArgs a) {
  final id = a.string('slideId') ?? ed.surfaceId;
  if (id == null) return null;
  final m = ed.model;
  return m.slide(id) != null || m.layout(id) != null || m.master(id) != null
      ? id
      : null;
}

/// The `MoveElementsZ` of `slides.arrange.setZ`, or null when it can't
/// run (nothing to move, unknown anchor, or a move into itself).
MoveElementsZ? _zTarget(DeckEditorController ed, JsonArgs a) {
  final raw = a.values['ids'];
  final ids = raw is List
      ? raw.whereType<String>().toList()
      : ed.selectedElementIds;
  if (ids.isEmpty) return null;
  final m = ed.model;
  final owner = m.element(ids.first)?.ownerId;
  if (owner == null) return null;
  if (ids.any((id) => m.element(id)?.ownerId != owner)) return null;
  final above = a.string('aboveId');
  final below = a.string('belowId');
  final group = a.string('groupId');
  final anchor = above ?? below ?? group;
  if (anchor != null) {
    final x = m.element(anchor);
    if (x == null || x.ownerId != owner || ids.contains(anchor)) return null;
    if (group != null && above == null && below == null) {
      if (x.kind != ElementKind.group) return null;
      final tree = m.indexes.tree(owner);
      for (String? p = group; p != null; p = tree.parentOf(p)) {
        if (ids.contains(p)) return null;
      }
    }
  }
  return MoveElementsZ(
    ids,
    aboveId: above,
    belowId: above == null ? below : null,
    intoGroupId: above == null && below == null ? group : null,
  );
}
