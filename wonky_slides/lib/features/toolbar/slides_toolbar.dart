import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../config/menus/slides_menu_spec.dart';
import '../../config/toolbar/slides_toolbar_spec.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../editor_screen/slide_labels.dart';
import '../text_editing/text_editing_host.dart' show textEditingOf;
import '../elements/shape/shape_gallery.dart';
import '../elements/shape/shape_tool.dart';
import 'command_ui.dart';

/// The Slides toolbar (Slides 04 §6): fixed items (history, paint format,
/// zoom, *New slide*, the insert tools), the contextual section that
/// follows the selection ([contextualToolbarGroups]) and, right-aligned,
/// *Comment* and *Animate*. Viewers and commenters get Zoom, Comment
/// (commenters) and the *View only* badge (04 §2).
class SlidesToolbar extends StatelessWidget {
  const SlidesToolbar({
    super.key,
    required this.services,
    required this.editor,
    this.controller,
  });

  final ShellServices services;
  final DeckEditorController editor;
  final WonkyToolbarController? controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      editor,
      services.registry,
      services.undo,
      textEditingOf(editor),
    ]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final ui = SlidesCommandUi(context, services);
    final l = ui.l;
    final ed = editor;
    final undoLabel = services.undo.undoLabel.value;
    final redoLabel = services.undo.redoLabel.value;

    final zoom = ToolbarGroup([
      ui.dropdown(
        'zoom',
        label: ed.zoomFit ? l.zoomFit : l.zoomPercent((ed.zoom * 100).round()),
        tooltip: l.toolbarZoom,
        priority: 5,
        minWidth: 34,
        items: () => [
          MenuSpec.command(
            'slides.view.zoomFit',
            label: l.zoomFit,
            id: 'toolbar.zoom.fit',
          ),
          for (final p in const [50, 75, 100, 150, 200])
            MenuSpec.command(
              'slides.view.zoom',
              label: l.zoomPercent(p),
              args: {'percent': p},
              id: 'toolbar.zoom.$p',
              radio: true,
            ),
        ],
      ),
    ], id: 'zoom');

    final comment = ui.button(
      'shell.comments.create',
      icon: LucideIcons.messageSquarePlus,
      label: l.toolbarAddComment,
      keyName: 'comment',
      priority: 4,
    );

    if (ed.viewMode) {
      return WonkyToolbar(
        controller: controller,
        semanticLabel: l.toolbarLabel,
        onEscape: ed.canvasFocus.requestFocus,
        groups: [
          zoom,
          if (ed.role >= Role.commenter) ToolbarGroup([comment], id: 'comment'),
        ],
        trailing: [
          ToolbarCustom(
            id: 'slides.toolbar.viewOnly',
            pinned: true,
            builder: (context) => ShadBadge.secondary(
              child: Text(
                ed.roleCanEdit
                    ? l.badgeViewing
                    : (ed.role == Role.commenter
                          ? l.badgeCommentOnly
                          : l.badgeViewOnly),
              ),
            ),
          ),
        ],
      );
    }

    final history = ToolbarGroup([
      ui.button(
        'shell.edit.undo',
        icon: LucideIcons.undo2,
        priority: 1,
        keyName: 'undo',
        label: undoLabel == null
            ? l.toolbarUndo
            : l.toolbarUndoLabel(undoLabel),
        onLongPress: () => ui.run('shell.edit.undoHistory'),
      ),
      ui.button(
        'shell.edit.redo',
        icon: LucideIcons.redo2,
        priority: 1,
        keyName: 'redo',
        label: redoLabel == null
            ? l.toolbarRedo
            : l.toolbarRedoLabel(redoLabel),
      ),
      ui.toggle('slides.format.paintFormat', priority: 3),
    ], id: 'history');

    final newSlide = ToolbarGroup([
      ToolbarSplitButton(
        id: 'slides.toolbar.newSlide',
        priority: 1,
        icon: LucideIcons.plus,
        label: ui.title('slides.slide.new'),
        shortcut: ui.shortcut('slides.slide.new'),
        enabled: ui.state('slides.slide.new').enabled,
        onPressed: () => ui.run('slides.slide.new'),
        entries: () => MenuResolver(services).entries(context, [
          for (final layout in SlideLabels.layouts(ed.model))
            MenuSpec.command(
              'slides.slide.new',
              label: layout.name,
              args: {'layoutId': layout.id},
              id: 'toolbar.newSlide.${layout.id}',
            ),
        ]),
      ),
    ], id: 'newSlide');

    final insert = ToolbarGroup([
      ui.toggle('slides.tool.select', priority: 2),
      ui.button('slides.insert.textBox', priority: 1),
      ToolbarDropdownButton(
        id: 'slides.toolbar.shape',
        priority: 2,
        label: l.menuShape,
        icon: LucideIcons.square,
        enabled: ui.state('slides.insert.shape').enabled,
        entries: () => [
          WonkyMenuCustom(
            label: l.menuShape,
            builder: (context, close) => ShapeGallery(
              selected: ShapeInsert.geometryOf(ed.armedTool),
              onSelected: (g) {
                close();
                ui.run('slides.insert.shape', {'geometry': g});
              },
            ),
          ),
          const WonkyMenuSeparator(),
          ui.item(
            'slides.insert.shape',
            args: const {'pick': true},
            label: l.menuShapeGallery,
            keyName: 'toolbar.shape.all',
          ),
        ],
      ),
      ui.dropdown(
        'line',
        label: l.menuLine,
        icon: LucideIcons.slash,
        priority: 3,
        enabled: ui.state('slides.insert.line').enabled,
        items: () => lineInsertItems(l),
      ),
      ui.dropdown(
        'image',
        label: l.menuImage,
        icon: LucideIcons.image,
        priority: 2,
        enabled: ui.state('slides.insert.image').enabled,
        items: () => [
          for (final (source, label) in [
            ('upload', l.imageUpload),
            ('drive', l.imageFromDrive),
            ('url', l.imageByUrl),
            ('clipboard', l.imageFromClipboard),
          ])
            MenuSpec.command(
              'slides.insert.image',
              label: label,
              args: {'source': source},
              id: 'toolbar.image.$source',
            ),
        ],
      ),
      ToolbarDropdownButton(
        id: 'slides.toolbar.table',
        priority: 4,
        label: l.menuTable,
        icon: LucideIcons.table,
        enabled: ui.state('slides.insert.table').enabled,
        entries: () => [
          WonkyMenuCustom(
            label: l.menuTable,
            builder: (context, close) => WonkyTableSizePicker(
              onSelected: (rows, cols) {
                close();
                ui.run('slides.insert.table', {'rows': rows, 'cols': cols});
              },
            ),
          ),
        ],
      ),
      ui.button('slides.insert.code', priority: 3),
      ui.dropdown(
        'chart',
        label: l.menuChart,
        icon: LucideIcons.chartColumn,
        priority: 4,
        enabled: ui.state('slides.insert.chartFromSheets').enabled,
        items: () => [
          MenuSpec.command(
            'slides.insert.chartFromSheets',
            label: l.chartFromSheets,
          ),
          MenuSpec.separator(),
          for (final (type, label) in [
            ('column', l.chartColumn),
            ('bar', l.chartBar),
            ('line', l.chartLine),
            ('pie', l.chartPie),
          ])
            MenuSpec.command(
              'slides.insert.chart',
              label: label,
              args: {'type': type},
              id: 'toolbar.chart.$type',
            ),
        ],
      ),
      ui.button('slides.insert.icon', priority: 5),
    ], id: 'insert');

    return WonkyToolbar(
      controller: controller,
      semanticLabel: l.toolbarLabel,
      onEscape: ed.canvasFocus.requestFocus,
      groups: [
        history,
        zoom,
        newSlide,
        insert,
        ...contextualToolbarGroups(ui, ed),
      ],
      trailing: [
        comment,
        ui.button(
          'slides.panel.animate',
          args: const {'tab': 'build'},
          label: l.toolbarAnimate,
          keyName: 'animate',
          priority: 2,
        ),
      ],
    );
  }
}
