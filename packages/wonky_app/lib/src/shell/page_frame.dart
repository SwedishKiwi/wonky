import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../l10n/wonky_app_localizations.dart';
import 'account_menu.dart';
import 'shell_services.dart';

/// A full-screen in-app page with a back affordance (settings, help,
/// templates, history): never a new window (suite 03 §1).
class ShellPageFrame extends StatelessWidget {
  const ShellPageFrame({
    super.key,
    required this.services,
    required this.title,
    required this.child,
    this.actions = const [],
    this.onBack,
  });

  final ShellServices services;
  final String title;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
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
                GestureDetector(
                  onTap: () => services.router.go('/'),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: services.config.logo(size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
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
                AccountMenuButton(services: services),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
