import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

import '../../l10n/slides_l10n.dart';

/// Localized names, descriptions and glyphs of the motion catalogs (06 §3,
/// §5.3, §7.2): the core's catalogs carry English names; the app shows its
/// ARB strings keyed by id.
abstract final class BuildLabels {
  /// The effect's name ("Rise").
  static String effect(SlidesLocalizations l, String id) {
    final s = l.animateEffectName(id);
    return s.isEmpty ? id : s;
  }

  /// The effect's one-line description (tile tooltip and accessible
  /// description, 06 §17).
  static String effectDescription(SlidesLocalizations l, String id) =>
      l.animateEffectDescription(id);

  /// The transition's name.
  static String transition(SlidesLocalizations l, String id) =>
      l.animateTransitionName(id);

  /// The transition's description.
  static String transitionDescription(SlidesLocalizations l, String id) =>
      l.animateTransitionDescription(id);

  /// A parameter's label.
  static String param(SlidesLocalizations l, String key) =>
      l.animateParamName(key);

  /// A choice value's label (directions, anchors, shapes, modes).
  static String choice(SlidesLocalizations l, String value) =>
      l.animateChoiceName(value);

  /// "Typewriter works on text only" (06 §5.2).
  static String targetReason(SlidesLocalizations l, EffectSpec spec) =>
      l.animateTargetReason(effect(l, spec.id), spec.target.name);

  /// The trigger's name ("After previous").
  static String trigger(SlidesLocalizations l, SlideBuildTrigger t) =>
      l.animateTriggerName(t.name);

  /// The trigger glyph of the Order list (06 §5.4).
  static IconData triggerIcon(SlideBuildTrigger t) => switch (t) {
    SlideBuildTrigger.onClick => LucideIcons.mousePointerClick,
    SlideBuildTrigger.withPrevious => LucideIcons.link,
    SlideBuildTrigger.afterPrevious => LucideIcons.clock,
    SlideBuildTrigger.onElementClick => LucideIcons.pointer,
  };

  /// The delivery's name ("By paragraph").
  static String delivery(SlidesLocalizations l, DeliveryBy by) =>
      l.animateDeliveryName(by.name);

  /// "Rise · by paragraph · 4 parts" (Order list rows, 06 §5.4).
  static String summary(
    SlidesLocalizations l,
    SlideBuildRec b, {
    int parts = 0,
  }) {
    final name = EffectCatalog.byId(b.kind, b.effect) == null
        ? l.animateEffectUnsupported
        : effect(l, b.effect);
    final by = BuildOptions.decode(b.optionsJson).value.delivery.by;
    return [
      name,
      if (by != DeliveryBy.all) delivery(l, by).toLowerCase(),
      if (parts > 1) l.animatePartsCount(parts),
    ].join(' · ');
  }

  /// The tile group's heading.
  static String group(SlidesLocalizations l, String group) =>
      l.animateGroupName(group);

  /// The effect's tile glyph.
  static IconData effectIcon(String id) => switch (id) {
    'appear' || 'disappear' => LucideIcons.eye,
    'fade' || 'fadeOut' || 'opacityTo' => LucideIcons.blend,
    'rise' => LucideIcons.arrowUpFromLine,
    'sink' => LucideIcons.arrowDownToLine,
    'moveIn' => LucideIcons.moveRight,
    'moveOut' => LucideIcons.moveLeft,
    'scale' || 'scaleOut' => LucideIcons.scaling,
    'pop' => LucideIcons.sparkle,
    'popOut' => LucideIcons.shrink,
    'zoom' => LucideIcons.zoomIn,
    'zoomOut' => LucideIcons.zoomOut,
    'blur' || 'blurOut' => LucideIcons.droplet,
    'wipe' || 'wipeOut' => LucideIcons.scanLine,
    'iris' || 'irisOut' => LucideIcons.aperture,
    'dissolve' || 'dissolveOut' => LucideIcons.grip,
    'drop' => LucideIcons.arrowDown,
    'fall' => LucideIcons.moveDown,
    'flip' || 'flipOut' => LucideIcons.flipHorizontal2,
    'rotate' || 'rotateOut' => LucideIcons.rotateCw,
    'typewriter' => LucideIcons.keyboard,
    'eraseText' => LucideIcons.eraser,
    'lineDraw' => LucideIcons.penLine,
    'lineErase' => LucideIcons.eraser,
    'chartGrow' => LucideIcons.chartColumnIncreasing,
    'chartShrink' => LucideIcons.chartColumnDecreasing,
    'codeType' => LucideIcons.textCursorInput,
    'pulse' => LucideIcons.heartPulse,
    'bounce' => LucideIcons.activity,
    'shake' => LucideIcons.vibrate,
    'blink' => LucideIcons.lightbulb,
    'spin' => LucideIcons.refreshCw,
    'grow' => LucideIcons.maximize2,
    'colorChange' => LucideIcons.palette,
    'highlight' => LucideIcons.highlighter,
    'chartHighlight' => LucideIcons.chartBar,
    'chartHighlightClear' => LucideIcons.chartNoAxesColumn,
    'chartOrbit' => LucideIcons.orbit,
    'chartCamera' => LucideIcons.rotate3d,
    'codeHighlight' => LucideIcons.searchCode,
    'codeState' => LucideIcons.codeXml,
    'path' => LucideIcons.spline,
    'moveTo' => LucideIcons.move3d,
    _ => LucideIcons.sparkles,
  };

