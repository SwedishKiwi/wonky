import 'dart:io';

import 'package:clock/clock.dart';
import 'package:serverpod/protocol.dart' as sp show FutureCallEntry;
import 'package:serverpod/serverpod.dart' as sp show Serverpod;
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_cloud_storage/serverpod_cloud_storage.dart';

import 'src/cache_busting.dart';
import 'src/generated/future_calls.dart' show FutureCalls;
import 'src/generated/serverpod.dart';
import 'src/platform/cluster/cluster.dart';
import 'src/platform/cluster/cluster_bus.dart';
import 'src/platform/config/wonky_config.dart';
import 'src/platform/mcp/mcp_route.dart';
import 'src/platform/users/email_idp.dart';
import 'src/platform/users/google_idp.dart';
import 'src/platform/versions/version_service.dart';
import 'src/sheets/versions/sheets_version_provider.dart';
import 'src/web/routes/app_config_route.dart';
import 'src/web/routes/invite_route.dart';
import 'src/web/routes/root_redirect_route.dart';
import 'src/write/themes/theme_service.dart';
import 'src/write/versions/write_version_provider.dart';

/// The starting point of the Wonky Work server.
void run(List<String> args) async {
  // The generated Serverpod is wired with the protocol, the endpoints and
  // the offline-sync engine for the `database: sync` tables.
  final pod = Serverpod(args);

  // One sign-in for both apps: email/password with JWTs (specs/04).
  pod.initializeAuthServices(
    tokenManagerBuilders: [JwtConfigFromPasswords()],
    identityProviderBuilders: [wonkyEmailIdpConfig(), ?wonkyGoogleIdpConfig()],
  );

  registerVersionProviders();
  _configureWebServer(pod);

  // Cloud storage for uploads, exports and snapshots. Works with Serverpod
  // Cloud without configuration; falls back to the database elsewhere.
  pod.addCloudStorage(
    await ServerpodCloudProvider.private(
      fallback: () => DatabaseCloudStorage('private'),
    ),
  );
  pod.addCloudStorage(
    await ServerpodCloudProvider.public(
      fallback: () => DatabaseCloudStorage('public'),
    ),
  );

  await pod.start();
  // Bus messages from the other instances arrive in batches (specs/13 §4).
  ClusterBus.flushInterval = Duration(
    milliseconds: WonkyConfig.current.busFlushMs,
  );
  await ClusterBus.listen(pod);

  final session = await pod.createSession(enableLogging: false);
  try {
    await ThemeService.upsertBuiltins(session);
    if (pod.redisController == null &&
        (pod.runMode == ServerpodRunMode.staging ||
            pod.runMode == ServerpodRunMode.production)) {
      stderr.writeln(
        'WARNING: Redis is disabled: run this server as a single instance. '
        'Several instances need Redis for global messages (specs/13 §4).',
      );
    }
  } finally {
    await session.close();
  }
  await scheduleMaintenanceJobs(pod);
}

/// Registers the per-app version providers (specs/07 §5).
void registerVersionProviders() {
  VersionService.register(const WriteVersionProvider());
  VersionService.register(const SheetsVersionProvider());
}

/// Web routes (specs/01 §2.4): both Flutter web apps on one origin, their
/// runtime config, the root redirect and share-link landing.
void _configureWebServer(Serverpod pod) {
  pod.webServer.addRoute(
    StaticRoute.withCacheBusting(cacheBustingConfig),
    cacheBustingConfig.mountPrefix,
  );
  pod.webServer.addRoute(RootRedirectRoute(), '/');
  // Sign in with Google on web (specs/04 §1.6): the OAuth2 redirect lands
  // here and hands the code back to the app's sign-in popup.
  pod.webServer.addRoute(FlutterWebAuth2CallbackRoute(), '/auth/callback');
  // Legal pages (specs/13 §5), linked from account creation.
  for (final page in const ['privacy', 'terms']) {
    pod.webServer.addRoute(
      StaticRoute.file(File(Uri(path: 'web/pages/$page.html').toFilePath())),
      '/$page',
    );
  }
  pod.webServer.addRoute(InviteRoute(), '/invite/:token');
  // The MCP endpoint (specs/09-mcp.md §1): Streamable HTTP, bearer tokens.
  pod.webServer.addRoute(McpRoute(), '/mcp');

  final fallbackPage = File(
    Uri(path: 'web/pages/build_flutter_app.html').toFilePath(),
  );
  for (final app in const ['write', 'sheets']) {
    pod.webServer.addRoute(
      AppConfigRoute(
        apiConfig: pod.config.apiServer,
        webOrigin: WonkyConfig.current.webOrigin(pod.config),
        cookieAuth: pod.config.authCookie != null,
        googleClientId: googleWebClientId(),
      ),
      '/$app/assets/assets/config.json',
    );
    final dir = Directory(Uri(path: 'web/$app').toFilePath());
    if (dir.existsSync()) {
      // Built with --wasm: cross-origin isolation headers (specs/13 §3).
      pod.webServer.addRoute(FlutterRoute(dir), '/$app');
    } else {
      // Not built yet: explain how to build (`serverpod run flutter_build`).
      pod.webServer.addRoute(StaticRoute.file(fallbackPage), '/$app/**');
    }
  }
}

/// Recurring maintenance jobs (specs/13 §3), registered under fixed
/// identifiers. Every instance runs this at start; it is idempotent and
/// serialized across instances (specs/13 §4): a job that is already
/// scheduled with the same cron is left alone, a missing one is scheduled,
/// and a changed or duplicated one is replaced. Serverpod's claims make
/// each scheduled run execute on one instance only.
Future<void> scheduleMaintenanceJobs(sp.Serverpod pod) async {
  final session = await pod.createSession(enableLogging: false);
  try {
    await Cluster.withLock(session, 'wonky.scheduleJobs', () async {
      await scheduleRecurringJobs(session, pod.futureCalls);
    });
  } finally {
    await session.close();
  }
}

/// The recurring jobs by identifier: cron and how to schedule them.
final _jobs = <String, (String, Future<void> Function(dynamic recurring))>{
  'wonky.captureVersions': (
    '* * * * *',
    (r) => r.maintenance.captureVersions(),
  ),
  'wonky.sendDigests': ('*/15 * * * *', (r) => r.maintenance.sendDigests()),
  'wonky.cleanupFiles': ('7 * * * *', (r) => r.maintenance.cleanupFiles()),
  'wonky.daily': ('17 3 * * *', (r) => r.maintenance.daily()),
};

/// Brings the scheduled recurring jobs in line with [_jobs] (see
/// [scheduleMaintenanceJobs]). Returns the identifiers that were (re)scheduled.
Future<List<String>> scheduleRecurringJobs(
  Session session,
  FutureCalls futureCalls,
) async {
  final scheduled = <String>[];
  final now = clock.now().toUtc();
  for (final MapEntry(key: id, value: (cron, schedule)) in _jobs.entries) {
    final entries = await sp.FutureCallEntry.db.find(
      session,
      where: (t) => t.identifier.equals(id),
    );
    final sameCron = entries.every(
      (e) => switch (e.scheduling) {
        CronFutureCallScheduling(cron: final c) => c == cron,
        _ => false,
      },
    );
    // One chain has at most one future run (a running entry inserts its
    // next run before it executes).
    final upcoming = entries.where((e) => e.time.isAfter(now)).length;
    if (entries.isNotEmpty && sameCron && upcoming <= 1) continue;
    await futureCalls.cancel(id);
    await schedule(futureCalls.callRecurring(identifier: id).cron(cron));
    scheduled.add(id);
  }
  return scheduled;
}
