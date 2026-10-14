import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart' show FValueToCellValue;
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'cleanup_suggestions.dart';
import 'data_tools.dart';

/// The cleanup suggestions of the active sheet (07 §12.3), recomputed
/// shortly after changes; dismissed ones are hidden on this device.
List<CleanupSuggestion> cleanupSuggestionsOf(SheetEditorController ed) {
  final sheet = ed.activeSheet;
  if (sheet == null) return const [];
  final sid = sheet.id;
  final dismissed = DataTools.of(ed).dismissedCleanup;
  return [
    for (final s in CleanupDetector.detect(
      sheet,
      value: (r, c) => ed.engine.valueAt(sid, r, c).toCellValue(),
      locale: ed.locale,
    ))
      if (!dismissed.contains('$sid/${s.id}')) s,
  ];
}

/// The *Cleanup suggestions* panel (`sheets.panel.cleanupSuggestions`,
/// 07 §12.3): one card per finding with a before/after preview of up to
/// three cells, *Apply* (one undo step) and *Dismiss* (local).
class CleanupSuggestionsPanel extends StatefulWidget {
  const CleanupSuggestionsPanel({super.key, required this.editor});

  final SheetEditorController editor;

  @override
  State<CleanupSuggestionsPanel> createState() =>
      _CleanupSuggestionsPanelState();
}

class _CleanupSuggestionsPanelState extends State<CleanupSuggestionsPanel> {
  final _scroll = ScrollController();
  Timer? _debounce;
  List<CleanupSuggestion>? _items;

  SheetEditorController get ed => widget.editor;

  @override
  void initState() {
    super.initState();
    ed.addListener(_schedule);
    ed.model.addListener(_onBatch);
    WidgetsBinding.instance.addPostFrameCallback((_) => _compute());
  }

  @override
  void dispose() {
    ed.removeListener(_schedule);
    ed.model.removeListener(_onBatch);
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onBatch(Object? _) => _schedule();

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _compute);
  }

  void _compute() {
    if (!mounted) return;
    setState(() => _items = cleanupSuggestionsOf(ed));
  }

  String _title(SheetsLocalizations l, CleanupSuggestion s) => switch (s.kind) {
    CleanupKind.numbersAsText => l.cleanupNumbersAsText(
      s.count,
      s.column ?? '',
    ),
    CleanupKind.whitespace => l.cleanupWhitespace(s.count, s.column ?? ''),
    CleanupKind.duplicates => l.cleanupDuplicates(s.count),
    CleanupKind.capitalization => l.cleanupCapitalization(
      s.count,
      s.column ?? '',
    ),
    CleanupKind.emptyRows => l.cleanupEmptyRows(s.count),
    CleanupKind.mixedTypes => l.cleanupMixedTypes(s.column ?? '', s.count),
  };

  Future<void> _apply(CleanupSuggestion s) async {
    await ed.invokeCommand('sheets.cleanup.applySuggestion', {'id': s.id});
    _compute();
  }

  void _dismiss(CleanupSuggestion s) {
    DataTools.of(ed).dismissedCleanup.add('${ed.activeSheetId}/${s.id}');
    _compute();
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final items = _items;
    if (items == null) return const Center(child: ShadSpinner());
    if (items.isEmpty) {
      return WonkyEmptyState(
        key: const ValueKey<String>('cleanup.empty'),
        illustration: EmptyIllustration.spreadsheets,
        title: l.cleanupNoneTitle,
        description: l.cleanupNoneBody,
        size: 96,
      );
    }
    return WonkyScrollArea(
      controller: _scroll,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            for (final s in items)
              Container(
                key: ValueKey<String>('cleanup.card.${s.id}'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.border),
                  borderRadius: theme.radius,
                  color: theme.colorScheme.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _title(l, s),
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (s.preview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      for (final (before, after) in s.preview)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            s.kind == CleanupKind.emptyRows ||
                                    s.kind == CleanupKind.duplicates
                                ? l.cleanupRow(before)
                                : '$before  →  $after',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.muted.copyWith(fontSize: 12),
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (s.applicable)
                          ShadButton(
                            key: ValueKey<String>('cleanup.apply.${s.id}'),
                            size: ShadButtonSize.sm,
                            enabled: ed.canEdit,
                            onPressed: () => unawaited(_apply(s)),
                            child: Text(l.cleanupApply),
                          )
                        else
                          ShadButton.outline(
                            key: ValueKey<String>('cleanup.stats.${s.id}'),
                            size: ShadButtonSize.sm,
                            onPressed: () {
                              DataTools.of(ed).statsColumn.value = s.colId;
                              unawaited(
                                ed.invokeCommand('sheets.data.columnStats', {
                                  'colId': ?s.colId,
                                }),
                              );
                            },
                            child: Text(l.cleanupColumnStats),
                          ),
                        ShadButton.ghost(
                          key: ValueKey<String>('cleanup.dismiss.${s.id}'),
                          size: ShadButtonSize.sm,
                          onPressed: () => _dismiss(s),
                          child: Text(l.cleanupDismiss),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
