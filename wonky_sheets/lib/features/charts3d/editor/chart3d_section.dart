import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../../l10n/sheets_l10n.dart';
import '../../charts/editor/chart_editor_widgets.dart';
import '../../formatting/panel_widgets.dart';

/// Writes a JSON merge patch on the spec; edits with the same [coalesceKey]
/// within a second are one undo step.
typedef ChartPatch =
    void Function(Map<String, Object?> patch, [String? coalesceKey]);

/// The controls of the chart editor's "3D" section (08 §23.9): show in 3D,
/// rotation and tilt, perspective, depth, gap depth, lighting, floor and
/// walls, floor color, column shape, pull slices apart, reset view.
List<Widget> chart3DControls(
  SheetsLocalizations l,
  ChartSpec spec,
  ChartPatch patch,
) {
  final t = spec.threeD;
  final type = spec.type;
  final on = t.enabled || type.only3D;
  final pie = type == ChartType.pie;
  void set(Map<String, Object?> m, [String? key]) => patch({'threeD': m}, key);
  return [
    // Surface charts only exist in 3D.
    if (!type.only3D)
      EditorCheck(
        keyName: 'threeD',
        label: l.chartEditor3DEnabled,
        value: on,
        onChanged: (v) => set({'enabled': v ? true : null}),
      ),
    if (on) ...[
      Chart3DSlider(
        keyName: 'azimuth',
        label: l.chartEditor3DRotation,
        value: t.azimuthFor(type),
        max: 359,
        suffix: '°',
        onChanged: (v) => set({'azimuth': v}, 'azimuth'),
      ),
      Chart3DSlider(
        keyName: 'elevation',
        label: l.chartEditor3DTilt,
        value: t.elevationFor(type),
        max: 90,
        suffix: '°',
        onChanged: (v) => set({'elevation': v}, 'elevation'),
      ),
      Chart3DSlider(
        keyName: 'perspective',
        label: l.chartEditor3DPerspective,
        value: t.perspective,
        max: ChartThreeD.maxPerspective,
        suffix: '°',
        onChanged: (v) => set({'perspective': v}, 'perspective'),
      ),
      EditorPair(
        left: EditorField(
          label: pie ? l.chartEditor3DHeight : l.chartEditor3DDepth,
          child: EditorStepper(
            keyName: 'depth',
            value: t.depth.round(),
            min: 20,
            max: 500,
            step: 10,
            suffix: '%',
            onChanged: (v) => set({'depth': v == 100 ? null : v}, 'depth'),
          ),
        ),
        right: pie
            ? EditorField(
                label: l.chartEditor3DExplode,
                child: EditorStepper(
                  keyName: 'explode',
                  value: (t.explode * 100).round(),
                  max: 100,
                  step: 5,
                  suffix: '%',
                  onChanged: (v) =>
                      set({'explode': v == 0 ? null : v / 100}, 'explode'),
                ),
              )
            : EditorField(
                label: l.chartEditor3DGapDepth,
                child: EditorStepper(
                  keyName: 'gapDepth',
                  value: t.gapDepth.round(),
                  max: 500,
                  step: 10,
                  suffix: '%',
                  onChanged: (v) =>
                      set({'gapDepth': v == 150 ? null : v}, 'gapDepth'),
                ),
              ),
      ),
      EditorField(
        label: l.chartEditor3DLighting,
        child: PanelSelect<Chart3DLighting>(
          keyName: 'chartEditor.lighting',
          value: t.lighting,
          options: {
            Chart3DLighting.soft: l.chartLightingSoft,
            Chart3DLighting.bright: l.chartLightingBright,
            Chart3DLighting.flat: l.chartLightingFlat,
          },
          onChanged: (v) =>
              set({'lighting': v == Chart3DLighting.soft ? null : v.name}),
        ),
      ),
      if (type == ChartType.column || type == ChartType.bar)
        EditorField(
          label: l.chartEditor3DShape,
          child: PanelSelect<Chart3DShape>(
            keyName: 'chartEditor.shape',
            value: t.shape,
            options: {
              Chart3DShape.box: l.chartShapeBox,
              Chart3DShape.cylinder: l.chartShapeCylinder,
              Chart3DShape.cone: l.chartShapeCone,
              Chart3DShape.pyramid: l.chartShapePyramid,
            },
            onChanged: (v) =>
                set({'shape': v == Chart3DShape.box ? null : v.name}),
          ),
        ),
      if (!pie) ...[
        EditorCheck(
          keyName: 'walls',
          label: l.chartEditor3DWalls,
          value: t.wallsVisible,
          onChanged: (v) => set({'wallsVisible': v ? null : false}),
        ),
        if (t.wallsVisible)
          EditorField(
            label: l.chartEditor3DFloorColor,
            child: EditorColorButton(
              keyName: 'floorColor',
              value: t.floorColor,
              resetLabel: l.colorAutomatic,
              onChanged: (v) => set({'floorColor': v}),
            ),
          ),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Expanded(
              child: Builder(
                builder: (context) => Text(
                  l.chartEditor3DOrbitHint,
                  style: ShadTheme.of(
                    context,
                  ).textTheme.muted.copyWith(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ShadButton.outline(
              key: const ValueKey<String>('chartEditor.reset3DView'),
              size: ShadButtonSize.sm,
              onPressed: t.azimuth == null && t.elevation == null
                  ? null
                  : () => set({'azimuth': null, 'elevation': null}),
              child: Text(l.chartEditor3DResetView),
            ),
          ],
        ),
      ),
    ],
  ];
}

/// A labelled slider with its value; keyboard operable (arrow keys).
class Chart3DSlider extends StatefulWidget {
  const Chart3DSlider({
    super.key,
    required this.keyName,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.min = 0,
    this.suffix = '',
  });

  final String keyName;
  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  State<Chart3DSlider> createState() => _Chart3DSliderState();
}

class _Chart3DSliderState extends State<Chart3DSlider> {
  late final ShadSliderController _c = ShadSliderController(
    initialValue: _clamped,
  );
  bool _dragging = false;

  double get _clamped => widget.value.clamp(widget.min, widget.max);

  @override
  void didUpdateWidget(Chart3DSlider old) {
    super.didUpdateWidget(old);
    if (!_dragging && _c.value != _clamped) _c.value = _clamped;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return EditorField(
      label: widget.label,
      child: Row(
        children: [
          Expanded(
            child: ShadSlider(
              key: ValueKey<String>('chartEditor.${widget.keyName}'),
              controller: _c,
              min: widget.min,
              max: widget.max,
              semanticFormatterCallback: (x) => '${x.round()}${widget.suffix}',
              onChangeStart: (_) => _dragging = true,
              onChangeEnd: (_) => _dragging = false,
              onChanged: (x) {
                final v = x.roundToDouble();
                if (v != widget.value.roundToDouble()) widget.onChanged(v);
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${_clamped.round()}${widget.suffix}',
              textAlign: TextAlign.end,
              style: theme.textTheme.small,
            ),
          ),
        ],
      ),
    );
  }
}
