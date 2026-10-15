import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:yaml/yaml.dart';

/// Settings of Bugs & Improvements from the `wonky: board:` section of
/// `config/<runMode>.yaml` (specs/16 §12). The defaults are the production
/// values: Serverpod Cloud does not upload `config/*.yaml`.
///
/// Environment overrides: `WONKY_BOARD_<KEY>` for top-level keys (e.g.
/// `WONKY_BOARD_ENABLED=false`), `WONKY_BOARD_AI_<KEY>` and
/// `WONKY_BOARD_GITHUB_<KEY>` for the nested sections; lists are
/// comma-separated.
class BoardConfig {
  BoardConfig({
    this.enabled = true,
    this.adminEmailDomains = const {'serverpod.dev'},
    this.adminEmails = const {},
    this.repository = 'serverpod/wonky',
    this.securityContact = 'security@serverpod.dev',
    this.claimHours = 48,
    this.claimWarnHours = 6,
    this.maxActiveClaimsPerUser = 2,
    this.flagsToHold = 3,
    this.publishWhenTriageFails = true,
    this.limits = const BoardLimits(),
    BoardAiConfig? ai,
    BoardGithubConfig? github,
  }) : ai = ai ?? BoardAiConfig(),
       github = github ?? BoardGithubConfig();

  final bool enabled;

  /// Users whose account email is in one of these domains are admins
  /// (exact match, lowercase; specs/16 §9.1).
  final Set<String> adminEmailDomains;

  /// Extra individual admins (lowercase emails).
  final Set<String> adminEmails;

  /// `owner/name` of the GitHub repository (PR links, contribute links).
  final String repository;
  final String securityContact;
  final int claimHours;
  final int claimWarnHours;
  final int maxActiveClaimsPerUser;

  /// Distinct users' flags that hold a visible post or comment.
  final int flagsToHold;

  /// Publish (unchecked) when the background triage failed three times;
  /// false holds such posts instead.
  final bool publishWhenTriageFails;
  final BoardLimits limits;
  final BoardAiConfig ai;
  final BoardGithubConfig github;

  Duration get claimDuration => Duration(hours: claimHours);

  static BoardConfig? _current;

  static BoardConfig get current => _current ??= _load();

  /// Replaces the configuration (tests).
  static set current(BoardConfig config) => _current = config;

  static BoardConfig _load() {
    String runMode;
    try {
      runMode = Serverpod.instance.runMode;
    } on Object {
      runMode = ServerpodRunMode.development;
    }
    final file = File('${Directory.current.path}/config/$runMode.yaml');
    Map<dynamic, dynamic> section = const {};
    if (file.existsSync()) {
      final yaml = loadYaml(file.readAsStringSync());
      if (yaml is Map &&
          yaml['wonky'] is Map &&
          yaml['wonky']['board'] is Map) {
        section = yaml['wonky']['board'] as Map;
      }
    }
    return fromMap(section, environment: Platform.environment);
  }

  /// Builds a configuration from the `board:` [map] with [environment]
  /// overrides.
  static BoardConfig fromMap(
    Map<dynamic, dynamic> map, {
    Map<String, String> environment = const {},
  }) {
    final r = _Reader(map, environment, 'WONKY_BOARD_');
    final ai = _Reader(
      map['ai'] is Map ? map['ai'] as Map : const {},
      environment,
      'WONKY_BOARD_AI_',
    );
    final gh = _Reader(
      map['github'] is Map ? map['github'] as Map : const {},
      environment,
      'WONKY_BOARD_GITHUB_',
    );
    final limits = _Reader(
      map['limits'] is Map ? map['limits'] as Map : const {},
      environment,
      'WONKY_BOARD_LIMITS_',
    );
    final thresholds = ai.raw('thresholds');
    const d = BoardLimits();
    return BoardConfig(
      enabled: r.b('enabled', true),
      adminEmailDomains: r.set('adminEmailDomains', const {'serverpod.dev'}),
      adminEmails: r.set('adminEmails', const {}),
      repository: r.s('repository', 'serverpod/wonky'),
      securityContact: r.s('securityContact', 'security@serverpod.dev'),
      claimHours: r.i('claimHours', 48),
      claimWarnHours: r.i('claimWarnHours', 6),
      maxActiveClaimsPerUser: r.i('maxActiveClaimsPerUser', 2),
      flagsToHold: r.i('flagsToHold', 3),
      publishWhenTriageFails: r.b('publishWhenTriageFails', true),
      limits: BoardLimits(
        postsPerHour: limits.i('postsPerHour', d.postsPerHour),
        postsPerDay: limits.i('postsPerDay', d.postsPerDay),
        commentsPerHour: limits.i('commentsPerHour', d.commentsPerHour),
        votesPerHour: limits.i('votesPerHour', d.votesPerHour),
        flagsPerDay: limits.i('flagsPerDay', d.flagsPerDay),
        similarPerMinute: limits.i('similarPerMinute', d.similarPerMinute),
      ),
      ai: BoardAiConfig(
        jevModel: ai.s('jevModel', 'jev-1.13.0'),
        geminiModel: ai.s('geminiModel', 'gemini-2.5-pro'),
        geminiFastModel: ai.s('geminiFastModel', 'gemini-2.5-flash'),
        jevDailyTokenBudget: ai.i('jevDailyTokenBudget', 20000000),
        geminiDailyTokenBudget: ai.i('geminiDailyTokenBudget', 5000000),
        thresholds: BoardAiThresholds.fromMap(
          thresholds is Map ? thresholds : const {},
        ),
      ),
      github: BoardGithubConfig(
        enabled: gh.b('enabled', false),
        appId: gh.i('appId', 0),
        maintainerOrg: gh.s('maintainerOrg', 'serverpod'),
        autoCloseDays: gh.i('autoCloseDays', 7),
        reviewBlocking: gh.b('reviewBlocking', false),
        reviewsPerPrPerDay: gh.i('reviewsPerPrPerDay', 10),
        maxDiffTokens: gh.i('maxDiffTokens', 400000),
        deployWorkflow: gh.s('deployWorkflow', 'deploy.yml'),
      ),
    );
  }
}

