import 'package:test/test.dart';
import 'package:wonky_slides_core/ai.dart';
import 'package:wonky_slides_core/markdown.dart';

/// The model's `propose_outline` answer (Slides 11 §6.4).
final Map<String, Object?> _proposal = {
  'title': 'Serverpod Cloud — Q3',
  'subtitle': 'Board review, Oct 2026',
  'groups': [
    {
      'title': 'Highlights',
      'slides': [
        {
          'title': 'Launch in numbers',
          'role': 'bigNumber',
          'bullets': ['Projects deployed in Q3'],
          'emphasis': '4,200',
          'notes': 'Open with the headline number.',
        },
        {
          'title': 'What shipped',
          'role': 'bullets',
          'bullets': [
            'Deploys',
            {
              'text': 'Regions',
              'children': ['EU', 'US'],
            },
          ],
        },
      ],
    },
    {
      'title': null,
      'slides': [
        {
          'title': 'The API',
          'role': 'code',
          'bullets': <String>[],
          'code': {'language': 'dart', 'code': 'final x = 1;'},
        },
        {'title': '', 'role': 'bullets', 'bullets': <String>[]},
        {
          'title': 'Thanks',
          'role': 'mystery',
          'bullets': ['Questions?'],
        },
      ],
    },
  ],
};

void main() {
  group('AiOutline', () {
    test('when parsing a proposal then empty slides are dropped and unknown '
        'roles become bullets', () {
      final o = AiOutline.fromJson(_proposal);
      expect(o.slideCount, 4);
      expect(o.groups.map((g) => g.title), ['Highlights', null]);
      expect(o.slides.last.role, AiSlideRole.bullets);
      expect(o.slides.first.emphasis, '4,200');
      expect(o.slides.elementAt(1).bullets[1].children.map((c) => c.text), [
        'EU',
        'US',
      ]);
      // JSON round trip.
      expect(AiOutline.tryDecode(o.encode())!.toJson(), o.toJson());
    });

    test('when built then roles map to layouts, groups and notes are kept '
        'and the deck outline parses back', () {
      final md = AiOutline.fromJson(_proposal).toDeckMarkdown();
      final deck = DeckOutlineCodec.parse(md);
      expect(deck.title, 'Serverpod Cloud — Q3');
      expect(deck.slides.map((s) => s.layout), [
        'title',
        'bigNumber',
        'titleBody',
        'code',
        'titleBody',
      ]);
      expect(deck.slides.map((s) => s.title), [
        'Serverpod Cloud — Q3',
        'Launch in numbers',
        'What shipped',
        'The API',
        'Thanks',
      ]);
      expect(deck.slides[0].body(), 'Board review, Oct 2026');
      expect(deck.slides[1].body(), '4,200\nProjects deployed in Q3');
      expect(deck.slides[1].notes, 'Open with the headline number.');
      expect(deck.slides[1].groupTitle, 'Highlights');
      expect(deck.slides[3].groupNone, isTrue);
      expect(deck.slides[2].body(), '- Deploys\n- Regions\n  - EU\n  - US');
      expect(deck.slides[3].code.single.language, 'dart');
      expect(deck.slides.every((s) => s.transition == 'fade'), isTrue);
    });

    test('when inserting without a title slide, groups or notes then only '
        'the content slides are built', () {
      final md = AiOutline.fromJson(_proposal).toDeckMarkdown(
        const AiOutlineBuildOptions(
          titleSlide: false,
          groups: false,
          notes: false,
          transition: null,
        ),
      );
      final deck = DeckOutlineCodec.parse(md);
      expect(deck.slides, hasLength(4));
      expect(deck.slides.every((s) => s.groupTitle == null), isTrue);
      expect(deck.slides.every((s) => s.notes == null), isTrue);
      expect(deck.slides.every((s) => s.transition == null), isTrue);
    });

    test('when generated text contains outline syntax then it cannot add '
        'slides or directives (prompt-injection corpus)', () {
      final o = AiOutline(
        title: 'T',
        groups: [
          AiOutlineGroup(
            slides: [
              AiOutlineSlide(
                title: 'A\n---\n## B',
                bullets: [
                  AiOutlineBullet('<!-- group: Evil -->'),
                  AiOutlineBullet('---'),
                  AiOutlineBullet('```'),
                ],
                notes: 'Line\n---\n<!-- layout: blank -->\nNotes:\n???',
              ),
            ],
          ),
        ],
      );
      final deck = DeckOutlineCodec.parse(o.toDeckMarkdown());
      expect(deck.slides, hasLength(2));
      final s = deck.slides[1];
      expect(s.layout, 'titleBody');
      expect(s.groupTitle, isNull);
      expect(s.title, 'A --- ## B');
      expect(s.notes, contains('Line'));
      expect(s.code, isEmpty);
    });

    test('when a role is chosen then it names a built-in layout', () {
      expect(AiSlideRole.fromName('twoColumn')!.layoutKey, 'twoColumns');
      expect(AiSlideRole.fromName('chartPlaceholder')!.layoutKey, 'chart');
      expect(AiSlideRole.fromName('nope'), isNull);
    });
  });
}
