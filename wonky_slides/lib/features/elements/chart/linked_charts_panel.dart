import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_ui/wonky_ui.dart';

import '../../../config/panels/slides_panels.dart';
import '../../../l10n/slides_l10n.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../toolbar/command_ui.dart';
import 'chart_canvas_mode.dart' show chartStatusLabel;
import 'chart_elements.dart';
import 'chart_links.dart';

/// The Linked charts side panel (`slides.panel.linkedObjects`, 08 §5.4).
SidePanelSpec linkedChartsPanelSpec(
  BuildContext context,
  ShellServices services,
  DeckEditorController editor,
) => SidePanelSpec(
  id: SlidesPanels.linkedObjects,
  title: slidesL10n(context).cmdPanelLinkedObjects,
  icon: LucideIcons.link2,
  showAsTab: false,
  builder: (context) => LinkedChartsPanel(services: services, editor: editor),
);

/// Widget keys of the panel.
abstract final class LinkedChartsKeys {
  static const panel = ValueKey<String>('slides.linkedCharts.panel');
  static const updateAll = ValueKey<String>('slides.linkedCharts.updateAll');
  static const check = ValueKey<String>('slides.linkedCharts.check');

  static ValueKey<String> row(String elementId) =>
      ValueKey<String>('slides.linkedCharts.row.$elementId');

  static ValueKey<String> update(String elementId) =>
      ValueKey<String>('slides.linkedCharts.update.$elementId');
}

/// Every linked chart of the deck grouped by spreadsheet with its status
/// (Up to date / Changed / No access / Source deleted …), the slide number
/// (a click goes to the slide and selects the chart), *Update* per chart and
/// *Update all* (one undo step). Read-only for viewers.
class LinkedChartsPanel extends StatelessWidget {
  const LinkedChartsPanel({
    super.key,
    required this.services,
    required this.editor,
  });

  final ShellServices services;
  final DeckEditorController editor;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([editor, ChartLinks.of(editor)]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final links = ChartLinks.of(editor);
    final probes = ChartLinkOps.probesOf(editor.model);
    final groups = <String, List<ChartLinkProbeData>>{};
    final titles = <String, String>{};
    for (final p in probes) {
      (groups[p.spreadsheetUuid] ??= []).add(p);
      final t = ChartElements.snapshotOf(
        editor,
        p.elementId,
      )?.dataSnapshot.source.spreadsheetTitle;
      if (t != null && t.isNotEmpty) titles[p.spreadsheetUuid] = t;
    }
    final changed = links.changedIds.length;
    final ui = SlidesCommandUi(context, services);
    final canEdit = editor.canEdit;
    return Column(
      key: LinkedChartsKeys.panel,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (canEdit)
                ShadButton(
                  key: LinkedChartsKeys.updateAll,
                  size: ShadButtonSize.sm,
                  enabled:
                      changed > 0 &&
                      ui.state('slides.chart.update', const {
                        'all': true,
                      }).enabled,
                  leading: const Icon(LucideIcons.refreshCw, size: 14),
                  onPressed: () => ui.run('slides.chart.update', const {
                    'all': true,
                  }, InvocationSource.ui),
                  child: Text(l.chartUpdateAll(changed)),
                ),
              ShadButton.outline(
                key: LinkedChartsKeys.check,
                size: ShadButtonSize.sm,
                enabled: links.online && !links.checking,
                onPressed: () => unawaited(links.check()),
                child: Text(links.checking ? l.chartChecking : l.chartCheckNow),
              ),
            ],
          ),
        ),
        if (!links.online)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(l.chartErrOffline, style: theme.textTheme.muted),
          ),
        Expanded(
          child: probes.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l.chartNoLinkedCharts,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.muted,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final g in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.sheet,
                              size: 14,
                              color: theme.colorScheme.mutedForeground,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                titles[g.key] ?? l.chartUntitled,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.small.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final p in g.value) _row(context, l, ui, p),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    SlidesLocalizations l,
    SlidesCommandUi ui,
    ChartLinkProbeData p,
  ) {
    final theme = ShadTheme.of(context);
    final links = ChartLinks.of(editor);
    final status = links.statusOf(p.elementId);
    final e = editor.model.element(p.elementId);
    final slideId = e?.ownerId;
    final index = slideId == null ? -1 : editor.order.indexOf(slideId);
    final snap = ChartElements.snapshotOf(editor, p.elementId);
    final title = snap == null
        ? l.chartUntitled
        : (snap.dataSnapshot.source.chartTitle.isNotEmpty
              ? snap.dataSnapshot.source.chartTitle
              : snap.spec.title.text);
    final changed = status == ChartLinkStatusCode.changed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: ShadButton.ghost(
              key: LinkedChartsKeys.row(p.elementId),
              height: 44,
              mainAxisAlignment: MainAxisAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: slideId == null || index < 0
                  ? null
                  : () {
                      editor.setCurrentSlide(slideId);
                      editor.selectElements([p.elementId]);
                    },
              child: Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? l.chartUntitled : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        if (index >= 0) l.chartOnSlide(index + 1),
                        chartStatusLabel(l, status),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.muted.copyWith(
                        fontSize: 12,
                        color: changed ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (editor.canEdit && changed)
            ShadButton.outline(
              key: LinkedChartsKeys.update(p.elementId),
              size: ShadButtonSize.sm,
              enabled: ui.state('slides.chart.update', {
                'elementId': p.elementId,
              }).enabled,
              onPressed: () => ui.run('slides.chart.update', {
                'elementId': p.elementId,
              }, InvocationSource.ui),
              child: Text(l.chartUpdateAction),
            ),
        ],
      ),
    );
  }
}
