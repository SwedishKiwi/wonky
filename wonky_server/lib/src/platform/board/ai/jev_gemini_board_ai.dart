import 'package:serverpod/serverpod.dart';

import '../../ai/llm/ai_client.dart';
import '../../ai/llm/dartantic_ai_client.dart';
import '../../common/models.dart';
import '../board_config.dart';
import 'board_ai.dart';
import 'board_ai_ledger.dart';
import 'board_gemini.dart';
import 'board_triage_questions.dart';
import 'jev_client.dart';

/// Thrown when today's board AI budget of a provider is spent
/// (specs/16 §6.1): Jev → triage runs unchecked; Gemini → *Today's AI
/// budget is used up*.
class BoardAiBudgetException extends BoardAiException {
  BoardAiBudgetException(this.provider)
    : super("Today's AI budget is used up.", retryable: false);

  /// `jev` or `gemini`.
  final String provider;
}

/// The production [BoardAi] (specs/16 §6): Jev for every decision, Gemini
/// for everything that writes. Keys are the passwords
/// [BoardAiConfig.jevPassword] and [BoardAiConfig.geminiPassword], read
/// for each call (never the in-app keys); usage goes to [BoardAiLedger].
class JevGeminiBoardAi implements BoardAi {
  JevGeminiBoardAi({
    String? Function(String name)? password,
    JevClient Function(String apiKey, String model)? jevClient,
    AiModelClient Function(String apiKey)? geminiClient,
    BoardConfig Function()? config,
  }) : _password = password ?? _serverPassword,
       _jevFactory = jevClient ?? _httpJev,
       _geminiFactory = geminiClient ?? _dartanticGemini,
       _config = config ?? (() => BoardConfig.current);

  /// A board AI on fixed clients (tests): configured exactly for the
  /// clients given.
  factory JevGeminiBoardAi.withClients({
    JevClient? jev,
    AiModelClient? gemini,
    BoardConfig Function()? config,
  }) => JevGeminiBoardAi(
    password: (name) => switch (name) {
      BoardAiConfig.jevPassword when jev != null => 'test-jev-key',
      BoardAiConfig.geminiPassword when gemini != null => 'test-gemini-key',
      _ => null,
    },
    jevClient: (_, _) => jev!,
    geminiClient: (_) => gemini!,
    config: config,
  );

  /// Installs the production board AI as [BoardAi.factory] (server start).
  static void install() {
    final shared = JevGeminiBoardAi();
    BoardAi.factory = () => shared;
  }

  final String? Function(String name) _password;
  final JevClient Function(String apiKey, String model) _jevFactory;
  final AiModelClient Function(String apiKey) _geminiFactory;
  final BoardConfig Function() _config;

  (String, String, JevClient)? _jev;
  (String, AiModelClient)? _gemini;

  static String? _serverPassword(String name) {
    try {
      return Serverpod.instance.getPassword(name);
    } on Object {
      return null;
    }
  }

  static JevClient _httpJev(String key, String model) =>
      HttpJevClient(apiKey: key, model: model);

  static AiModelClient _dartanticGemini(String key) =>
      DartanticAiClient(provider: AiProvider.gemini, apiKey: key);

  BoardAiConfig get _ai => _config().ai;

  String? _key(String name) {
    final k = _password(name)?.trim();
    return k == null || k.isEmpty ? null : k;
  }

  JevClient? _jevClient() {
    final key = _key(BoardAiConfig.jevPassword);
    if (key == null) return null;
    final model = _ai.jevModel;
    final cached = _jev;
    if (cached != null && cached.$1 == key && cached.$2 == model) {
      return cached.$3;
    }
    final client = _jevFactory(key, model);
    _jev = (key, model, client);
    return client;
  }

  BoardGemini? _boardGemini() {
    final key = _key(BoardAiConfig.geminiPassword);
    if (key == null) return null;
    final cached = _gemini;
    final client = cached != null && cached.$1 == key
        ? cached.$2
        : _geminiFactory(key);
    _gemini = (key, client);
    return BoardGemini(
      client,
      model: _ai.geminiModel,
      fastModel: _ai.geminiFastModel,
    );
  }

  // --------------------------------------------------------- availability

  @override
  bool get jevConfigured => _key(BoardAiConfig.jevPassword) != null;

  @override
  bool get geminiConfigured => _key(BoardAiConfig.geminiPassword) != null;

  @override
  Future<bool> jevAvailable(Session session) async =>
      jevConfigured &&
      await BoardAiLedger.usedToday(session, BoardAiLedger.jev) <
          _ai.jevDailyTokenBudget;

  @override
  Future<bool> geminiAvailable(Session session) async =>
      geminiConfigured &&
      await BoardAiLedger.usedToday(session, BoardAiLedger.gemini) <
          _ai.geminiDailyTokenBudget;

  Future<JevClient> _requireJev(Session session) async {
    final client = _jevClient();
    if (client == null) {
      throw BoardAiException('Jev is not configured.', retryable: false);
    }
    final used = await BoardAiLedger.usedToday(session, BoardAiLedger.jev);
    if (used >= _ai.jevDailyTokenBudget) {
      throw BoardAiBudgetException(BoardAiLedger.jev);
    }
    return client;
  }

