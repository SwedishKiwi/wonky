import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:wonky_client/wonky_client.dart';

import 'app_urls.dart';

/// Creates and owns the generated Serverpod [Client] (suite 01 §2.5): server
/// URL from `config.json`, `FlutterConnectivityMonitor`,
/// `FlutterAuthSessionManager`, cookie auth on web.
///
/// Only repositories use the client; widgets never do (suite 03 §5).
class WonkyClient {
  WonkyClient._(this.client, this.urls);

  final Client client;
  final AppUrls urls;

  /// Replaces the persisted session storage (E2E tests keep the session in
  /// memory so runs neither depend on nor touch the OS keychain).
  @visibleForTesting
  static ClientAuthSuccessStorage? sessionStorageOverride;

  /// Loads the config and initializes the client and its auth session.
  static Future<WonkyClient> initialize({AppUrls? urls}) async {
    final u = urls ?? await AppUrls.load();
    final client = Client(u.apiUrl)
      ..connectivityMonitor = FlutterConnectivityMonitor()
      ..authSessionManager = FlutterAuthSessionManager(
        storage: sessionStorageOverride ?? _desktopSessionStorage(),
      );
    if (kIsWeb && u.cookieAuth) {
      // One sign-in for both apps: the session lives in the httpOnly auth
      // cookie on the shared origin; tokens never sit in JS storage. Only
      // when the server is configured for it (`cookieAuth` in config.json):
      // without `authCookie`/`allowedOrigins` the API answers CORS with `*`
      // and browsers block every credentialed request. Otherwise the
      // session is kept in the origin's storage, shared by /write/ and
      // /sheets/.
      client.cookieAuth = true;
    }
    // Restores the persisted session (or the cookie session on web). Never
    // blocks startup for long: the shell shows a splash until it completes.
    try {
      await client.auth.initialize().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Offline start: keep whatever session info was restored.
    } catch (e) {
      debugPrint('Auth initialization failed: $e');
    }
    return WonkyClient._(client, u);
  }

  /// macOS: the data-protection keychain needs a signed app with the
  /// `keychain-access-groups` entitlement (error -34018 otherwise, so the
  /// session could not be saved and sign-in failed in debug and E2E runs).
  /// The login keychain works for sandboxed, unsigned builds too. Other
  /// platforms keep the package default.
  static ClientAuthSuccessStorage? _desktopSessionStorage() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return null;
    return SecureClientAuthSuccessStorage(
      secureStorage: const FlutterSecureStorage(
        mOptions: MacOsOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
          usesDataProtectionKeychain: false,
        ),
      ),
    );
  }
}
