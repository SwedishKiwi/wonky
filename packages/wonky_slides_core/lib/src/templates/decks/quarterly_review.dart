import '../../model/api/kinds.dart';
import '../../motion/builds/build_options.dart';
import '../../motion/builds/transition_spec.dart';
import '../../theme/model/common.dart';
import '../slides_template.dart';
import '../template_text.dart';
import 'parts.dart';
import 'sample_charts.dart';

const _chartNote =
    'The chart shows sample data. To show your own numbers, select it and '
    'choose Relink… to pick a chart from one of your spreadsheets: the '
    'builds stay and the slide updates whenever the spreadsheet changes.';

/// *Quarterly review* on *Classic* (corporate navy): a business review
/// with key figures that build in, charts that grow series by series (one
/// in 3D with a camera move), a KPI table and priorities that dim as the
/// presenter moves on. The charts are sample snapshots placed in the
/// layout's chart placeholders — *Relink…* turns them into linked
/// spreadsheet charts (Slides 04 §15 "linked-chart placeholders").
final SlidesTemplate quarterlyReviewTemplate = SlidesTemplate(
  key: 'slides.quarterly-review',
  name: 'Quarterly review',
  description: 'Report the quarter with key figures, charts and priorities.',
  category: 'work',
  themeKey: 'classic',
  subtitle: 'Q3 2026 · Leadership team',
  defaultTransition: TransitionSpec.of('fade'),
  script: (b) {
    b.slide(
      'title',
      text: {
        'title': 'Q3 2026 business review',
        'subtitle': 'Northwind Outfitters · Leadership team · October 2026',
      },
      notes: 'Welcome everyone and set the goal: decisions for Q4 by noon.',
    );
    b.slide(
      'agenda',
      text: {
        'title': 'Agenda',
        'body': TemplateText.numbered([
          'Highlights of the quarter',
          'Revenue and regions',
          'Customers and KPIs',
          'What we learned',
          'Priorities for Q4',
        ]),
      },
    );

    b.group('Highlights', color: 'blue');
    final growth = b.slide(
      'bigNumber',
      text: {
        'bigNumber': '+18 %',
        'caption': 'revenue growth over Q3 2025 — our best quarter yet',
      },
    );
    b.builds(growth, [
      buildIn(
        b.placeholder(growth, 'bigNumber'),
        'pop',
        trigger: SlideBuildTrigger.withPrevious,
      ),
      buildIn(
        b.placeholder(growth, 'caption'),
        'fade',
        trigger: SlideBuildTrigger.afterPrevious,
      ),
    ]);
    final figures = b.slide(
      'titleOnly',
      text: {'title': 'The quarter in numbers'},
      elements: stats([
        ('€12.4M', 'Revenue, up from €10.5M'),
        ('41 %', 'Gross margin, up 3 points'),
        ('2,310', 'New business customers'),
      ]),
      notes: 'One click per figure. Pause on the margin: it pays for Q4.',
    );
    b.builds(figures, [
      for (final stat in chunks(b.lastElements, 3))
        ...buildTogether(stat, 'rise'),
    ]);

    b.group('Revenue', color: 'teal');
    final monthly = b.slide(
      'chart',
      text: {
        'title': 'Revenue by month',
        'caption': 'Every month beat last year; September set a record.',
      },
      notes: _chartNote,
    );
    final monthlyChart = b.staticChart(
      monthly,
      altText:
          'Column chart of revenue by month: Q3 2026 beat Q3 2025 in July, '
          'August and September.',
      sampleChart(
        title: 'Revenue by month (€M)',
        type: 'column',
        domainName: 'Month',
        categories: const ['July', 'August', 'September'],
        series: const [
          ('q3-2025', 'Q3 2025', [3.3, 3.4, 3.8]),
          ('q3-2026', 'Q3 2026', [3.8, 4.0, 4.6]),
        ],
      ),
    );
    b.builds(monthly, [
      buildIn(
        monthlyChart,
        'chartGrow',
        delivery: const BuildDelivery(
          by: DeliveryBy.series,
          partTrigger: SlideBuildTrigger.onClick,
        ),
      ),
    ]);
    final regions = b.slide(
      'chart',
      text: {
        'title': 'Revenue by region',
        'caption': 'The north grew fastest; the coast is our largest market.',
      },
      notes: '$_chartNote Click once more to turn the 3D chart.',
    );
    final regionChart = b.staticChart(
      regions,
      altText:
          '3D column chart of revenue by region, Q2 and Q3 2026: the coast '
          'is largest, the north grew fastest.',
      sampleChart(
        title: 'Revenue by region (€M)',
        type: 'column',
        domainName: 'Region',
        categories: const ['North', 'Coast', 'Capital', 'South'],
        series: const [
          ('q2', 'Q2 2026', [2.1, 3.9, 3.0, 1.6]),
          ('q3', 'Q3 2026', [2.9, 4.4, 3.3, 1.8]),
        ],
        threeD: const {'enabled': true, 'azimuth': 20, 'elevation': 18},
      ),
    );
    b.transition([regions], TransitionSpec.of('push'));
    b.builds(regions, [
      buildIn(
        regionChart,
        'chartGrow',
        trigger: SlideBuildTrigger.withPrevious,
      ),
      emphasis(
        regionChart,
        'chartCamera',
        params: const {'azimuth': 55, 'elevation': 32},
      ),
    ]);

    b.group('Customers', color: 'amber');
    final kpis = b.slide('titleOnly', text: {'title': 'KPIs'});
    b.table(kpis, const SuRect(120, 288, 1680, 560), const [
      ['Metric', 'Q2 2026', 'Q3 2026', 'Target'],
      ['Active customers', '18,950', '21,260', '21,000'],
      ['Net revenue retention', '108 %', '112 %', '110 %'],
      ['Support satisfaction', '4.4 / 5', '4.6 / 5', '4.5 / 5'],
      ['Time to first order', '9 days', '6 days', '7 days'],
    ]);
    b.slide(
      'quote',
      text: {
        'quote':
            'Ordering for all twelve stores now takes us ten minutes '
            'instead of a morning.',
        'attribution': 'Priya Natarajan, Operations lead at Trailhead Co.',
      },
    );

    b.group('Looking ahead', color: 'violet');
    final learned = b.slide(
      'comparison',
      text: {
        'title': 'What we learned',
        'headingLeft': 'Worked',
        'body': TemplateText.bullets([
          'Bundles for repeat customers',
          'Same-day shipping in the north',
          'The new onboarding call',
        ]),
        'headingRight': 'Didn\'t',
        'bodyRight': TemplateText.bullets([
          'Discounts without a minimum order',
          'Two launches in one month',
          'Manual stock checks',
        ]),
      },
    );
    b.builds(learned, [
      ...buildTogether([
        b.placeholder(learned, 'headingRight'),
        b.placeholder(learned, 'bodyRight'),
      ], 'fade'),
    ]);
    final priorities = b.slide(
      'titleBody',
      text: {
        'title': 'Priorities for Q4',
        'body': TemplateText.bullets([
          'Open the capital region warehouse',
          'Bring bundles to every customer',
          'Automate stock checks before the holidays',
          'Hire two account managers for the coast',
        ]),
      },
      notes: 'One click per priority; the previous ones dim.',
    );
    b.builds(priorities, [
      buildIn(
        b.placeholder(priorities, 'body'),
        'rise',
        delivery: const BuildDelivery(by: DeliveryBy.paragraph),
        afterBuild: const AfterBuild(mode: AfterBuildMode.dim),
      ),
    ]);
    b.endGroup();

    b.slide(
      'title',
      text: {
        'title': 'Questions?',
        'subtitle': 'Next review: January 2027 · Slides in the team drive',
      },
    );
  },
);
