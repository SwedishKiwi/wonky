import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart';
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/scene.dart';

import '../../../l10n/slides_l10n.dart';
import '../../canvas/canvas_interactions.dart';
import '../../canvas/slide_canvas_controller.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../settings/slides_user_defaults.dart';
import 'chart_elements.dart';
import 'chart_links.dart';

/// Widget keys of the chart canvas mode.
abstract final class ChartCanvasKeys {
  static const badge = ValueKey<String>('slides.chart.badge');
  static const update = ValueKey<String>('slides.chart.badge.update');
}

/// The canvas side of chart elements (Slides 08 §5.4, §9.4, §10.2):
///
/// - the **link badge** of the selected linked chart at its top-left:
///   "Linked", the source state (no access, deleted, in the trash,
///   offline), or the **Update** button when the source changed;
/// - **orbit by drag** on the plot of a selected 3D chart (live camera on
///   the canvas, one `slides.chart.setCamera` step at the end);
/// - the **update morph**: an applied update animates from the old chart
///   scene to the new one (`ChartSceneMorph`, 450 ms; off with reduced
///   motion);
/// - starting the deck's link checks ([ChartLinks]) and repainting when the
///   3D GPU backend becomes ready.
class ChartCanvasMode extends CanvasInteraction {
  ChartCanvasMode(super.c) {
    _links = ChartLinks.of(c.editor)
      ..start()
      ..willUpdate = morphFrom
      ..addListener(c.refresh);
    _ticker = Ticker(_tick, debugLabel: 'slides.chart.morph');
    _orbit = ChartOrbitGesture(
      vsync: _Vsync(),
      onChanged: (a, e) => _setLive(a, e),
      onEnd: _commitOrbit,
    );
    Chart3DBackends.gpu.addListener(c.refresh);
  }

  /// The chart mode of [ed]'s canvas, or null without a canvas.
  static ChartCanvasMode? of(DeckEditorController ed) {
    final canvas = SlideCanvasController.of(ed);
    return canvas == null
        ? null
        : CanvasInteractions.find<ChartCanvasMode>(canvas);
  }

  /// Duration of the update morph (08 §9.4).
  static const morphDuration = Duration(milliseconds: 450);

  late final ChartLinks _links;
  late final Ticker _ticker;
  late final ChartOrbitGesture _orbit;
  final VelocityTracker _velocity = VelocityTracker.withKind(
    PointerDeviceKind.mouse,
  );

  // Update morph.
  String? _morphId;
  ChartScene? _morphFrom;
  ChartSceneMorph? _morph;
  double _morphT = 1;

  // Orbit.
  String? _orbitId;
  Chart3DView? _live;
  Chart3DView? _orbitBase;

  DeckEditorController get ed => c.editor;

  /// Whether a morph or an orbit is running (tests).
  bool get animating => _ticker.isActive || _orbit.active;

  bool get _reduceMotion {
    try {
      return ed.defaults.flag(SlidesUserDefaults.keyReduceEditorMotion);
    } catch (_) {
      return false;
    }
  }

  ChartScene? _chartSceneOf(SlideScene? s, String id) {
    if (s == null) return null;
    ChartScene? walk(List<SceneNode> nodes) {
      for (final n in nodes) {
        if (n is ChartNode && n.elementId == id) return n.scene;
        if (n is GroupNode) {
          final k = walk(n.children);
          if (k != null) return k;
        }
      }
      return null;
    }

    return walk(s.nodes);
  }

  /// Starts the update morph of [elementId] from the scene shown now (call
  /// before the new snapshot is written).
  void morphFrom(String elementId) {
    if (_reduceMotion) return;
    final from = _chartSceneOf(c.scene, elementId);
    if (from == null) return;
    _morphId = elementId;
    _morphFrom = from;
    _morph = null;
    _morphT = 0;
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / morphDuration.inMicroseconds;
    _morphT = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
    if (t >= 1) {
      _ticker.stop();
      _morphId = null;
      _morphFrom = null;
      _morph = null;
    }
    c.refresh();
  }

  @override
  bool get active => true;

