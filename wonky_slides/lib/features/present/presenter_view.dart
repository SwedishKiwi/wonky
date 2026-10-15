import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show PresentationRole;

import '../../l10n/slides_l10n.dart';
import '../../theme/slides_tokens.dart';
import '../editor_screen/slide_labels.dart';
import '../notes/notes_view.dart';
import '../settings/slides_user_defaults.dart';
import '../stage/slide_renderer.dart';
import '../thumbnails/slide_thumbnail.dart';
import 'present_controller.dart';
import 'present_ink.dart';
import 'present_overlays.dart';
import 'present_stage.dart';
import 'presentation_link.dart';

/// The presenter view in this window (Slides 10 §5.1): the current slide
/// (live, with the step indicator; pointer tools mirrored to the audience),
/// the next build or slide, the speaker notes (A−/A+), the timers (elapsed
/// or countdown with pause/reset, wall clock, slide n / N, pacing against
/// rehearsed timings), the audience controls and the strip of slides with
/// group separators. Chrome follows the app theme; slides render as
/// authored. Layout presets (`standard`, `notesFocus`, `nextLarge`) come
/// from the presenter preferences; below 720 px everything stacks.
///
/// The audience sees nothing of this window: it runs on another device or
/// browser joined to the presentation session (10 §5.2).
class PresenterView extends StatefulWidget {
  const PresenterView({
    super.key,
    required this.services,
    required this.controller,
    required this.renderer,
    required this.title,
    required this.onOpenOnDevice,
    this.onContextMenu,
  });

  final ShellServices services;
  final PresentController controller;
  final SlideRenderer renderer;
  final String title;
  final VoidCallback onOpenOnDevice;
  final void Function(Offset global)? onContextMenu;

  @override
  State<PresenterView> createState() => _PresenterViewState();
}

class _PresenterViewState extends State<PresenterView> {
  Timer? _tick;
  final _strip = ScrollController();
  final _notes = ScrollController();
  String? _stripFor;

