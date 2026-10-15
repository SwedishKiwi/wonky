import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:wonky_slides_core/charts.dart' show SlideChartMotion;
import 'package:wonky_slides_core/interfaces.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/pdf.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart'
    show ResolvedBackground, ResolvedNoFill;

import '../motion/render/motion_scenes.dart';
import '../stage/slide_renderer.dart';
import '../stage/slide_stage.dart';
import 'stored_zip.dart';

/// Which frame of a slide a PNG shows (Slides 10 §13 *Step*; 06 §9.6).
enum SlidesImageFrames {
  /// The print frame (authored layout, content complete — like the PDF and
  /// thumbnails, v2 review Q24).
  print,

  /// The final frame (after every build, as the audience last sees it).
  last,

  /// One image per build step (the steps the PDF prints as pages).
  builds;

  /// The JSON name (`print`, `final`, `builds`).
  String get id => this == last ? 'final' : name;

  static SlidesImageFrames parse(Object? v) => switch (v) {
    'final' || 'last' => last,
    'builds' => builds,
    _ => print,
  };
}

/// The options of a PNG export (Slides 10 §13; `slides.file.download
/// {format: png|pngZip, options}` and the user's last-used options).
class SlidesPngOptions {
  const SlidesPngOptions({
    this.range = 'current',
    this.scale = 1,
    this.transparent = false,
    this.frames = SlidesImageFrames.print,
    this.includeSkipped = false,
    this.zip = false,
    this.fileName,
  });

  /// `current`, `selection`, `all` or deck positions (`"1-3,7"`).
  final String range;

  /// 1, 2 or 4 px per slide unit (1920 × 1080 su → 1920 × 1080 px at 1×),
  /// capped at [SlidesPngExport.maxWidth] px wide.
  final int scale;

  /// Omits the slide background (and its image).
  final bool transparent;
  final SlidesImageFrames frames;

  /// Skipped slides are exported too (always for `current`/`selection`).
  final bool includeSkipped;

  /// A ZIP even for one image (`pngZip`).
  final bool zip;

  /// The file name without extension (null = the deck title).
  final String? fileName;

  /// The scales offered.
  static const scales = [1, 2, 4];

  /// The options of [json] (unknown keys ignored, invalid values reset).
  static SlidesPngOptions fromJson(Map<String, Object?> json) {
    final scale = json['scale'];
    final s = scale is num ? scale.round() : 1;
    final range = json['range'];
    final name = json['fileName'];
    return SlidesPngOptions(
      range: range is String && range.trim().isNotEmpty
          ? range.trim()
          : 'current',
      scale: scales.contains(s) ? s : 1,
      transparent: json['transparent'] == true,
      frames: SlidesImageFrames.parse(json['frames']),
      includeSkipped: json['includeSkipped'] == true,
      zip: json['zip'] == true,
      fileName: name is String && name.trim().isNotEmpty
          ? SlidesPdfOptionsCodec.sanitizeFileName(name)
          : null,
    );
  }

  /// JSON (MCP results, last-used options).
  Map<String, Object?> toJson() => {
    'range': range,
    'scale': scale,
    'transparent': transparent,
    'frames': frames.id,
    'includeSkipped': includeSkipped,
    'zip': zip,
    'fileName': ?fileName,
  };

  /// What is remembered between exports (not the range, zip or name).
  Map<String, Object?> toPreferences() => {
    'scale': scale,
    'transparent': transparent,
    'frames': frames.id,
  };

  SlidesPngOptions copyWith({
    String? range,
    int? scale,
    bool? transparent,
    SlidesImageFrames? frames,
    bool? includeSkipped,
    bool? zip,
  }) => SlidesPngOptions(
    range: range ?? this.range,
    scale: scale ?? this.scale,
    transparent: transparent ?? this.transparent,
    frames: frames ?? this.frames,
    includeSkipped: includeSkipped ?? this.includeSkipped,
    zip: zip ?? this.zip,
    fileName: fileName,
  );
}

/// One rendered image.
class SlidesPngImage {
  const SlidesPngImage({
    required this.slideId,
    required this.number,
    required this.step,
    required this.bytes,
  });

  final String slideId;

  /// The slide's number (deck position when it has none).
  final int number;

  /// The build step (null = one image for the slide).
  final int? step;
  final Uint8List bytes;
}

/// The images of a PNG export, their pixel size and the warnings
/// (`empty_selection`, `range_unresolved`).
class SlidesPngResult {
  const SlidesPngResult(this.images, this.width, this.height, this.warnings);

  final List<SlidesPngImage> images;
  final int width;
  final int height;
  final List<String> warnings;
}

