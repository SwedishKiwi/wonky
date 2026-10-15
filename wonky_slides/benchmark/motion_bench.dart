// Motion benchmark (Slides 06 §14, AC 9): presents a fixture deck with
// every transition, 50 simultaneously animating elements, a 2,000-character
// build and a 60-pair Magic Move through the real present stage, and
// reports frame times (vsync intervals and engine FrameTimings) per
// segment. Build it as a web release in place of the Slides app and open
// /slides/ (no sign-in needed):
//
//   flutter build web --wasm --release --target benchmark/motion_bench.dart \
//     --base-href /slides/ --output ../wonky_server/web/slides
//
// The summary is printed to the browser console (`MOTION_BENCH {…}`) and
// shown on screen. Rebuild the app afterwards.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:wonky_slides/features/motion/player/slide_player.dart';
import 'package:wonky_slides/features/stage/scene_painter.dart';
import 'package:wonky_slides/features/transitions/magic_move_painter.dart';
import 'package:wonky_slides/features/transitions/slide_snapshots.dart';
import 'package:wonky_slides/features/transitions/transition_painter.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_slides/features/present/present_controller.dart';
import 'package:wonky_slides/features/present/present_stage.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/transitions/gpu/gpu_transitions.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart' show ScenePurpose;
import 'package:wonky_slides_core/testing.dart';

void main() {
  // `?gpu=0` measures the 2D projective path of the 3D transitions.
  if (Uri.base.queryParameters['gpu'] == '0') GpuTransitions.enabled = false;
  if (Uri.base.queryParameters['offscreen'] == '1') {
    // Without a visible page (no requestAnimationFrame): paint and
    // rasterize every frame offscreen and time it.
    WidgetsFlutterBinding.ensureInitialized();
    unawaited(Future<void>.delayed(const Duration(seconds: 2), offscreenBench));
    return;
  }
  runApp(const MotionBenchApp());
}

/// Paints every frame of the benchmark deck at 1920 × 1080 device px into
/// a picture, rasterizes it (`toImageSync`, forced by drawing it into a
/// 1 × 1 image and reading that back) and reports the wall time per frame
/// (paint + raster + one GPU round trip) per segment.
Future<void> offscreenBench() async {
  final model = benchDeck();
  final renderer = SlideRenderer(model: model);
  // Fonts load on demand: lay out every slide once and wait for them.
  for (final e in model.indexes.order.entries) {
    renderer.scene(e.id, purpose: ScenePurpose.present);
  }
  await Future<void>.delayed(const Duration(seconds: 2));
  var clock = 0;
  final c = PresentController(
    model: model,
    view: PresentView.present,
    nowMs: () => clock,
    scenesOf: (id) => renderer.scene(id, purpose: ScenePurpose.present),
  );
  final snapshots = SlideSnapshots.of(renderer);
  const w = 1920, h = 1080;
  final scale = w / renderer.slideSize.width;
  final segments = <_Segment>[];
  Future<int> frame() async {
    final sw = Stopwatch()..start();
    final view = c.playerView;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawColor(const Color(0xff000000), BlendMode.src);
    switch (view) {
      case SlidePlayerView():
        final scene = renderer.scene(
          view.slideId,
          purpose: ScenePurpose.present,
        )!;
        SlideScenePainter.paintScene(
          canvas,
          snapshots.scenes.apply(scene, view.frame),
          scale: scale,
          options: ScenePaintOptions(
            frame: view.frame,
            images: renderer.images,
          ),
        );
      case TransitionPlayerView():
        final mm = view.frame.magicMove;
        if (mm != null) {
          MagicMovePainter(
            frame: mm,
            from: renderer.scene(
              view.fromSlideId,
              purpose: ScenePurpose.present,
            )!,
            to: renderer.scene(view.slideId, purpose: ScenePurpose.present)!,
            origin: Offset.zero,
            scale: scale,
          ).paint(canvas, const Size(1920, 1080));
        } else {
          TransitionPainter(
            frame: view.frame,
            outgoing: snapshots.imageOf(
              view.fromSlideId,
              view.fromFrame,
              pxPerSu: scale,
            ),
            incoming: snapshots.imageOf(
              view.slideId,
              view.toFrame,
              pxPerSu: scale,
            ),
            slideWidth: renderer.slideSize.width,
            slideHeight: renderer.slideSize.height,
            origin: Offset.zero,
            scale: scale,
          ).paint(canvas, const Size(1920, 1080));
        }
      case CrossfadePlayerView() || null:
        break;
    }
    final pic = rec.endRecording();
    final img = pic.toImageSync(w, h);
    final rec2 = ui.PictureRecorder();
    Canvas(rec2).drawImageRect(
      img,
      const Rect.fromLTWH(960, 540, 1, 1),
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint(),
    );
    final pic2 = rec2.endRecording();
    final px = pic2.toImageSync(1, 1);
    await px.toByteData();
    pic.dispose();
    pic2.dispose();
    img.dispose();
    px.dispose();
    return sw.elapsedMicroseconds;
  }

  while (true) {
    final p = c.position;
    final seg = _Segment(
      'slide ${p == null ? '-' : c.sequence.order.indexOf(p.slideId) + 1} '
      'step ${p?.step}',
    );
    segments.add(seg);
    var n = 0;
    while (c.animating && n < 600) {
      seg.vsyncUs.add(await frame());
      clock += 16;
      n++;
    }
    clock += 500;
    if (c.endScreen) break;
    c.next(user: false);
    if (c.endScreen) break;
  }
  final all = _Segment('all');
  for (final s in segments) {
    all.vsyncUs.addAll(s.vsyncUs);
  }
  // ignore: avoid_print
  print(
    'MOTION_BENCH_OFFSCREEN ${jsonEncode({
      'size': '${w}x$h',
      'segments': [
        for (final s in segments)
          if (s.vsyncUs.isNotEmpty) {'segment': s.label, 'frameMs': _Segment.stats(s.vsyncUs)},
      ],
      'all': _Segment.stats(all.vsyncUs),
    })}',
  );
}