  @override
  SlideScene sceneFor(SlideScene scene) {
    var out = scene;
    final id = _morphId, from = _morphFrom;
    if (id != null && from != null) {
      final to = _chartSceneOf(scene, id);
      if (to != null && !identical(to, from)) {
        final m = _morph ??= ChartSceneMorph(from, to);
        out = replaceChart(out, id, m.at(_morphT));
      } else if (to != null) {
        out = replaceChart(out, id, from);
      }
    }
    final oid = _orbitId, live = _live;
    if (oid != null && live != null) {
      final b = ChartElements.buildOf(ed, oid, view: live);
      if (b != null) out = replaceChart(out, oid, b.scene);
    }
    return out;
  }

  /// [scene] with the chart node of [elementId] drawing [chart].
  static SlideScene replaceChart(
    SlideScene scene,
    String elementId,
    ChartScene chart,
  ) {
    var changed = false;
    SceneNode swap(SceneNode n) {
      switch (n) {
        case ChartNode() when n.elementId == elementId:
          changed = true;
          return ChartNode(elementId: n.elementId, dst: n.dst, scene: chart);
        case GroupNode():
          final kids = [for (final k in n.children) swap(k)];
          if (!kids.indexed.any((e) => !identical(e.$2, n.children[e.$1]))) {
            return n;
          }
          return GroupNode(
            elementId: n.elementId,
            transform: n.transform,
            opacity: n.opacity,
            clip: n.clip,
            effects: n.effects,
            children: kids,
          );
        default:
          return n;
      }
    }

    final nodes = [for (final n in scene.nodes) swap(n)];
    if (!changed) return scene;
    return SlideScene(
      slideId: scene.slideId,
      width: scene.width,
      height: scene.height,
      background: scene.background,
      nodes: nodes,
    );
  }

  // ------------------------------------------------------------- orbit

  /// The selected 3D chart whose plot is under [su], or null.
  String? _orbitTarget(Offset su) {
    if (!ed.canEdit) return null;
    final sel = ed.selectedElementIds;
    if (sel.length != 1) return null;
    final id = sel.single;
    final e = ed.model.element(id);
    if (e == null || e.locked || !ChartElements.isChart(e)) return null;
    final scene = _chartSceneOf(c.scene, id);
    final f = c.frameOf(id);
    final three = scene?.threeD;
    if (scene == null || f == null || three == null || f.width <= 0) {
      return null;
    }
    final local = SlideCanvasController.slideToLocal(f, su);
    final k = scene.width / f.width;
    final p = local * k;
    final r = scene.plotArea ?? three.viewport;
    return r.contains(p.dx, p.dy) ? id : null;
  }

  @override
  bool down(CanvasPointer p) {
    if ((p.buttons & kPrimaryMouseButton) == 0 && p.buttons != 0) return false;
    final id = _orbitTarget(p.su);
    if (id == null) return false;
    final cam = ChartElements.cameraOf(ed, id);
    if (cam == null) return false;
    _orbitId = id;
    _orbitBase = cam;
    _live = null;
    _velocity.addPosition(_now(), p.px);
    _orbit.start(p.px, cam.azimuth, cam.elevation);
    return true;
  }

  static Duration _now() =>
      Duration(microseconds: DateTime.now().microsecondsSinceEpoch);

  @override
  void move(CanvasPointer p) {
    if (_orbitId == null) return;
    _velocity.addPosition(_now(), p.px);
    _orbit.update(p.px);
  }

  @override
  void up(CanvasPointer p) {
    if (_orbitId == null) return;
    final moved = _orbit.moved;
    _orbit.end(_velocity.getVelocity().pixelsPerSecond);
    if (!moved) _endOrbit();
  }

  @override
  void cancel() {
    if (_orbitId == null) return;
    _orbit.cancel();
    _endOrbit();
  }

  void _setLive(double azimuth, double elevation) {
    final base = _orbitBase;
    if (_orbitId == null || base == null) return;
    _live = Chart3DView(
      azimuth: azimuth,
      elevation: elevation,
      perspective: base.perspective,
    );
    c.refresh();
  }

  void _commitOrbit(double azimuth, double elevation) {
    final id = _orbitId;
    if (id == null) return;
    final az = (ChartThreeD.normalizeAzimuth(azimuth) * 10).round() / 10;
    final el = (elevation * 10).round() / 10;
    unawaited(
      ed
          .invokeCommand('slides.chart.setCamera', {
            'elementId': id,
            'azimuth': az,
            'elevation': el,
          })
          .whenComplete(_endOrbit),
    );
  }

