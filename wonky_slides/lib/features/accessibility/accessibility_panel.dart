import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../config/panels/slides_panels.dart';
import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../editor_screen/slide_labels.dart';
import '../layers/element_names.dart';
import '../toolbar/command_ui.dart';
import 'accessibility_checker.dart';
import 'accessibility_controller.dart';

/// The Accessibility side panel (`slides.panel.accessibility`, 03 §17.4).
SidePanelSpec accessibilityPanelSpec(
  BuildContext context,
  ShellServices services,
  DeckEditorController editor,
) => SidePanelSpec(
  id: SlidesPanels.accessibility,
  title: slidesL10n(context).a11yPanelTitle,
  icon: LucideIcons.accessibility,
  builder: (context) => AccessibilityPanel(services: services, editor: editor),
);

/// Stable widget keys of the Accessibility panel.
abstract final class AccessibilityPanelKeys {
  static const panel = ValueKey<String>('slides.a11y.panel');
  static const summary = ValueKey<String>('slides.a11y.summary');
  static const refresh = ValueKey<String>('slides.a11y.refresh');
  static const empty = ValueKey<String>('slides.a11y.empty');

  static ValueKey<String> slide(String id) =>
      ValueKey<String>('slides.a11y.slide.$id');
  static ValueKey<String> issue(A11yIssue i) =>
      ValueKey<String>('slides.a11y.issue.${i.id}');
  static ValueKey<String> goTo(A11yIssue i) =>
      ValueKey<String>('slides.a11y.goTo.${i.id}');
  static ValueKey<String> fix(A11yIssue i) =>
      ValueKey<String>('slides.a11y.fix.${i.id}');
  static ValueKey<String> decorative(A11yIssue i) =>
      ValueKey<String>('slides.a11y.decorative.${i.id}');
}

/// The Accessibility panel (03 §17.4): a summary (errors, warnings, tips)
/// with *Check again*, then the issues grouped by slide, each with *Go to*
/// and its quick fix (`slides.a11y.fix`, one undo step). The report is
/// re-checked while the panel is open.
class AccessibilityPanel extends StatefulWidget {
  const AccessibilityPanel({
    super.key,
    required this.services,
    required this.editor,
  });

  final ShellServices services;
  final DeckEditorController editor;

  @override
  State<AccessibilityPanel> createState() => _AccessibilityPanelState();
}

class _AccessibilityPanelState extends State<AccessibilityPanel> {
  final _scroll = ScrollController();
  late final AccessibilityController _a11y = accessibilityOf(widget.editor);

  @override
  void initState() {
    super.initState();
    _a11y.watch();
  }

