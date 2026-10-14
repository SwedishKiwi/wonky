import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../auth/screens/reset_password_screen.dart';
import '../auth/screens/sign_in_screen.dart';
import '../auth/screens/sign_up_screen.dart';
import '../auth/screens/verify_email_screen.dart';
import '../drive/drive_location.dart';
import '../drive/home_screen.dart';
import '../drive/template_gallery.dart';
import '../settings/settings_screen.dart';
import '../shell/shell_services.dart';
import '../versions/version_history_screen.dart';
import 'misc_pages.dart';

const _authPaths = {'/signin', '/signup', '/signup/verify', '/reset'};

/// The suite routes of 03 §2 plus the app's routes. Paths are relative to
/// the app's base href.
GoRouter buildShellRouter(ShellServices s) {
  final prefix = s.config.itemPath('x').replaceFirst(RegExp(r'x$'), '');
  final base = prefix.endsWith('/')
      ? prefix.substring(0, prefix.length - 1)
      : prefix;
  Page<void> page(GoRouterState state, Widget child) =>
      NoTransitionPage<void>(key: state.pageKey, child: child);

  return GoRouter(
    navigatorKey: s.navigatorKey,
    refreshListenable: s.auth,
    redirect: (context, state) {
      final path = state.uri.path;
      final status = s.auth.status;
      final isAuth = _authPaths.contains(path);
      if (status == AuthStatus.sessionExpired) {
        return null; // dialog over the screen
      }
      if (status == AuthStatus.signedOut) {
        if (isAuth) return null;
        final next = state.uri.toString();
        return next == '/'
            ? '/signin'
            : '/signin?next=${Uri.encodeQueryComponent(next)}';
      }
      if (isAuth) {
        final next = state.uri.queryParameters['next'];
        return next != null && next.startsWith('/') && !next.startsWith('//')
            ? next
            : '/';
      }
      if (path == '/settings') return '/settings/account';
      return null;
    },
    errorPageBuilder: (context, state) =>
        page(state, NotFoundPage(services: s)),
    routes: [
      GoRoute(
        path: '/signin',
        pageBuilder: (c, st) => page(st, SignInScreen(services: s)),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (c, st) => page(st, SignUpScreen(services: s)),
      ),
      GoRoute(
        path: '/signup/verify',
        pageBuilder: (c, st) => page(st, VerifyEmailScreen(services: s)),
      ),
      GoRoute(
        path: '/reset',
        pageBuilder: (c, st) => page(st, ResetPasswordScreen(services: s)),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (c, st) => page(
          st,
          DriveHomeScreen(services: s, location: const DriveLocation.home()),
        ),
      ),
      GoRoute(
        path: '/drive/:folderUuid',
        pageBuilder: (c, st) => page(
          st,
          DriveHomeScreen(
            services: s,
            location: DriveLocation.folder(st.pathParameters['folderUuid']!),
          ),
        ),
      ),
      for (final (path, loc) in [
        ('/my-drive', const DriveLocation.myDrive()),
        ('/shared', const DriveLocation.shared()),
        ('/starred', const DriveLocation.starred()),
        ('/recent', const DriveLocation.recent()),
        ('/offline', const DriveLocation.offline()),
        ('/trash', const DriveLocation.trash()),
      ])
        GoRoute(
          path: path,
          pageBuilder: (c, st) =>
              page(st, DriveHomeScreen(services: s, location: loc)),
        ),
      GoRoute(
        path: '/search',
        pageBuilder: (c, st) => page(
          st,
          DriveHomeScreen(
            services: s,
            location: DriveLocation.search(st.uri.queryParameters['q'] ?? ''),
          ),
        ),
      ),
      GoRoute(
        path: '/templates',
        pageBuilder: (c, st) => page(st, TemplateGalleryScreen(services: s)),
      ),
      GoRoute(path: '/settings', redirect: (c, st) => '/settings/account'),
      GoRoute(
        path: '/settings/:section',
        pageBuilder: (c, st) => page(
          st,
          SettingsScreen(services: s, section: st.pathParameters['section']!),
        ),
      ),
      GoRoute(
        path: '/invite/:token',
        pageBuilder: (c, st) => page(
          st,
          InvitePage(services: s, token: st.pathParameters['token']!),
        ),
      ),
      GoRoute(
        path: '/no-access',
        pageBuilder: (c, st) => page(
          st,
          NoAccessPage(services: s, itemUuid: st.uri.queryParameters['item']),
        ),
      ),
      GoRoute(
        path: '$base/:uuid',
        pageBuilder: (c, st) =>
            page(st, s.config.buildEditor(c, st, st.pathParameters['uuid']!)),
        routes: [
          if (s.config.versionRenderer != null)
            GoRoute(
              path: 'history',
              pageBuilder: (c, st) => page(
                st,
                VersionHistoryScreen(
                  services: s,
                  itemUuid: st.pathParameters['uuid']!,
                ),
              ),
            ),
          ...s.config.editorRoutes(s),
        ],
      ),
      ...s.config.routes(s),
    ],
  );
}
