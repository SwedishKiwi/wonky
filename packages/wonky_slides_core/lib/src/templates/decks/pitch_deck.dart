import '../../motion/builds/transition_spec.dart';
import '../slides_template.dart';
import '../template_text.dart';
import 'parts.dart';

/// *Pitch deck* on *Aurora* (dark): an investor pitch in four slide
/// groups — the opportunity, the solution, the business and the ask.
final SlidesTemplate pitchDeckTemplate = SlidesTemplate(
  key: 'slides.pitch-deck',
  name: 'Pitch deck',
  description: 'Tell investors your story: problem, solution, traction, ask.',
  category: 'work',
  themeKey: 'aurora',
  defaultTransition: TransitionSpec.of('fade'),
  subtitle: 'Real-time energy insights for every building',
  script: (b) {
    b.slide(
      'title',
      text: {
        'title': 'Lumen',
        'subtitle':
            'Real-time energy insights for every building · Seed round 2026',
      },
      notes:
          'Open with the one-sentence pitch. Leave this slide up for no '
          'more than 30 seconds.',
    );

    b.group('The opportunity', color: 'violet');
    b.slide(
      'titleBody',
      text: {
        'title': 'The problem',
        'body': TemplateText.bullets([
          'Commercial buildings waste 30 % of the energy they buy',
          'Facility teams see their usage once a month — on the bill',
          'Existing tools need weeks of installation and a consultant',
        ]),
      },
      notes: 'Tell the story of one real customer before showing numbers.',
    );
    b.slide(
      'bigNumber',
      text: {
        'bigNumber': '€4.2B',
        'caption':
            'wasted every year by mid-size commercial buildings in the EU',
      },
    );

    b.group('Our solution', color: 'blue');
    b.slide(
      'titleOnly',
      text: {'title': 'How Lumen works'},
      elements: cards([
        ('Clip on', 'Sensors snap onto the main panel in 15 minutes.'),
        ('See', 'Live usage per circuit, right in the browser.'),
        ('Save', 'Alerts when something runs that shouldn\'t.'),
      ]),
    );
    b.slide(
      'comparison',
      text: {
        'title': 'Why we win',
        'headingLeft': 'Today',
        'body': TemplateText.bullets([
          'A monthly bill without detail',
          'Consultants and yearly audits',
          'Weeks to install',
        ]),
        'headingRight': 'With Lumen',
        'bodyRight': TemplateText.bullets([
          'Live data for every circuit',
          'Self-serve in an afternoon',
          'Pays for itself in four months',
        ]),
      },
    );
    b.slide(
      'quote',
      text: {
        'quote':
            'We found a compressor running all weekend in the first hour. '
            'Lumen paid for itself before lunch.',
        'attribution': 'Maria Chen, facilities lead at Harbor Logistics',
      },
    );

    b.group('Business', color: 'green');
    b.slide(
      'titleOnly',
      text: {'title': 'Traction'},
      elements: stats([
        ('42', 'paying customers'),
        ('€38k', 'monthly recurring revenue'),
        ('18 %', 'growth month over month'),
      ]),
    );
    b.slide(
      'titleBody',
      text: {
        'title': 'Business model',
        'body': TemplateText.bullets([
          'Hardware at cost: €290 per building',
          'Subscription: €49 per building and month',
          '- Annual plans get two months free',
          'Installer partners earn 15 % recurring',
        ]),
      },
    );
    b.slide(
      'titleOnly',
      text: {'title': 'Roadmap'},
      elements: timeline([
        ('Q1', 'Self-serve onboarding'),
        ('Q2', 'Automatic savings reports'),
        ('Q3', 'Utility integrations'),
        ('Q4', 'First US pilots'),
      ]),
    );

    b.group('The ask', color: 'amber');
    b.slide(
      'titleOnly',
      text: {'title': 'The team'},
      elements: people([
        ('AK', 'Ada Kowalski', 'CEO', 'Ten years in building energy'),
        ('TN', 'Tom Nguyen', 'CTO', 'Built IoT fleets of 1M devices'),
        ('SR', 'Sara Rossi', 'Sales', 'Sold to 300+ facility teams'),
      ]),
    );
    b.slide(
      'bigNumber',
      text: {
        'bigNumber': '€2M',
        'caption': 'to reach 500 buildings and break even in 18 months',
      },
      notes: 'Say the number, then stop talking and wait for questions.',
    );
    b.endGroup();

    b.slide(
      'title',
      text: {
        'title': 'Thank you',
        'subtitle': 'ada@lumen.example · lumen.example',
      },
    );
  },
);
