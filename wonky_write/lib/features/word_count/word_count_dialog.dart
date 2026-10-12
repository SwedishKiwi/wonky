import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shad/shad.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../screen/command_invoke.dart';
import '../screen/write_document_controller.dart';

final _number = intl.NumberFormat.decimalPattern('en_US');

/// "1,234".
String formatCount(int n) => _number.format(n);

/// "3 min" / "< 1 min".
String readingTime(DocumentStats s) {
  final m = s.readingTimeMinutes;
  return m <= 0 ? '< 1 min' : '$m min';
}

/// Status bar label: "1,234 words" or "56 of 1,234 words".
String wordCountLabel(DocumentStats doc, DocumentStats? selection) {
  final total = formatCount(doc.words);
  final unit = doc.words == 1 ? 'word' : 'words';
  if (selection == null) return '$total $unit';
  return '${formatCount(selection.words)} of $total $unit';
}

/// Word count dialog (`write.dialog.wordCount`, Write 05 §12.5).
Future<void> showWordCountDialog(
  BuildContext context,
  WriteDocumentController doc, {
  int? pageCount,
}) {
  doc.insights.refresh();
  return showShadDialog<void>(
    context: context,
    builder: (context) => WordCountDialog(doc: doc, pageCount: pageCount),
  );
}

class WordCountDialog extends StatelessWidget {
  const WordCountDialog({super.key, required this.doc, this.pageCount});

  final WriteDocumentController doc;
  final int? pageCount;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: doc,
      builder: (context, _) {
        final s = doc.insights.stats;
        final sel = doc.insights.selectionStats;
        final rows = <(String, String, String?)>[
          if (pageCount != null) ('Pages', formatCount(pageCount!), null),
          (
            'Words',
            formatCount(s.words),
            sel == null ? null : formatCount(sel.words),
          ),
          (
            'Characters',
            formatCount(s.characters),
            sel == null ? null : formatCount(sel.characters),
          ),
          (
            'Characters excluding spaces',
            formatCount(s.charactersNoSpaces),
            sel == null ? null : formatCount(sel.charactersNoSpaces),
          ),
          (
            'Paragraphs',
            formatCount(s.paragraphs),
            sel == null ? null : formatCount(sel.paragraphs),
          ),
          (
            'Reading time',
            readingTime(s),
            sel == null ? null : readingTime(sel),
          ),
        ];
        TextStyle head = theme.textTheme.small.copyWith(
          color: theme.colorScheme.mutedForeground,
        );
        return ShadDialog(
          key: const ValueKey<String>('write.dialog.wordCount'),
          title: const Text('Word count'),
          constraints: const BoxConstraints(maxWidth: 420),
          actions: [
            ShadButton(
              key: const ValueKey<String>('write.dialog.wordCount.ok'),
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(),
                  1: IntrinsicColumnWidth(),
                  2: IntrinsicColumnWidth(),
                },
                children: [
                  TableRow(
                    children: [
                      const SizedBox(),
                      _cell(Text('Document', style: head), right: true),
                      sel == null
                          ? const SizedBox()
                          : _cell(Text('Selection', style: head), right: true),
                    ],
                  ),
                  for (final (label, value, selValue) in rows)
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: theme.colorScheme.border),
                        ),
                      ),
                      children: [
                        _cell(Text(label, style: theme.textTheme.small)),
                        _cell(
                          Text(
                            value,
                            style: theme.textTheme.small.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          right: true,
                        ),
                        _cell(
                          Text(
                            selValue ?? '',
                            style: theme.textTheme.small.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          right: true,
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ShadCheckbox(
                    key: const ValueKey<String>(
                      'write.dialog.wordCount.showWhileTyping',
                    ),
                    value: doc.viewPrefs.showWordCount,
                    onChanged: (_) =>
                        invokeCommand(context, 'write.view.toggleWordCount'),
                    label: const Text('Display word count while typing'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(Widget child, {bool right = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
    child: Align(
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      child: child,
    ),
  );
}