  /// The transition's tile glyph (`TransitionInfo.icon` names).
  static IconData transitionIcon(String id) => switch (id) {
    'none' => LucideIcons.square,
    'fade' => LucideIcons.blend,
    'dissolve' => LucideIcons.grip,
    'push' => LucideIcons.arrowLeft,
    'slide' => LucideIcons.panelLeftOpen,
    'cover' => LucideIcons.layers,
    'uncover' => LucideIcons.panelLeftClose,
    'wipe' => LucideIcons.moveRight,
    'iris' => LucideIcons.circleDot,
    'zoom' => LucideIcons.zoomIn,
    'flip' => LucideIcons.flipHorizontal2,
    'cube' => LucideIcons.box,
    'doorway' => LucideIcons.doorOpen,
    'swap' => LucideIcons.arrowLeftRight,
    'revolve' => LucideIcons.rotate3d,
    'magicMove' => LucideIcons.wandSparkles,
    _ => LucideIcons.squareStack,
  };

  /// The arrow of a direction choice (`left`, `topRight`, `up`, …).
  static IconData directionIcon(String d) => switch (d) {
    'left' => LucideIcons.arrowLeft,
    'right' => LucideIcons.arrowRight,
    'top' || 'up' => LucideIcons.arrowUp,
    'bottom' || 'down' => LucideIcons.arrowDown,
    'topLeft' => LucideIcons.arrowUpLeft,
    'topRight' => LucideIcons.arrowUpRight,
    'bottomLeft' => LucideIcons.arrowDownLeft,
    'bottomRight' => LucideIcons.arrowDownRight,
    _ => LucideIcons.circle,
  };

  /// A label for an element in the Order list and badges (06 A-06-6): its
  /// `name`, else its kind with the start of its text ("Text: Pricing").
  static String element(SlidesLocalizations l, SlideElementRec? e) {
    if (e == null) return l.animateMissingObject;
    final name = e.name;
    if (name != null && name.isNotEmpty) return name;
    final kind = switch (e.kind) {
      ElementKind.text => l.elementKindText,
      ElementKind.shape => l.elementKindShape,
      ElementKind.line => l.elementKindLine,
      ElementKind.image => l.elementKindImage,
      ElementKind.table => l.elementKindTable,
      ElementKind.code => l.elementKindCode,
      ElementKind.chart => l.elementKindChart,
      ElementKind.icon => l.elementKindIcon,
      ElementKind.group => l.elementKindGroup,
    };
    final text = SlidesText.plainText(e.text).trim().replaceAll('\n', ' ');
    if (text.isEmpty) return kind;
    final short = text.length > 32 ? '${text.substring(0, 32)}…' : text;
    return '$kind: $short';
  }

  /// The element kind's glyph.
  static IconData elementIcon(ElementKind kind) => switch (kind) {
    ElementKind.text => LucideIcons.type,
    ElementKind.shape => LucideIcons.square,
    ElementKind.line => LucideIcons.penLine,
    ElementKind.image => LucideIcons.camera,
    ElementKind.table => LucideIcons.grip,
    ElementKind.code => LucideIcons.codeXml,
    ElementKind.chart => LucideIcons.chartColumnIncreasing,
    ElementKind.icon => LucideIcons.sparkle,
    ElementKind.group => LucideIcons.boxes,
  };

  /// Seconds for the timing fields ("0.6").
  static String seconds(int ms) {
    final s = ms / 1000;
    final t = s.toStringAsFixed(2);
    return t.replaceFirst(RegExp(r'0$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}

/// The easing presets of the Build and Transition tabs (06 §4.3).
abstract final class EasingPresets {
  /// Preset id → expression (`custom` keeps the current expression).
  static const presets = <String, String>{
    'smooth': 'easeInOutCubic',
    'snappy': 'spring(0.4,0)',
    'bouncy': 'spring(0.5,0.35)',
    'gentle': 'spring(0.9,0)',
    'linear': 'linear',
    'easeIn': 'easeInCubic',
    'easeOut': 'easeOutCubic',
  };

  /// The preset of [expression] (springs match by bounce), else `custom`.
  static String presetOf(String expression) {
    for (final e in presets.entries) {
      if (e.value == expression) return e.key;
    }
    final curve = MotionEasing.tryParse(expression);
    if (curve is SpringEasing) {
      for (final e in presets.entries) {
        final p = MotionEasing.tryParse(e.value);
        if (p is SpringEasing && (p.b - curve.b).abs() < 1e-6) {
          if (e.key == 'snappy' || e.key == 'gentle') {
            if ((p.d - curve.d).abs() < 1e-6) return e.key;
            continue;
          }
          return e.key;
        }
      }
    }
    return switch (expression) {
      'easeOut' || 'easeOutQuint' || 'easeOutExpo' => 'easeOut',
      'easeIn' => 'easeIn',
      'easeInOut' || 'ease' => 'smooth',
      _ => 'custom',
    };
  }

  /// The expression of [preset] for a build of [durationMs] (springs keep
  /// the duration as their perceptual `d`).
  static String expressionOf(String preset, int durationMs) {
    final e = presets[preset] ?? 'easeInOutCubic';
    final curve = MotionEasing.tryParse(e);
    if (curve is SpringEasing && durationMs > 0) {
      return curve.withDuration(durationMs / 1000).expression;
    }
    return e;
  }
}
