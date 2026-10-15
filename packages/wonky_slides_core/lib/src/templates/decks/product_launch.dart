import '../../model/api/kinds.dart';
import '../../motion/builds/transition_spec.dart';
import '../../ops/operations.dart';
import '../../theme/model/common.dart';
import '../slides_template.dart';
import '../template_builder.dart';
import '../template_text.dart';
import 'parts.dart';

/// The product device of the Magic Move pair: a rounded body with a screen
/// showing the week, at [x], [y] scaled by [s] (1 = 400 × 640 su).
List<ElementSpec> _device(double x, double y, double s) => [
  TemplateShapes.shape(
    'roundRect',
    SuRect(x, y, 400 * s, 640 * s),
    fill: 'theme:accent1',
    adjust: const {'radius': 0.12},
    decorative: true,
    name: 'Device',
    matchKey: 'product-launch.device',
  ),
  TemplateShapes.shape(
    'roundRect',
    SuRect(x + 32 * s, y + 48 * s, 336 * s, 544 * s),
    fill: 'theme:bg1',
    adjust: const {'radius': 0.08},
    text: [
      TemplatePara.runs([TemplateRun.bold('This week')]),
      TemplatePara('Mon · Focus time'),
      TemplatePara('Tue · Team sync'),
      TemplatePara('Wed · Deep work'),
      TemplatePara('Thu · 1:1s'),
      TemplatePara('Fri · Free'),
    ],
    textColor: 'theme:text1',
    textSize: 30 * s,
    align: 'left',
    anchor: 'top',
    insets: [40 * s, 32 * s, 32 * s, 32 * s],
    name: 'Screen',
    matchKey: 'product-launch.screen',
  ),
];

/// *Product launch* on *Studio* (bold, light): a launch keynote — a title
/// that builds in, a statement, the product revealed with a Magic Move,
/// feature cards that pop in, pricing, a launch timeline drawn on, and a
/// doorway (3D) into the closing slide.
final SlidesTemplate productLaunchTemplate = SlidesTemplate(
  key: 'slides.product-launch',
  name: 'Product launch',
  description: 'Reveal a product with builds, Magic Move and 3D transitions.',
  category: 'work',
  themeKey: 'studio',
  subtitle: 'The calendar that plans your week',
  defaultTransition: TransitionSpec.of('push'),
  script: (b) {
    final title = b.slide(
      'title',
      text: {
        'title': 'Introducing Orbit',
        'subtitle': 'The calendar that plans your week for you',
      },
      notes: 'Let the title build in by itself, then pause before speaking.',
    );
    b.builds(title, [
      buildIn(
        b.placeholder(title, 'title'),
        'rise',
        trigger: SlideBuildTrigger.withPrevious,
      ),
      buildIn(
        b.placeholder(title, 'subtitle'),
        'fade',
        trigger: SlideBuildTrigger.afterPrevious,
      ),
    ]);
    final statement = b.slide(
      'statement',
      text: {'body': 'Your week, planned in seconds.'},
    );
    b.transition([statement], TransitionSpec.of('fade'));
    b.builds(statement, [
      buildIn(
        b.placeholder(statement, 'body'),
        'blur',
        trigger: SlideBuildTrigger.withPrevious,
      ),
    ]);

    b.group('The product', color: 'orange');
    b.slide(
      'titleOnly',
      text: {'title': 'Meet Orbit'},
      elements: _device(760, 280, 1),
      notes: 'Click to the next slide: the device moves aside.',
    );
    final features = b.slide(
      'titleOnly',
      text: {'title': 'Meet Orbit'},
      elements: [
        ..._device(160, 264, 1.15),
        for (final (i, (head, line)) in const [
          ('Plans for you', 'Drop in your tasks; Orbit finds the time.'),
          ('Protects focus', 'Meetings cluster, deep work stays whole.'),
          ('Works with your tools', 'Google, Outlook and Slack in two clicks.'),
        ].indexed) ...[
          badge(800, 300 + i * 220.0, '${i + 1}', size: 96),
          TemplateShapes.text(
            SuRect(936, 300 + i * 220.0, 864, 56),
            TemplatePara.runs([TemplateRun.bold(head)]),
            textStyle: 'heading',
            size: 44,
            color: 'theme:text1',
          ),
          TemplateShapes.text(
            SuRect(936, 364 + i * 220.0, 864, 96),
            line,
            textStyle: 'body2',
            size: 32,
            color: 'theme:text2',
          ),
        ],
      ],
    );
    b.transition([features], TransitionSpec.of('magicMove'));
    final cards3 = b.slide(
      'titleOnly',
      text: {'title': 'What\'s new in 2.0'},
      elements: cards([
        ('Smart blocks', 'Tasks become time blocks that move when plans do.'),
        ('Team view', 'See when everyone is free without asking.'),
        ('Weekly review', 'Friday summary of what got done.'),
      ]),
    );
    b.builds(cards3, [
      for (final card in chunks(b.lastElements, 4))
        ...buildTogether(card, 'pop'),
    ]);
    b.slide(
      'comparison',
      text: {
        'title': 'Before and after',
        'headingLeft': 'Before',
        'body': TemplateText.bullets([
          'Planning takes Monday morning',
          'Meetings land in focus time',
          'Tasks slip to next week',
        ]),
        'headingRight': 'With Orbit',
        'bodyRight': TemplateText.bullets([
          'A plan in seconds, updated all week',
          'Focus time protected by default',
          'Tasks scheduled before they slip',
        ]),
      },
    );
    final saved = b.slide(
      'bigNumber',
      text: {
        'bigNumber': '4.6 h',
        'caption': 'saved per person every week in our beta',
      },
    );
    b.transition([saved], TransitionSpec.of('flip'));

    b.group('Launch', color: 'pink');
    final pricing = b.slide('titleOnly', text: {'title': 'Pricing'});
    final table = b.table(pricing, const SuRect(120, 288, 1680, 480), const [
      ['Plan', 'Price', 'For'],
      ['Free', '€0', 'Teams up to 5'],
      ['Team', '€8 per person / month', 'Growing teams'],
      ['Business', '€14 per person / month', 'SSO, admin and audit'],
    ]);
    b.builds(pricing, [
      buildIn(table, 'wipe', trigger: SlideBuildTrigger.withPrevious),
    ]);
    final plan = b.slide(
      'titleOnly',
      text: {'title': 'Launch plan'},
      elements: timeline([
        ('Today', 'Public launch and press'),
        ('Nov', 'Outlook and Teams apps'),
        ('Dec', 'Team view for everyone'),
        ('Q1', 'Orbit for iPad'),
      ]),
    );
    final line = b.lastElements.first;
    b.builds(plan, [
      buildIn(line, 'lineDraw', trigger: SlideBuildTrigger.withPrevious),
      for (final milestone in chunks(b.lastElements.sublist(1), 3))
        ...buildTogether(milestone, 'rise'),
    ]);
    b.slide(
      'titleBody',
      text: {
        'title': 'Launch checklist',
        'body': TemplateText.bullets([
          'Press briefing on Monday',
          'Launch post and video at 9:00',
          'Support rota for the first week',
          'Thank-you note to every beta tester',
        ]),
      },
    );
    b.slide(
      'quote',
      text: {
        'quote': 'Orbit gave me my Fridays back.',
        'attribution': 'Sam Rivera, beta tester',
      },
    );
    b.endGroup();

    final close = b.slide(
      'title',
      text: {
        'title': 'Available today',
        'subtitle': 'orbit.example · Free for teams up to 5',
      },
    );
    b.transition([close], TransitionSpec.of('doorway'));
  },
);
