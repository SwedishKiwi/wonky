import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart';
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;

import '../../../config/slides_features.dart';
import '../../../l10n/slides_l10n.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../style/style_sections.dart';
import 'chart_canvas_mode.dart' show chartStatusLabel;
import 'chart_elements.dart';
import 'chart_links.dart';
import 'chart_style_strings.dart';

/// Widget keys of the chart section.
abstract final class ChartSectionKeys {
  static ValueKey<String> of(String name) =>
      ValueKey<String>('slides.chart.section.$name');
}

/// Inspector › Format › **Chart** (Slides 08 §8.1, §10.2): the source
/// (spreadsheet › sheet › chart, *Open*), the link status with *Update* and
/// *Update automatically*, *Unlink* / *Change linked chart…*, the style mode
/// (*Match theme* | *Keep source*), the background, the 3D camera (presets,
/// rotation, tilt, perspective, *Reset*, camera steps), presenting options,
/// the shared `ChartStyleEditor` in override mode (allowlisted fields, a
/// dot and reset on changed fields, *Reset overrides*, unused series
/// overrides with *Clean up*) and *View data as table*. Every change runs a
/// `slides.chart.*` command (one undo step).
Widget chartSection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final s = StyleScope(context, services, ed);
  final els = [
    for (final e in s.targets)
      if (e.record.kind == ElementKind.chart) e,
  ];
  if (els.length != 1) return const SizedBox.shrink();
  return ListenableBuilder(
    listenable: ChartLinks.of(ed),
    builder: (context, _) =>
        _ChartSection(s: s, ed: ed, element: els.single.record),
  );
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.s,
    required this.ed,
    required this.element,
  });

  final StyleScope s;
  final DeckEditorController ed;
  final SlideElementRec element;

  SlidesLocalizations get l => s.l;

  Map<String, Object?> get _id => {'elementId': element.id};

  void run(String id, [Map<String, Object?> args = const {}]) =>
      s.run(id, {..._id, ...args});

  bool on(String id, [Map<String, Object?> args = const {}]) =>
      s.enabled(id, {..._id, ...args});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final data = ChartElements.dataOf(element);
    final linked = ChartElements.isLinked(ed, element);
    final build = ChartElements.buildOf(ed, element.id);
    final snap = build?.snapshot;
    final children = <Widget>[];

    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    Widget button(
      String key,
      String label,
      IconData icon,
      String command, {
      Map<String, Object?> args = const {},
      bool primary = false,
    }) {
      final enabled = on(command, args);
      final b = primary
          ? ShadButton(
              key: ChartSectionKeys.of(key),
              size: ShadButtonSize.sm,
              enabled: enabled,
              leading: Icon(icon, size: 14),
              onPressed: () => run(command, args),
              child: Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          : ShadButton.outline(
              key: ChartSectionKeys.of(key),
              size: ShadButtonSize.sm,
              enabled: enabled,
              leading: Icon(icon, size: 14),
              onPressed: () => run(command, args),
              child: Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
      return b;
    }

    // ---- Source and link (08 §8.1)
    if (snap == null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(l.chartNoDataYet, style: theme.textTheme.muted),
        ),
      );
      if (ChartElements.isEmpty(ed, element)) {
        children.add(
          Align(
            alignment: Alignment.centerLeft,
            child: button(
              'insert',
              l.cmdInsertChartFromSheets,
              LucideIcons.sheet,
              'slides.insert.chartFromSheets',
            ),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      }
    } else {
      final src = snap.dataSnapshot.source;
      final path = [
        if (src.spreadsheetTitle.isNotEmpty) src.spreadsheetTitle,
        if (src.sheetName.isNotEmpty) src.sheetName,
        src.chartTitle.isNotEmpty
            ? src.chartTitle
            : (snap.spec.title.hasText
                  ? snap.spec.title.text
                  : l.chartUntitled),
      ].join(' › ');
      children.add(
        Row(
          children: [
            Icon(
              linked ? LucideIcons.link : LucideIcons.chartColumn,
              size: 14,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                path,
                key: ChartSectionKeys.of('source'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small,
              ),
            ),
            if (linked)
              ShadTooltip(
                builder: (_) => Text(l.cmdChartOpenSource),
                child: ShadIconButton.ghost(
                  key: ChartSectionKeys.of('open'),
                  width: 28,
                  height: 28,
                  enabled: on('slides.chart.openSource'),
                  icon: const Icon(LucideIcons.externalLink, size: 14),
                  onPressed: () => run('slides.chart.openSource'),
                ),
              ),
          ],
        ),
      );
    }
    if (linked) {
      final links = ChartLinks.of(ed);
      final status = links.statusOf(element.id);
      final checked = links.infoOf(element.id)?.checkedAt;
      var text = chartStatusLabel(l, status);
      if (status == ChartLinkStatusCode.upToDate && checked != null) {
        text = l.chartStatusUpToDate(
          timeAgo(WonkyAppLocalizations.of(context), checked),
        );
      }
      if (!links.online) text = l.chartStatusOffline(text);
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Text(
            text,
            key: ChartSectionKeys.of('status'),
            style: theme.textTheme.muted.copyWith(fontSize: 12),
          ),
        ),
      );
      final auto = ed.model.chartLinkOf(element.id)?.autoUpdate ?? false;
      children.add(
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            button(
              'update',
              l.chartUpdateAction,
              LucideIcons.refreshCw,
              'slides.chart.update',
              primary: status == ChartLinkStatusCode.changed,
            ),
            ShadCheckbox(
              key: ChartSectionKeys.of('auto'),
              value: auto,
              enabled: on('slides.chart.setAutoUpdate'),
              onChanged: (v) =>
                  run('slides.chart.setAutoUpdate', {'autoUpdate': v}),
              label: Text(l.chartAutoShort),
            ),
          ],
        ),
      );
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              button(
                'unlink',
                l.chartUnlinkShort,
                LucideIcons.unlink,
                'slides.chart.unlink',
              ),
              button(
                'relink',
                l.cmdChartRelink,
                LucideIcons.link,
                'slides.chart.relink',
              ),
            ],
          ),
        ),
      );
    } else if (snap != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(l.chartNotLinked, style: theme.textTheme.muted),
        ),
      );
    }

    // ---- Style mode and background
    final canStyle = on('slides.chart.setUseDeckTheme', {'useDeckTheme': true});
    children.add(header(l.chartStyleMode));
    children.add(
      Row(
        children: [
          for (final (deck, label) in [
            (true, l.chartMatchThemeShort),
            (false, l.chartKeepSource),
          ])
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: deck ? 4 : 0),
                child: ShadButton.raw(
                  key: ChartSectionKeys.of(deck ? 'matchTheme' : 'keepSource'),
                  variant: data.style.useDeckTheme == deck
                      ? ShadButtonVariant.secondary
                      : ShadButtonVariant.outline,
                  size: ShadButtonSize.sm,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  enabled: canStyle,
                  onPressed: () => run('slides.chart.setUseDeckTheme', {
                    'useDeckTheme': deck,
                  }),
                  child: Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    const bgOptions = ['default', 'transparent', 'theme', '#FFFFFF'];
    final bg = bgOptions.contains(data.background ?? 'default')
        ? (data.background ?? 'default')
        : 'default';
    children.add(
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: InspectorRow(
          label: l.chartBackground,
          child: StyleSelect<String>(
            keyName: 'chart.background',
            value: bg,
            options: bgOptions,
            enabled: canStyle,
            label: (v) => switch (v) {
              'transparent' => l.chartBackgroundTransparent,
              'theme' => l.chartBackgroundTheme,
              '#FFFFFF' => l.chartBackgroundWhite,
              _ => l.chartBackgroundDefault,
            },
            onChanged: (v) => run('slides.chart.updateStyle', {
              'options': {'background': v == 'default' ? null : v},
            }),
          ),
        ),
      ),
    );

    // ---- 3D camera (08 §10.2)
    final spec = build?.look.spec;
    if (spec != null && spec.is3D) {
      final cam = ChartElements.cameraOf(ed, element.id)!;
      final presets = spec.type == ChartType.pie
          ? Chart3DView.piePresets
          : Chart3DView.presets;
      final canCam = on('slides.chart.setCamera', {'reset': true});
      String? presetOf() {
        for (final e in presets.entries) {
          final v = e.value;
          if ((v.normalizedAzimuth - cam.normalizedAzimuth).abs() < 0.05 &&
              (v.elevation - cam.elevation).abs() < 0.05 &&
              (v.perspective - cam.perspective).abs() < 0.05) {
            return e.key;
          }
        }
        return null;
      }

      children.add(header(l.chartCamera));
      children.add(
        InspectorRow(
          label: l.chartCameraPreset,
          child: StyleSelect<String>(
            keyName: 'chart.preset',
            value: presetOf(),
            placeholder: l.chartCameraCustom,
            options: presets.keys.toList(),
            enabled: canCam,
            label: (k) => chartPresetLabel(l, k),
            onChanged: (k) => run('slides.chart.setCamera', {'preset': k}),
          ),
        ),
      );
      children.add(
        _CameraSlider(
          keyName: 'rotation',
          label: l.chartCameraRotation,
          value: cam.normalizedAzimuth,
          max: 359,
          unit: '°',
          enabled: canCam,
          onCommit: (v) => run('slides.chart.setCamera', {'azimuth': v}),
        ),
      );
      children.add(
        _CameraSlider(
          keyName: 'tilt',
          label: l.chartCameraTilt,
          value: cam.elevation,
          max: 90,
          unit: '°',
          enabled: canCam,
          onCommit: (v) => run('slides.chart.setCamera', {'elevation': v}),
        ),
      );
      children.add(
        _CameraSlider(
          keyName: 'perspective',
          label: l.chartCameraPerspective,
          value: cam.perspective,
          max: 60,
          unit: '°',
          enabled: canCam,
          onCommit: (v) => run('slides.chart.setCamera', {'perspective': v}),
        ),
      );
      children.add(
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (data.camera != null)
              button(
                'cameraReset',
                l.chartCameraReset,
                LucideIcons.rotateCcw,
                'slides.chart.setCamera',
                args: const {'reset': true},
              ),
            if (SlidesFeatures.isOn(SlidesFeature.animations))
              button(
                'cameraStep',
                l.cmdChartAddCameraStep,
                LucideIcons.clapperboard,
                'slides.chart.addCameraStep',
              ),
          ],
        ),
      );
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l.chartCameraHint, style: theme.textTheme.muted),
        ),
      );
    }

    // ---- Presenting (08 §10.5)
    children.add(header(l.chartPresenting));
    children.add(
      InspectorRow(
        label: l.chartHoverTooltips,
        child: ShadSwitch(
          key: ChartSectionKeys.of('hoverTooltips'),
          value: data.interactive.hoverTooltips,
          enabled: canStyle,
          onChanged: (v) => run('slides.chart.updateStyle', {
            'options': {
              'interactive': {'hoverTooltips': v},
            },
          }),
        ),
      ),
    );
    if (spec != null && spec.is3D) {
      children.add(
        InspectorRow(
          label: l.chartOrbitInPresent,
          child: ShadSwitch(
            key: ChartSectionKeys.of('orbitInPresent'),
            value: data.interactive.orbitInPresent,
            enabled: canStyle,
            onChanged: (v) => run('slides.chart.updateStyle', {
              'options': {
                'interactive': {'orbitInPresent': v},
              },
            }),
          ),
        ),
      );
    }

    // ---- Customize (ChartStyleEditor, override mode)
    if (build != null) {
      children.add(header(l.chartCustomize));
      children.add(
        ChartStyleEditor(
          key: ChartSectionKeys.of('editor.${element.id}'),
          spec: build.look.spec,
          data: build.snapshot.data,
          overrides: data.overrides,
          allows: ChartOverrides.allows,
          enabled: canStyle,
          strings: SlidesChartStyleStrings(l),
          keyPrefix: 'slides.chart.style',
          onPatch: (patch, {coalesceKey}) => run('slides.chart.updateStyle', {
            'patch': patch,
            'coalesceKey': ?coalesceKey,
          }),
        ),
      );
      final unused = ChartOverrides.unusedSeries(
        data.overrides,
        build.snapshot.data,
      );
      if (unused.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.chartUnusedOverrides(unused.length),
                    style: theme.textTheme.muted,
                  ),
                ),
                ShadButton.ghost(
                  key: ChartSectionKeys.of('cleanUp'),
                  size: ShadButtonSize.sm,
                  enabled: on('slides.chart.resetOverrides'),
                  onPressed: () =>
                      run('slides.chart.resetOverrides', {'series': unused}),
                  child: Text(l.chartCleanUp),
                ),
              ],
            ),
          ),
        );
      }
      for (final w in build.look.warnings) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              w == SlideChartSpec.invalidOverrides
                  ? l.chartInvalidOverrides
                  : w,
              style: theme.textTheme.muted,
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (data.overrides.isNotEmpty)
                button(
                  'resetOverrides',
                  l.cmdChartResetOverrides,
                  LucideIcons.rotateCcw,
                  'slides.chart.resetOverrides',
                ),
              button(
                'dataTable',
                l.cmdChartViewDataTable,
                LucideIcons.table,
                'slides.chart.viewDataTable',
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// The label of camera preset [key] (08 §10.2).
String chartPresetLabel(SlidesLocalizations l, String key) => switch (key) {
  'front' => l.chartPresetFront,
  'isometric' => l.chartPresetIsometric,
  'topDown' => l.chartPresetTopDown,
  'lowAngle' => l.chartPresetLowAngle,
  'side' => l.chartPresetSide,
  'dramatic' => l.chartPresetDramatic,
  'flat' => l.chartPresetFlat,
  'tilted' => l.chartPresetTilted,
  'steep' => l.chartPresetSteep,
  _ => l.chartPresetDefault,
};

/// A camera angle slider that commits on release (one undo step).
class _CameraSlider extends StatefulWidget {
  const _CameraSlider({
    required this.keyName,
    required this.label,
    required this.value,
    required this.max,
    required this.unit,
    required this.onCommit,
    this.enabled = true,
  });

  final String keyName;
  final String label;
  final double value;
  final double max;
  final String unit;
  final bool enabled;
  final ValueChanged<double> onCommit;

  @override
  State<_CameraSlider> createState() => _CameraSliderState();
}

class _CameraSliderState extends State<_CameraSlider> {
  double? _live;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final v = (_live ?? widget.value).clamp(0.0, widget.max);
    return InspectorRow(
      label: widget.label,
      child: Row(
        children: [
          Expanded(
            child: ShadSlider(
              key: ValueKey<String>(
                'slides.chart.section.${widget.keyName}.${widget.value}',
              ),
              initialValue: v,
              min: 0,
              max: widget.max,
              enabled: widget.enabled,
              onChanged: (x) => setState(() => _live = x),
              onChangeEnd: (x) {
                setState(() => _live = null);
                widget.onCommit(x.roundToDouble());
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${v.round()}${widget.unit}',
              style: theme.textTheme.small,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