/// The fixture deck of the benchmark.
DeckModel benchDeck() {
  final b = DeckBuilder(title: 'Motion benchmark');
  final slides = <String>[];
  final transitions = <String, Map<String, Object?>>{};

  // 1. 50 elements building in together, every visual effect.
  const effects = [
    ('rise', '{}'),
    ('moveIn', '{"direction":"left"}'),
    ('scale', '{}'),
    ('pop', '{}'),
    ('zoom', '{}'),
    ('blur', '{}'),
    ('wipe', '{"direction":"left","softness":0.2}'),
    ('iris', '{}'),
    ('dissolve', '{}'),
    ('flip', '{}'),
    ('rotate', '{}'),
    ('fade', '{}'),
    ('drop', '{}'),
  ];
  final s1 = b.slide(layoutKey: 'blank');
  slides.add(s1);
  for (var i = 0; i < 50; i++) {
    final col = i % 10, row = i ~/ 10;
    final e = b.shape(
      s1,
      x: 40 + col * 186.0,
      y: 40 + row * 206.0,
      width: 160,
      height: 160,
      geometry: i.isEven ? 'rect' : 'ellipse',
      text: 'E$i',
    );
    final (effect, params) = effects[i % effects.length];
    b.build_(
      s1,
      e,
      effect: effect,
      trigger: i == 0
          ? SlideBuildTrigger.onClick
          : SlideBuildTrigger.withPrevious,
      delayMs: i == 0 ? 0 : 20, // withPrevious: after the previous start
      durationMs: 1200,
      easing: 'easeOutCubic',
      optionsJson: '{"v":1,"params":$params}',
    );
  }

  // 2. 2,000 characters building in by character.
  final words = <String>[];
  final rnd = math.Random(7);
  const lorem = [
    'motion',
    'slides',
    'present',
    'build',
    'frame',
    'magic',
    'move',
    'stage',
    'budget',
    'glyph',
    'text',
    'wonky',
    'work',
    'smooth',
  ];
  while (words.join(' ').length < 2000) {
    words.add(lorem[rnd.nextInt(lorem.length)]);
  }
  final text = words.join(' ').substring(0, 2000);
  final s2 = b.slide(layoutKey: 'blank');
  slides.add(s2);
  final t2 = b.textBox(s2, text, x: 60, y: 60, width: 1800, height: 960);
  b.build_(
    s2,
    t2,
    effect: 'rise',
    durationMs: 500,
    optionsJson: jsonEncode({
      'v': 1,
      'delivery': {
        'by': 'character',
        'partTrigger': 'withPrevious',
        'staggerMs': 2,
      },
    }),
  );

  // 3. A 600-character typewriter (200 characters/s, the maximum).
  final s3 = b.slide(layoutKey: 'blank');
  slides.add(s3);
  final t3 = b.textBox(
    s3,
    text.substring(0, 600),
    x: 60,
    y: 60,
    width: 1800,
    height: 960,
  );
  b.build_(
    s3,
    t3,
    effect: 'typewriter',
    optionsJson: '{"v":1,"params":{"cps":200}}',
  );

  // 4. Every transition between busy slides.
  const types = [
    ('fade', <String, Object?>{}),
    ('push', {'direction': 'left'}),
    ('slide', {'direction': 'up'}),
    ('cover', {'direction': 'left'}),
    ('uncover', {'direction': 'right'}),
    ('wipe', {'direction': 'left', 'softness': 0.15}),
    ('iris', {'shape': 'circle'}),
    ('zoom', {'mode': 'in'}),
    ('dissolve', <String, Object?>{}),
    ('flip', {'axis': 'y'}),
    ('cube', {'direction': 'left'}),
    ('doorway', <String, Object?>{}),
    ('swap', {'direction': 'left'}),
    ('revolve', {'direction': 'left'}),
  ];
  for (final (i, (type, params)) in types.indexed) {
    final s = b.slide(layoutKey: 'titleBody', title: 'Transition: $type');
    slides.add(s);
    for (var k = 0; k < 12; k++) {
      b.shape(
        s,
        x: 100 + (k % 6) * 290.0,
        y: 400 + (k ~/ 6) * 300.0,
        width: 240,
        height: 240,
        geometry: (i + k).isEven ? 'rect' : 'ellipse',
        text: '$type $k',
      );
    }
    transitions[s] = {
      'v': 1,
      'type': type,
      'durationMs': 1000,
      'easing': 'easeInOutCubic',
      'params': params,
    };
  }

  // 5. Magic Move with 60 pairs (and a title matched by character).
  final mA = b.slide(layoutKey: 'blank');
  final mB = b.slide(layoutKey: 'blank');
  slides
    ..add(mA)
    ..add(mB);
  final keys = <String, String>{};
  final pairs = <(String, String)>[];
  for (var k = 0; k < 60; k++) {
    final a = b.shape(
      mA,
      x: 40 + (k % 10) * 186.0,
      y: 300 + (k ~/ 10) * 120.0,
      width: 100,
      height: 100,
      geometry: 'rect',
    );
    final bb = b.shape(
      mB,
      x: 1800 - (k % 10) * 180.0,
      y: 980 - (k ~/ 10) * 130.0,
      width: 60 + (k % 5) * 20.0,
      height: 60 + (k % 5) * 20.0,
      geometry: 'ellipse',
      fillJson: jsonEncode({
        'type': 'solid',
        'color':
            '#${(0x204080 + k * 0x030507).toRadixString(16).padLeft(6, '0')}',
      }),
    );
    pairs.add((a, bb));
  }
  final ta = b.textBox(
    mA,
    'Magic Move keeps every glyph moving',
    x: 100,
    y: 80,
  );
  final tb = b.textBox(
    mB,
    'Every glyph moving with Magic Move',
    x: 400,
    y: 160,
  );
  pairs.add((ta, tb));
  transitions[mB] = {
    'v': 1,
    'type': 'magicMove',
    'durationMs': 1500,
    'easing': 'easeInOutCubic',
    'magicMove': {'textMatching': 'character'},
  };

  var rows = b.rows;
  for (final (a, bb) in pairs) {
    keys[bb] =
        rows.firstWhere((r) => r.$2['id'] == a).$2['matchKey']! as String;
  }
  rows = [
    for (final r in rows)
      if (transitions.containsKey(r.$2['id']))
        (r.$1, {...r.$2, 'transitionJson': jsonEncode(transitions[r.$2['id']])})
      else if (keys.containsKey(r.$2['id']))
        (r.$1, {...r.$2, 'matchKey': keys[r.$2['id']]})
      else
        r,
  ];
  return DeckModel.fromRows(b.deckId, rows);
}

