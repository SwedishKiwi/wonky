import '../../model/api/kinds.dart';
import '../../motion/builds/build_options.dart';
import '../../motion/builds/transition_spec.dart';
import '../../ops/operations.dart';
import '../../theme/model/common.dart';
import '../slides_template.dart';
import '../template_builder.dart';
import '../template_text.dart';
import 'parts.dart';

const _projects = [
  ('Harbor', 'Booking for marinas', 'theme:accent1'),
  ('Fieldnotes', 'Research that writes itself', 'theme:accent2'),
  ('Tandem', 'Shared budgets for couples', 'theme:accent3'),
];

/// A project cover: a colored card with the project's name and line
/// (stand-ins for screenshots; the Magic Move key follows the project).
List<ElementSpec> _cover(int i, SuRect r, {double nameSize = 56}) {
  final (name, line, color) = _projects[i];
  return [
    TemplateShapes.shape(
      'roundRect',
      r,
      fill: color,
      adjust: const {'radius': 0.04},
      text: [
        TemplatePara.runs([TemplateRun.bold(name)]),
        TemplatePara(line),
      ],
      textColor: 'theme:bg1',
      textStyle: 'heading',
      textSize: nameSize,
      align: 'left',
      anchor: 'bottom',
      insets: const [40, 48, 48, 48],
      name: name,
      matchKey: 'portfolio.project-$i',
    ),
  ];
}

/// *Portfolio* on *Paper* (editorial serif, light): a designer's
/// portfolio — selected work as covers that open into project pages with
/// Magic Move, an outcome figure, how they work, a testimonial and a
/// timeline of their experience.
final SlidesTemplate portfolioTemplate = SlidesTemplate(
  key: 'slides.portfolio',
  name: 'Portfolio',
  description: 'Show your best work, one project at a time.',
  category: 'personal',
  themeKey: 'paper',
  subtitle: 'Product designer · Selected work',
  defaultTransition: const TransitionSpec(type: 'fade', durationMs: 600),
  script: (b) {
    b.slide(
      'title',
      text: {
        'title': 'Maya Chen',
        'subtitle': 'Product designer · Selected work 2022–2026',
      },
      notes:
          'Replace the colored covers with screenshots of your own work: '
          'insert an image, then set the same Magic Move ID on it '
          '(Arrange › Magic Move ID) so it still opens into its page.',
    );
    b.slide(
      'statement',
      text: {'body': 'I design calm tools for busy people.'},
    );
    final work = b.slide(
      'titleOnly',
      text: {'title': 'Selected work'},
      elements: [
        for (final (i, (x, w)) in columns(3).indexed)
          ..._cover(i, SuRect(x, 320, w, 600), nameSize: 52),
      ],
    );
    b.builds(work, [
      for (final id in b.lastElements)
        buildIn(id, 'rise', trigger: SlideBuildTrigger.afterPrevious),
    ]);

    b.group('Harbor', color: 'teal');
    final harbor = b.slide(
      'titleOnly',
      text: {'title': 'Harbor'},
      elements: [
        ..._cover(0, const SuRect(120, 288, 840, 672), nameSize: 72),
        TemplateShapes.text(
          const SuRect(1032, 288, 768, 672),
          [
            TemplatePara.runs([TemplateRun.bold('Role')]),
            TemplatePara('Lead designer, 2024–2025', {'spaceAfter': 24}),
            TemplatePara.runs([TemplateRun.bold('Challenge')]),
            TemplatePara(
              'Boat owners booked berths by phone, and harbor masters '
              'kept the plan on paper.',
              {'spaceAfter': 24},
            ),
            TemplatePara.runs([TemplateRun.bold('Outcome')]),
            TemplatePara('Online booking for 140 marinas in one season.'),
          ],
          size: 36,
          color: 'theme:text1',
        ),
      ],
      notes: 'Magic Move opens the cover into the project page.',
    );
    b.transition([harbor], TransitionSpec.of('magicMove'));
    b.slide(
      'bigNumber',
      text: {
        'bigNumber': '−38 %',
        'caption': 'time to book a berth after the Harbor redesign',
      },
    );
    b.slide(
      'twoColumns',
      text: {
        'title': 'How I worked',
        'body': TemplateText.bullets([
          'Two weeks in three marinas',
          'Paper prototypes on the dock',
          'Weekly tests with harbor masters',
        ]),
        'bodyRight': TemplateText.bullets([
          'A design system for the web and tablets',
          'Booking flow in four steps',
          'Shipped in three releases',
        ]),
      },
    );

    b.group('Fieldnotes', color: 'amber');
    final fieldnotes = b.slide(
      'titleBody',
      text: {
        'title': 'Fieldnotes',
        'body': TemplateText.bullets([
          'Interview notes tagged while you type',
          'Themes found across a whole study',
          'Quotes ready for the readout deck',
        ]),
      },
    );
    b.builds(fieldnotes, [
      buildIn(
        b.placeholder(fieldnotes, 'body'),
        'fade',
        delivery: const BuildDelivery(by: DeliveryBy.paragraph),
      ),
    ]);
    b.slide(
      'quote',
      text: {
        'quote':
            'Maya turns messy problems into clear, friendly tools — and '
            'brings the whole team along.',
        'attribution': 'Jordan Park, Head of Product at Harbor',
      },
    );
    b.endGroup();

    b.slide(
      'titleOnly',
      text: {'title': 'Experience'},
      elements: timeline([
        ('2018', 'Studio Nord, junior designer'),
        ('2021', 'Fieldnotes, product designer'),
        ('2024', 'Harbor, lead designer'),
        ('Now', 'Independent'),
      ]),
    );
    final end = b.slide(
      'title',
      text: {
        'title': 'Let\'s work together',
        'subtitle': 'maya@example.com · maya.example',
      },
    );
    b.transition([end], TransitionSpec.of('revolve'));
  },
);