/// PNG export of slides (Slides 10 §13; SL-33): the stage's own software
/// renderer — the slide scene with its frame's code and chart content
/// (`MotionScenes`, SL-29) recorded as a picture (`recordScene`, like
/// thumbnails and snapshot transitions; 3D charts on the software backend)
/// and rasterized offscreen, independent of the canvas zoom. Slides and
/// steps are picked like the PDF's (`SlidesPdfPlanner`, identical build
/// frames dropped). Images wait for the deck's pictures to decode.
abstract final class SlidesPngExport {
  /// Widest image (px, 10 §13).
  static const maxWidth = 7680;

  /// The image size of a [slideWidth] × [slideHeight] su slide at
  /// [scale], capped at [maxWidth].
  static (int, int) sizeOf(double slideWidth, double slideHeight, int scale) {
    var k = scale.toDouble();
    if (slideWidth * k > maxWidth) k = maxWidth / slideWidth;
    return (
      math.max(1, (slideWidth * k).round()),
      math.max(1, (slideHeight * k).round()),
    );
  }

  /// Renders the slides of [o] from [renderer]'s deck; [slideIds] resolve
  /// the `current`/`selection` ranges.
  static Future<SlidesPngResult> render(
    SlideRenderer renderer,
    SlidesPngOptions o, {
    List<String>? slideIds,
    bool Function()? isCancelled,
  }) async {
    final deck = renderer.model;
    final shapes = SlideChartMotion.shapes(deck);
    final purpose = o.frames == SlidesImageFrames.print
        ? ScenePurpose.print
        : ScenePurpose.present;
    final timelines = <String, SlideTimeline>{};
    SlideTimeline timeline(String id) =>
        timelines[id] ??= SlideTimelineCompiler.compile(
          SlideMotionInput.fromDeck(
            deck,
            id,
            scene: renderer.scene(id, purpose: purpose),
            chartShapeOf: shapes,
          ),
        );
    final explicit = o.range == 'current' || o.range == 'selection';
    final selection = SlidesPdfPlanner.select(
      deck,
      SlidesPdfOptions(
        range: explicit ? 'all' : o.range,
        slideIds: explicit ? (slideIds ?? const []) : null,
        includeSkipped: o.includeSkipped,
        includeBuilds: o.frames == SlidesImageFrames.builds,
      ),
      stepCounts: (id) => timeline(id).stepCount,
      buildSteps: (id) => SlidesPdfExporter.printedSteps(timeline(id)),
    );
    final size = renderer.slideSize;
    final (w, h) = sizeOf(size.width, size.height, o.scale);
    final scenes = MotionScenes(renderer);
    final out = <SlidesPngImage>[];
    for (final s in selection.slides) {
      final base = renderer.scene(s.slideId, purpose: purpose);
      if (base == null) continue;
      final scene = o.transparent ? _withoutBackground(base) : base;
      for (final step in s.steps) {
        if (isCancelled?.call() ?? false) {
          throw const SlidesPdfCancelledException();
        }
        final tl = timeline(s.slideId);
        final frame = step != null
            ? tl.endOfStep(step)
            : o.frames == SlidesImageFrames.last
            ? tl.finalFrame
            : tl.printFrame;
        final shown = scenes.apply(scene, frame);
        await renderer.images.preload(shown);
        final picture = recordScene(
          shown,
          scale: w / size.width,
          images: renderer.images,
          frame: frame,
        );
        final image = await picture.toImage(w, h);
        picture.dispose();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (data == null) continue;
        out.add(
          SlidesPngImage(
            slideId: s.slideId,
            number: s.entry.number ?? s.entry.index + 1,
            step: step,
            bytes: data.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            ),
          ),
        );
      }
    }
    return SlidesPngResult(out, w, h, selection.warnings);
  }

  /// The file of [r]: one PNG, or a ZIP of every image (when [zip] or
  /// there are several), named by [baseName] and [entryName].
  static (String fileName, Uint8List bytes, String mimeType) package(
    SlidesPngResult r, {
    required String baseName,
    required String Function(SlidesPngImage image, int digits) entryName,
    bool zip = false,
  }) {
    if (r.images.length == 1 && !zip) {
      return ('$baseName.png', r.images.single.bytes, 'image/png');
    }
    final digits =
        '${r.images.fold(0, (a, i) => math.max(a, i.number))}'.length;
    final used = <String>{};
    final entries = <(String, Uint8List)>[];
    for (final i in r.images) {
      var name = entryName(i, digits);
      var n = 2;
      while (!used.add(name)) {
        name = '${entryName(i, digits)} ($n)';
        n++;
      }
      entries.add(('$name.png', i.bytes));
    }
    return ('$baseName.zip', StoredZip.encode(entries), 'application/zip');
  }

  static SlideScene _withoutBackground(SlideScene s) => SlideScene(
    slideId: s.slideId,
    width: s.width,
    height: s.height,
    background: const ResolvedBackground(ResolvedNoFill(), null),
    nodes: s.nodes,
    frames: s.frames,
    routes: s.routes,
  );
}