  @override
  void dispose() {
    _a11y.unwatch();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_a11y, widget.services.registry]),
    builder: (context, _) {
      final l = slidesL10n(context);
      final theme = ShadTheme.of(context);
      final ui = SlidesCommandUi(context, widget.services);
      final report = _a11y.report ?? const AccessibilityReport([]);
      final ed = widget.editor;
      final children = <Widget>[
        _summary(context, ui, l, report),
        const SizedBox(height: 8),
      ];
      if (report.issues.isEmpty) {
        children.add(
          Padding(
            key: AccessibilityPanelKeys.empty,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  LucideIcons.circleCheck,
                  size: 24,
                  color: theme.colorScheme.success,
                ),
                const SizedBox(height: 8),
                Text(
                  l.a11yNoIssues,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.small,
                ),
                const SizedBox(height: 4),
                Text(
                  l.a11yNoIssuesBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.muted,
                ),
              ],
            ),
          ),
        );
      }
      String? lastSlide;
      for (final issue in report.issues) {
        if (issue.slideId != lastSlide) {
          lastSlide = issue.slideId;
          final entry = ed.order.entry(issue.slideId);
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                entry == null
                    ? l.outlineNoTitle
                    : l.a11ySlideHeading(
                        SlideLabels.goToLabel(
                          ed.model,
                          entry,
                          untitled: l.outlineNoTitle,
                        ),
                      ),
                key: AccessibilityPanelKeys.slide(issue.slideId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
        children.add(_issueRow(context, ui, l, issue));
      }
      return Semantics(
        container: true,
        label: l.a11yPanelTitle,
        child: KeyedSubtree(
          key: AccessibilityPanelKeys.panel,
          child: WonkyScrollArea(
            controller: _scroll,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: children,
            ),
          ),
        ),
      );
    },
  );

  Widget _summary(
    BuildContext context,
    SlidesCommandUi ui,
    SlidesLocalizations l,
    AccessibilityReport report,
  ) {
    final theme = ShadTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l.a11ySummary(
              report.count(A11ySeverity.error),
              report.count(A11ySeverity.warning),
              report.count(A11ySeverity.info),
            ),
            key: AccessibilityPanelKeys.summary,
            style: theme.textTheme.muted,
          ),
        ),
        ShadTooltip(
          builder: (_) => Text(l.a11yCheckAgain),
          child: ShadIconButton.ghost(
            key: AccessibilityPanelKeys.refresh,
            width: 28,
            height: 28,
            iconSize: 14,
            semanticLabel: l.a11yCheckAgain,
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ui.run(
              'slides.tools.accessibilityCheck',
              const {},
              InvocationSource.ui,
            ),
          ),
        ),
      ],
    );
  }

  Widget _issueRow(
    BuildContext context,
    SlidesCommandUi ui,
    SlidesLocalizations l,
    A11yIssue issue,
  ) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final (icon, color, severity) = switch (issue.severity) {
      A11ySeverity.error => (
        LucideIcons.circleX,
        cs.destructive,
        l.a11ySeverityError,
      ),
      A11ySeverity.warning => (
        LucideIcons.triangleAlert,
        cs.warning,
        l.a11ySeverityWarning,
      ),
      A11ySeverity.info => (LucideIcons.info, cs.info, l.a11ySeverityInfo),
    };
    final rec = issue.elementId == null
        ? null
        : widget.editor.model.element(issue.elementId!);
    final name = rec == null ? null : ElementNames.of(l, rec);
    final message = a11yMessage(l, issue);
    final goArgs = {'slideId': issue.slideId, 'elementId': ?issue.elementId};
    final fixArgs = {
      'rule': issue.rule.name,
      'slideId': issue.slideId,
      'elementId': ?issue.elementId,
    };
    final fixLabel = a11yFixLabel(l, issue.rule);
    final canFix = ui.state('slides.a11y.fix', fixArgs).enabled;
    Widget action(Key key, String label, VoidCallback onPressed, bool on) =>
        ShadButton.outline(
          key: key,
          size: ShadButtonSize.sm,
          enabled: on,
          onPressed: onPressed,
          child: Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        );
    return Semantics(
      key: AccessibilityPanelKeys.issue(issue),
      container: true,
      label: '$severity: $message${name == null ? '' : ', $name'}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(icon, size: 14, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message, style: theme.textTheme.small),
                        if (name != null)
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.muted,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                action(
                  AccessibilityPanelKeys.goTo(issue),
                  l.a11yGoTo,
                  () => ui.run('slides.a11y.goTo', goArgs, InvocationSource.ui),
                  true,
                ),
                if (fixLabel != null)
                  action(
                    AccessibilityPanelKeys.fix(issue),
                    fixLabel,
                    () =>
                        ui.run('slides.a11y.fix', fixArgs, InvocationSource.ui),
                    canFix,
                  ),
                if (issue.rule == A11yRule.missingAltText)
                  action(
                    AccessibilityPanelKeys.decorative(issue),
                    l.a11yFixDecorative,
                    () => ui.run('slides.a11y.fix', {
                      ...fixArgs,
                      'decorative': true,
                    }, InvocationSource.ui),
                    canFix,
                  ),
                if (issue.rule == A11yRule.readingOrder)
                  action(
                    ValueKey<String>('slides.a11y.order.${issue.id}'),
                    l.a11yEditReadingOrder,
                    () => ui.run('slides.panel.layers', {
                      'tab': 'readingOrder',
                    }, InvocationSource.ui),
                    ui.state('slides.panel.layers').enabled,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The message of [issue] (panel, MCP `message`).
String a11yMessage(SlidesLocalizations l, A11yIssue issue) =>
    switch (issue.rule) {
      A11yRule.missingAltText => l.a11yMissingAltText,
      A11yRule.lowContrast => l.a11yLowContrast(
        (issue.ratio ?? 0).toStringAsFixed(1),
        (issue.required ?? 4.5).toStringAsFixed(1),
      ),
      A11yRule.contrastOverImage => l.a11yContrastOverImage,
      A11yRule.missingTitle => l.a11yMissingTitle,
      A11yRule.duplicateTitle => l.a11yDuplicateTitle(issue.title ?? ''),
      A11yRule.smallText => l.a11ySmallText(
        (issue.size ?? 0).round(),
        AccessibilityChecker.minTextSize.round(),
      ),
      A11yRule.readingOrder => l.a11yReadingOrder,
      A11yRule.tableHeader => l.a11yTableHeader,
      A11yRule.emptyPlaceholder => l.a11yEmptyPlaceholder,
    };

/// The label of the quick fix of [rule], or null without one.
String? a11yFixLabel(SlidesLocalizations l, A11yRule rule) => switch (rule) {
  A11yRule.missingAltText => l.a11yFixAltText,
  A11yRule.lowContrast => l.a11yFixContrast,
  A11yRule.smallText => l.a11yFixTextSize(
    AccessibilityChecker.minTextSize.round(),
  ),
  A11yRule.readingOrder => l.a11yFixReadingOrder,
  A11yRule.tableHeader => l.a11yFixTableHeader,
  A11yRule.emptyPlaceholder => l.a11yFixRemovePlaceholder,
  A11yRule.contrastOverImage ||
  A11yRule.missingTitle ||
  A11yRule.duplicateTitle => null,
};