  void _endOrbit() {
    _orbitId = null;
    _live = null;
    _orbitBase = null;
    c.refresh();
  }

  @override
  MouseCursor? cursorAt(Offset su) {
    if (_orbit.active) return SystemMouseCursors.grabbing;
    return _orbitTarget(su) == null ? null : SystemMouseCursors.grab;
  }

  // ------------------------------------------------------------- badge

  @override
  List<Widget> overlays(BuildContext context) {
    final sel = ed.selectedElementIds;
    if (sel.length != 1 || _orbit.active) return const [];
    final id = sel.single;
    final e = ed.model.element(id);
    if (e == null || !ChartElements.isLinked(ed, e)) return const [];
    // Viewers see the snapshot only (08 §5.4).
    if (!ed.roleCanEdit) return const [];
    final f = c.frameOf(id);
    if (f == null) return const [];
    final r = c.viewport.rectToViewport(f.bounds);
    return [
      Positioned(
        left: r.left + 8,
        top: r.top + 8,
        child: CanvasChrome(
          child: ChartLinkBadge(editor: ed, elementId: id),
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _links
      ..removeListener(c.refresh)
      ..stop();
    if (_links.willUpdate == morphFrom) _links.willUpdate = null;
    Chart3DBackends.gpu.removeListener(c.refresh);
    _ticker.dispose();
    _orbit.dispose();
  }
}

class _Vsync implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) =>
      Ticker(onTick, debugLabel: 'slides.chart.orbit');
}

/// The link chip of a linked chart (08 §5.4, §6): "Linked" with the
/// source's state, or the primary **Update** button when it changed.
class ChartLinkBadge extends StatelessWidget {
  const ChartLinkBadge({
    super.key,
    required this.editor,
    required this.elementId,
  });

  final DeckEditorController editor;
  final String elementId;

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final links = ChartLinks.of(editor);
    final status = links.statusOf(elementId);
    final online = links.online;
    final snap = ChartElements.snapshotOf(editor, elementId);
    final source = snap?.dataSnapshot.source;
    if (status == ChartLinkStatusCode.changed && editor.canEdit) {
      final title = [
        if (source != null && source.spreadsheetTitle.isNotEmpty)
          source.spreadsheetTitle,
        if (source != null && source.chartTitle.isNotEmpty) source.chartTitle,
      ].join(' › ');
      final tip = online
          ? l.chartUpdateTooltip(
              title.isEmpty ? l.chartUntitled : title,
              links.infoOf(elementId)?.summary ?? '',
            )
          : l.chartErrOffline;
      return ShadTooltip(
        builder: (_) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(tip),
        ),
        child: ShadButton(
          key: ChartCanvasKeys.update,
          size: ShadButtonSize.sm,
          enabled: online,
          leading: const Icon(LucideIcons.refreshCw, size: 14),
          onPressed: () => unawaited(
            editor.invokeCommand('slides.chart.update', {
              'elementId': elementId,
            }),
          ),
          child: Text(l.chartUpdateAction),
        ),
      );
    }
    final theme = ShadTheme.of(context);
    var text = chartStatusLabel(l, status);
    if (!online) text = l.chartStatusOffline(text);
    return Semantics(
      label: text,
      child: Container(
        key: ChartCanvasKeys.badge,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.popover,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.sheet,
              size: 13,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(width: 4),
            Text(text, style: theme.textTheme.small.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// The badge text of a link [status] (08 §6).
String chartStatusLabel(SlidesLocalizations l, ChartLinkStatusCode? status) =>
    switch (status) {
      null || ChartLinkStatusCode.upToDate => l.chartStatusLinked,
      ChartLinkStatusCode.changed => l.chartStatusChanged,
      ChartLinkStatusCode.noAccess ||
      ChartLinkStatusCode.exportDisabled => l.chartStatusNoAccess,
      ChartLinkStatusCode.chartDeleted => l.chartStatusChartDeleted,
      ChartLinkStatusCode.spreadsheetTrashed => l.chartStatusTrashed,
      ChartLinkStatusCode.spreadsheetDeleted => l.chartStatusDeleted,
      ChartLinkStatusCode.unsupportedSpec => l.chartStatusUnsupported,
    };
