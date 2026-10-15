import '../../theme/model/common.dart';
import '../slides_template.dart';
import '../template_text.dart';
import 'parts.dart';

/// *Weekly update* on *Wonky* (light): a short team status deck — key
/// numbers, shipped vs. in progress, project status table, risks and next
/// week.
final SlidesTemplate weeklyUpdateTemplate = SlidesTemplate(
  key: 'slides.weekly-update',
  name: 'Weekly update',
  description: 'Share progress, numbers, risks and next steps in ten minutes.',
  category: 'work',
  themeKey: 'wonky',
  subtitle: 'Team Phoenix · Week 14',
  script: (b) {
    b.slide(
      'title',
      text: {'title': 'Weekly update', 'subtitle': 'Team Phoenix · Week 14'},
    );
    b.slide(
      'titleOnly',
      text: {'title': 'This week at a glance'},
      elements: stats([
        ('24', 'tickets closed'),
        ('3', 'features shipped'),
        ('99.9 %', 'uptime'),
      ]),
      notes: 'Compare each number with last week in one sentence.',
    );
    b.slide(
      'comparison',
      text: {
        'title': 'Progress',
        'headingLeft': 'Shipped',
        'body': TemplateText.bullets([
          'New onboarding for all users',
          'Faster search in large projects',
          'Dark mode for the mobile app',
        ]),
        'headingRight': 'In progress',
        'bodyRight': TemplateText.bullets([
          'Billing migration (70 %)',
          'Team permissions',
          'Usage reports for admins',
        ]),
      },
    );
    b.slide(
      'bigNumber',
      text: {
        'bigNumber': '+18 %',
        'caption': 'weekly active users since the new onboarding went live',
      },
    );
    final status = b.slide('titleOnly', text: {'title': 'Status by project'});
    b.table(status, const SuRect(120, 288, 1680, 480), const [
      ['Project', 'Status', 'Owner', 'Next step'],
      ['Onboarding', 'Done', 'Mia', 'Measure activation'],
      ['Billing migration', 'At risk', 'Ravi', 'Vendor call on Tuesday'],
      ['Mobile app', 'On track', 'Leo', 'Beta build to QA'],
    ]);
    b.slide(
      'titleBody',
      text: {
        'title': 'Risks and blockers',
        'body': TemplateText.bullets([
          'Billing vendor has not confirmed the API change',
          '- Plan B: keep the old flow for two more weeks',
          'Two people are out next week',
          'Need a decision on pricing for team plans',
        ]),
      },
    );
    b.slide(
      'quote',
      text: {
        'quote':
            'The new onboarding is the first time I didn\'t need to read '
            'the docs.',
        'attribution': 'Customer interview, April 3',
      },
    );
    b.slide(
      'agenda',
      text: {
        'title': 'Next week',
        'body': TemplateText.numbered([
          'Finish the billing migration',
          'Start usage reports',
          'Plan the team offsite',
        ]),
      },
    );
    b.slide(
      'statement',
      text: {
        'body': [
          TemplatePara('Questions or blockers?'),
          TemplatePara('Post them in #phoenix before Friday.', const {
            'style': 'subtitle',
            'spaceBefore': 32,
          }),
        ],
      },
    );
  },
);
