import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show PresentationSessionInfo, UuidValue;
import 'package:wonky_core/wonky_core.dart';

import '../../l10n/slides_l10n.dart';
import 'active_presentation.dart';
import 'presentation_link.dart';

/// "You're presenting on MacBook — *Show audience view here*" (Slides 10
/// §5.2, §6.3): when the same user opens the deck while one of their
/// presentation sessions is live, this banner above the editor body offers
/// to join it as the audience (`slides.present.joinAsAudience`). Opening a
/// window is always the user's own navigation — never the app's.
class PresentSessionBanner extends StatefulWidget {
  const PresentSessionBanner({
    super.key,
    required this.services,
    required this.itemUuid,
    required this.child,
  });

  final ShellServices services;
  final String itemUuid;
  final Widget child;

  @override
  State<PresentSessionBanner> createState() => _PresentSessionBannerState();
}

class _PresentSessionBannerState extends State<PresentSessionBanner> {
  PresentationSessionInfo? _live;
  bool _dismissed = false;
  bool _checking = false;
  bool _wasOnline = false;

  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    _wasOnline = s.connectivity.online;
    s.connectivity.addListener(_onConnectivity);
    unawaited(_check());
  }

  @override
  void dispose() {
    s.connectivity.removeListener(_onConnectivity);
    super.dispose();
  }

  void _onConnectivity() {
    final online = s.connectivity.online;
    if (online && !_wasOnline) unawaited(_check());
    _wasOnline = online;
  }

  Future<void> _check() async {
    final transport = presentationTransportOf(s);
    if (transport == null || _checking || !s.connectivity.online) return;
    _checking = true;
    try {
      final info = await transport.findSession(
        UuidValue.fromString(widget.itemUuid),
      );
      if (mounted) setState(() => _live = info);
    } on Object {
      // Offline or no access: no banner.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = _live;
    // This window presents itself (the presenter view is a child route).
    final own = activePresentation.value?.link?.sessionId;
    if (live == null || _dismissed || own == live.sessionId) {
      return widget.child;
    }
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          child: Container(
            key: const ValueKey<String>('slides.present.banner'),
            color: theme.colorScheme.accent,
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            child: Row(
              children: [
                Icon(
                  LucideIcons.presentation,
                  size: 16,
                  color: theme.colorScheme.accentForeground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    live.deviceLabel.isEmpty
                        ? l.presentBannerTitleNoDevice
                        : l.presentBannerTitle(live.deviceLabel),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small,
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton.outline(
                  key: const ValueKey<String>('slides.present.banner.join'),
                  height: 30,
                  onPressed: () => s.dispatcher.invoke(
                    'slides.present.joinAsAudience',
                    args: {'sessionId': live.sessionId},
                    source: InvocationSource.ui,
                    context: context,
                  ),
                  child: Text(l.cmdPresentJoinAsAudience),
                ),
                ShadTooltip(
                  builder: (_) => Text(l.presentBannerDismiss),
                  child: ShadIconButton.ghost(
                    key: const ValueKey<String>(
                      'slides.present.banner.dismiss',
                    ),
                    width: 30,
                    height: 30,
                    iconSize: 14,
                    semanticLabel: l.presentBannerDismiss,
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => setState(() => _dismissed = true),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
