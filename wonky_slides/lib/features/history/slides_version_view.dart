import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show ItemVersionView, UuidValue;
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_slides_core/history.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;
import 'package:wonky_ui/wonky_ui.dart';

import '../../commands/slides_command.dart' show editorOfServices;
import '../../l10n/slides_l10n.dart';
import '../stage/slide_renderer.dart';
import '../stage/slide_stage.dart';
import '../thumbnails/slide_thumbnail.dart';
import '../uploads/slides_image_service.dart';
import 'change_labels.dart';
import 'version_copy.dart';
import 'version_snapshots.dart';

/// A read-only deck version in the history route (Slides 09 §4.2): the
/// version's navigator with change badges, the selected slide on a
/// read-only stage with changed objects outlined in their author's
/// presence color (added ones with a "+" tag, removed ones as dashed
/// ghosts), and the *Changes on this slide* list with inline text diffs.
/// The shell's versions list and top bar (restore, *Show changes*) frame
/// it ([VersionHistoryScreen]).
class SlidesVersionView extends StatefulWidget {
  const SlidesVersionView({
    super.key,
    required this.services,
    required this.itemUuid,
    required this.version,
    required this.previous,
    required this.showChanges,
  });

  final ShellServices services;
  final UuidValue itemUuid;
  final ItemVersionView version;
  final ItemVersionView? previous;
  final bool showChanges;

  /// The version shown in the history route (the `slides.history.*`
  /// commands act on it).
  static final ValueNotifier<SlidesVersionViewState?> current = ValueNotifier(
    null,
  );

  /// *Show removed objects* (`slides.history.toggleShowRemoved`).
  static final ValueNotifier<bool> showRemoved = ValueNotifier(true);

  /// Overrides `slidesVersion.changes` (tests).
  @visibleForTesting
  static Future<String> Function(UuidValue item, int versionId)? fetchChanges;

  /// Below this width the navigator becomes a strip above the stage and
  /// the change list goes below it.
  static const narrowWidth = 720.0;

  @override
  State<SlidesVersionView> createState() => SlidesVersionViewState();
}

/// The state of [SlidesVersionView] (commands drive it through
/// [SlidesVersionView.current]).
class SlidesVersionViewState extends State<SlidesVersionView> {
  DeckModel? model;
  DeckModel? previousModel;
  DeckDiff? diff;
  SlidesVersionChanges changes = SlidesVersionChanges.empty;
  SlideRenderer? renderer;
  SlideRenderer? previousRenderer;
  Object? _error;
  bool _copying = false;

  /// The shown slide (of the version, or of the previous version when
  /// [showingRemoved]).
  String? slideId;

  /// Whether [slideId] is a slide deleted in this version (its ghost row).
  bool showingRemoved = false;

  /// The element highlighted by next/previous change or a click in the
  /// change list.
  String? activeElementId;

  /// Position in [DeckDiff.stops] (−1 = none).
  int stopIndex = -1;

  ShellServices get s => widget.services;

  bool get copying => _copying;

  @override
  void initState() {
    super.initState();
    SlidesVersionView.current.value = this;
    SlidesVersionView.showRemoved.addListener(_rebuild);
    unawaited(_load());
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(SlidesVersionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showChanges != widget.showChanges &&
        widget.showChanges &&
        diff == null) {
      unawaited(_loadDiff());
    }
  }

