import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/sheets_l10n.dart';
import '../../objects/object_menu.dart';
import '../../objects/objects_controller.dart';
import '../../sheet_editor/sheet_editor_controller.dart';
import '../../toolbar/command_ui.dart';
import 'chart_view.dart';

/// A chart sheet (08 §11): no grid; the sheet's chart fills the content
/// area with 24 px padding (keeping the stored aspect ratio only with
/// `lockAspect`). The chart is selected while the sheet is shown, so the
/// object shortcuts (Del, Enter, Mod+C …) apply to it.
class ChartSheetView extends StatefulWidget {
  const ChartSheetView({
    super.key,
    required this.editor,
    required this.services,
    required this.objects,
  });

  final SheetEditorController editor;
  final ShellServices services;
  final ObjectsController objects;

  @override
  State<ChartSheetView> createState() => _ChartSheetViewState();
}

class _ChartSheetViewState extends State<ChartSheetView> {
  static const double padding = 24;

  ObjectsController get objects => widget.objects;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _selectChart());
  }

  EmbeddedObjectRecord? get _chart {
    final list = objects.objectsOn(widget.editor.activeSheetId);
    for (final o in list) {
      if (o.kind == EmbeddedObjectKind.chart) return o;
    }
    return list.isEmpty ? null : list.first;
  }

  void _selectChart() {
    if (!mounted) return;
    final c = _chart;
    if (c != null && objects.selectedId != c.id) objects.select(c.id);
  }

  void _menu(EmbeddedObjectRecord o, Offset global) {
    WonkyPopupMenuHost.maybeOf(context)?.show(
      global,
      () => objectMenu(CommandUi(context, widget.services), widget.editor, o),
      onClosed: () => objects.focus.requestFocus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = sheetsL10n(context);
    return ListenableBuilder(
      listenable: Listenable.merge([objects, widget.editor.scroll]),
      builder: (context, _) {
        final o = _chart;
        return Container(
          key: const ValueKey<String>('sheets.chartSheet'),
          color: theme.colorScheme.canvas,
          child: o == null
              ? Center(
                  child: Text(l.chartSheetEmpty, style: theme.textTheme.muted),
                )
              : LayoutBuilder(
                  builder: (context, c) => _content(context, o, c.biggest),
                ),
        );
      },
    );
  }

  Widget _content(BuildContext context, EmbeddedObjectRecord o, Size size) {
    final theme = ShadTheme.of(context);
    final anchor = objects.anchorOf(o);
    var w = math.max(40.0, size.width - 2 * padding);
    var h = math.max(40.0, size.height - 2 * padding);
    if ((anchor?.lockAspect ?? false) &&
        (anchor?.width ?? 0) > 0 &&
        (anchor?.height ?? 0) > 0) {
      final aspect = anchor!.width / anchor.height;
      if (w / h > aspect) {
        w = h * aspect;
      } else {
        h = w / aspect;
      }
    }
    final chart = objects.chartOf(o);
    final alt = o.altText?.trim() ?? '';
    final selected = objects.isSelected(o.id);
    return Center(
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                container: true,
                button: true,
                selected: selected,
                label: alt.isNotEmpty ? alt : chart.autoDescription,
                child: Listener(
                  onPointerDown: (e) {
                    objects.select(o.id);
                    if (e.buttons == kSecondaryMouseButton) {
                      _menu(o, e.position);
                    }
                  },
                  child: GestureDetector(
                    onDoubleTap: () => unawaited(
                      widget.editor.invokeCommand('sheets.chart.edit', {
                        'objectId': o.id,
                      }),
                    ),
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.border
                              : const Color(0x00000000),
                        ),
                      ),
                      child: RepaintBoundary(
                        child: chart.spec.isFromNewerVersion
                            ? const NewerVersionChartCard()
                            : ChartObjectView(
                                controller: chart,
                                width: w,
                                height: h,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Builder(
                builder: (context) => ShadIconButton.outline(
                  key: const ValueKey<String>('sheets.chartSheet.more'),
                  width: 28,
                  height: 28,
                  padding: EdgeInsets.zero,
                  icon: const Icon(LucideIcons.ellipsisVertical, size: 16),
                  onPressed: () {
                    final box = context.findRenderObject() as RenderBox?;
                    _menu(
                      o,
                      box == null
                          ? Offset.zero
                          : box.localToGlobal(Offset(0, box.size.height + 4)),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
