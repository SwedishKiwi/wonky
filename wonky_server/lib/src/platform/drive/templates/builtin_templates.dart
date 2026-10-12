import 'package:serverpod/serverpod.dart';

import '../../common/models.dart';

/// A sheet of a built-in spreadsheet template. [rows] hold user input as
/// typed in a cell (numbers, text, `=` formulas in A1 notation, en_US).
class TemplateSheet {
  const TemplateSheet({
    required this.name,
    required this.rows,
    this.columnWidths = const {},
    this.boldRows = const {0},
    this.frozenRows = 1,
    this.numberFormats = const {},
  });

  final String name;
  final List<List<String?>> rows;

  /// Column index → width in px.
  final Map<int, double> columnWidths;

  /// Rows rendered bold (headers).
  final Set<int> boldRows;
  final int frozenRows;

  /// Column index → number format applied to the data rows.
  final Map<int, String> numberFormats;
}

/// A built-in template (specs/05 §3.1). Document templates carry Markdown,
/// spreadsheet templates carry [sheets].
class BuiltinTemplate {
  const BuiltinTemplate({
    required this.key,
    required this.kind,
    required this.name,
    required this.description,
    required this.category,
    this.markdown,
    this.sheets = const [],
    this.inGallery = true,
  });

  final String key;
  final DriveItemKind kind;
  final String name;
  final String description;
  final TemplateCategory category;
  final String? markdown;
  final List<TemplateSheet> sheets;

  /// Welcome content is created at sign-up but not listed in the gallery.
  final bool inGallery;

  UuidValue get uuid =>
      const Uuid().v5obj(Namespace.url.value, 'wonky-template:$key');

  String get previewText {
    if (markdown != null) {
      // One line per block (for the thumbnail): headings keep a leading
      // "#", list markers become "•", tables become spaced cells.
      final lines = <String>[];
      for (var line in markdown!.split('\n')) {
        line = line.trim();
        if (line.isEmpty || RegExp(r'^\|?[\s:|-]+\|?$').hasMatch(line)) {
          continue;
        }
        final heading = line.startsWith('#');
        line = line
            .replaceFirst(RegExp(r'^#+\s*'), '')
            .replaceFirst(RegExp(r'^[-*+]\s+\[[ xX]\]\s*'), '☐ ')
            .replaceFirst(RegExp(r'^[-*+]\s+'), '• ')
            .replaceFirst(RegExp(r'^>\s*'), '')
            .replaceAll(RegExp(r'[*_`]'), '')
            .replaceAll(RegExp(r'\s*\|\s*'), '   ')
            .trim();
        if (line.isEmpty) continue;
        lines.add(heading ? '# $line' : line);
        if (lines.length >= 14) break;
      }
      final text = lines.join('\n');
      return text.length > 600 ? '${text.substring(0, 600)}…' : text;
    }
    final first = sheets.isEmpty ? const <List<String?>>[] : sheets.first.rows;
    final text = first
        .take(3)
        .map((r) => r.whereType<String>().join(' · '))
        .join(' — ');
    return text.length > 140 ? '${text.substring(0, 140)}…' : text;
  }
}

/// The built-in template gallery.
abstract final class BuiltinTemplates {
  static const welcomeDocumentKey = 'write.welcome';
  static const welcomeSpreadsheetKey = 'sheets.welcome';

  static BuiltinTemplate? byUuid(UuidValue uuid) {
    for (final t in all) {
      if (t.uuid == uuid) return t;
    }
    return null;
  }

  static BuiltinTemplate byKey(String key) =>
      all.firstWhere((t) => t.key == key);