  @override
  void dispose() {
    if (SlidesVersionView.current.value == this) {
      SlidesVersionView.current.value = null;
    }
    SlidesVersionView.showRemoved.removeListener(_rebuild);
    final r = renderer, p = previousRenderer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      r?.dispose();
      p?.dispose();
    });
    super.dispose();
  }

  SlideRenderer _rendererOf(DeckModel m) {
    final editor = editorOfServices(s);
    return SlideRenderer(
      model: m,
      images: editor == null ? null : SlidesImageService.of(editor),
    );
  }

  Future<void> _load() async {
    try {
      final snapshot = await SlidesVersionSnapshots.load(
        s,
        widget.itemUuid,
        widget.version.id,
      );
      if (!mounted) return;
      final m = snapshot.toModel();
      setState(() {
        model = m;
        renderer = _rendererOf(m);
        slideId = m.indexes.order.entries.firstOrNull?.id;
      });
      if (widget.showChanges) await _loadDiff();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<SlidesVersionChanges> _attribution() async {
    try {
      final override = SlidesVersionView.fetchChanges;
      final client = s.client;
      if (override == null && (client == null || Api.simulatedOffline)) {
        return SlidesVersionChanges.empty;
      }
      final json = override != null
          ? await override(widget.itemUuid, widget.version.id)
          : await client!.slidesVersion.changes(
              widget.itemUuid,
              widget.version.id,
            );
      return SlidesVersionChanges.parse(json);
    } catch (e) {
      debugPrint('Version authors unavailable: $e');
      return SlidesVersionChanges.empty;
    }
  }

  Future<void> _loadDiff() async {
    final m = model;
    if (m == null) return;
    DeckModel? before;
    final prev = widget.previous;
    if (prev != null) {
      try {
        before = (await SlidesVersionSnapshots.load(
          s,
          widget.itemUuid,
          prev.id,
        )).toModel();
      } catch (e) {
        debugPrint('Previous version unavailable: $e');
        return;
      }
    }
    final d = DeckDiff.compute(before, m);
    final attribution = await _attribution();
    if (!mounted) return;
    setState(() {
      previousModel = before;
      previousRenderer = before == null ? null : _rendererOf(before);
      diff = d;
      changes = attribution;
      stopIndex = -1;
      activeElementId = null;
    });
  }

  // ------------------------------------------------------------ colors

  /// The presence color of author [id]; unknown authors take the single
  /// author's color, else a neutral color (several authors, 09 §4.2).
  Color colorOf(ShadColorScheme cs, int? id) {
    final authors = widget.version.authors;
    if (id != null) {
      for (final a in authors) {
        if (a.id == id) return cs.presence(a.colorIndex);
      }
    }
    return authors.length == 1
        ? cs.presence(authors.single.colorIndex)
        : cs.mutedForeground;
  }

  VersionChangeLabels labels(BuildContext context) => VersionChangeLabels(
    slidesL10n(context),
    authors: widget.version.authors,
    changes: changes,
    someone: WonkyAppLocalizations.of(context).someone,
  );

  // ------------------------------------------------------------ navigation

  /// Shows [id] (a slide of the version, or with [removed] a slide deleted
  /// in it, from the previous version).
  void selectSlide(String id, {bool removed = false}) {
    setState(() {
      slideId = id;
      showingRemoved = removed;
      activeElementId = null;
      final i = diff?.stops.indexWhere(
        (st) => st.slideId == id && st.elementId == null,
      );
      if (i != null && i >= 0) stopIndex = i;
    });
  }

  /// Highlights element [id] on the shown slide.
  void selectElement(String? id) {
    setState(() {
      activeElementId = id;
      final i = diff?.stops.indexWhere(
        (st) => st.slideId == slideId && st.elementId == id,
      );
      if (i != null && i >= 0) stopIndex = i;
    });
  }

  /// Moves to the next/previous changed slide or object in presentation
  /// order (`slides.history.nextChange` / `previousChange`). Returns the
  /// stop, or null without changes.
  DeckChangeStop? step({required bool forward}) {
    final stops = diff?.stops ?? const <DeckChangeStop>[];
    if (stops.isEmpty) return null;
    final n = stops.length;
    final next = forward
        ? (stopIndex + 1) % n
        : (stopIndex <= 0 ? n - 1 : stopIndex - 1);
    final stop = stops[next];
    setState(() {
      stopIndex = next;
      slideId = stop.slideId;
      showingRemoved = false;
      activeElementId = stop.elementId;
    });
    return stop;
  }

  // -------------------------------------------------------------- actions

  /// The default name of a copy ("Copy of Pitch").
  String get copyName {
    final l = slidesL10nOf(s);
    final title = model?.deck?.title ?? '';
    return l.versionCopyName(
      title.isNotEmpty ? title : s.currentItem.value?.name ?? '',
    );
  }

  /// *Make a copy* of this version (09 §4.5). Returns the new item, or
  /// null when it failed (a toast says why).
  Future<UuidValue?> makeCopy({
    String? name,
    UuidValue? folderUuid,
    bool copyComments = false,
    bool copySharing = false,
  }) async {
    if (_copying) return null;
    final l = slidesL10nOf(s);
    final title = (name ?? copyName).trim();
    setState(() => _copying = true);
    try {
      final copy = await copySlidesVersion(
        s,
        itemUuid: widget.itemUuid,
        versionId: widget.version.id,
        name: title,
        folderUuid: folderUuid,
        copyComments: copyComments,
        copySharing: copySharing,
      );
      s.refreshDrive();
      s.toasts.show(
        l.toastVersionCopied(copy.name),
        actionLabel: l.versionOpenCopy,
        onAction: () => s.router.go(s.config.itemPath(copy.uuid.uuid)),
      );
      return copy.uuid;
    } catch (e) {
      s.toasts.error(l.toastVersionCopyFailed, description: errorMessage(e));
      return null;
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  /// *Make a copy* with its dialog (name, comments, sharing).
  Future<UuidValue?> makeCopyWithDialog(BuildContext context) async {
    final r = await showVersionCopyDialog(context, initialName: copyName);
    if (r == null) return null;
    return makeCopy(
      name: r.name,
      copyComments: r.comments,
      copySharing: r.sharing,
    );
  }

  /// *Download as PDF* of this version (09 §4.5). Returns the file name
  /// (null when cancelled).
  Future<String?> download() async {
    final m = model;
    final r = renderer;
    if (m == null || r == null) return null;
    final l = slidesL10nOf(s);
    try {
      return await downloadSlidesVersionPdf(
        s,
        m,
        images: r.images.resolver,
        fileName: _fileName(),
      );
    } catch (e) {
      s.toasts.error(
        l.toastVersionDownloadFailed,
        description: errorMessage(e),
      );
      rethrow;
    }
  }

  String _fileName() {
    final title = (model?.deck?.title ?? '').trim();
    final base = (title.isEmpty ? 'Presentation' : title).replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    final at = widget.version.createdAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '$base ${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}${two(at.minute)}.pdf';
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final err = _error;
    if (err != null) {
      return WonkyEmptyState(
        key: const ValueKey<String>('slides.version.error'),
        illustration: isOfflineError(err)
            ? EmptyIllustration.offline
            : EmptyIllustration.error,
        title: l.versionLoadFailed,
        description: errorMessage(err),
        actions: [
          ShadButton.outline(
            onPressed: () {
              setState(() => _error = null);
              unawaited(_load());
            },
            child: Text(WonkyAppLocalizations.of(context).actionRetry),
          ),
        ],
      );
    }
    final m = model;
    final r = renderer;
    if (m == null || r == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ShadSpinner(),
            const SizedBox(height: 12),
            Text(l.versionLoading, style: theme.textTheme.muted),
          ],
        ),
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < SlidesVersionView.narrowWidth;
          final bar = _VersionBar(state: this, compact: c.maxWidth < 480);
          final stage = _VersionStage(state: this);
          final list = _ChangeList(state: this);
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                bar,
                SizedBox(
                  height: 100,
                  child: _VersionNavigator(state: this, horizontal: true),
                ),
                Expanded(child: stage),
                SizedBox(
                  height: math.min(200, c.maxHeight * 0.35),
                  child: list,
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bar,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 188,
                      child: _VersionNavigator(state: this, horizontal: false),
                    ),
                    Expanded(child: stage),
                    Container(
                      width: 260,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: theme.colorScheme.border),
                        ),
                      ),
                      child: list,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Summary, author legend, change navigation, *Show removed*, download and
/// *Make a copy*.
class _VersionBar extends StatelessWidget {
  const _VersionBar({required this.state, this.compact = false});

  final SlidesVersionViewState state;

  /// Narrow widths: icon-only actions, no author legend.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final s = state.s;
    final d = state.diff;
    final show = state.widget.showChanges;
    final stops = d?.stops ?? const <DeckChangeStop>[];
    void invoke(String id) => unawaited(
      s.dispatcher.invoke(id, source: InvocationSource.ui, context: context),
    );
    Widget icon(
      String key,
      IconData i,
      String label,
      String command, {
      bool enabled = true,
      bool selected = false,
    }) => ShadTooltip(
      builder: (_) => Text(label),
      child: ShadIconButton.ghost(
        key: ValueKey<String>(key),
        width: 28,
        height: 28,
        iconSize: 16,
        semanticLabel: label,
        enabled: enabled,
        backgroundColor: selected ? cs.accent : null,
        icon: Icon(i),
        onPressed: () => invoke(command),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: cs.background,
        border: Border(bottom: BorderSide(color: cs.border)),
      ),
      child: Row(
        children: [
          if (show && !compact) ...[
            _AuthorLegend(state: state),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              !show
                  ? l.versionChangesHidden
                  : d == null
                  ? l.versionComputingChanges
                  : state.labels(context).summary(d),
              key: const ValueKey<String>('slides.version.summary'),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: theme.textTheme.small,
            ),
          ),
          if (show && stops.isNotEmpty) ...[
            Text(
              state.stopIndex < 0
                  ? '${stops.length}'
                  : l.versionChangeCounter(state.stopIndex + 1, stops.length),
              style: theme.textTheme.muted,
            ),
            icon(
              'slides.version.prev',
              LucideIcons.chevronUp,
              l.cmdHistoryPreviousChange,
              'slides.history.previousChange',
            ),
            icon(
              'slides.version.next',
              LucideIcons.chevronDown,
              l.cmdHistoryNextChange,
              'slides.history.nextChange',
            ),
          ],
          if (show)
            icon(
              'slides.version.showRemoved',
              LucideIcons.squareDashed,
              l.cmdHistoryToggleShowRemoved,
              'slides.history.toggleShowRemoved',
              selected: SlidesVersionView.showRemoved.value,
            ),
          icon(
            'slides.version.download',
            LucideIcons.download,
            l.cmdHistoryDownload,
            'slides.history.download',
          ),
          if (compact)
            icon(
              'slides.version.copy',
              LucideIcons.copy,
              l.cmdHistoryMakeCopy,
              'slides.history.makeCopy',
              enabled: !state.copying,
            )
          else ...[
            const SizedBox(width: 4),
            ShadButton.outline(
              key: const ValueKey<String>('slides.version.copy'),
              size: ShadButtonSize.sm,
              enabled: !state.copying,
              leading: state.copying
                  ? const SizedBox.square(dimension: 14, child: ShadSpinner())
                  : const Icon(LucideIcons.copy, size: 14),
              onPressed: () => invoke('slides.history.makeCopy'),
              child: Text(l.cmdHistoryMakeCopy),
            ),
          ],
        ],
      ),
    );
  }
}

