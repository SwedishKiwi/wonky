import 'dart:io';

import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_cloud_storage/serverpod_cloud_storage.dart';

import 'src/cache_busting.dart';
import 'src/generated/serverpod.dart';
import 'src/platform/users/email_idp.dart';
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
    identityProviderBuilders: [wonkyEmailIdpConfig()],
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

  final session = await pod.createSession(enableLogging: false);
  try {
    await ThemeService.upsertBuiltins(session);
  } finally {
    await session.close();
  }
  await _scheduleJobs(pod);
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
  pod.webServer.addRoute(InviteRoute(), '/invite/:token');

  final fallbackPage = File(
    Uri(path: 'web/pages/build_flutter_app.html').toFilePath(),
  );
  for (final app in const ['write', 'sheets']) {
    pod.webServer.addRoute(
      AppConfigRoute(
        apiConfig: pod.config.apiServer,
        webConfig: pod.config.webServer ?? pod.config.apiServer,
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

/// Recurring maintenance jobs (specs/13 §3). Re-registered on every start
/// under fixed identifiers.
Future<void> _scheduleJobs(Serverpod pod) async {
  final futureCalls = pod.futureCalls;
  Future<void> every(
    String id,
    String cron,
    Future<void> Function(dynamic recurring) schedule,
  ) async {
    await futureCalls.cancel(id);
    await schedule(futureCalls.callRecurring(identifier: id).cron(cron));
  }

  await every(
    'wonky.captureVersions',
    '* * * * *',
    (r) => r.maintenance.captureVersions(),
  );
  await every(
    'wonky.sendDigests',
    '*/15 * * * *',
    (r) => r.maintenance.sendDigests(),
  );
  await every(
    'wonky.cleanupFiles',
    '7 * * * *',
    (r) => r.maintenance.cleanupFiles(),
  );
  await every('wonky.daily', '17 3 * * *', (r) => r.maintenance.daily());
}