  static const List<BuiltinTemplate> all = [
    BuiltinTemplate(
      key: welcomeDocumentKey,
      kind: DriveItemKind.document,
      name: 'Welcome to Wonky Write',
      description: 'A short tour of Wonky Write.',
      category: TemplateCategory.personal,
      inGallery: false,
      markdown: '''
# Welcome to Wonky Write

Wonky Write is a **Markdown-first** word processor. Everything you write is
plain Markdown underneath, so your documents stay portable.

## Getting started

- Type `#` and a space to start a heading.
- Type `-` and a space for a bullet list, or `1.` for a numbered list.
- Type `- [ ]` for a checklist.
- Select text and press **Mod+B** for bold or **Mod+I** for *italic*.

## Working together

1. Click **Share** to invite people as viewers, commenters or editors.
2. Select text and press **Mod+Alt+M** to comment.
3. Switch to *Suggesting* to propose changes that others can accept.

## Make it yours

Open **Format › Theme** to change how your document looks. Themes control
fonts, colors and spacing — the content stays clean Markdown.

> Tip: press **Mod+K** to open the command palette and find any action.

- [ ] Write your first document
- [ ] Share it with a friend
- [ ] Try a theme
''',
    ),
    BuiltinTemplate(
      key: 'write.meeting-notes',
      kind: DriveItemKind.document,
      name: 'Meeting notes',
      description: 'Agenda, notes, decisions and action items.',
      category: TemplateCategory.work,
      markdown: '''
# Meeting notes

**Date:**
**Attendees:**

## Agenda

1.
2.
3.

## Notes

-

## Decisions

-

## Action items

- [ ] Owner — task — due date
- [ ] Owner — task — due date
''',
    ),
    BuiltinTemplate(
      key: 'write.project-brief',
      kind: DriveItemKind.document,
      name: 'Project brief',
      description: 'Goals, scope, milestones and risks of a project.',
      category: TemplateCategory.projectManagement,
      markdown: '''
# Project brief

## Summary

One paragraph describing the project and why it matters.

## Goals

-
-

## Non-goals

-

## Scope

| Area | In scope | Notes |
| --- | --- | --- |
| | | |

## Milestones

1. **Kick-off** —
2. **First release** —
3. **Launch** —

## Risks

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| | | |

## Team

- **Lead:**
- **Contributors:**
''',
    ),
    BuiltinTemplate(
      key: 'write.letter',
      kind: DriveItemKind.document,
      name: 'Letter',
      description: 'A simple formal letter.',
      category: TemplateCategory.personal,
      markdown: '''
Your name
Street address
City, postal code

Date

Recipient name
Street address
City, postal code

Dear recipient,

Start your letter here. Keep the first paragraph short and state why you are
writing.

Use the following paragraphs for the details.

Kind regards,

Your name
''',
    ),
    BuiltinTemplate(
      key: 'write.weekly-report',
      kind: DriveItemKind.document,
      name: 'Weekly report',
      description: 'Progress, plans and blockers for the week.',
      category: TemplateCategory.work,
      markdown: '''
# Weekly report

**Week of:**

## Highlights

-

## Progress

| Workstream | Status | Notes |
| --- | --- | --- |
| | On track | |

## Next week

- [ ]
- [ ]

## Blockers

-
''',
    ),
    BuiltinTemplate(
      key: 'write.lecture-notes',
      kind: DriveItemKind.document,
      name: 'Lecture notes',
      description: 'Structured notes with key terms and questions.',
      category: TemplateCategory.education,
      markdown: '''
# Lecture notes

**Course:**
**Date:**

## Key ideas

-

## Key terms

- **Term** — definition

## Questions

-

## Summary

Write a short summary in your own words.
''',
    ),
    BuiltinTemplate(
      key: 'write.todo',
      kind: DriveItemKind.document,
      name: 'To-do list',
      description: 'A checklist for the day or the week.',
      category: TemplateCategory.personal,
      markdown: '''
# To-do list

## Today

- [ ]
- [ ]
- [ ]

## This week

- [ ]
- [ ]

## Someday

- [ ]
''',
    ),
    BuiltinTemplate(
      key: welcomeSpreadsheetKey,
      kind: DriveItemKind.spreadsheet,
      name: 'Welcome to Wonky Sheets',
      description: 'A short tour of Wonky Sheets.',
      category: TemplateCategory.personal,
      inGallery: false,
      sheets: [
        TemplateSheet(
          name: 'Welcome',
          columnWidths: {0: 220, 1: 120, 2: 360},
          rows: [
            ['Welcome to Wonky Sheets', null, null],
            ['Item', 'Amount', 'Try this'],
            ['Coffee', '3.5', 'Change a number and watch the total update'],
            ['Lunch', '12', 'Type =SUM( and select a range'],
            ['Books', '24.9', 'Select cells and press Mod+B'],
            ['Total', '=SUM(B3:B5)', 'Works offline — changes sync later'],
          ],
          boldRows: {0, 1, 5},
          frozenRows: 2,
        ),
      ],
    ),
    BuiltinTemplate(
      key: 'sheets.monthly-budget',
      kind: DriveItemKind.spreadsheet,
      name: 'Monthly budget',
      description: 'Planned and actual income and expenses.',
      category: TemplateCategory.finance,
      sheets: [
        TemplateSheet(
          name: 'Budget',
          columnWidths: {0: 200, 1: 120, 2: 120, 3: 120},
          numberFormats: {1: '#,##0.00', 2: '#,##0.00', 3: '#,##0.00'},
          rows: [
            ['Category', 'Planned', 'Actual', 'Difference'],
            ['Salary', '3000', '3000', '=C2-B2'],
            ['Rent', '-1100', '-1100', '=C3-B3'],
            ['Groceries', '-400', '-436.2', '=C4-B4'],
            ['Transport', '-120', '-95', '=C5-B5'],
            ['Utilities', '-150', '-162.4', '=C6-B6'],
            ['Entertainment', '-100', '-80', '=C7-B7'],
            ['Savings', '-500', '-500', '=C8-B8'],
            ['Total', '=SUM(B2:B8)', '=SUM(C2:C8)', '=C9-B9'],
          ],
          boldRows: {0, 8},
        ),
      ],
    ),
    BuiltinTemplate(
      key: 'sheets.todo',
      kind: DriveItemKind.spreadsheet,
      name: 'To-do list',
      description: 'Tasks with due dates and status.',
      category: TemplateCategory.personal,
      sheets: [
        TemplateSheet(
          name: 'Tasks',
          columnWidths: {0: 280, 1: 120, 2: 120},
          rows: [
            ['Task', 'Due', 'Status'],
            ['Plan the week', null, 'Not started'],
            ['Reply to emails', null, 'In progress'],
            ['Book appointments', null, 'Done'],
          ],
        ),
      ],
    ),
    BuiltinTemplate(
      key: 'sheets.project-tracker',
      kind: DriveItemKind.spreadsheet,
      name: 'Project tracker',
      description: 'Tasks, owners, dates and progress.',
      category: TemplateCategory.projectManagement,
      sheets: [
        TemplateSheet(
          name: 'Tracker',
          columnWidths: {0: 240, 1: 140, 2: 110, 3: 110, 4: 110, 5: 100},
          numberFormats: {5: '0%'},
          rows: [
            ['Task', 'Owner', 'Start', 'End', 'Status', 'Progress'],
            ['Kick-off', null, null, null, 'Done', '1'],
            ['Design', null, null, null, 'In progress', '0.5'],
            ['Build', null, null, null, 'Not started', '0'],
            ['Launch', null, null, null, 'Not started', '0'],
            ['Overall', null, null, null, null, '=AVERAGE(F2:F5)'],
          ],
          boldRows: {0, 5},
        ),
      ],
    ),
    BuiltinTemplate(
      key: 'sheets.invoice',
      kind: DriveItemKind.spreadsheet,
      name: 'Invoice',
      description: 'Line items with quantities, prices and totals.',
      category: TemplateCategory.finance,
      sheets: [
        TemplateSheet(
          name: 'Invoice',
          columnWidths: {0: 280, 1: 90, 2: 110, 3: 120},
          numberFormats: {2: '#,##0.00', 3: '#,##0.00'},
          rows: [
            ['Description', 'Quantity', 'Unit price', 'Amount'],
            ['Consulting (hours)', '10', '95', '=B2*C2'],
            ['Design work (hours)', '6', '80', '=B3*C3'],
            ['Materials', '1', '120', '=B4*C4'],
            ['Subtotal', null, null, '=SUM(D2:D4)'],
            ['Tax (20%)', null, null, '=D5*0.2'],
            ['Total', null, null, '=D5+D6'],
          ],
          boldRows: {0, 6},
        ),
      ],
    ),
    BuiltinTemplate(
      key: 'sheets.gradebook',
      kind: DriveItemKind.spreadsheet,
      name: 'Gradebook',
      description: 'Scores per assignment with averages.',
      category: TemplateCategory.education,
      sheets: [
        TemplateSheet(
          name: 'Grades',
          columnWidths: {0: 200},
          numberFormats: {4: '0.0'},
          rows: [
            ['Student', 'Assignment 1', 'Assignment 2', 'Exam', 'Average'],
            ['Student A', '85', '92', '78', '=AVERAGE(B2:D2)'],
            ['Student B', '72', '80', '88', '=AVERAGE(B3:D3)'],
            ['Student C', '95', '90', '93', '=AVERAGE(B4:D4)'],
            [
              'Class average',
              '=AVERAGE(B2:B4)',
              '=AVERAGE(C2:C4)',
              '=AVERAGE(D2:D4)',
              '=AVERAGE(E2:E4)',
            ],
          ],
          boldRows: {0, 4},
        ),
      ],
    ),
    BuiltinTemplate(
      key: 'sheets.weekly-schedule',
      kind: DriveItemKind.spreadsheet,
      name: 'Weekly schedule',
      description: 'Time slots for each day of the week.',
      category: TemplateCategory.personal,
      sheets: [
        TemplateSheet(
          name: 'Schedule',
          columnWidths: {0: 90},
          rows: [
            ['Time', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            ['08:00'],
            ['09:00'],
            ['10:00'],
            ['11:00'],
            ['12:00'],
            ['13:00'],
            ['14:00'],
            ['15:00'],
            ['16:00'],
            ['17:00'],
          ],
        ),
      ],
    ),
  ];
}
