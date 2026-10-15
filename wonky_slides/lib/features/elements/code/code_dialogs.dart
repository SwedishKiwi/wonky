import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart';
import 'package:wonky_slides_core/code.dart';

import '../../../l10n/slides_l10n.dart';
import 'code_blocks.dart';

/// The languages of the pickers (07 §2.4): *Plain text*, recently used (max
/// 5), then the picker list; values are normalized ids (`''` = plain).
Map<String, String> codeLanguageOptions(SlidesLocalizations l) => {
  '': l.codePlainText,
  for (final id in CodeBlockView.recentLanguages)
    if (id.isNotEmpty) id: CodeLanguages.displayName(id),
  for (final id in CodeLanguages.pickerLanguages)
    if (id.isNotEmpty) id: CodeLanguages.displayName(id),
};

/// The palette options (07 §2.5): *Auto*, *Light*, *Dark* (the deck
/// theme's pair) and every built-in palette.
Map<String, String> codePaletteOptions(SlidesLocalizations l) => {
  'auto': l.codePaletteAuto,
  'light': l.codePaletteLight,
  'dark': l.codePaletteDark,
  for (final p in BuiltInPalettes.all) p.id: p.name,
};

/// The language picker (`slides.code.setLanguage`, *Insert › Code block ›
/// All languages…*): a `WonkyDialogSpec` select, MCP-operable. Returns the
/// normalized language id (`''` = plain text) or null when cancelled.
Future<String?> showCodeLanguageDialog(
  BuildContext context, {
  String initial = '',
  bool insert = false,
}) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final options = codeLanguageOptions(l);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: insert ? l.codeInsertDialogTitle : l.codeLanguageDialogTitle,
      dialogKey: 'dialog.slides.codeLanguage',
      fields: [
        SelectFieldSpec(
          id: 'language',
          label: l.codeLanguageLabel,
          options: options,
          initial: options.containsKey(initial) ? initial : '',
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(
          id: 'apply',
          label: insert ? l.dialogInsert : l.dialogApply,
          primary: true,
        ),
      ],
    ),
  );
  if (r?.buttonId != 'apply') return null;
  return r!.text('language');
}

/// A localized message for a highlight step issue (07 §4.1).
String codeStepIssueText(SlidesLocalizations l, HighlightIssue issue) {
  final n = (issue.step ?? 0) + 1;
  return switch (issue.code) {
    'syntax' => l.codeStepIssueSyntax(n),
    'reversedRange' => l.codeStepIssueReversed(n),
    'columnRange' => l.codeStepIssueColumns(n),
    _ => l.codeStepIssuePastEnd(n),
  };
}

/// *Highlight steps…* (`slides.code.setHighlightSteps`, 07 §4.1): the
/// step syntax `1-3 | 5 | 7-9` with a syntax check (unknown items are
/// refused; lines past the end are kept and flagged in the inspector).
/// Returns the steps as typed, or null when cancelled.
Future<String?> showHighlightStepsDialog(
  BuildContext context, {
  String initial = '',
  int? lineCount,
  int startLine = 1,
}) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.codeStepsDialogTitle,
      description: l.codeStepsHint,
      dialogKey: 'dialog.slides.codeSteps',
      fields: [
        TextFieldSpec(
          id: 'steps',
          label: l.codeStepsLabel,
          initial: initial,
          placeholder: '1-3 | 5 | 7-9',
          validator: (v) {
            final issues = HighlightSteps.parse(
              v,
              lineCount: lineCount,
              startLine: startLine,
            ).issues;
            for (final i in issues) {
              if (i.code == 'syntax') return codeStepIssueText(l, i);
            }
            return null;
          },
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'apply', label: l.dialogApply, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'apply') return null;
  return r!.text('steps').trim();
}

/// The callout of a step (07 §4.4): inline Markdown text (≤ 280 chars),
/// side and style. Returns the callout JSON (`null` text = remove) or null
/// when cancelled.
Future<Map<String, Object?>?> showCodeCalloutDialog(
  BuildContext context, {
  required int step,
  CodeCallout? initial,
}) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.codeCalloutDialogTitle(step + 1),
      description: l.codeCalloutHint,
      dialogKey: 'dialog.slides.codeCallout',
      fields: [
        TextFieldSpec(
          id: 'text',
          label: l.codeCalloutText,
          initial: initial?.text ?? '',
          multiline: true,
          maxLength: CodeCallout.maxLength,
        ),
        SelectFieldSpec(
          id: 'side',
          label: l.codeCalloutSide,
          options: {
            'auto': l.codeSideAuto,
            'right': l.codeSideRight,
            'left': l.codeSideLeft,
            'above': l.codeSideAbove,
            'below': l.codeSideBelow,
          },
          initial: initial?.side ?? 'auto',
        ),
        SelectFieldSpec(
          id: 'style',
          label: l.codeCalloutStyle,
          options: {
            '': l.codeCalloutStyleDefault,
            'bubble': l.codeCalloutBubble,
            'label': l.codeCalloutLabel,
            'pill': l.codeCalloutPill,
          },
          initial: initial?.style ?? '',
        ),
      ],
      buttons: [
        if (initial != null)
          DialogButtonSpec(
            id: 'remove',
            label: l.codeCalloutRemove,
            validates: false,
          ),
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'apply', label: l.dialogSave, primary: true),
      ],
    ),
  );
  switch (r?.buttonId) {
    case 'remove':
      return const {'text': null};
    case 'apply':
      final text = r!.text('text').trim();
      if (text.isEmpty) return const {'text': null};
      final style = r.text('style');
      return {
        'text': text,
        'side': r.text('side'),
        if (style.isNotEmpty) 'style': style,
      };
    default:
      return null;
  }
}

