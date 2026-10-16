import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../routing/misc_pages.dart';
import '../../shell/shell_services.dart';
import 'board_page.dart';
import 'board_trail.dart';
import 'contribute_page.dart';
import 'post_page.dart';
import 'task_page.dart';

/// The board routes of specs/16 §4.3, added to every app next to the
/// settings routes. A post's or task's breadcrumb trail comes from the
/// query (`?list=…&task=…`, [BoardTrail.parse]); a search from
/// `?q=…&closed=1&kind=…` ([BoardSearchQuery.parse]). They are public: the router's auth redirect lets
/// `/improvements` and everything below it through when signed out.
List<RouteBase> boardRoutes(
  ShellServices s,
  Page<void> Function(GoRouterState state, Widget child) page,
) {
  Page<void> tab(GoRouterState st, BoardTab t) => page(
    st,
    BoardPage(
      services: s,
      tab: t,
      search: BoardSearchQuery.parse(st.uri.queryParameters, t),
    ),
  );
  return [
    GoRoute(
      path: '/improvements',
      pageBuilder: (c, st) => tab(st, BoardTab.improvements),
      routes: [
        GoRoute(path: 'bugs', pageBuilder: (c, st) => tab(st, BoardTab.bugs)),
        GoRoute(path: 'tasks', pageBuilder: (c, st) => tab(st, BoardTab.tasks)),
        GoRoute(
          path: 'claimed',
          pageBuilder: (c, st) => tab(st, BoardTab.claimed),
        ),
        GoRoute(path: 'done', pageBuilder: (c, st) => tab(st, BoardTab.done)),
        GoRoute(
          path: 'review',
          pageBuilder: (c, st) => tab(st, BoardTab.review),
        ),
        GoRoute(
          path: 'search',
          pageBuilder: (c, st) => tab(st, BoardTab.search),
        ),
        GoRoute(
          path: 'contribute',
          pageBuilder: (c, st) => page(st, BoardContributePage(services: s)),
        ),
        GoRoute(
          path: 'p/:number',
          pageBuilder: (c, st) {
            final n = int.tryParse(st.pathParameters['number']!);
            return page(
              st,
              n == null
                  ? NotFoundPage(services: s)
                  : BoardPostPage(
                      key: ValueKey<int>(n),
                      services: s,
                      number: n,
                      trail: BoardTrail.parse(st.uri),
                      mergedFrom: int.tryParse(
                        st.uri.queryParameters['merged'] ?? '',
                      ),
                    ),
            );
          },
        ),
        GoRoute(
          path: 't/:number',
          pageBuilder: (c, st) {
            final n = int.tryParse(st.pathParameters['number']!);
            return page(
              st,
              n == null
                  ? NotFoundPage(services: s)
                  : BoardTaskPage(
                      key: ValueKey<int>(n),
                      services: s,
                      number: n,
                      trail: BoardTrail.parse(st.uri),
                    ),
            );
          },
        ),
      ],
    ),
  ];
}
