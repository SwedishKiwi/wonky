import 'dart:convert';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wonky_slides_core/copy.dart';
import 'package:wonky_slides_core/maintenance.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart' show SlidesPlanContext;
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/templates.dart';
import 'package:wonky_slides_core/themes.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;
import 'package:wonky_sync_models/ids.dart';

const _deckId = '0192f0a0-0000-7000-8000-00000000d001';
const _copyId = '0192f0a0-0000-7000-8000-00000000d002';
const _userId = '0192f0a0-0000-7000-8000-0000000000a1';
final _now = DateTime.utc(2026, 3, 2, 9);

SlidesTemplateDeck _build(SlidesTemplate t, {int seed = 1}) => t.build(
  deckId: _deckId,
  userId: _userId,
  now: _now,
  ids: SequentialIdGenerator(seed),
);

/// Every element of the slides (any depth), not the theme's.
Iterable<SlideElementRec> _slideElements(DeckModel m) => [
  for (final s in m.slides) ...m.allElementsOf(s.id),
];

/// Plain text of the slides, in order (placeholders, shapes, cells).
List<String> _texts(DeckModel m) => [
  for (final s in m.slides) ...[
    for (final e in m.allElementsOf(s.id))
      if (e.text != null) SlidesText.plainText(e.text).trim(),
    for (final e in m.allElementsOf(s.id))
      for (final c in m.cellsOf(e.id))
        if (c.text != null) SlidesText.plainText(c.text).trim(),
  ],
];

String _json(Object? o) => jsonEncode(
  o,
  toEncodable: (v) => v is DateTime ? v.toIso8601String() : v.toString(),
);

/// Text that overflows, shrinks below 75 % or lacks contrast with the
/// fills painted behind it (opaque or translucent, in painting order; the
/// slide background [base] at the bottom). Text needs 4.5:1; large text
/// (48 su, or 36 su bold — stricter than WCAG's 24/18.7 px at 1 su = 1 px)
/// and list markers (graphics, WCAG 1.4.11) 3:1.
List<String> _textChecks(SlideScene scene, int base, String label) {
  final fills = <(SuRect, int)>[];
  final out = <String>[];

  SuRect bounds(ScenePath p, Matrix4 m) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final c in p.commands) {
      final v = c.toJson((d) => d);
      for (var i = 1; i + 1 < v.length; i += 2) {
        final t = m.transformed3(
          Vector3((v[i] as num).toDouble(), (v[i + 1] as num).toDouble(), 0),
        );
        minX = math.min(minX, t.x);
        maxX = math.max(maxX, t.x);
        minY = math.min(minY, t.y);
        maxY = math.max(maxY, t.y);
      }
    }
    return SuRect(minX, minY, maxX - minX, maxY - minY);
  }

  int behind(double x, double y) {
    var c = base;
    for (final (r, color) in fills) {
      if (x >= r.x && x <= r.right && y >= r.y && y <= r.bottom) {
        c = compositeOver(color, c);
      }
    }
    return c;
  }

  void visit(SceneNode n, Matrix4 m, double opacity) {
    switch (n) {
      case GroupNode():
        final mm = m.multiplied(n.transform);
        for (final c in n.children) {
          visit(c, mm, opacity * n.opacity);
        }
      case PathNode(:final fill?):
        final color = fill.representativeColor;
        if (color != null && opacity > 0) {
          final a = ((color >> 24) & 0xff) * opacity;
          fills.add((
            bounds(n.path, m),
            (a.round() << 24) | (color & 0xffffff),
          ));
        }
      case TextNode():
        final l = n.layout;
        final what = '$label ${n.elementId}';
        if (l.overflows) out.add('$what overflows');
        if (l.fitScale < 0.75) {
          out.add('$what shrinks to ${l.fitScale.toStringAsFixed(2)}');
        }
        for (final line in l.lines) {
          for (final (run, marker) in [
            for (final r in line.runs) (r, false),
            if (line.bullet case final b?) (b, true),
          ]) {
            if (run.text.trim().isEmpty) continue;
            final p = m.transformed3(
              Vector3(
                n.originX + line.left + run.x + run.width / 2,
                n.originY + line.top + line.height / 2,
                0,
              ),
            );
            final bg = behind(p.x, p.y);
            final ratio = contrastRatio(compositeOver(run.color, bg), bg);
            final large =
                run.fontSize >= 48 ||
                (run.fontWeight >= 700 && run.fontSize >= 36);
            final need = marker || large ? 3.0 : 4.5;
            if (ratio < need) {
              out.add(
                '$what "${run.text.trim()}" '
                '${ratio.toStringAsFixed(2)} < $need',
              );
            }
          }
        }
      default:
        break;
    }
  }

  for (final n in scene.nodes) {
    visit(n, Matrix4.identity(), 1);
  }
  return out;
}

