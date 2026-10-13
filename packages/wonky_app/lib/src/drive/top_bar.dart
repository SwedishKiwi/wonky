import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';

import '../branding/product_icon.dart';
import '../l10n/wonky_app_localizations.dart';
import '../notifications/notifications_button.dart';
import '../shell/account_menu.dart';
import '../shell/shell_services.dart';

/// The home top bar (suite 05 §3.1 `WonkyTopBar`): hamburger, logo + name,
/// drive search with suggestions, theme toggle, notifications and the
/// account menu.
class WonkyTopBar extends StatelessWidget {
  const WonkyTopBar({
    super.key,
    required this.services,
    required this.onToggleSidebar,
    required this.searchFocus,
    this.initialQuery,
  });

  final ShellServices services;
  final VoidCallback onToggleSidebar;
  final FocusNode searchFocus;
  final String? initialQuery;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 640;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ShadTooltip(
            builder: (_) => Text(l.toggleSidebar),
            child: ShadIconButton.ghost(
              key: const ValueKey<String>('shell.topBar.menu'),
              semanticLabel: l.toggleSidebar,
              icon: const Icon(LucideIcons.menu, size: 18),
              onPressed: onToggleSidebar,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => services.router.go('/'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                children: [
                  services.config.logo(size: 32),
                  if (!narrow) ...[
                    const SizedBox(width: 10),
                    Text(
                      services.config.appName,
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: DriveSearchField(
                  services: services,
                  focusNode: searchFocus,
                  initialQuery: initialQuery,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ThemeToggleButton(services: services),
          NotificationsButton(services: services),
          const SizedBox(width: 4),
          AccountMenuButton(services: services),
        ],
      ),
    );
  }
}

/// Drive search with a suggestions dropdown (recent searches, matching
/// items, "Search for '…'").
class DriveSearchField extends StatefulWidget {
  const DriveSearchField({
    super.key,
    required this.services,
    required this.focusNode,
    this.initialQuery,
  });

  final ShellServices services;
  final FocusNode focusNode;
  final String? initialQuery;

  @override
  State<DriveSearchField> createState() => _DriveSearchFieldState();
}

class _DriveSearchFieldState extends State<DriveSearchField> {
  late final _text = TextEditingController(text: widget.initialQuery ?? '');
  final _popover = ShadPopoverController();
  List<DriveItemView> _matches = const [];
  Timer? _debounce;

  ShellServices get s => widget.services;

  List<String> get _recent => [
    for (final q
        in (s.prefs.device<List<Object?>>('search.recent') ?? const []))
      '$q',
  ];

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (widget.focusNode.hasFocus) {
        _popover.show();
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _popover.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _popover.show();
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _matches = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final p = await s.drive.search(
          q,
          filters: DriveSearchFilters(),
          limit: 6,
        );
        if (mounted && _text.text == q) setState(() => _matches = p.items);
      } catch (_) {}
    });
  }

  void _submit(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    final recent = [t, ..._recent.where((r) => r != t)].take(8).toList();
    s.prefs.setDevice('search.recent', recent);
    _popover.hide();
    widget.focusNode.unfocus();
    s.router.go('/search?q=${Uri.encodeQueryComponent(t)}');
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return ShadPopover(
      controller: _popover,
      padding: const EdgeInsets.all(4),
      anchor: const ShadAnchor(
        childAlignment: AlignmentDirectional.bottomStart,
        overlayAlignment: AlignmentDirectional.topStart,
        offset: Offset(0, 4),
      ),
      popover: (context) {
        final q = _text.text.trim();
        final recent = q.isEmpty ? _recent : const <String>[];
        if (q.isEmpty && recent.isEmpty) {
          return SizedBox(
            width: 520,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l.searchHint, style: theme.textTheme.muted),
            ),
          );
        }
        return SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in recent)
                ShadButton.ghost(
                  mainAxisAlignment: MainAxisAlignment.start,
                  leading: const Icon(LucideIcons.history, size: 16),
                  onPressed: () {
                    _text.text = r;
                    _submit(r);
                  },
                  child: Text(r),
                ),
              for (final m in _matches)
                ShadButton.ghost(
                  mainAxisAlignment: MainAxisAlignment.start,
                  leading: DriveKindIcon(m.kind, size: 18),
                  onPressed: () {
                    _popover.hide();
                    s.openItem(m);
                  },
                  child: Expanded(
                    child: Text(m.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              if (q.isNotEmpty)
                ShadButton.ghost(
                  key: const ValueKey<String>('drive.search.submit'),
                  mainAxisAlignment: MainAxisAlignment.start,
                  leading: const Icon(LucideIcons.search, size: 16),
                  onPressed: () => _submit(q),
                  child: Text(l.searchFor(q)),
                ),
            ],
          ),
        );
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            _popover.hide();
            widget.focusNode.unfocus();
          },
        },
        child: ShadInput(
          key: const ValueKey<String>('drive.search'),
          controller: _text,
          focusNode: widget.focusNode,
          placeholder: Text(l.searchPlaceholder),
          leading: const Icon(LucideIcons.search, size: 16),
          trailing: _text.text.isEmpty
              ? null
              : ShadIconButton.ghost(
                  width: 24,
                  height: 24,
                  iconSize: 14,
                  semanticLabel: l.actionClear,
                  icon: const Icon(LucideIcons.x),
                  onPressed: () {
                    _text.clear();
                    _onChanged('');
                  },
                ),
          onChanged: _onChanged,
          onSubmitted: _submit,
          onPressedOutside: (_) => _popover.hide(),
        ),
      ),
    );
  }
}
