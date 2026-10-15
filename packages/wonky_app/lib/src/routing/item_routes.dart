import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';

import '../config/home_scope.dart';
import '../data/api.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/shell_services.dart';

/// Runs a route action once (`/new`, `/import`, suite 03 §2) and replaces
/// the route with the created item's editor; on cancel or failure it goes
/// back (or home). Shows a centered spinner with [label] meanwhile.
class _ItemRoutePage extends StatefulWidget {
  const _ItemRoutePage({
    super.key,
    required this.services,
    required this.label,
    required this.action,
  });

  final ShellServices services;
  final String Function(WonkyAppLocalizations l) label;
  final Future<UuidValue?> Function(BuildContext context) action;

  @override
  State<_ItemRoutePage> createState() => _ItemRoutePageState();
}

class _ItemRoutePageState extends State<_ItemRoutePage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  Future<void> _run() async {
    final s = widget.services;
    UuidValue? uuid;
    var failed = false;
    try {
      uuid = await widget.action(context);
    } catch (e) {
      failed = true;
      s.toasts.error(
        s.l10n?.errorGeneric ?? 'Error',
        description: errorMessage(e),
      );
    }
    if (!mounted) return;
    // Replace the `/new` / `/import` entry: Back must not create again.
    Router.neglect(context, () {
      if (uuid != null) {
        s.router.go(s.config.itemPath(uuid.uuid));
      } else if (s.canGoBack) {
        s.goBack();
      } else if (failed || !s.crossApp.historyBack()) {
        // Errors stay in this app so their toast is seen; a cancel returns
        // to the page that navigated here (Drive's *Open with*, Drive 02
        // §7.2: `history.back`).
        s.router.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = WonkyAppLocalizations.of(context);
    return ColoredBox(
      color: theme.colorScheme.background,
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ShadSpinner(),
              const SizedBox(height: 12),
              Text(widget.label(l), style: theme.textTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// `/new?folder=&template=` (suite 03 §2, Drive 04 §5): creates an item of
/// the app's kind with `WonkyAppConfig.newItemRoute` and opens it.
class NewItemRoutePage extends StatelessWidget {
  const NewItemRoutePage({
    super.key,
    required this.services,
    required this.handler,
    required this.request,
  });

  final ShellServices services;
  final NewItemRouteHandler handler;
  final NewItemRequest request;

  @override
  Widget build(BuildContext context) => _ItemRoutePage(
    key: const ValueKey<String>('route.new'),
    services: services,
    label: (l) => l.routeCreating,
    action: (c) => handler(c, services, request),
  );
}

/// `/import?file=<fileItemUuid>` (Drive 02 §7.2): imports an uploaded Drive
/// file with `WonkyAppConfig.importRoute` and opens the result.
class ImportRoutePage extends StatelessWidget {
  const ImportRoutePage({
    super.key,
    required this.services,
    required this.handler,
    required this.request,
  });

  final ShellServices services;
  final ImportRouteHandler handler;

  /// Null when the query has no valid `file` (the page goes back).
  final ImportRouteRequest? request;

  @override
  Widget build(BuildContext context) => _ItemRoutePage(
    key: const ValueKey<String>('route.import'),
    services: services,
    label: (l) => l.routeImporting,
    action: (c) async {
      final r = request;
      if (r == null) {
        services.toasts.error(WonkyAppLocalizations.of(c).routeImportInvalid);
        return null;
      }
      return handler(c, services, r);
    },
  );
}
