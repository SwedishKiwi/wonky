import '../../theme/model/common.dart';
import '../slides_template.dart';
import '../template_text.dart';
import 'parts.dart';

const _loadCsv = '''
import pandas as pd

sales = pd.read_csv("sales.csv", parse_dates=["date"])

print(sales.shape)   # (rows, columns)
sales.head(10)       # the first ten rows
''';

const _groupBy = '''
monthly = (
    sales
    .dropna(subset=["amount"])
    .assign(month=sales["date"].dt.to_period("M"))
    .groupby("month")["amount"]
    .sum()
)
monthly.plot(kind="bar")
''';

/// *Workshop agenda* on *Terminal* (dark, monospace headings): a
/// hands-on coding workshop in slide groups per part, with a schedule
/// table, setup cards, code slides and exercises.
final SlidesTemplate workshopTemplate = SlidesTemplate(
  key: 'slides.workshop',
  name: 'Workshop agenda',
  description:
      'TemplateRun a hands-on workshop with setup, code and exercises.',
  category: 'education',
  themeKey: 'terminal',
  subtitle: 'Hands-on workshop · 3 hours',
  script: (b) {
    b.slide(
      'title',
      text: {
        'title': 'Data wrangling with Python',
        'subtitle': 'Hands-on workshop · 3 hours · bring a laptop',
      },
    );
    final schedule = b.slide('titleOnly', text: {'title': 'Schedule'});
    b.table(schedule, const SuRect(120, 288, 1680, 600), const [
      ['Time', 'Session', 'Format'],
      ['09:00', 'Welcome and setup', 'Together'],
      ['09:20', 'Part 1 · Loading data', 'Demo + exercise'],
      ['10:15', 'Break', ''],
      ['10:30', 'Part 2 · Cleaning and reshaping', 'Demo + exercise'],
      ['11:30', 'Your own dataset', 'Pairs'],
      ['11:50', 'Wrap-up', 'Together'],
    ]);
    b.slide(
      'titleOnly',
      text: {'title': 'Before we start'},
      elements: cards([
        ('Python 3.12', 'Check with: python3 --version'),
        ('pandas 2', 'Install with: pip install pandas'),
        ('The notebook', 'Download it from workshop.example'),
      ]),
      notes:
          'Walk around and help with setup while people introduce '
          'themselves.',
    );
    b.slide(
      'bigNumber',
      text: {
        'bigNumber': '80 %',
        'caption':
            'of a data project is wrangling. Let\'s make it the fun part.',
      },
    );

    b.group('Part 1 · Loading data', color: 'teal');
    b.slide(
      'section',
      text: {
        'label': 'Part 1',
        'title': 'Loading data',
        'subtitle': 'From a CSV file to a DataFrame',
      },
    );
    final load = b.slide('code', text: {'title': 'Read a CSV file'});
    b.code(load, _loadCsv.trimRight(), language: 'python');
    b.slide(
      'titleBody',
      text: {
        'title': 'Your turn',
        'body': TemplateText.bullets([
          'Open exercise 1 in the notebook',
          'Load trips.csv and show the first ten rows',
          '- Tip: nrows=1000 makes huge files quick to try',
          'Raise your hand when you see a table',
        ]),
      },
      notes: 'Give ten minutes. Show one solution on screen afterwards.',
    );

    b.group('Part 2 · Cleaning and reshaping', color: 'violet');
    b.slide(
      'section',
      text: {
        'label': 'Part 2',
        'title': 'Cleaning and reshaping',
        'subtitle': 'Small steps, chained together',
      },
    );
    final group = b.slide('code', text: {'title': 'Sales per month'});
    b.code(group, _groupBy.trimRight(), language: 'python');
    b.slide(
      'comparison',
      text: {
        'title': 'Habits that help',
        'headingLeft': 'Do',
        'body': TemplateText.bullets([
          'Check the column types after loading',
          'Chain small, readable steps',
          'Name intermediate results',
        ]),
        'headingRight': 'Avoid',
        'bodyRight': TemplateText.bullets([
          'Loops over rows',
          'Changing data in place',
          'Dropping missing values everywhere',
        ]),
      },
    );
    b.endGroup();

    b.slide(
      'agenda',
      text: {
        'title': 'Wrap-up',
        'body': TemplateText.numbered([
          'Load with read_csv, look with head',
          'Clean with dropna and assign',
          'Summarize with groupby',
        ]),
      },
    );
    b.slide(
      'title',
      text: {
        'title': 'Thanks for joining!',
        'subtitle': 'Slides and notebook: workshop.example',
      },
    );
  },
);