/// *More…* typing settings of a state's arrival (07 §5.3). Returns a
/// `transitionJson` merge patch, or null when cancelled.
Future<Map<String, Object?>?> showTypingSettingsDialog(
  BuildContext context, {
  required TypingSettings settings,
}) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  String n(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
  String? number(String v, num min, num max) {
    final x = num.tryParse(v.trim());
    if (x == null || x < min || x > max) {
      return l.codeNumberRange(n(min), n(max));
    }
    return null;
  }

  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.codeTypingDialogTitle,
      dialogKey: 'dialog.slides.codeTyping',
      width: 460,
      fields: [
        TextFieldSpec(
          id: 'cps',
          label: l.codeTypingCps,
          initial: n(settings.cps),
          validator: (v) => number(v, 5, 200),
        ),
        TextFieldSpec(
          id: 'jitter',
          label: l.codeTypingRhythm,
          initial: n(settings.jitter),
          validator: (v) => number(v, 0, 1),
        ),
        SelectFieldSpec(
          id: 'deleteMode',
          label: l.codeTypingDeletions,
          options: {
            'auto': l.codeDeleteAuto,
            'backspace': l.codeDeleteBackspace,
            'select': l.codeDeleteSelect,
          },
          initial: settings.deleteMode.name,
        ),
        TextFieldSpec(
          id: 'backspaceMax',
          label: l.codeTypingBackspaceMax,
          initial: '${settings.backspaceMax}',
          validator: (v) => number(v, 0, 10000),
        ),
        TextFieldSpec(
          id: 'deleteCps',
          label: l.codeTypingDeleteCps,
          initial: n(settings.deleteCps),
          validator: (v) => number(v, 5, 400),
        ),
        TextFieldSpec(
          id: 'caretGlideMs',
          label: l.codeTypingCaretGlide,
          initial: '${settings.caretGlideMs}',
          validator: (v) => number(v, 0, 5000),
        ),
        SelectFieldSpec(
          id: 'order',
          label: l.codeTypingOrder,
          options: {
            'document': l.codeOrderDocument,
            'reverse': l.codeOrderReverse,
          },
          initial: settings.order.name,
        ),
        TextFieldSpec(
          id: 'pasteLines',
          label: l.codeTypingPasteLines,
          initial: '${settings.pasteLines}',
          validator: (v) => number(v, 1, 100000),
        ),
        TextFieldSpec(
          id: 'maxDurationMs',
          label: l.codeTypingMaxDuration,
          initial: '${settings.maxDurationMs}',
          validator: (v) => number(v, 200, 600000),
        ),
        SelectFieldSpec(
          id: 'caret',
          label: l.codeTypingCaret,
          options: {
            'bar': l.codeCaretBar,
            'block': l.codeCaretBlock,
            'underline': l.codeCaretUnderline,
          },
          initial: settings.caret.name,
        ),
        CheckboxFieldSpec(
          id: 'autoIndent',
          label: l.codeTypingAutoIndent,
          initial: settings.autoIndent,
        ),
        CheckboxFieldSpec(
          id: 'scrollFollow',
          label: l.codeTypingScrollFollow,
          initial: settings.scrollFollow,
        ),
        CheckboxFieldSpec(
          id: 'highlightOnArrive',
          label: l.codeTypingHighlightOnArrive,
          initial: settings.highlightOnArrive,
        ),
        TextFieldSpec(
          id: 'morphMs',
          label: l.codeMorphDuration,
          initial: '${settings.morphDurationMs}',
          validator: (v) => number(v, 0, 60000),
        ),
        TextFieldSpec(
          id: 'stagger',
          label: l.codeMorphStagger,
          initial: '${settings.morphStaggerMs}',
          validator: (v) => number(v, 0, 5000),
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'apply', label: l.dialogApply, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'apply') return null;
  num v(String id) => num.parse(r!.text(id).trim());
  return {
    'cps': v('cps'),
    'jitter': v('jitter'),
    'deleteMode': r!.text('deleteMode'),
    'backspaceMax': v('backspaceMax').round(),
    'deleteCps': v('deleteCps'),
    'caretGlideMs': v('caretGlideMs').round(),
    'order': r.text('order'),
    'pasteLines': v('pasteLines').round(),
    'maxDurationMs': v('maxDurationMs').round(),
    'caret': r.text('caret'),
    'autoIndent': r.flag('autoIndent'),
    'scrollFollow': r.flag('scrollFollow'),
    'highlightOnArrive': r.flag('highlightOnArrive'),
    'morphMs': v('morphMs').round(),
    'stagger': v('stagger').round(),
  };
}
