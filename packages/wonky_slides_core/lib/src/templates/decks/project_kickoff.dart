import '../../motion/builds/transition_spec.dart';
import '../../theme/model/common.dart';
import '../slides_template.dart';
import '../template_text.dart';
import 'parts.dart';

/// *Project kickoff* on *Swiss* (light): why, what and how of a new
/// project in three slide groups, with goals, scope, a milestone table and
/// the team.
final SlidesTemplate projectKickoffTemplate = SlidesTemplate(
  key: 'slides.project-kickoff',
  name: 'Project kickoff',
  description: 'Align the team on goals, scope, milestones and roles.',
  category: 'projectManagement',
  themeKey: 'swiss',
  defaultTransition: TransitionSpec.of('fade'),
  subtitle: 'Team meeting · Week 1',
  script: (b) {
    b.slide(
      'title',
      text: {
        'title': 'Project Atlas',
        'subtitle': 'Kickoff · Team meeting, week 1',
      },
    );
    b.slide(
      'agenda',
      text: {
        'title': 'Agenda',
        'body': TemplateText.numbered([
          'Why we are doing this',
          'Goals and scope',
          'Milestones',
          'Team and ways of working',
          'Questions',
        ]),
      },
    );

    b.group('Why', color: 'red');
    b.slide(
      'statement',
      text: {
        'body':
            'Customers wait three days for an answer. '
            'We want them to wait three minutes.',
      },
      notes: 'Pause here. Ask who has waited for support this week.',
    );
    b.slide(
      'titleBody',
      text: {
        'title': 'Background',
        'body': TemplateText.bullets([
          'Support volume doubled in the last twelve months',
          'Half of all questions are about the same ten topics',
          'Agents switch between four tools to answer one ticket',
        ]),
      },
    );

    b.group('What', color: 'blue');
    b.slide(
      'titleOnly',
      text: {'title': 'Goals'},
      elements: cards([
        ('Faster answers', 'From three days to under one hour.'),
        ('Self-service', '60 % of questions answered without an agent.'),
        ('Happier customers', 'Satisfaction score from 72 to 85.'),
      ]),
    );
    b.slide(
      'comparison',
      text: {
        'title': 'Scope',
        'headingLeft': 'In scope',
        'body': TemplateText.bullets([
          'New help center',
          'Chat on web and mobile',
          'One inbox for agents with routing',
        ]),
        'headingRight': 'Not in scope',
        'bodyRight': TemplateText.bullets([
          'Phone support',
          'Billing system changes',
          'Translations (phase 2)',
        ]),
      },
    );

    b.group('How', color: 'green');
    final milestones = b.slide('titleOnly', text: {'title': 'Milestones'});
    b.table(milestones, const SuRect(120, 288, 1680, 560), const [
      ['Milestone', 'Date', 'Owner'],
      ['Kickoff', 'March 2', 'Everyone'],
      ['Design complete', 'March 27', 'Lina'],
      ['Beta with 50 customers', 'May 8', 'Omar'],
      ['Launch', 'June 12', 'Priya'],
    ]);
    b.slide(
      'titleOnly',
      text: {'title': 'Team'},
      elements: people([
        ('PS', 'Priya Shah', 'Project lead', 'Owns scope and dates'),
        ('OM', 'Omar Malik', 'Engineering', 'Chat and inbox'),
        ('LB', 'Lina Berg', 'Design', 'Help center and flows'),
        ('JC', 'Jonas Clarke', 'Support', 'Content and training'),
      ]),
    );
    b.slide(
      'twoColumns',
      text: {
        'title': 'How we work',
        'body': [
          TemplatePara.runs([TemplateRun.bold('Rituals')]),
          ...TemplateText.bullets([
            'Weekly sync, Mondays at 10:00',
            'Demo every second Friday',
            'Async updates in #atlas',
          ]),
        ],
        'bodyRight': [
          TemplatePara.runs([TemplateRun.bold('Decisions')]),
          ...TemplateText.bullets([
            'The owner decides, the team advises',
            'Decisions are written down in the brief',
            'Blockers are raised within a day',
          ]),
        ],
      },
    );
    b.endGroup();

    b.slide(
      'bigNumber',
      text: {'bigNumber': '12 weeks', 'caption': 'from kickoff to launch'},
    );
    b.slide(
      'title',
      text: {'title': 'Questions?', 'subtitle': 'Let\'s build this together.'},
    );
  },
);
