import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/slides_l10n.dart';

/// The editor child routes whose screens other work packages build
/// (Slides 04 §1): `present` (SL-19), `print` (SL-20) and `history`
/// (SL-39).
enum DeckChildRoute { present, print, history }

/// A full-window *Coming soon* page for a deck child route (the deck
/// editor stays mounted underneath, `WonkyAppConfig.editorRoutes`), with
/// *Back to the presentation*.
class DeckRoutePlaceholder extends StatelessWidget {
  const DeckRoutePlaceholder({
    super.key,
    required this.services,
    required this.itemUuid,
    required this.route,
  });

  final ShellServices services;
  final String itemUuid;
  final DeckChildRoute route;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    return ColoredBox(
      key: ValueKey<String>('slides.route.${route.name}'),
      color: theme.colorScheme.background,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const WonkyProductIcon(
                  WonkyProduct.slides,
                  size: 72,
                  semanticLabel: '',
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    switch (route) {
                      DeckChildRoute.present => l.routePresentTitle,
                      DeckChildRoute.print => l.routePrintTitle,
                      DeckChildRoute.history => l.routeHistoryTitle,
                    },
                    style: theme.textTheme.large,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.editorComingSoonTitle,
                  style: theme.textTheme.muted,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ShadButton.outline(
                  key: const ValueKey<String>('slides.route.back'),
                  leading: const Icon(LucideIcons.arrowLeft, size: 16),
                  onPressed: () =>
                      services.router.go(services.config.itemPath(itemUuid)),
                  child: Text(l.backToPresentation),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
