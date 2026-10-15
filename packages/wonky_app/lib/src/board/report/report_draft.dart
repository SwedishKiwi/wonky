import 'package:wonky_client/wonky_client.dart';

import '../../bootstrap/app_urls.dart';
import '../../core/local_store.dart';

/// The text fields of the report dialog (specs/16 §4.2.1). The names are
/// stable: draft storage, keys `dialog.board.report.<name>`, MCP fields.
enum BoardReportField {
  title,

  /// Bug: *What happened?* (required) → `## What happened`.
  happened,

  /// Bug: *What did you expect?* → `## Expected`.
  expected,

  /// Bug: *Steps to reproduce* → `## Steps to reproduce`.
  steps,

  /// Improvement: *What would you like?* (required) → `## Idea`.
  idea,

  /// Improvement: *Why would it help?* → `## Why`.
  why;

  /// The body fields of [kind], in order.
  static List<BoardReportField> bodyFields(BoardPostKind kind) =>
      kind == BoardPostKind.bug
      ? const [happened, expected, steps]
      : const [idea, why];

  /// The required body field of [kind].
  static BoardReportField requiredField(BoardPostKind kind) =>
      kind == BoardPostKind.bug ? happened : idea;

  /// The Markdown section heading of the field in the post body.
  String get heading => switch (this) {
    title => '',
    happened => 'What happened',
    expected => 'Expected',
    steps => 'Steps to reproduce',
    idea => 'Idea',
    why => 'Why',
  };
}

/// Limits of a post (specs/16 §4.2.1).
abstract final class BoardReportLimits {
  static const titleMin = 8;
  static const titleMax = 120;
  static const bodyMax = 10000;
}

/// What the report dialog holds: the kind, the text of every field (both
/// kinds, so switching keeps the text) and the last-error opt-in.
@immutable
class BoardReportDraft {
  const BoardReportDraft({
    this.kind = BoardPostKind.bug,
    this.text = const {},
    this.includeError,
  });

  final BoardPostKind kind;
  final Map<BoardReportField, String> text;

  /// The user's choice for *Include the last error* (null: the default).
  final bool? includeError;

  String operator [](BoardReportField f) => text[f] ?? '';

  BoardReportDraft copyWith({
    BoardPostKind? kind,
    Map<BoardReportField, String>? text,
    bool? includeError,
  }) => BoardReportDraft(
    kind: kind ?? this.kind,
    text: text ?? this.text,
    includeError: includeError ?? this.includeError,
  );

  /// Whether any field has text (closing then asks *Discard draft?*).
  bool get hasContent => text.values.any((t) => t.trim().isNotEmpty);

  /// The post body: the kind's sections as Markdown, empty ones omitted.
  String get body => buildBoardReportBody(kind, text);

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'text': {
      for (final e in text.entries)
        if (e.value.isNotEmpty) e.key.name: e.value,
    },
    'includeError': ?includeError,
  };

  static BoardReportDraft? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = BoardPostKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final raw = json['text'];
    final text = <BoardReportField, String>{};
    if (raw is Map) {
      for (final f in BoardReportField.values) {
        final v = raw[f.name];
        if (v is String) text[f] = v;
      }
    }
    final include = json['includeError'];
    return BoardReportDraft(
      kind: kind ?? BoardPostKind.bug,
      text: text,
      includeError: include is bool ? include : null,
    );
  }
}

/// The post body of [kind] from [text] (specs/16 §4.2.1): `## <heading>`
/// sections in order, empty sections omitted.
String buildBoardReportBody(
  BoardPostKind kind,
  Map<BoardReportField, String> text,
) => [
  for (final f in BoardReportField.bodyFields(kind))
    if ((text[f] ?? '').trim().isNotEmpty)
      '## ${f.heading}\n\n${text[f]!.trim()}',
].join('\n\n');

/// A validation problem of a draft.
enum BoardReportProblem { titleLength, required, bodyTooLong }

/// Validates [draft] for posting: the title 8–120 characters, the kind's
/// required field, the body at most 10,000 characters.
Map<BoardReportField, BoardReportProblem> validateBoardReport(
  BoardReportDraft draft,
) {
  final problems = <BoardReportField, BoardReportProblem>{};
  final title = draft[BoardReportField.title].trim();
  if (title.length < BoardReportLimits.titleMin ||
      title.length > BoardReportLimits.titleMax) {
    problems[BoardReportField.title] = BoardReportProblem.titleLength;
  }
  final req = BoardReportField.requiredField(draft.kind);
  if (draft[req].trim().isEmpty) {
    problems[req] = BoardReportProblem.required;
  } else if (draft.body.length > BoardReportLimits.bodyMax) {
    problems[req] = BoardReportProblem.bodyTooLong;
  }
  return problems;
}

/// The report dialog's draft in the user's local store, keyed by the app
/// (specs/16 §4.2.1): kept while the dialog is open, after *See all posts*
/// and *Vote instead*, cleared by posting and *Discard*.
class BoardReportDraftStore {
  BoardReportDraftStore(this.store, this.app);

  final LocalStore store;
  final WonkyAppKind app;

  String get key => 'board.reportDraft.${app.name}';

  Future<BoardReportDraft?> load() async {
    try {
      return BoardReportDraft.fromJson(await store.read(key));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(BoardReportDraft draft) =>
      draft.hasContent ? store.write(key, draft.toJson()) : store.remove(key);

  Future<void> clear() => store.remove(key);
}
