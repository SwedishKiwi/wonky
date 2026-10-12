import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show ImportWarningView, UuidValue;

/// The import banner (Write 07 §3.2 step 5): the first time the importing
/// user opens an imported document, "N elements couldn't be imported
/// exactly" with *Details* and *Dismiss* is shown above [child]. The
/// warnings come from `document.getInfo` (stored by the server import and
/// returned once).
class ImportWarningsBanner extends StatefulWidget {
  const ImportWarningsBanner({
    super.key,
    required this.services,
    required this.documentUuid,
    required this.child,
    this.loadWarnings,
  });

  final ShellServices services;
  final UuidValue? documentUuid;
  final Widget child;

  /// Loads the warnings (defaults to `document.getInfo`; tests inject).
  final Future<List<ImportWarningView>> Function(UuidValue documentUuid)?
  loadWarnings;

  @override
  State<ImportWarningsBanner> createState() => _ImportWarningsBannerState();
}

class _ImportWarningsBannerState extends State<ImportWarningsBanner> {
  List<ImportWarningView> _warnings = const [];
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(ImportWarningsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentUuid != widget.documentUuid) {
      _warnings = const [];
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final uuid = widget.documentUuid;
    if (uuid == null) return;
    try {
      final List<ImportWarningView> warnings;
      final load = widget.loadWarnings;
      if (load != null) {
        warnings = await load(uuid);
      } else {
        final client = widget.services.client;
        if (client == null) return;
        final info = await client.document.getInfo(uuid);
        warnings = info.importWarnings ?? const [];
      }
      if (mounted && uuid == widget.documentUuid) {
        setState(() => _warnings = warnings);
      }
    } catch (_) {
      // The banner is optional; the document works without it.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_warnings.isEmpty) return widget.child;
    final n = _warnings.length;
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: ShadAlert(
            key: const ValueKey<String>('write.importBanner'),
            icon: const Icon(LucideIcons.fileWarning),
            title: Text(
              n == 1
                  ? "1 element couldn't be imported exactly"
                  : "$n elements couldn't be imported exactly",
            ),
            description: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_expanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final w in _warnings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• ${w.message}',
                              style: theme.textTheme.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    ShadButton.outline(
                      key: const ValueKey<String>('write.importBanner.details'),
                      size: ShadButtonSize.sm,
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Text(_expanded ? 'Hide details' : 'Details'),
                    ),
                    ShadButton.ghost(
                      key: const ValueKey<String>('write.importBanner.dismiss'),
                      size: ShadButtonSize.sm,
                      onPressed: () => setState(() => _warnings = const []),
                      child: const Text('Dismiss'),
                    ),
                  ],
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
