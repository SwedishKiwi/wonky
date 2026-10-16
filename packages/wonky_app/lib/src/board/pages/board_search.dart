import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/wonky_app_localizations.dart';
import '../../shell/shell_services.dart';
import 'board_chrome.dart';
import 'board_trail.dart';

/// The board's search button (specs/16 §4.4): a toolbar icon button at the
/// end of the tabs strip (highlighted while a search is active) that opens
/// [BoardSearchPanel] in a popover anchored to it. `/` on the board page
/// opens it too ([controller]).
class BoardSearchButton extends StatelessWidget {
  const BoardSearchButton({
    super.key,
    required this.services,
    required this.controller,
    required this.tab,
    this.search,
  });

  final ShellServices services;
  final ShadPopoverController controller;

  /// The list shown ([BoardTab.search] for the results of all posts).
  final BoardTab tab;

  /// The active search, if any.
  final BoardSearchQuery? search;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final size = WonkyThemeScope.of(context).toolbarButtonSize;
    final active = search != null;
    final tt = theme.tabsTheme;
    final window = MediaQuery.sizeOf(context).width;
    return ShadPopover(
      controller: controller,
      padding: EdgeInsets.zero,
      anchor: const ShadAnchor(
        childAlignment: AlignmentDirectional.bottomEnd,
        overlayAlignment: AlignmentDirectional.topEnd,
        offset: Offset(0, 6),
      ),
      popover: (context) => BoardSearchPanel(
        services: services,
        tab: tab,
        search: search,
        // Full width on phones (the page's 16 px gutters, less the
        // popover's 1 px border), else compact.
        width: window < 600 ? window - 32 - 2 : 360,
        onClose: controller.hide,
      ),
      child: ShadTooltip(
        builder: (_) => Text(l.boardSearchButton),
        // One node: a toggle button named by the active search.
        child: Semantics(
          key: const ValueKey<String>('board.search'),
          container: true,
          button: true,
          toggled: active,
          label: active
              ? l.boardSearchActive(search!.text)
              : l.boardSearchButton,
          excludeSemantics: true,
          onTap: controller.toggle,
          child: ShadIconButton.ghost(
            width: size,
            height: size,
            iconSize: 16,
            // Active: the selected tab's look.
            backgroundColor: active
                ? tt.tabSelectedBackgroundColor ?? cs.background
                : null,
            hoverBackgroundColor: cs.background.withValues(
              alpha: active ? 1 : 0.5,
            ),
            foregroundColor: cs.foreground,
            shadows: active ? tt.tabSelectedShadows : null,
            icon: const Icon(LucideIcons.search),
            onPressed: controller.toggle,
          ),
        ),
      ),
    );
  }
}

/// The search popover (specs/16 §4.4): the search field (focused; Enter
/// searches) and the options: *Search in* (all posts, or the current tab
/// when it lists posts), *Kind* (all posts only) and *Include closed*;
/// then *Clear* and *Search*. Esc closes it.
class BoardSearchPanel extends StatefulWidget {
  const BoardSearchPanel({
    super.key,
    required this.services,
    required this.tab,
    required this.onClose,
    this.search,
    this.width = 360,
  });

  final ShellServices services;
  final BoardTab tab;
  final BoardSearchQuery? search;
  final VoidCallback onClose;
  final double width;

  @override
  State<BoardSearchPanel> createState() => _BoardSearchPanelState();
}

class _BoardSearchPanelState extends State<BoardSearchPanel> {
  late final _text = TextEditingController(text: widget.search?.text ?? '');
  final _focus = FocusNode(debugLabel: 'board.search.input');

  /// Search all posts (else the current tab, when it can be searched).
  late bool _all = !widget.tab.searchable || widget.tab == BoardTab.search
      ? true
      : widget.search == null;
  late bool _closed = widget.search?.closed ?? false;
  late BoardPostKind? _kind = widget.search?.kind;

  @override
  void initState() {
    super.initState();
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _text.text.length,
    );
    // The popover's focus scope can take the focus after `autofocus` ran
    // (opening with `/`): focus the field once it is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isEmpty) return _clear();
    widget.onClose();
    boardOpenSearch(
      widget.services,
      BoardSearchQuery(text, closed: _closed, kind: _all ? _kind : null),
      tab: _all ? null : widget.tab,
      context: context,
    );
  }

  void _clear() {
    widget.onClose();
    if (widget.search == null) return;
    boardOpenSearch(
      widget.services,
      null,
      tab: widget.tab.searchable ? widget.tab : null,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final label = theme.textTheme.small.copyWith(fontWeight: FontWeight.w600);
    Widget section(String title, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(title, style: label),
        child,
      ],
    );
    final canScope = widget.tab.searchable;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: SizedBox(
        key: const ValueKey<String>('board.search.panel'),
        width: widget.width,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              ShadInput(
                key: const ValueKey<String>('board.search.input'),
                controller: _text,
                focusNode: _focus,
                autofocus: true,
                placeholder: Text(l.boardSearch),
                leading: Icon(
                  LucideIcons.search,
                  size: 16,
                  color: theme.colorScheme.mutedForeground,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
              ),
              if (canScope)
                section(
                  l.boardSearchIn,
                  ShadRadioGroup<bool>(
                    key: const ValueKey<String>('board.search.in'),
                    initialValue: _all,
                    axis: Axis.horizontal,
                    spacing: 16,
                    runSpacing: 6,
                    onChanged: (v) => setState(() => _all = v ?? true),
                    items: [
                      ShadRadio(
                        key: const ValueKey<String>('board.search.in.all'),
                        value: true,
                        label: Text(l.boardSearchInAll),
                      ),
                      ShadRadio(
                        key: const ValueKey<String>('board.search.in.tab'),
                        value: false,
                        label: Text(boardTabName(l, widget.tab)),
                      ),
                    ],
                  ),
                ),
              if (_all)
                section(
                  l.boardSearchKind,
                  ShadRadioGroup<String>(
                    key: const ValueKey<String>('board.search.kind'),
                    initialValue: _kind?.name ?? 'any',
                    axis: Axis.horizontal,
                    spacing: 16,
                    runSpacing: 6,
                    onChanged: (v) => setState(
                      () => _kind = switch (v) {
                        'bug' => BoardPostKind.bug,
                        'idea' => BoardPostKind.idea,
                        _ => null,
                      },
                    ),
                    items: [
                      for (final (value, text) in [
                        ('any', l.boardSearchKindAll),
                        ('bug', l.boardTabBugs),
                        ('idea', l.boardTabImprovements),
                      ])
                        ShadRadio(
                          key: ValueKey<String>('board.search.kind.$value'),
                          value: value,
                          label: Text(text),
                        ),
                    ],
                  ),
                ),
              ShadCheckbox(
                key: const ValueKey<String>('board.search.closed'),
                value: _closed,
                onChanged: (v) => setState(() => _closed = v),
                label: Text(l.boardSearchIncludeClosed),
                sublabel: Text(l.boardSearchIncludeClosedHint),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  ShadButton.outline(
                    key: const ValueKey<String>('board.search.clear'),
                    size: ShadButtonSize.sm,
                    onPressed: _clear,
                    child: Text(l.actionClear),
                  ),
                  ShadButton(
                    key: const ValueKey<String>('board.search.submit'),
                    size: ShadButtonSize.sm,
                    leading: const Icon(LucideIcons.search, size: 14),
                    onPressed: _submit,
                    child: Text(l.boardSearchButton),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