class MotionBenchApp extends StatelessWidget {
  const MotionBenchApp({super.key});

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xff000000),
    debugShowCheckedModeBanner: false,
    builder: (context, _) => const MotionBench(),
  );
}

class MotionBench extends StatefulWidget {
  const MotionBench({super.key});

  @override
  State<MotionBench> createState() => _MotionBenchState();
}

class _Segment {
  _Segment(this.label);

  final String label;
  final List<int> vsyncUs = [];
  final List<int> buildUs = [];
  final List<int> rasterUs = [];

  static Map<String, num> stats(List<int> us) {
    if (us.isEmpty) return const {};
    final s = [...us]..sort();
    num p(double q) => s[math.min(s.length - 1, (q * s.length).floor())] / 1000;
    return {'n': s.length, 'p50': p(0.5), 'p95': p(0.95), 'max': s.last / 1000};
  }

  Map<String, Object?> toJson() => {
    'segment': label,
    'vsyncMs': stats(vsyncUs),
    'buildMs': stats(buildUs),
    'rasterMs': stats(rasterUs),
  };
}

class _MotionBenchState extends State<MotionBench>
    with SingleTickerProviderStateMixin {
  late final DeckModel model = benchDeck();
  late final SlideRenderer renderer = SlideRenderer(model: model);
  // `?freeze=<slide number>&at=<ms>`: stops at [at] ms into the transition
  // into that slide (visual checks of single frames).
  final int? _freeze = int.tryParse(Uri.base.queryParameters['freeze'] ?? '');
  int _manual = 0;
  late final PresentController c = PresentController(
    model: model,
    view: PresentView.present,
    nowMs: _freeze == null ? null : () => _manual,
    scenesOf: (id) => renderer.scene(id, purpose: ScenePurpose.present),
  );
  int _pass = 1;
  late final Ticker _ticker = createTicker(_tick);
  final List<_Segment> _segments = [];
  _Segment? _current;
  Duration? _last;
  int _idleSince = 0;
  bool _done = false;
  String _summary = '';
  final Stopwatch _clock = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_timings);
    // Let fonts and the first scene settle before measuring.
    Timer(const Duration(seconds: 3), () {
      final freeze = _freeze;
      if (freeze != null) {
        final order = c.sequence.order.entries;
        final before = order[freeze - 2].id;
        c.goTo(before, c.timelineOf(before).stepCount);
        _manual += 10000;
        // Let the stage prepare snapshots and GPU textures first.
        Timer(const Duration(seconds: 2), () {
          _manual += 10000;
          c.next(user: false);
          _manual += int.tryParse(Uri.base.queryParameters['at'] ?? '') ?? 500;
          setState(() {});
        });
        return;
      }
      _begin();
      _ticker.start();
    });
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    _ticker.dispose();
    c.dispose();
    renderer.dispose();
    super.dispose();
  }

  void _timings(List<FrameTiming> timings) {
    final seg = _current;
    if (seg == null || !c.animating) return;
    for (final t in timings) {
      seg.buildUs.add(t.buildDuration.inMicroseconds);
      seg.rasterUs.add(t.rasterDuration.inMicroseconds);
    }
  }

  String _label() {
    final p = c.position;
    if (p == null) return 'end';
    final i = c.sequence.order.indexOf(p.slideId) + 1;
    final type = model.slide(p.slideId)?.transitionJson;
    final t = type == null ? '' : ' ${jsonDecode(type)['type']}';
    return 'p$_pass slide $i step ${p.step}$t';
  }

  void _begin() {
    _current = _Segment(_label());
    _segments.add(_current!);
    _last = null;
  }

  void _tick(Duration elapsed) {
    if (_done) return;
    final animating = c.animating;
    if (animating) {
      final last = _last;
      if (last != null) {
        _current?.vsyncUs.add((elapsed - last).inMicroseconds);
      }
      _last = elapsed;
      _idleSince = _clock.elapsedMilliseconds;
      return;
    }
    _last = null;
    if (_clock.elapsedMilliseconds - _idleSince < 400) return;
    if (c.endScreen || c.position == null) {
      if (_pass == 1) {
        // A second, warm pass (fonts, snapshots, GPU pipelines ready).
        _pass = 2;
        c.goTo(c.sequence.order.entries.first.id);
        _begin();
        _idleSince = _clock.elapsedMilliseconds;
        return;
      }
      _finish();
      return;
    }
    c.next(user: false);
    _begin();
    _idleSince = _clock.elapsedMilliseconds;
  }

  void _finish() {
    _done = true;
    _ticker.stop();
    final all = _Segment('all');
    for (final s in _segments) {
      all.vsyncUs.addAll(s.vsyncUs);
      all.buildUs.addAll(s.buildUs);
      all.rasterUs.addAll(s.rasterUs);
    }
    final view = View.of(context);
    final json = {
      'gpu': GpuTransitions.instance.available.value,
      'physicalSize':
          '${view.physicalSize.width.round()}×${view.physicalSize.height.round()}',
      'dpr': view.devicePixelRatio,
      'segments': [
        for (final s in _segments)
          if (s.vsyncUs.isNotEmpty) s.toJson(),
      ],
      'all': all.toJson(),
    };
    final out = jsonEncode(json);
    // ignore: avoid_print
    print('MOTION_BENCH $out');
    setState(() => _summary = const JsonEncoder.withIndent(' ').convert(json));
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return ColoredBox(
        color: const Color(0xff101010),
        child: SingleChildScrollView(
          child: Text(
            _summary,
            style: const TextStyle(color: Color(0xffe5e7eb), fontSize: 11),
          ),
        ),
      );
    }
    return PresentStage(controller: c, renderer: renderer, interactive: false);
  }
}
