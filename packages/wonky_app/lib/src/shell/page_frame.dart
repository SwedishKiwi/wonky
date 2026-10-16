import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../l10n/wonky_app_localizations.dart';
import 'account_menu.dart';
import 'shell_services.dart';

/// The width of a [ShellPageFrame] page's content column (Settings, Bugs &
/// Improvements).
const double shellPageMaxWidth = 760;

/// Below this window width a page's side padding is 16 px instead of 24.
const double shellPageNarrowWidth = 760;

/// The side padding of a page's content at window width [width].
double shellPagePadding(double width) => width < shellPageNarrowWidth ? 16 : 24;

/// The horizontal inset that puts content in the centered
/// [shellPageMaxWidth] column of a full-width page at window width [width]
/// (at least [shellPagePadding]): for pages whose header and list scroll
/// separately, so the list's scrollbar stays at the window edge.
double shellPageInset(double width) =>
    math.max(shellPagePadding(width), (width - shellPageMaxWidth) / 2);

/// A full-screen in-app page with a back affordance (settings, help,
/// templates, history, Bugs & improvements): never a new window (suite 03
/// §1).
///
/// The bar is 56 px: back, the app logo (home), the title (`large`),
/// [actions], and the account menu — or, signed out, [signedOutAction]
/// (pages that are public, like the board, offer *Sign in* there).
class ShellPageFrame extends StatelessWidget {
  const ShellPageFrame({
    super.key,
    required this.services,
    required this.title,
    required this.child,
    this.actions = const [],
    this.onBack,
    this.signedOutAction,
  });

  final ShellServices services;
  final String title;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback? onBack;

  /// Shown instead of the account menu while signed out.
  final Widget? signedOutAction;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final signedIn = services.auth.isSignedIn;
    return ColoredBox(
      color: theme.colorScheme.background,
      child: Column(
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.border),
              ),
            ),
            child: Row(
              children: [
                ShadTooltip(
                  builder: (_) => Text(l.actionBack),
                  child: ShadIconButton.ghost(
                    key: const ValueKey<String>('shell.page.back'),
                    semanticLabel: l.actionBack,
                    icon: const Icon(LucideIcons.arrowLeft, size: 18),
                    onPressed:
                        onBack ??
                        () => services.canGoBack
                            ? services.goBack()
                            : services.router.go('/'),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: l.goHome,
                  child: GestureDetector(
                    onTap: () => services.router.go('/'),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: services.config.logo(size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.large,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ...actions,
                const SizedBox(width: 8),
                if (signedIn)
                  AccountMenuButton(services: services)
                else
                  ?signedOutAction,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The scrolling content of a [ShellPageFrame] page: [children] in a
/// centered column of [shellPageMaxWidth], 24 px from the top, 48 px of
/// bottom room and [shellPagePadding] at the sides — the settings layout
/// (suite 04 §4.2), shared with the board's post, task and contribute pages.
class ShellPageBody extends StatelessWidget {
  const ShellPageBody({super.key, required this.children, this.spacing = 0});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final pad = shellPagePadding(MediaQuery.sizeOf(context).width);
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 24, pad, 48),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: shellPageMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