/// The version's authors with their change colors.
class _AuthorLegend extends StatelessWidget {
  const _AuthorLegend({required this.state});

  final SlidesVersionViewState state;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final authors = state.widget.version.authors;
    final shown = authors.take(3).toList();
    final labels = state.labels(context);
    Widget dot(Color c) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    if (shown.isEmpty) return dot(state.colorOf(cs, null));
    return ShadTooltip(
      builder: (_) =>
          Text([for (final a in authors) labels.author(a.id)].join(', ')),
      child: Row(
        key: const ValueKey<String>('slides.version.authors'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in shown) ...[
            dot(cs.presence(a.colorIndex)),
            const SizedBox(width: 3),
          ],
          if (authors.length > 3)
            Text('+${authors.length - 3}', style: theme.textTheme.muted),
        ],
      ),
    );
  }
}

/// One row of the version navigator.
sealed class _NavRow {
  const _NavRow();
}

final class _GroupRow extends _NavRow {
  const _GroupRow(this.group);
  final SlideGroupRec group;
}

final class _SlideRow extends _NavRow {
  const _SlideRow(this.entry);
  final SlideOrderEntry entry;
}

final class _GhostRow extends _NavRow {
  const _GhostRow(this.removed);
  final RemovedSlide removed;
}

/// The version's slides (groups, thumbnails) with change badges and ghost
/// rows of deleted slides (09 §4.2 step 3). Arrow keys move between rows.
class _VersionNavigator extends StatefulWidget {
  const _VersionNavigator({required this.state, required this.horizontal});