  PresentController get c => widget.controller;
  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    // Timers and the clock refresh every second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _strip.dispose();
    _notes.dispose();
    super.dispose();
  }

  SlidesUserDefaults get _prefs => SlidesUserDefaults.of(s);

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => ColoredBox(
        key: const ValueKey<String>('slides.presenter'),
        color: theme.colorScheme.background,
        child: LayoutBuilder(
          builder: (context, box) {
            final narrow = box.maxWidth < 720;
            final layout = _prefs.presenterString(
              SlidesUserDefaults.keyPresenterLayout,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, narrow),
                Container(height: 1, color: theme.colorScheme.border),
                Expanded(
                  child: narrow
                      ? _narrowBody(context)
                      : _wideBody(context, layout),
                ),
                Container(height: 1, color: theme.colorScheme.border),
                SizedBox(
                  height: narrow ? 84 : 104,
                  child: _stripView(context, narrow ? 84 : 104),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- header

  Widget _header(BuildContext context, bool narrow) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(
              LucideIcons.presentation,
              size: 18,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  narrow
                      ? l.presenterViewTitle
                      : l.presenterViewTitleWithName(widget.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.large,
                ),
              ),
            ),
            _sessionChip(context, narrow),
            const SizedBox(width: 8),
            if (narrow)
              ShadTooltip(
                builder: (_) => Text(l.cmdPresentOpenOnAnotherDevice),
                child: ShadIconButton.outline(
                  key: const ValueKey<String>('slides.presenter.openOnDevice'),
                  semanticLabel: l.cmdPresentOpenOnAnotherDevice,
                  icon: const Icon(LucideIcons.monitorSmartphone, size: 16),
                  onPressed: widget.onOpenOnDevice,
                ),
              )
            else
              ShadButton.outline(
                key: const ValueKey<String>('slides.presenter.openOnDevice'),
                leading: const Icon(LucideIcons.monitorSmartphone, size: 16),
                onPressed: widget.onOpenOnDevice,
                child: Text(l.presenterOtherDevice),
              ),
            const SizedBox(width: 8),
            ShadButton.destructive(
              key: const ValueKey<String>('slides.presenter.end'),
              onPressed: () => invokePresent(s, context, 'slides.present.end'),
              child: Text(l.presentEnd),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionChip(BuildContext context, bool narrow) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final link = c.link;
    final (IconData icon, String text, Color color) = switch (link?.status) {
      null || PresentationLinkStatus.offline => (
        LucideIcons.wifiOff,
        l.presentOfflineNoDevices,
        theme.colorScheme.mutedForeground,
      ),
      PresentationLinkStatus.connecting ||
      PresentationLinkStatus.reconnecting => (
        LucideIcons.loader,
        l.presentConnecting,
        theme.colorScheme.mutedForeground,
      ),
      PresentationLinkStatus.ended => (
        LucideIcons.circleSlash,
        l.presentSessionEnded,
        theme.colorScheme.destructive,
      ),
      PresentationLinkStatus.connected => (
        LucideIcons.monitor,
        l.presentAudienceDevices(
          link!.participants
              .where((p) => p.role != PresentationRole.follower)
              .length,
        ),
        theme.colorScheme.foreground,
      ),
    };
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Row(
          key: const ValueKey<String>('slides.presenter.session'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            if (!narrow) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(color: color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ body

  Widget _wideBody(BuildContext context, String layout) {
    final current = _currentPane(context);
    final next = _nextPane(context);
    final notes = _notesPane(context);
    final timers = _timersPane(context);
    const gap = SizedBox(width: 12, height: 12);
    final Widget body = switch (layout) {
      'nextLarge' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: current),
                gap,
                Expanded(child: next),
              ],
            ),
          ),
          gap,
          Expanded(
            flex: 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: notes),
                gap,
                SizedBox(width: 240, child: timers),
              ],
            ),
          ),
        ],
      ),
      'notesFocus' => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: current),
                gap,
                Expanded(flex: 2, child: next),
              ],
            ),
          ),
          gap,
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                timers,
                gap,
                Expanded(child: notes),
              ],
            ),
          ),
        ],
      ),
      _ => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: current),
          gap,
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SizedBox(height: 180, child: next)),
                    gap,
                    SizedBox(width: 168, child: timers),
                  ],
                ),
                gap,
                Expanded(child: notes),
              ],
            ),
          ),
        ],
      ),
    };
    return Padding(padding: const EdgeInsets.all(12), child: body);
  }

  Widget _narrowBody(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      AspectRatio(aspectRatio: 16 / 11, child: _currentPane(context)),
      const SizedBox(height: 12),
      _timersPane(context),
      const SizedBox(height: 12),
      SizedBox(height: 160, child: _nextPane(context)),
      const SizedBox(height: 12),
      SizedBox(height: 280, child: _notesPane(context)),
    ],
  );

  Widget _paneLabel(BuildContext context, String text, {Widget? trailing}) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _currentPane(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final p = c.position;
    final steps = p == null ? 0 : c.timelineOf(p.slideId).stepCount;
    final label = p == null
        ? l.presenterCurrent
        : steps == 0
        ? l.presenterCurrent
        : l.presenterCurrentStep(p.step + 1, steps + 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paneLabel(
          context,
          label,
          trailing: c.blank == PresentBlank.none
              ? (c.degraded
                    ? Text(
                        key: const ValueKey<String>(
                          'slides.presenter.reducedEffects',
                        ),
                        l.presenterReducedEffects,
                        style: theme.textTheme.muted,
                      )
                    : null)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.blank == PresentBlank.black
                          ? l.presenterAudienceBlack
                          : l.presenterAudienceWhite,
                      style: theme.textTheme.small,
                    ),
                    const SizedBox(width: 6),
                    ShadButton.outline(
                      key: const ValueKey<String>('slides.presenter.showSlide'),
                      height: 26,
                      onPressed: () => invokePresent(
                        s,
                        context,
                        'slides.present.blank',
                        const {'color': 'none'},
                      ),
                      child: Text(l.presenterShowSlide),
                    ),
                  ],
                ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: PresentStage(
              key: const ValueKey<String>('slides.presenter.currentSlide'),
              controller: c,
              renderer: widget.renderer,
              letterbox: theme.colorScheme.muted,
              onSecondaryTap: widget.onContextMenu,
              reduceMotion: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _controls(context),
      ],
    );
  }

  Widget _controls(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    Widget btn(
      String key,
      IconData icon,
      String label,
      String id, [
      Map<String, Object?> args = const {},
      bool active = false,
    ]) => ShadTooltip(
      builder: (_) {
        final sc = s.keymap.labelsFor(id, args);
        return Text(sc == null ? label : '$label (${sc.join()})');
      },
      child: ShadIconButton.ghost(
        key: ValueKey<String>('slides.presenter.$key'),
        width: 34,
        height: 34,
        iconSize: 16,
        semanticLabel: label,
        backgroundColor: active ? theme.colorScheme.accent : null,
        icon: Icon(icon),
        onPressed: () => invokePresent(s, context, id, args),
      ),
    );
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        btn(
          'previous',
          LucideIcons.chevronLeft,
          l.cmdPresentPrevious,
          'slides.present.previous',
        ),
        btn(
          'next',
          LucideIcons.chevronRight,
          l.cmdPresentNext,
          'slides.present.next',
        ),
        btn(
          'picker',
          LucideIcons.layoutGrid,
          l.cmdPresentPicker,
          'slides.present.picker',
          const {'open': true},
        ),
        btn(
          'laser',
          LucideIcons.pointer,
          l.presentToolLaser,
          'slides.present.tool',
          const {'tool': 'laser', 'toggle': true},
          c.tool == PresentTool.laser,
        ),
        btn(
          'pen',
          LucideIcons.pen,
          l.presentToolPen,
          'slides.present.tool',
          const {'tool': 'pen', 'toggle': true},
          c.tool == PresentTool.pen,
        ),
        btn(
          'highlighter',
          LucideIcons.highlighter,
          l.presentToolHighlighter,
          'slides.present.tool',
          const {'tool': 'highlighter', 'toggle': true},
          c.tool == PresentTool.highlighter,
        ),
        btn(
          'eraser',
          LucideIcons.eraser,
          l.presentToolEraser,
          'slides.present.tool',
          const {'tool': 'eraser', 'toggle': true},
          c.tool == PresentTool.eraser,
        ),
        btn(
          'clear',
          LucideIcons.brushCleaning,
          l.cmdPresentClearInk,
          'slides.present.clearInk',
        ),
        btn(
          'black',
          LucideIcons.square,
          l.presentBlackScreen,
          'slides.present.blank',
          const {'color': 'black'},
          c.blank == PresentBlank.black,
        ),
        btn(
          'white',
          LucideIcons.squareDashed,
          l.presentWhiteScreen,
          'slides.present.blank',
          const {'color': 'white'},
          c.blank == PresentBlank.white,
        ),
        btn(
          'skipped',
          LucideIcons.eyeOff,
          l.cmdPresentToggleSkipped,
          'slides.present.toggleSkipped',
          const {},
          c.showSkipped,
        ),
        btn(
          'help',
          LucideIcons.keyboard,
          l.cmdPresentHelp,
          'slides.present.help',
        ),
      ],
    );
  }

  Widget _nextPane(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final cur = c.position;
    final n = c.upNext;
    String label;
    if (c.endScreen) {
      label = l.presenterNextExit;
    } else if (n == null) {
      label = l.presenterNextEnd;
    } else if (cur != null && n.slideId == cur.slideId) {
      label = l.presenterNextBuild(n.step, c.timelineOf(n.slideId).stepCount);
    } else {
      final t = SlideLabels.title(c.model, n.slideId);
      label = t.isEmpty
          ? l.presenterNextSlideUntitled
          : l.presenterNextSlide(t);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paneLabel(context, label),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: n == null
                ? ColoredBox(
                    key: const ValueKey<String>(
                      'slides.presenter.nextSlide.end',
                    ),
                    color: theme.colorScheme.muted,
                    child: Center(
                      child: Text(
                        l.presenterNextEnd,
                        style: theme.textTheme.muted,
                      ),
                    ),
                  )
                : PresentStage(
                    key: const ValueKey<String>('slides.presenter.nextSlide'),
                    controller: c,
                    renderer: widget.renderer,
                    position: n,
                    interactive: false,
                    showOverlays: false,
                    letterbox: theme.colorScheme.muted,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _notesPane(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final p = c.position;
    final json = p == null ? null : c.model.slide(p.slideId)?.notes;
    final style = theme.textTheme.p.copyWith(
      fontSize: c.notesSize.toDouble(),
      height: 1.4,
    );
    Widget sizeBtn(String key, IconData icon, String label, int delta) =>
        ShadTooltip(
          builder: (_) => Text(label),
          child: ShadIconButton.ghost(
            key: ValueKey<String>('slides.presenter.notes.$key'),
            width: 28,
            height: 28,
            iconSize: 14,
            semanticLabel: label,
            icon: Icon(icon),
            onPressed: () => invokePresent(
              s,
              context,
              'slides.present.notesSize',
              {'delta': delta},
            ),
          ),
        );
    final empty = json == null || json.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paneLabel(
          context,
          l.presenterNotes,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              sizeBtn(
                'smaller',
                LucideIcons.aArrowDown,
                l.presentNotesSmaller,
                -2,
              ),
              sizeBtn('larger', LucideIcons.aArrowUp, l.presentNotesLarger, 2),
            ],
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.colorScheme.border),
            ),
            child: Semantics(
              label: l.presenterNotes,
              container: true,
              child: SingleChildScrollView(
                key: const ValueKey<String>('slides.presenter.notes'),
                controller: _notes,
                padding: const EdgeInsets.all(12),
                child: empty
                    ? Text(l.presenterNoNotes, style: theme.textTheme.muted)
                    : NotesRichView(
                        json: json,
                        style: style,
                        linkColor: theme.colorScheme.primary,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _hms(int ms) {
    final neg = ms < 0;
    final t = ms.abs() ~/ 1000;
    final h = t ~/ 3600, m = (t % 3600) ~/ 60, sec = t % 60;
    final body = h > 0
        ? '$h:${'$m'.padLeft(2, '0')}:${'$sec'.padLeft(2, '0')}'
        : '${'$m'.padLeft(2, '0')}:${'$sec'.padLeft(2, '0')}';
    return neg ? '−$body' : body;
  }

  /// Rehearsed milliseconds up to the current step (null without
  /// rehearsed timings).
  int? _rehearsedUntilNow() {
    final p = c.position;
    if (p == null) return null;
    var total = 0;
    var any = false;
    for (final e in c.sequence.presented) {
      final raw = e.slide.timingsJson;
      Map<String, Object?>? t;
      if (raw != null) {
        try {
          final v = jsonDecode(raw);
          if (v is Map) t = v.cast<String, Object?>();
        } on FormatException {
          t = null;
        }
      }
      final steps = t?['stepsMs'];
      if (e.id == p.slideId) {
        if (steps is List) {
          any = true;
          for (var i = 0; i <= p.step && i < steps.length; i++) {
            final v = steps[i];
            if (v is num) total += v.toInt();
          }
        }
        break;
      }
      final tm = t?['totalMs'];
      if (tm is num) {
        any = true;
        total += tm.toInt();
      }
    }
    return any ? total : null;
  }

  Widget _timersPane(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final countdown =
        _prefs.presenterString(SlidesUserDefaults.keyTimerMode) == 'countdown';
    final target =
        _prefs.presenterInt(SlidesUserDefaults.keyTimerTargetMinutes) * 60000;
    final elapsed = c.timer.elapsedMs;
    final shown = countdown ? target - elapsed : elapsed;
    final over = countdown && shown < 0;
    final (n, total) = c.counter;
    final rehearsed = _rehearsedUntilNow();
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    Widget? pacing;
    if (rehearsed != null) {
      final diff = rehearsed - elapsed;
      final ahead = diff >= 0;
      final filled = (3 + (diff / 30000).round()).clamp(1, 5);
      pacing = Semantics(
        label: ahead
            ? l.presenterAhead(_hms(diff))
            : l.presenterBehind(_hms(-diff)),
        child: ExcludeSemantics(
          child: Row(
            key: const ValueKey<String>('slides.presenter.pacing'),
            children: [
              for (var i = 1; i <= 5; i++)
                Container(
                  width: 10,
                  height: 6,
                  margin: const EdgeInsets.only(right: 2),
                  color: i <= filled
                      ? (ahead
                            ? theme.colorScheme.primary
                            : theme.colorScheme.destructive)
                      : theme.colorScheme.muted,
                ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  ahead
                      ? l.presenterAhead(_hms(diff))
                      : l.presenterBehind(_hms(-diff)),
                  style: theme.textTheme.small,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      key: const ValueKey<String>('slides.presenter.timers'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: countdown
              ? l.presenterRemaining(_hms(shown))
              : l.presenterElapsed(_hms(shown)),
          child: ExcludeSemantics(
            child: Text(
              _hms(shown),
              key: const ValueKey<String>('slides.presenter.timer'),
              style: theme.textTheme.h3.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: over ? theme.colorScheme.destructive : null,
              ),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShadTooltip(
              builder: (_) => Text(
                c.timer.running ? l.presentTimerPause : l.presentTimerResume,
              ),
              child: ShadIconButton.ghost(
                key: const ValueKey<String>('slides.presenter.timer.pause'),
                width: 28,
                height: 28,
                iconSize: 14,
                semanticLabel: c.timer.running
                    ? l.presentTimerPause
                    : l.presentTimerResume,
                icon: Icon(
                  c.timer.running ? LucideIcons.pause : LucideIcons.play,
                ),
                onPressed: () => invokePresent(
                  s,
                  context,
                  'slides.present.timer',
                  const {'action': 'toggle'},
                ),
              ),
            ),
            ShadTooltip(
              builder: (_) => Text(l.presentTimerReset),
              child: ShadIconButton.ghost(
                key: const ValueKey<String>('slides.presenter.timer.reset'),
                width: 28,
                height: 28,
                iconSize: 14,
                semanticLabel: l.presentTimerReset,
                icon: const Icon(LucideIcons.rotateCcw),
                onPressed: () => invokePresent(
                  s,
                  context,
                  'slides.present.timer',
                  const {'action': 'reset'},
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat.Hm(locale).format(DateTime.now()),
          style: theme.textTheme.muted,
        ),
        Text(
          l.presenterSlideOf(n, total),
          key: const ValueKey<String>('slides.presenter.counter'),
          style: theme.textTheme.small,
        ),
        if (pacing != null) ...[const SizedBox(height: 4), pacing],
      ],
    );
  }

  // ----------------------------------------------------------------- strip

  Widget _stripView(BuildContext context, double height) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final order = c.sequence.order;
    final cur = c.position?.slideId;
    // Thumbnail height = strip − padding (16) − number row (18).
    final size = widget.renderer.slideSize;
    final thumb = (height - 34) * size.width / size.height;
    final items = <Widget>[];
    String? group;
    var curOffset = 0.0;
    var x = 8.0;
    for (final e in order.entries) {
      if (e.groupId != group) {
        group = e.groupId;
        final g = group == null ? null : c.model.group(group);
        if (g != null) {
          final color =
              SlidesTokens.of(context).groupColor(g.color) ??
              theme.colorScheme.mutedForeground;
          items.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 3, height: 40, color: color),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 64,
                    child: Text(
                      g.title.isEmpty ? l.groupUntitled : g.title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.muted.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          );
          x += 76;
        }
      }
      if (e.id == cur) curOffset = x;
      x += thumb + 8;
      final current = e.id == cur;
      final title = SlideLabels.title(c.model, e.id);
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Semantics(
            button: true,
            selected: current,
            label: l.presentPickerSlide(
              e.index + 1,
              title.isEmpty ? l.slideUntitled : title,
            ),
            hint: e.skipped ? l.presentPickerSkipped : null,
            child: GestureDetector(
              key: ValueKey<String>('slides.presenter.strip.${e.id}'),
              onTap: () => invokePresent(s, context, 'slides.present.goTo', {
                'slideId': e.id,
              }),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: e.skipped && !c.showSkipped ? 0.4 : 1,
                      child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: current
                                ? theme.colorScheme.primary
                                : theme.colorScheme.border,
                            width: current ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: SlideThumbnail(
                          renderer: widget.renderer,
                          slideId: e.id,
                          width: thumb,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${e.index + 1}',
                          style: theme.textTheme.muted.copyWith(fontSize: 11),
                        ),
                        if (e.skipped) ...[
                          const SizedBox(width: 3),
                          Icon(
                            LucideIcons.eyeOff,
                            size: 10,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (cur != _stripFor) {
      _stripFor = cur;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_strip.hasClients) return;
        final view = _strip.position.viewportDimension;
        final target = (curOffset - view / 2 + thumb / 2).clamp(
          0.0,
          math.max(0.0, _strip.position.maxScrollExtent),
        );
        unawaited(
          _strip.animateTo(
            target.toDouble(),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      });
    }
    return Semantics(
      label: l.presenterStrip,
      container: true,
      child: SingleChildScrollView(
        key: const ValueKey<String>('slides.presenter.strip'),
        controller: _strip,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: items),
      ),
    );
  }
}
