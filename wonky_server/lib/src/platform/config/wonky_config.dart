import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:yaml/yaml.dart';

/// Wonky Work settings from the `wonky:` section of `config/<runMode>.yaml`
/// (specs/01-architecture.md §6). Serverpod ignores the section; this class
/// reads it. Environment variables `WONKY_<SECTION>_<KEY>` override values,
/// e.g. `WONKY_FEATURES_AI=false`.
class WonkyConfig {
  WonkyConfig({
    this.aiEnabled = true,
    this.scriptingEnabled = false,
    this.mcpUiBridgeEnabled = true,
    this.experimentalCharts = false,
    this.maxCellsPerSpreadsheet = 1000000,
    this.maxActiveSpacesPerUser = 30,
    this.maxSheetsPerSpreadsheet = 200,
    this.scriptTimeoutMs = 30000,
    this.scriptDailyQuotaMs = 5400000,
    this.snapshotEveryNOps = 500,
    this.maxDocumentChars = 2000000,
    this.maxImageUploadBytes = 20 * 1024 * 1024,
    this.maxImportUploadBytes = 100 * 1024 * 1024,
    this.minClientVersion = '1.0.0',
    this.serverVersion = '1.0.0',
    this.publicWebUrl,
    this.busFlushMs = 1000,
  });

  /// The public origin of the web apps in production (`wonky.work`).
  /// Serverpod Cloud generates the server config with its own hosts, and
  /// `config/*.yaml` is not uploaded (`.scloudignore`), so production
  /// defaults to this in code.
  static const productionWebUrl = 'https://wonky.work';

  final bool aiEnabled;
  final bool scriptingEnabled;
  final bool mcpUiBridgeEnabled;
  final bool experimentalCharts;
  final int maxCellsPerSpreadsheet;
  final int maxActiveSpacesPerUser;
  final int maxSheetsPerSpreadsheet;
  final int scriptTimeoutMs;
  final int scriptDailyQuotaMs;
  final int snapshotEveryNOps;
  final int maxDocumentChars;
  final int maxImageUploadBytes;
  final int maxImportUploadBytes;
  final String minClientVersion;
  final String serverVersion;

  /// The origin users reach the apps on (`publicWebUrl` / env
  /// `WONKY_PUBLIC_WEB_URL`), when it differs from the web server's
  /// configured public host. Used for every public link: the apps' config,
  /// emails, MCP links, the legal pages and the Google sign-in redirect.
  final String? publicWebUrl;

  /// How long bus messages wait before they are relayed to the other
  /// instances in one Redis publish (`cluster.busFlushMs`, specs/13 §4).
  final int busFlushMs;

  /// [publicWebUrl] or, without it, the web server's public URL in
  /// [config].
  Uri webOrigin(ServerpodConfig config) {
    final url = publicWebUrl;
    if (url != null && url.isNotEmpty) return Uri.parse(url).resolve('/');
    final server = config.webServer ?? config.apiServer;
    return Uri(
      scheme: server.publicScheme,
      host: server.publicHost,
      port: server.publicPort,
    ).resolve('/');
  }

  static WonkyConfig? _current;

  /// The configuration of the running server, loaded on first use from the
  /// config file of [Serverpod.instance]'s run mode.
  static WonkyConfig get current => _current ??= _loadForRunningServer();

  /// Replaces the current configuration (tests).
  static set current(WonkyConfig config) => _current = config;

  static WonkyConfig _loadForRunningServer() {
    String runMode;
    try {
      runMode = Serverpod.instance.runMode;
    } catch (_) {
      runMode = ServerpodRunMode.development;
    }
    return load(runMode);
  }

  /// Loads the configuration for [runMode] from `config/<runMode>.yaml`
  /// relative to [directory] (default: the working directory).
  static WonkyConfig load(String runMode, {Directory? directory}) {
    final file = File(
      '${(directory ?? Directory.current).path}/config/$runMode.yaml',
    );
    Map<dynamic, dynamic> section = const {};
    if (file.existsSync()) {
      final yaml = loadYaml(file.readAsStringSync());
      if (yaml is Map && yaml['wonky'] is Map) {
        section = yaml['wonky'] as Map;
      }
    }
    return fromMap(
      section,
      environment: Platform.environment,
      defaultPublicWebUrl: runMode == ServerpodRunMode.production
          ? productionWebUrl
          : null,
    );
  }

  /// Builds a configuration from the `wonky:` [map], applying [environment]
  /// overrides.
  static WonkyConfig fromMap(
    Map<dynamic, dynamic> map, {
    Map<String, String> environment = const {},
    String? defaultPublicWebUrl,
  }) {
    Object? read(String section, String key) {
      final envKey = 'WONKY_${section.toUpperCase()}_${_snake(key)}';
      final env = environment[envKey];
      if (env != null) return env;
      final s = section.isEmpty ? map : map[section];
      return s is Map ? s[key] : null;
    }

    bool b(String section, String key, bool fallback) {
      final v = read(section, key);
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      return fallback;
    }

    int i(String section, String key, int fallback) {
      final v = read(section, key);
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    String s(String key, String fallback) {
      final env = environment['WONKY_${_snake(key)}'];
      if (env != null) return env;
      final v = map[key];
      return v == null ? fallback : '$v';
    }

    return WonkyConfig(
      aiEnabled: b('features', 'ai', true),
      scriptingEnabled: b('features', 'scripting', false),
      mcpUiBridgeEnabled: b('features', 'mcpUiBridge', true),
      experimentalCharts: b('features', 'experimentalCharts', false),
      maxCellsPerSpreadsheet: i('sheets', 'maxCellsPerSpreadsheet', 1000000),
      maxActiveSpacesPerUser: i('sheets', 'maxActiveSpacesPerUser', 30),
      maxSheetsPerSpreadsheet: i('sheets', 'maxSheetsPerSpreadsheet', 200),
      scriptTimeoutMs: i('sheets', 'scriptTimeoutMs', 30000),
      scriptDailyQuotaMs: i('sheets', 'scriptDailyQuotaMs', 5400000),
      snapshotEveryNOps: i('write', 'snapshotEveryNOps', 500),
      maxDocumentChars: i('write', 'maxDocumentChars', 2000000),
      maxImageUploadBytes: i('files', 'maxImageUploadBytes', 20 * 1024 * 1024),
      maxImportUploadBytes: i(
        'files',
        'maxImportUploadBytes',
        100 * 1024 * 1024,
      ),
      minClientVersion: s('minClientVersion', '1.0.0'),
      serverVersion: s('serverVersion', '1.0.0'),
      busFlushMs: i('cluster', 'busFlushMs', 1000),
      publicWebUrl:
          environment['WONKY_PUBLIC_WEB_URL'] ??
          (map['publicWebUrl'] as String?) ??
          defaultPublicWebUrl,
    );
  }

  static String _snake(String key) =>
      key.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}').toUpperCase();
}