  Future<BoardGemini> _requireGemini(Session session) async {
    final gemini = _boardGemini();
    if (gemini == null) {
      throw BoardAiException('Gemini is not configured.', retryable: false);
    }
    final used = await BoardAiLedger.usedToday(session, BoardAiLedger.gemini);
    if (used >= _ai.geminiDailyTokenBudget) {
      throw BoardAiBudgetException(BoardAiLedger.gemini);
    }
    return gemini;
  }

  Future<JevResult> _askJev(
    Session session,
    String feature,
    JevRequest request,
    Duration timeout,
  ) async {
    final client = await _requireJev(session);
    final r = await client.ask(request, timeout: timeout);
    try {
      await BoardAiLedger.record(
        session,
        provider: BoardAiLedger.jev,
        model: r.model,
        feature: feature,
        inputTokens: r.inputTokens,
        outputTokens: r.outputTokens,
      );
    } on Object catch (e) {
      session.log('Board AI usage not recorded: $e', level: LogLevel.warning);
    }
    return r;
  }

  // ------------------------------------------------------------ decisions

  @override
  Future<BoardTriage> triagePost(
    Session session,
    BoardPost post, {
    List<BoardPost> candidates = const [],
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final request = BoardTriageQuestions.triage(post, candidates: candidates);
    final r = await _askJev(session, 'triage', request, timeout);
    return triageFrom(r, post, _ai.thresholds);
  }

  /// Reads a triage answer: labels only above
  /// [BoardAiThresholds.labelConfidence].
  static BoardTriage triageFrom(
    JevResult r,
    BoardPost post,
    BoardAiThresholds thresholds,
  ) {
    T? label<T extends Enum>(String id, List<T> values) {
      final a = r.answers[id];
      if (a == null || (a.confidence ?? 0) < thresholds.labelConfidence) {
        return null;
      }
      return values.where((v) => v.name == a.choice).firstOrNull;
    }

    final kindAnswer = r.answers['kind'];
    final kind = BoardPostKind.values
        .where((k) => k.name == kindAnswer?.choice)
        .firstOrNull;
    const prefix = BoardTriageQuestions.duplicatePrefix;
    return BoardTriage(
      scores: _scores(r),
      kind: kind ?? post.reportedKind,
      kindConfidence: kind == null ? 0 : kindAnswer?.confidence ?? 0,
      area: label('area', BoardArea.values),
      size: label('size', BoardSize.values),
      duplicates: {
        for (final MapEntry(:key, :value) in r.answers.entries)
          if (key.startsWith(prefix))
            ?int.tryParse(key.substring(prefix.length)): ?value.noul,
      },
      model: r.model,
    );
  }

  static BoardModerationScores _scores(JevResult r) => BoardModerationScores(
    offensive: r.noul('offensive'),
    spam: r.noul('spam'),
    notActionable: r.noul('not_actionable'),
    offTopic: r.noul('off_topic'),
    personalData: r.noul('personal_data'),
    security: r.noul('security'),
  );

  @override
  Future<BoardModerationScores> checkComment(
    Session session,
    String body, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final r = await _askJev(
      session,
      'comment',
      BoardTriageQuestions.comment(body),
      timeout,
    );
    return _scores(r);
  }

  @override
  Future<List<(int, double)>> rerankSimilar(
    Session session, {
    required String title,
    required String body,
    required List<BoardPost> candidates,
  }) async {
    final ids = [
      for (final c in candidates)
        if (c.id != null) c.id!,
    ];
    if (ids.isEmpty) return const [];
    final r = await _askJev(
      session,
      'rerank',
      BoardTriageQuestions.rerank(
        title: title,
        body: body,
        candidates: candidates,
      ),
      const Duration(seconds: 5),
    );
    final ranked = [
      for (final id in ids) (id, r.noul(BoardTriageQuestions.sameId(id))),
    ];
    // Stable: equal probabilities keep the full-text order.
    final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    ranked.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : order[a.$1]!.compareTo(order[b.$1]!);
    });
    return ranked;
  }

  // -------------------------------------------------------------- writing

  @override
  Future<({String? title, String summary})> summarize(
    Session session,
    BoardPost post,
  ) async => (await _requireGemini(session)).summarize(session, post);

  @override
  Future<List<BoardBundleProposal>> suggestBundles(
    Session session,
    List<BoardPost> posts,
  ) async => (await _requireGemini(session)).suggestBundles(session, posts);

  @override
  Future<String> writeTaskPrompt(
    Session session, {
    required BoardTask task,
    required List<BoardPost> posts,
    required Map<int, List<BoardComment>> comments,
    required Uri webOrigin,
  }) async => (await _requireGemini(session)).writeTaskPrompt(
    session,
    task: task,
    posts: posts,
    comments: comments,
    webOrigin: webOrigin,
  );
}
