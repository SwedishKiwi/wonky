import '../../common/models.dart';
import 'jev_client.dart';

/// The Jev requests of the board (specs/16 §6.2): state and question
/// wording. The wording follows TypeSafe's notes on `jev-1.13`: every
/// question states its exact condition and boundary cases (literal
/// reading), the state holds only what the questions need, and boundary
/// cases that posts may argue for themselves are spelled out in the
/// criteria (adversarial content).
abstract final class BoardTriageQuestions {
  /// Longest post body sent (Jev's per-question context is 32k tokens).
  static const maxBodyChars = 8000;

  /// Longest excerpt of a duplicate or rerank candidate.
  static const maxCandidateChars = 600;

  /// Most duplicate candidates per triage request.
  static const maxDuplicates = 5;

  static const product =
      'Wonky Work: Drive (files), Write (documents), Sheets (spreadsheets), '
      'Slides (presentations)';

  /// Option descriptions of the `area` Choice, in [BoardArea] order.
  static const areaCriteria = <BoardArea, String>{
    BoardArea.drive:
        'Wonky Drive, the file manager: the list of files and folders, '
        'creating, opening, uploading, downloading, moving, renaming and '
        'deleting files and folders, previews of uploaded files, the trash, '
        'storage space.',
    BoardArea.write:
        'Wonky Write, the document editor: writing and formatting text, '
        'headings, lists, links, tables and images in documents, comments '
        'and suggestions in a document, document history, document themes, '
        'importing, exporting and printing documents.',
    BoardArea.sheets:
        'Wonky Sheets, the spreadsheet: cells, rows and columns, formulas '
        'and functions, number and cell formatting, sorting, filtering, '
        'charts, pivot tables, importing, exporting and printing '
        'spreadsheets.',
    BoardArea.slides:
        'Wonky Slides, the presentation editor: slides, layouts and themes, '
        'text boxes, shapes, images, transitions and animations, speaker '
        'notes, presenting, exporting presentations.',
    BoardArea.suite:
        'Parts shared by all apps: signing in, accounts and passwords, '
        'settings and preferences, the menus and toolbar frame around every '
        'app, switching between apps, sharing and permissions, '
        'notifications, the AI assistant panel, keyboard shortcuts that work '
        'in every app, this bug and idea board.',
    BoardArea.server:
        'Things without a screen of their own: slowness, saving and syncing '
        'changes between devices or people, working offline, lost data, '
        'emails sent by Wonky Work, the service being down or returning '
        'errors.',
  };

  /// Option descriptions of the `size` Choice (specs/16 §2).
  static const sizeCriteria = <BoardSize, String>{
    BoardSize.small:
        'One focused change a developer finishes in a single session: a '
        'wrong label or message, one broken button or shortcut, one missing '
        'option in an existing menu, one visual glitch.',
    BoardSize.medium:
        'A change to one feature area that touches several files and needs '
        'new tests: a new option with its own dialog, a missing import or '
        'export case, a bug that shows up in several places of one app.',
    BoardSize.large:
        'Work across several apps or packages, or a change that needs a new '
        'design or specification first: a new kind of document, a new '
        'collaboration feature, a redesign of a whole screen, offline or '
        'sync changes.',
  };

  // ------------------------------------------------------------ moderation

  static JevQuestion offensive(String subject) => JevQuestion.noul(
    'Does `$subject` insult, harass or demean a person or a group of people, '
    'use slurs, threaten anyone, or contain sexual content?',
    yes:
        'It attacks or demeans people (including the developers or other '
        'users by name or as a group), uses slurs, threatens, or is sexual.',
    no:
        'It does none of these. Rudeness, swearing, sarcasm or frustration '
        'about the product, a feature or a bug (for example "this export is '
        'garbage" or "who designed this terrible menu?") is NOT offensive.',
  );

  static JevQuestion spam(String subject) => JevQuestion.noul(
    'Is `$subject` advertising, link spam, or text that is not about any '
    'software at all?',
    yes:
        'It promotes a product, service or website, is a list of links, or '
        'is unrelated text (a recipe, a story, random characters copied in '
        'bulk).',
    no:
        'It talks about software, even briefly or badly written. A link to '
        'an example, a screenshot or a similar feature in another product is '
        'not spam.',
  );

  static JevQuestion notActionable(String subject) => JevQuestion.noul(
    'Does `$subject` contain no report of a problem and no request for a '
    'change at all?',
    yes:
        'There is nothing to fix or build: a test such as "asdf" or "test", '
        'only a greeting or a thank-you, or a question that asks for help '
        'and describes nothing broken or missing.',
    no:
        'It reports at least one problem or asks for at least one change, '
        'even if it is short, vague or rude.',
  );

  static JevQuestion offTopic(String subject) => JevQuestion.noul(
    'Is `$subject` about a product other than `product`, and not about '
    '`product` at all?',
    yes:
        'It is about another product only (for example Google Docs, '
        'Microsoft Excel, a phone or a game) and asks nothing of `product`.',
    no:
        'It is about `product` or one of its apps. Comparing `product` with '
        'another product, or asking `product` to work like another product, '
        'is NOT off topic.',
  );

  static JevQuestion personalData(String subject) => JevQuestion.noul(
    'Does `$subject` contain an email address, a phone number, a street '
    'address, or the full name of a real person other than its author?',
    yes:
        'It contains at least one email address, phone number, street '
        "address, or another real person's full name (first and last "
        'name).',
    no:
        'It contains none of these. Product names, app names, file names, '
        'example data such as "John Doe" or "test@example.com", and '
        'first names alone are not personal data.',
  );