void main() {
  test('Given the registry then it holds the five M9 templates with unique '
      'keys, uuids, categories and themes', () {
    final keys = [for (final t in SlidesTemplates.all) t.key];
    expect(keys, [
      'slides.pitch-deck',
      'slides.project-kickoff',
      'slides.weekly-update',
      'slides.lesson',
      'slides.workshop',
    ]);
    expect({for (final t in SlidesTemplates.all) t.uuid}, hasLength(5));
    for (final t in SlidesTemplates.all) {
      expect(BuiltInThemes.byKey(t.themeKey), isNotNull, reason: t.key);
      expect({
        'personal',
        'work',
        'education',
        'projectManagement',
        'finance',
      }, contains(t.category));
      expect(SlidesTemplates.byUuid(t.uuid.toUpperCase()), same(t));
      expect(SlidesTemplates.byKey(t.key), same(t));
    }
    // Five different themes: five different looks in the gallery.
    expect({for (final t in SlidesTemplates.all) t.themeKey}, hasLength(5));
  });

  test('Given a key when deriving the gallery uuid then it is UUIDv5 of '
      '"wonky-template:<key>" in the URL namespace', () {
    // python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_URL,
    //   'wonky-template:slides.pitch-deck'))"
    expect(
      SlidesTemplates.uuidOf('slides.pitch-deck'),
      '6aabc24c-4123-5ca2-9eb3-902a1342c7c7',
    );
    expect(
      SlidesTemplates.uuidOf('write.meeting-notes'),
      'da939d2c-8cd5-5b68-80b9-a8a4935a360d',
    );
  });

  test('Given the templates then at least two use slide groups and every '
      'group holds slides', () {
    var withGroups = 0;
    for (final t in SlidesTemplates.all) {
      final m = _build(t).model;
      if (m.groups.isNotEmpty) withGroups++;
      for (final g in m.groups) {
        expect(m.slidesInGroup(g.id), isNotEmpty, reason: '${t.key} $g');
        expect(g.title, isNotEmpty);
      }
    }
    expect(withGroups, greaterThanOrEqualTo(2));
  });

  test('Given a deck with low-contrast and overflowing text when checking '
      'it like the templates then both are reported (negative control)', () {
    final b = TemplateDeckBuilder(
      deckId: _deckId,
      title: 'Bad',
      themeKey: 'wonky',
      ctx: SlidesPlanContext(
        userId: _userId,
        now: _now,
        ids: SequentialIdGenerator(1),
      ),
    );
    final id = b.slide(
      'blank',
      elements: [
        TemplateShapes.shape(
          'rect',
          const SuRect(120, 120, 600, 200),
          fill: 'theme:bg2',
          text: 'Pale on pale',
          textColor: 'theme:bg1',
          textSize: 32,
        ),
        TemplateShapes.text(
          const SuRect(120, 600, 300, 40),
          'Far too much text for a tiny box that cannot hold it at all, '
          'not even when it shrinks as far as auto-fit allows it to go',
          size: 40,
        ),
      ],
    );
    final slide = SlideResolver(b.model).resolve(id)!;
    final scene = SlideSceneBuilder().build(
      slide,
      SceneContext(
        theme: slide.theme,
        textLayout: SlideTextLayout(),
        deck: b.model,
        purpose: ScenePurpose.present,
      ),
    );

    final failures = _textChecks(
      scene,
      slide.background.effectiveColor(slide.theme.colorOf('bg1')!),
      'bad',
    );

    expect(failures, contains(contains('"Pale')));
    expect(
      failures,
      contains(anyOf(contains('overflows'), contains('shrinks'))),
    );
  });

  for (final t in SlidesTemplates.all) {
    group('Given template ${t.key}', () {
      late SlidesTemplateDeck built;
      setUpAll(() => built = _build(t));

      test('when built then the planner reports no warning and the deck '
          'passes maintenance', () {
        expect(built.warnings, isEmpty);
        expect(DeckMaintenance.detect(built.model), isEmpty);
        expect(DeckMaintenance.repairOp(built.model), isNull);
      });

      test('when built then it has a title slide, 8+ slides, its theme and '
          'real content layouts', () {
        final m = built.model;
        expect(m.deck!.title, t.name);
        expect(m.deck!.createdBy, _userId);
        expect(m.themes.single.sourceKey, startsWith('builtin:${t.themeKey}@'));
        expect(m.slides.length, greaterThanOrEqualTo(8));
        final layouts = [for (final s in m.slides) m.layout(s.layoutId!)!.key];
        expect(layouts.first, 'title');
        expect(layouts, contains('titleBody'));
        expect(layouts, anyOf(contains('twoColumns'), contains('comparison')));
        expect(layouts, contains('bigNumber'));
      });

      test('when built then no placeholder is left empty (no prompts) and '
          'every shape geometry exists', () {
        final m = built.model;
        for (final e in _slideElements(m)) {
          if (e.placeholderType != null) {
            if (e.kind == ElementKind.code) {
              expect(m.codeStatesOf(e.id), hasLength(1));
              expect(m.codeStatesOf(e.id).single.code, isNotEmpty);
            } else {
              expect(
                SlidesText.plainText(e.text).trim(),
                isNotEmpty,
                reason: '${e.placeholderType} on ${e.slideId}',
              );
            }
          }
          if (e.kind == ElementKind.shape) {
            final data = jsonDecode(e.dataJson!) as Map<String, Object?>;
            expect(
              ShapeLibrary.of(data['geometry'] as String?),
              isNotNull,
              reason: '${data['geometry']}',
            );
          }
        }
      });

      test('when built twice with the same ids and time then the rows are '
          'identical, and the inserts rebuild the same model', () {
        final again = _build(t);
        expect(
          _json([for (final c in again.inserts) c.columnsAfter]),
          _json([for (final c in built.inserts) c.columnsAfter]),
        );
        final rebuilt = DeckModel.fromRows(_deckId, [
          for (final c in built.inserts) (c.table, c.columnsAfter),
        ]);
        expect(_json(rebuilt.dump()), _json(built.model.dump()));
        // Dependency order: the deck row first, then its theme.
        expect(built.inserts.first.table, SlidesTables.deck);
        expect(built.inserts[1].table, SlidesTables.deckTheme);
      });

      test('when copied with the deck copier then the copy has new ids, the '
          'same content and passes maintenance', () {
        final copy = DeckCopier.copy(
          built.model,
          deckId: _copyId,
          userId: _userId,
          now: _now,
          title: 'My copy',
          ids: SequentialIdGenerator(9000),
        );
        expect(copy.dropped, isEmpty);
        final m = DeckModel.fromRows(_copyId, copy.rows);
        expect(m.deck!.title, 'My copy');
        expect(m.slides, hasLength(built.model.slides.length));
        expect(m.groups, hasLength(built.model.groups.length));
        expect(_texts(m), _texts(built.model));
        expect(DeckMaintenance.detect(m), isEmpty);
        final sourceIds = {
          for (final tb in SlidesTables.dependencyOrder)
            for (final r in built.model.records(tb)) r.id,
        };
        for (final tb in SlidesTables.dependencyOrder) {
          for (final r in m.records(tb)) {
            expect(sourceIds, isNot(contains(r.id)));
          }
        }
      });

      for (final appearance in SlideAppearance.values) {
        test('when rendered ${appearance.name} then all text fits its box '
            'and has enough contrast with what is painted behind it', () {
          final m = built.model;
          final resolver = SlideResolver(m);
          final engine = SlideTextLayout();
          final builder = SlideSceneBuilder();
          final failures = <String>[];
          for (final s in m.slides) {
            final slide = resolver.resolve(s.id, appearance: appearance)!;
            final scene = builder.build(
              slide,
              SceneContext(
                theme: slide.theme,
                textLayout: engine,
                deck: m,
                purpose: ScenePurpose.present,
              ),
            );
            final label =
                'slide ${m.slides.indexOf(s) + 1} '
                '(${m.layout(s.layoutId!)!.key})';
            failures.addAll(
              _textChecks(
                scene,
                slide.background.effectiveColor(slide.theme.colorOf('bg1')!),
                label,
              ),
            );
          }
          expect(failures, isEmpty);
        });
      }
    });
  }
}
