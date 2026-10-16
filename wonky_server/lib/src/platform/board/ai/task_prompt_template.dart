import '../../common/models.dart';

/// The fixed frame around a task prompt (specs/16 §10.1). The AI writes
/// only the body; the header and the "When you are done" part come from
/// here and cannot be changed by the model.
abstract final class TaskPromptTemplate {
  /// The placeholder of the claim line in prompts read by anyone but the
  /// claimant (admins).
  static const claimPlaceholder = '<your claim code from the task page>';

  /// The full prompt shown on the task page: header, [body], the posts the
  /// task comes from, and the PR instructions with the two description
  /// lines — filled in with [claimCode] for the claimant, else the
  /// [claimPlaceholder].
  static String wrap({
    required BoardTask task,
    required List<BoardPost> posts,
    required String body,
    required Uri webOrigin,
    String repository = 'serverpod/wonky',
    String? claimCode,
  }) {
    final b = StringBuffer()
      ..writeln('# Wonky task T-${task.id}: ${task.title}')
      ..writeln()
      ..writeln(
        'You are working in a clone of github.com/$repository. Read '
        'AGENTS.md first and follow it (specs are the source of truth, every '
        'action is a command and undoable, single window, light and dark, '
        'the checklist after changes).',
      )
      ..writeln()
      ..writeln(body.trim())
      ..writeln()
      ..writeln('## Reports this task comes from');
    for (final p in posts) {
      final link = webOrigin.replace(path: '/improvements/p/${p.id}');
      b.writeln(
        '- #${p.id} ${p.title} — $link '
        '(${p.score} ${p.score == 1 ? 'vote' : 'votes'})',
      );
    }
    b
      ..writeln()
      ..writeln('## When you are done')
      ..writeln('- Run the checklist in AGENTS.md (analyze, format, tests).')
      ..writeln('- Update the specs if behavior changed.')
      ..writeln()
      ..writeln(
        'Open a pull request against `main`. Its description contains these '
        'two lines:',
      )
      ..writeln()
      ..writeln('```')
      ..writeln('Wonky-Task: T-${task.id}')
      ..writeln('Wonky-Claim: ${claimCode ?? claimPlaceholder}')
      ..writeln('```')
      ..writeln()
      ..writeln(
        'and a short summary of how each acceptance criterion is met.',
      );
    return b.toString();
  }

  /// The body admins fill in when no AI is available.
  static const blankBody = '''
## Goal

## Acceptance criteria
- [ ] 

## Specs to read

## Likely code

## Out of scope

## Tests to add
''';
}