  static JevQuestion security(String subject) => JevQuestion.noul(
    'Does `$subject` describe a way to see or change other users\' data, '
    "take over someone else's account, run code on the server, or get "
    'around sharing permissions?',
    yes:
        'It describes a security hole: access to files or data the person '
        'should not have, taking over or signing in as someone else, '
        'running code or commands on the server, or bypassing permissions '
        'or sign-in.',
    no:
        'It describes ordinary bugs or ideas about the person\'s own work. '
        'Forgetting a password, a sharing dialog that is confusing, or '
        'asking for a new permission option is NOT a security hole.',
  );

  // --------------------------------------------------------------- triage

  /// The state of a triage request: only what the questions need.
  static Map<String, Object?> postState(BoardPost post) => {
    'post': {
      'kind_chosen_by_author': post.reportedKind.name,
      'title': post.title,
      'body': clip(post.body, maxBodyChars),
    },
    'app_in_use': post.appHint,
    'product': product,
  };

  static JevQuestion kind() => JevQuestion.choice(
    {
      'question':
          'Is `post` a report of something that does not work, or a request '
          'for new or changed behavior?',
      'focus':
          'Decide from `post.title` and `post.body`. '
          '`post.kind_chosen_by_author` is what the author picked and may be '
          'wrong.',
    },
    {
      BoardPostKind.bug.name:
          'Existing behavior is broken or wrong: an error, a crash, lost '
          'data, something that does not do what it says, a visual glitch.',
      BoardPostKind.idea.name:
          'A new feature, or a change to behavior that works as designed: '
          'a missing option, a wish, a different design.',
    },
  );

  static JevQuestion area({bool reversed = false}) {
    final options = {
      for (final e in areaCriteria.entries) e.key.name: e.value,
    };
    return JevQuestion.choice({
      'question': 'Which part of `product` is `post` about?',
      'focus':
          '`app_in_use` is the app the author had open when writing; the '
          'post may still be about another part.',
    }, reversed ? _reverse(options) : options);
  }

  static JevQuestion size({bool reversed = false}) {
    final options = {
      for (final e in sizeCriteria.entries) e.key.name: e.value,
    };
    return JevQuestion.choice(
      'How much work would it take one developer with an AI coding agent '
      'to fix or build what `post` describes?',
      reversed ? _reverse(options) : options,
    );
  }

  static JevQuestion duplicate(BoardPost candidate) => JevQuestion.noul(
    {
      'candidate': {
        'title': candidate.title,
        'body': clip(candidate.body, maxCandidateChars),
      },
      'question':
          'Do `post` and `candidate` describe the same problem or the same '
          'request?',
    },
    yes:
        'Both describe the same broken behavior or ask for the same change, '
        'even in different words.',
    no:
        'They describe different behavior, even if both are about the same '
        'app or feature.',
  );

  static const duplicatePrefix = 'duplicate_';
  static const samePrefix = 'same_';

  /// Question id of the duplicate check of [candidateId].
  static String duplicateId(int candidateId) => '$duplicatePrefix$candidateId';

  /// One request with every triage question (§6.2).
  static JevRequest triage(
    BoardPost post, {
    List<BoardPost> candidates = const [],
    bool reversedChoices = false,
  }) {
    const s = 'post';
    return JevRequest(
      state: postState(post),
      questions: {
        'kind': reversedChoices ? _reversedChoice(kind()) : kind(),
        'area': area(reversed: reversedChoices),
        'size': size(reversed: reversedChoices),
        'offensive': offensive(s),
        'spam': spam(s),
        'not_actionable': notActionable(s),
        'off_topic': offTopic(s),
        'personal_data': personalData(s),
        'security': security(s),
        for (final c
            in candidates
                .where((c) => c.id != null && c.id != post.id)
                .take(maxDuplicates))
          duplicateId(c.id!): duplicate(c),
      },
    );
  }

  /// The moderation-only request of a comment (§6.3 step 6).
  static JevRequest comment(String body) {
    const s = 'comment';
    return JevRequest(
      state: {'comment': clip(body, maxBodyChars), 'product': product},
      questions: {
        'offensive': offensive(s),
        'spam': spam(s),
        'personal_data': personalData(s),
        'security': security(s),
      },
    );
  }

  /// Question id of the rerank check of [candidateId].
  static String sameId(int candidateId) => '$samePrefix$candidateId';

  /// One `same_<id>` Noul per candidate (§6.4).
  static JevRequest rerank({
    required String title,
    required String body,
    required List<BoardPost> candidates,
  }) => JevRequest(
    state: {
      'draft': {'title': title, 'body': clip(body, maxBodyChars)},
    },
    questions: {
      for (final c in candidates.where((c) => c.id != null))
        sameId(c.id!): JevQuestion.noul(
          {
            'candidate': {
              'title': c.title,
              'body': clip(c.body, maxCandidateChars),
            },
            'question':
                'Do `draft` and `candidate` describe the same problem or '
                'the same request?',
          },
          yes:
              'Both describe the same broken behavior or ask for the same '
              'change, even in different words.',
          no:
              'They describe different behavior, even if both are about the '
              'same app or feature.',
        ),
    },
  );

  static String clip(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  static Map<String, Object?> _reverse(Map<String, Object?> m) =>
      Map.fromEntries(m.entries.toList().reversed);

  static JevQuestion _reversedChoice(JevQuestion q) => JevQuestion.choice(
    q.instructions,
    _reverse((q.criteria! as Map).cast<String, Object?>()),
  );
}