  final SlidesVersionViewState state;
  final bool horizontal;

  @override
  State<_VersionNavigator> createState() => _VersionNavigatorState();
}

class _VersionNavigatorState extends State<_VersionNavigator> {
  final _focus = FocusNode(debugLabel: 'slides.version.navigator');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  List<_NavRow> _rows() {
    final st = widget.state;
    final m = st.model!;
    final show = st.widget.showChanges;
    final removed = show
        ? st.diff?.removedSlides ?? const <RemovedSlide>[]
        : const <RemovedSlide>[];
    final order = m.indexes.order;
    final out = <_NavRow>[
      for (final r in removed)
        if (r.afterSlideId == null) _GhostRow(r),
    ];
    String? group;
    for (final e in order.entries) {
      if (e.groupId != group) {
        group = e.groupId;
        final g = group == null ? null : m.group(group);
        if (g != null) out.add(_GroupRow(g));
      }
      out.add(_SlideRow(e));
      for (final r in removed) {
        if (r.afterSlideId == e.id) out.add(_GhostRow(r));
      }
    }
    return out;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final back = widget.horizontal
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowUp;
    final forward = widget.horizontal
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowDown;
    if (e.logicalKey != back && e.logicalKey != forward) {
      return KeyEventResult.ignored;
    }
    final st = widget.state;
    final rows = [
      for (final r in _rows())
        if (r is! _GroupRow) r,
    ];
    final at = rows.indexWhere(
      (r) => switch (r) {
        _SlideRow(:final entry) => !st.showingRemoved && entry.id == st.slideId,
        _GhostRow(:final removed) =>
          st.showingRemoved && removed.change.slideId == st.slideId,
        _GroupRow() => false,
      },
    );
    final next = (at + (e.logicalKey == forward ? 1 : -1)).clamp(
      0,
      rows.length - 1,
    );
    if (rows.isEmpty) return KeyEventResult.handled;
    switch (rows[next]) {
      case _SlideRow(:final entry):
        st.selectSlide(entry.id);
      case _GhostRow(:final removed):
        st.selectSlide(removed.change.slideId, removed: true);
      case _GroupRow():
        break;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    final cs = ShadTheme.of(context).colorScheme;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Container(
        decoration: BoxDecoration(
          color: cs.muted,
          border: widget.horizontal
              ? Border(bottom: BorderSide(color: cs.border))
              : Border(right: BorderSide(color: cs.border)),
        ),
        child: ListView.builder(
          key: const ValueKey<String>('slides.version.navigator'),
          scrollDirection: widget.horizontal ? Axis.horizontal : Axis.vertical,
          padding: const EdgeInsets.all(8),
          itemCount: rows.length,
          itemBuilder: (context, i) => _row(context, rows[i]),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, _NavRow row) {
    final st = widget.state;
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final show = st.widget.showChanges;
    final thumbWidth = widget.horizontal ? 96.0 : 140.0;
    Widget tag(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.small.copyWith(fontSize: 11, color: color),
      ),
    );
    switch (row) {
      case _GroupRow(:final group):
        final g = show ? st.diff?.groups[group.id] : null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  group.title.isEmpty ? '—' : group.title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (g != null) ...[
                const SizedBox(width: 4),
                tag(
                  g.status == DiffStatus.added
                      ? l.versionTagNew
                      : g.kinds.contains(GroupChangeKind.renamed)
                      ? l.versionTagRenamed
                      : l.versionTagMoved,
                  g.status == DiffStatus.added ? cs.success : cs.info,
                ),
              ],
            ],
          ),
        );
      case _SlideRow(:final entry):
        final c = show ? st.diff?.slide(entry.id) : null;
        final selected = !st.showingRemoved && st.slideId == entry.id;
        final title = SnapshotSlideEntry.titleOf(st.model!, entry.id);
        final color = st.colorOf(
          cs,
          st.labels(context).authorOfSlide(entry.id),
        );
        return _thumbRow(
          context,
          key: ValueKey<String>('slides.version.slide.${entry.id}'),
          selected: selected,
          number: '${entry.index + 1}',
          label: title,
          thumb: SlideThumbnail(
            renderer: st.renderer!,
            slideId: entry.id,
            width: thumbWidth,
            semanticLabel: '${entry.index + 1} $title',
          ),
          badges: [
            if (c != null && c.status == DiffStatus.added)
              tag(l.versionTagNew, cs.success),
            if (c != null && c.moved) tag('↕ ${l.versionTagMoved}', cs.info),
            if (c != null &&
                c.status == DiffStatus.changed &&
                (c.contentChanged || c.skipToggled))
              Container(
                key: ValueKey<String>('slides.version.dot.${entry.id}'),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
          onTap: () => st.selectSlide(entry.id),
        );
      case _GhostRow(:final removed):
        final id = removed.change.slideId;
        final prev = st.previousRenderer;
        final title = st.previousModel == null
            ? ''
            : SnapshotSlideEntry.titleOf(st.previousModel!, id);
        return _thumbRow(
          context,
          key: ValueKey<String>('slides.version.removed.$id'),
          selected: st.showingRemoved && st.slideId == id,
          number: '',
          label: title,
          strike: true,
          thumb: prev == null
              ? SizedBox(width: thumbWidth, height: thumbWidth * 9 / 16)
              : Opacity(
                  opacity: 0.45,
                  child: SlideThumbnail(
                    renderer: prev,
                    slideId: id,
                    width: thumbWidth,
                    semanticLabel: l.versionDeletedSlide(title),
                  ),
                ),
          badges: [tag(l.versionTagDeleted, cs.destructive)],
          onTap: () => st.selectSlide(id, removed: true),
        );
    }
  }

  Widget _thumbRow(
    BuildContext context, {
    required Key key,
    required bool selected,
    required String number,
    required String label,
    required Widget thumb,
    required List<Widget> badges,
    required VoidCallback onTap,
    bool strike = false,
  }) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      key: key,
      padding: widget.horizontal
          ? const EdgeInsets.only(right: 8)
          : const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focus.requestFocus();
            onTap();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.horizontal)
                    SizedBox(
                      width: 18,
                      child: Text(number, style: theme.textTheme.muted),
                    ),
                  DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected ? cs.primary : cs.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: thumb,
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: widget.horizontal ? 0 : 18,
                  top: 2,
                ),
                child: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (strike && label.isNotEmpty)
                      Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.muted.copyWith(
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ...badges,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One outline drawn over the stage.
typedef _Outline = ({
  SuRect frame,
  double rotation,
  Color color,
  bool dashed,
  bool added,
  bool active,
});

/// The shown slide on a read-only stage with the changed objects outlined.
class _VersionStage extends StatelessWidget {
  const _VersionStage({required this.state});

  final SlidesVersionViewState state;

  static void _index(
    List<ResolvedElement> list,
    Map<String, ResolvedElement> out,
  ) {
    for (final e in list) {
      out[e.id] = e;
      _index(e.children, out);
    }
  }

  static Map<String, ResolvedElement> _frames(SlideRenderer r, String slideId) {
    final out = <String, ResolvedElement>{};
    final slide = r.resolver.resolve(slideId);
    if (slide != null) _index(slide.elements, out);
    return out;
  }

  List<_Outline> _outlines(BuildContext context) {
    final st = state;
    final id = st.slideId;
    final d = st.diff;
    if (id == null || d == null || !st.widget.showChanges) return const [];
    final cs = ShadTheme.of(context).colorScheme;
    final labels = st.labels(context);
    final change = st.showingRemoved
        ? d.removedSlides
              .where((r) => r.change.slideId == id)
              .firstOrNull
              ?.change
        : d.slide(id);
    if (change == null) return const [];
    final current = st.showingRemoved
        ? (st.previousRenderer == null
              ? const <String, ResolvedElement>{}
              : _frames(st.previousRenderer!, id))
        : _frames(st.renderer!, id);
    final previous = st.previousRenderer == null || st.showingRemoved
        ? const <String, ResolvedElement>{}
        : _frames(st.previousRenderer!, id);
    final out = <_Outline>[];
    for (final c in change.elements) {
      final removed = c.status == DiffStatus.removed;
      if (removed && !SlidesVersionView.showRemoved.value) continue;
      final frames = removed && !st.showingRemoved ? previous : current;
      final e = frames[c.topId] ?? frames[c.id];
      if (e == null) continue;
      out.add((
        frame: e.frame,
        rotation: e.rotation,
        color: st.colorOf(cs, labels.authorOfElement(c)),
        dashed: removed,
        added: c.status == DiffStatus.added,
        active: c.id == st.activeElementId,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final st = state;
    final id = st.slideId;
    final r = st.showingRemoved ? st.previousRenderer : st.renderer;
    final cs = ShadTheme.of(context).colorScheme;
    final scene = id == null || r == null ? null : r.scene(id);
    if (scene == null) {
      return ColoredBox(color: cs.canvas);
    }
    final outlines = _outlines(context);
    return ColoredBox(
      color: cs.canvas,
      child: LayoutBuilder(
        builder: (context, c) {
          const pad = 24.0;
          final scale = SlideStage.fitScale(
            scene,
            Size(
              math.max(1, c.maxWidth - 2 * pad),
              math.max(1, c.maxHeight - 2 * pad),
            ),
          );
          return Center(
            child: ListenableBuilder(
              listenable: Listenable.merge([r, r!.images]),
              builder: (context, _) {
                final sc = r.scene(id!) ?? scene;
                return Opacity(
                  opacity: st.showingRemoved ? 0.6 : 1,
                  child: Stack(
                    key: ValueKey<String>('slides.version.stage.$id'),
                    clipBehavior: Clip.none,
                    children: [
                      SlideStage(
                        scene: sc,
                        scale: scale,
                        images: r.images,
                        semanticLabel: SnapshotSlideEntry.titleOf(r.model, id),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            key: const ValueKey<String>(
                              'slides.version.outlines',
                            ),
                            painter: _OutlinePainter(outlines, scale),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Paints the change outlines (2 px in the author color, dashed for
/// removed objects, a "+" corner tag for added ones, a wider halo for the
/// active one).
class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.outlines, this.scale);

  final List<_Outline> outlines;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (final o in outlines) {
      final f = o.frame;
      final rect = Rect.fromLTWH(
        f.x * scale,
        f.y * scale,
        math.max(1, f.width * scale),
        math.max(1, f.height * scale),
      ).inflate(2);
      canvas.save();
      if (o.rotation != 0) {
        canvas.translate(rect.center.dx, rect.center.dy);
        canvas.rotate(o.rotation * math.pi / 180);
        canvas.translate(-rect.center.dx, -rect.center.dy);
      }
      final paint = Paint()
        ..color = o.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      if (o.dashed) {
        _dashed(canvas, rect, paint);
      } else {
        canvas.drawRect(rect, paint);
      }
      if (o.active) {
        canvas.drawRect(
          rect.inflate(3),
          Paint()
            ..color = o.color.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      if (o.added) {
        const s = 14.0;
        final tag = Rect.fromLTWH(rect.right - s, rect.top - s / 2, s, s);
        canvas.drawRect(tag, Paint()..color = o.color);
        final plus = Paint()
          ..color = const Color(0xffffffff)
          ..strokeWidth = 2;
        canvas.drawLine(
          tag.center.translate(-4, 0),
          tag.center.translate(4, 0),
          plus,
        );
        canvas.drawLine(
          tag.center.translate(0, -4),
          tag.center.translate(0, 4),
          plus,
        );
      }
      canvas.restore();
    }
  }

  static void _dashed(Canvas canvas, Rect r, Paint p) {
    const dash = 6.0, gap = 4.0;
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var t = 0.0; t < len; t += dash + gap) {
        canvas.drawLine(a + dir * t, a + dir * math.min(t + dash, len), p);
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      old.scale != scale || !listEquals(old.outlines, outlines);
}

/// *Changes on this slide* (09 §4.2 step 4): deck-level rows on top, the
/// slide's own changes, then one row per changed object with its author;
/// text changes show their inline text diff. Clicking a row highlights
/// the object.
class _ChangeList extends StatelessWidget {
  const _ChangeList({required this.state});

  final SlidesVersionViewState state;

  @override
  Widget build(BuildContext context) {
    final st = state;
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final d = st.diff;
    final labels = st.labels(context);
    final id = st.slideId;
    final children = <Widget>[];
    if (st.widget.showChanges && d != null) {
      for (final row in labels.deckRows(d)) {
        children.add(_row(context, text: row, color: cs.info));
      }
      final change = id == null
          ? null
          : st.showingRemoved
          ? d.removedSlides
                .where((r) => r.change.slideId == id)
                .firstOrNull
                ?.change
          : d.slide(id);
      if (change != null) {
        final slideAuthor = labels.authorOfSlide(change.slideId);
        for (final row in labels.slideRows(change)) {
          children.add(
            _row(
              context,
              text: labels.by(row, slideAuthor),
              color: st.colorOf(cs, slideAuthor),
            ),
          );
        }
        for (final c in change.elements) {
          final author = labels.authorOfElement(c);
          final textDiff =
              c.status == DiffStatus.changed &&
                  c.kinds.contains(ElementChangeKind.text)
              ? TextDiff.ofBodies(c.before?.text, c.after?.text)
              : null;
          children.add(
            _row(
              context,
              key: ValueKey<String>('slides.version.change.${c.id}'),
              text: labels.by(labels.elementWhat(c), author),
              color: st.colorOf(cs, author),
              active: c.id == st.activeElementId,
              diff: textDiff,
              onTap: c.status == DiffStatus.removed && !st.showingRemoved
                  ? null
                  : () => st.selectElement(c.id),
            ),
          );
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Text(
            l.versionChangesOnSlide,
            style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: children.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    st.widget.showChanges
                        ? l.versionNoChangesOnSlide
                        : l.versionChangesHidden,
                    key: const ValueKey<String>('slides.version.noChanges'),
                    style: theme.textTheme.muted,
                  ),
                )
              : ListView(
                  key: const ValueKey<String>('slides.version.changes'),
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  children: children,
                ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    Key? key,
    required String text,
    required Color color,
    bool active = false,
    List<TextDiffSpan>? diff,
    VoidCallback? onTap,
  }) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: active ? cs.accent : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.small),
                if (diff != null && diff.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          for (final span in diff)
                            TextSpan(
                              text: span.text,
                              style: switch (span.op) {
                                TextDiffOp.equal => null,
                                TextDiffOp.insert => TextStyle(
                                  backgroundColor: cs.suggestionInsert,
                                ),
                                TextDiffOp.delete => TextStyle(
                                  backgroundColor: cs.suggestionDelete,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              },
                            ),
                        ],
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return Padding(key: key, padding: EdgeInsets.zero, child: body);
    }
    return _Activatable(key: key, selected: active, onTap: onTap, child: body);
  }
}

/// A focusable, clickable row: Enter/Space activate it, a focus ring shows
/// keyboard focus.
class _Activatable extends StatefulWidget {
  const _Activatable({
    super.key,
    required this.onTap,
    required this.child,
    this.selected = false,
  });

  final VoidCallback onTap;
  final Widget child;
  final bool selected;

  @override
  State<_Activatable> createState() => _ActivatableState();
}

class _ActivatableState extends State<_Activatable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: _focused ? Border.all(color: cs.ring, width: 2) : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
