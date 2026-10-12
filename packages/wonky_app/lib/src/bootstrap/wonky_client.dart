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

  /// Loads the config and initializes the client and its auth session.
  static Future<WonkyClient> initialize({AppUrls? urls}) async {
    final u = urls ?? await AppUrls.load();
    final client = Client(u.apiUrl)
      ..connectivityMonitor = FlutterConnectivityMonitor()
      ..authSessionManager = FlutterAuthSessionManager();
    if (kIsWeb) {
      // One sign-in for both apps: the session lives in the httpOnly auth
      // cookie on the shared origin; tokens never sit in JS storage.
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
}