/// Per-user rate limits of the board (specs/16 §11).
class BoardLimits {
  const BoardLimits({
    this.postsPerHour = 5,
    this.postsPerDay = 20,
    this.commentsPerHour = 30,
    this.votesPerHour = 300,
    this.flagsPerDay = 30,
    this.similarPerMinute = 60,
  });

  final int postsPerHour;
  final int postsPerDay;
  final int commentsPerHour;
  final int votesPerHour;
  final int flagsPerDay;
  final int similarPerMinute;
}

/// The board AI (specs/16 §6). Keys are the passwords [jevPassword] and
/// [geminiPassword], separate from the in-app AI.
class BoardAiConfig {
  BoardAiConfig({
    this.jevModel = 'jev-1.13.0',
    this.geminiModel = 'gemini-2.5-pro',
    this.geminiFastModel = 'gemini-2.5-flash',
    this.jevDailyTokenBudget = 20000000,
    this.geminiDailyTokenBudget = 5000000,
    BoardAiThresholds? thresholds,
  }) : thresholds = thresholds ?? const BoardAiThresholds();

  static const jevPassword = 'internalJevApiKey';
  static const geminiPassword = 'internalGeminiApiKey';

  final String jevModel;
  final String geminiModel;
  final String geminiFastModel;
  final int jevDailyTokenBudget;
  final int geminiDailyTokenBudget;
  final BoardAiThresholds thresholds;
}

/// Hold / review bands of the moderation decisions (specs/16 §6.2).
class BoardAiThresholds {
  const BoardAiThresholds({
    this.securityHold = 0.5,
    this.securityReview = 0.2,
    this.harmHold = 0.7,
    this.harmReview = 0.4,
    this.junkHold = 0.85,
    this.junkReview = 0.5,
    this.kindCorrection = 0.8,
    this.labelConfidence = 0.5,
    this.duplicate = 0.8,
    this.rerank = 0.3,
  });

  /// `security` Noul.
  final double securityHold;
  final double securityReview;

  /// `offensive` and `personal_data`.
  final double harmHold;
  final double harmReview;

  /// `spam`, `not_actionable`, `off_topic`.
  final double junkHold;
  final double junkReview;

  /// Confidence of the other kind needed to correct bug ↔ idea.
  final double kindCorrection;

  /// Confidence needed to set area and size.
  final double labelConfidence;

  /// Duplicate hint for admins.
  final double duplicate;

  /// Similar posts shown in the dialog.
  final double rerank;

  static BoardAiThresholds fromMap(Map<dynamic, dynamic> m) {
    const d = BoardAiThresholds();
    double v(String k, double f) {
      final x = m[k];
      return x is num ? x.toDouble() : f;
    }

    return BoardAiThresholds(
      securityHold: v('securityHold', d.securityHold),
      securityReview: v('securityReview', d.securityReview),
      harmHold: v('harmHold', d.harmHold),
      harmReview: v('harmReview', d.harmReview),
      junkHold: v('junkHold', d.junkHold),
      junkReview: v('junkReview', d.junkReview),
      kindCorrection: v('kindCorrection', d.kindCorrection),
      labelConfidence: v('labelConfidence', d.labelConfidence),
      duplicate: v('duplicate', d.duplicate),
      rerank: v('rerank', d.rerank),
    );
  }
}

/// The GitHub App integration (specs/16 §13). Passwords:
/// [privateKeyPassword], [webhookSecretPassword].
class BoardGithubConfig {
  BoardGithubConfig({
    this.enabled = false,
    this.appId = 0,
    this.maintainerOrg = 'serverpod',
    this.autoCloseDays = 7,
    this.reviewBlocking = false,
    this.reviewsPerPrPerDay = 10,
    this.maxDiffTokens = 400000,
    this.deployWorkflow = 'deploy.yml',
  });

  static const privateKeyPassword = 'githubAppPrivateKey';
  static const webhookSecretPassword = 'githubWebhookSecret';

  final bool enabled;
  final int appId;
  final String maintainerOrg;
  final int autoCloseDays;
  final bool reviewBlocking;
  final int reviewsPerPrPerDay;
  final int maxDiffTokens;
  final String deployWorkflow;
}

class _Reader {
  _Reader(this.map, this.env, this.prefix);

  final Map<dynamic, dynamic> map;
  final Map<String, String> env;
  final String prefix;

  Object? raw(String key) {
    final e = env['$prefix${_snake(key)}'];
    return e ?? map[key];
  }

  bool b(String key, bool fallback) {
    final v = raw(key);
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return fallback;
  }

  int i(String key, int fallback) {
    final v = raw(key);
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  String s(String key, String fallback) {
    final v = raw(key);
    return v == null || '$v'.isEmpty ? fallback : '$v';
  }

  Set<String> set(String key, Set<String> fallback) {
    final v = raw(key);
    if (v is String) {
      return {
        for (final p in v.split(','))
          if (p.trim().isNotEmpty) p.trim().toLowerCase(),
      };
    }
    if (v is List) return {for (final p in v) '$p'.trim().toLowerCase()};
    return fallback;
  }

  static String _snake(String key) =>
      key.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}').toUpperCase();
}
