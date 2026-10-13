import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:yaml/yaml.dart';

import '../config/wonky_config.dart';
import 'anthropic/anthropic_client.dart';

/// Settings of the AI assistant from the `wonky: ai:` section of
/// `config/<runMode>.yaml` (suite 10 §1):
///
/// ```yaml
/// wonky:
///   features:
///     ai: true                      # server-wide switch (also feature flag)
///   ai:
///     enabled: true
///     dailyTokenBudget: 2000000     # per user, all models
///     maxConcurrentRequests: 2      # per user
///     requestTimeoutMinutes: 10
///     maxToolRounds: 30             # model requests per assistant run
///     baseUrl: https://api.anthropic.com
/// ```
///
/// The API key is the `anthropicApiKey` entry of `config/passwords.yaml`
/// (or the `SERVERPOD_PASSWORD_anthropicApiKey` environment variable). Without
/// it the assistant reports "AI isn't configured on this server".
/// Environment overrides: `WONKY_AI_ENABLED`, `WONKY_AI_DAILY_TOKEN_BUDGET`.
class AiConfig {
  AiConfig({
    this.enabled = true,
    this.apiKey,
    this.dailyTokenBudget = 2000000,
    this.maxConcurrentRequests = 2,
    this.requestTimeout = const Duration(minutes: 10),
    this.maxToolRounds = 30,
    this.baseUrl = 'https://api.anthropic.com',
  });

  /// `features.ai` and `ai.enabled`.
  final bool enabled;

  /// `anthropicApiKey` from the passwords file; null = not configured.
  final String? apiKey;
  final int dailyTokenBudget;
  final int maxConcurrentRequests;
  final Duration requestTimeout;

  /// Model requests per assistant run before it stops.
  final int maxToolRounds;
  final String baseUrl;

  bool get configured => apiKey != null && apiKey!.trim().isNotEmpty;

  static AiConfig? _current;
  static AnthropicClient? _client;

  /// The configuration of the running server (loaded on first use).
  static AiConfig get current => _current ??= _load();

  /// Replaces the configuration (tests).
  static set current(AiConfig config) {
    _current = config;
    _client = null;
  }

  /// The model client: [clientOverride] in tests, else an
  /// [HttpAnthropicClient] with the configured key (null when the key is
  /// missing).
  static AnthropicClient? get client {
    final o = clientOverride;
    if (o != null) return o;
    final c = current;
    if (!c.configured) return null;
    return _client ??= HttpAnthropicClient(
      apiKey: c.apiKey!.trim(),
      baseUrl: c.baseUrl,
      requestTimeout: c.requestTimeout,
      log: (m) => _log(m),
    );
  }

  /// A client used instead of the HTTP client (tests, fixtures).
  static AnthropicClient? clientOverride;

  static void _log(String m) {
    try {
      Serverpod.instance.logVerbose(m);
    } on Object {
      // No server (tests).
    }
  }

  static AiConfig _load() {
    String runMode;
    String? key;
    try {
      final pod = Serverpod.instance;
      runMode = pod.runMode;
      key = pod.getPassword('anthropicApiKey');
    } on Object {
      runMode = ServerpodRunMode.development;
    }
    final file = File('${Directory.current.path}/config/$runMode.yaml');
    Map<dynamic, dynamic> section = const {};
    if (file.existsSync()) {
      final yaml = loadYaml(file.readAsStringSync());
      if (yaml is Map && yaml['wonky'] is Map && yaml['wonky']['ai'] is Map) {
        section = yaml['wonky']['ai'] as Map;
      }
    }
    return fromMap(
      section,
      apiKey: key,
      featureEnabled: WonkyConfig.current.aiEnabled,
      environment: Platform.environment,
    );
  }

  /// Builds a configuration from the `wonky: ai:` [map].
  static AiConfig fromMap(
    Map<dynamic, dynamic> map, {
    String? apiKey,
    bool featureEnabled = true,
    Map<String, String> environment = const {},
  }) {
    Object? read(String key, String env) => environment[env] ?? map[key];
    bool b(String key, String env, bool fallback) {
      final v = read(key, env);
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      return fallback;
    }

    int i(String key, String env, int fallback) {
      final v = read(key, env);
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return AiConfig(
      enabled: featureEnabled && b('enabled', 'WONKY_AI_ENABLED', true),
      apiKey: apiKey,
      dailyTokenBudget: i(
        'dailyTokenBudget',
        'WONKY_AI_DAILY_TOKEN_BUDGET',
        2000000,
      ),
      maxConcurrentRequests: i(
        'maxConcurrentRequests',
        'WONKY_AI_MAX_CONCURRENT_REQUESTS',
        2,
      ),
      requestTimeout: Duration(
        minutes: i(
          'requestTimeoutMinutes',
          'WONKY_AI_REQUEST_TIMEOUT_MINUTES',
          10,
        ),
      ),
      maxToolRounds: i('maxToolRounds', 'WONKY_AI_MAX_TOOL_ROUNDS', 30),
      baseUrl:
          '${read('baseUrl', 'WONKY_AI_BASE_URL') ?? 'https://api.anthropic.com'}',
    );
  }
}
