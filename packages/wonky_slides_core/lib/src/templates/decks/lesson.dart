import '../../theme/model/common.dart';
import '../slides_template.dart';
import '../template_builder.dart';
import '../template_text.dart';
import 'parts.dart';

/// *Lesson* on *Botanical* (light, serif headings): a school lesson on
/// photosynthesis in slide groups per part, with learning goals, a process
/// flow, a comparison, questions and homework; teacher tips in the notes.
final SlidesTemplate lessonTemplate = SlidesTemplate(
  key: 'slides.lesson',
  name: 'Lesson',
  description: 'Teach one topic in parts, with goals, questions and homework.',
  category: 'education',
  themeKey: 'botanical',
  subtitle: 'How plants turn light into food',
  script: (b) {
    b.slide(
      'title',
      text: {
        'title': 'Photosynthesis',
        'subtitle': 'How plants turn light into food · Biology, grade 8',
      },
    );
    b.slide(
      'titleBody',
      text: {
        'title': 'Learning goals',
        'body': TemplateText.bullets([
          'Explain what photosynthesis is and why it matters',
          'Name what goes in and what comes out',
          'Describe the role of chlorophyll and sunlight',
          'Connect photosynthesis to the food chain',
        ]),
      },
      notes:
          'Read the goals aloud. Come back to them at the end of the '
          'lesson.',
    );

    b.group('Part 1 · The big idea', color: 'green');
    b.slide(
      'section',
      text: {
        'label': 'Part 1',
        'title': 'The big idea',
        'subtitle': 'Plants are solar-powered kitchens',
      },
    );
    b.slide(
      'statement',
      text: {'body': 'Almost every bite of food you eat started as sunlight.'},
      notes: 'Ask: what did you have for breakfast? Trace it back to a plant.',
    );
    b.slide(
      'titleOnly',
      text: {'title': 'The recipe'},
      elements: [
        ...flow(
          ['Carbon dioxide', 'Water', 'Sunlight', 'Sugar and oxygen'],
          ['+', '+', null],
          y: 420,
          height: 220,
        ),
        TemplateShapes.text(
          const SuRect(120, 720, 1680, 160),
          'Plants take in carbon dioxide through their leaves and water '
          'through their roots, and use the energy of light to make sugar.',
          textStyle: 'body2',
          size: 34,
          color: 'theme:text2',
          align: 'center',
        ),
      ],
    );

    b.group('Part 2 · Inside the leaf', color: 'teal');
    b.slide(
      'section',
      text: {
        'label': 'Part 2',
        'title': 'Inside the leaf',
        'subtitle': 'Where the work happens',
      },
    );
    b.slide(
      'comparison',
      text: {
        'title': 'Two stages',
        'headingLeft': 'Light reactions',
        'body': TemplateText.bullets([
          'Happen in the thylakoids',
          'Chlorophyll captures sunlight',
          'Water is split and oxygen released',
        ]),
        'headingRight': 'Calvin cycle',
        'bodyRight': TemplateText.bullets([
          'Happens in the stroma',
          'Uses the captured energy',
          'Builds sugar from carbon dioxide',
        ]),
      },
    );
    b.slide(
      'bigNumber',
      text: {
        'bigNumber': '50 %',
        'caption':
            'of the oxygen we breathe comes from tiny plants and algae '
            'in the ocean',
      },
    );
    b.slide(
      'quote',
      text: {
        'quote':
            'Look deep into nature, and then you will understand everything '
            'better.',
        'attribution': 'Albert Einstein',
      },
    );

    b.group('Check your understanding', color: 'amber');
    b.slide(
      'agenda',
      text: {
        'title': 'Questions',
        'body': TemplateText.numbered([
          'What are the three ingredients of photosynthesis?',
          'Where in the leaf does it happen?',
          'Why would a plant in a dark closet stop growing?',
        ]),
      },
      notes: 'Think, pair, share: one minute alone, two minutes in pairs.',
    );
    b.slide(
      'titleBody',
      text: {
        'title': 'Homework',
        'body': TemplateText.bullets([
          'Read chapter 4.2 (pages 88–95)',
          'Put a leaf in a glass of water in the sun',
          '- What do you see after an hour? Draw it.',
          'Bring one question to the next class',
        ]),
      },
    );
    b.endGroup();
  },
);
