import 'dart:async';

import 'package:flutter/material.dart' show Theme, ThemeData;
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:super_editor/super_editor.dart' show TextNodePosition;
import 'package:wonky_ui/wonky_ui.dart';
import 'package:wonky_write_core/wonky_write_core.dart'
    show Delta, PageSetup, PageMargins, ThemeElement, ThemeVariant, WonkyAttr;

import '../../l10n/write_l10n.dart';
import '../editor/controller/editor_types.dart';
import '../editor/controller/write_editor_controller.dart';
import '../editor/ui/wonky_editor.dart';
import '../screen/write_document_controller.dart' show editorPageSetupOf;
import '../themes/theme_adapter.dart';
import '../themes/write_fonts.dart';
import 'theme_editor_controller.dart';
import 'theme_editor_model.dart';
import 'theme_sample.dart';

/// The live preview of the theme editor (Write 06 §10.2): the sample
/// document (or the `?doc=` document, read-only) rendered with the draft
/// theme in the chosen variant and layout. Clicking text selects its
/// element in the tree and inspector.
class ThemePreview extends StatefulWidget {
  const ThemePreview({super.key, required this.controller});

  final ThemeEditorController controller;

  @override
  State<ThemePreview> createState() => _ThemePreviewState();
}

class _ThemePreviewState extends State<ThemePreview> {
  final WriteEditorController _editor = WriteEditorController(
    mode: EditorMode.viewing,
  );
  final ScrollController _scroll = ScrollController();
  ThemePreviewSource? _shownSource;
  ThemeEditorController get c => widget.controller;
  int? _lastOffset;

  /// The sample document's title (header/footer `{title}` token).
  String _sampleTitle = writeL10nEnglish.themeEditorSampleTitle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final title = writeL10n(context).themeEditorSampleTitle;
    if (title != _sampleTitle) {
      _sampleTitle = title;
      _sync();
    }
  }

  @override
  void initState() {
    super.initState();
    _editor.addListener(_onEditor);
    c.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(ThemePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _shownSource = null;
      _sync();
    }
  }

  @override
  void dispose() {
    c.removeListener(_sync);
    _editor.removeListener(_onEditor);
    _editor.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _sync() {
    final source = c.source == ThemePreviewSource.document && c.document != null
        ? ThemePreviewSource.document
        : ThemePreviewSource.sample;
    if (source != _shownSource) {
      _shownSource = source;
      final Delta delta = source == ThemePreviewSource.document
          ? c.document!.delta
          : themeSampleDelta();
      _editor.resetDocument(delta.isEmpty ? (Delta()..insert('\n')) : delta);
    }
    final view = _editor.view;
    view.layout = c.layout == ThemePreviewLayout.pages
        ? LayoutMode.pages
        : LayoutMode.pageless;
    final margins = c.resolved(ThemeVariant.light).page.defaultMargins;
    view.pageSetup = editorPageSetupOf(
      PageSetup.defaultsFor('en'),
      themeMarginsPt: PageMargins(
        top: margins.top,
        right: margins.right,
        bottom: margins.bottom,
        left: margins.left,
      ),
      tokens: {'title': c.document?.title ?? _sampleTitle},
    );
    view.zoom = c.zoom;
  }

  /// Click-to-select: the element under the caret.
  void _onEditor() {
    final sel = _editor.selection;
    if (sel == null || !sel.isCollapsed) return;
    if (sel.start == _lastOffset) return;
    _lastOffset = sel.start;
    final node = elementAt();
    if (node != null) c.select(ThemeNode.element(node));
  }

  /// The theme element at the caret (inline styles win over blocks).
  ThemeElement? elementAt() {
    final selection = _editor.composer.selection;
    if (selection == null) return null;
    final entry = _editor.mirror.entryOf(selection.extent.nodeId);
    if (entry == null) return null;
    final ops = entry.delta.operations;
    final position = selection.extent.nodePosition;
    Map<String, dynamic>? inline;
    if (position is TextNodePosition) {
      var at = 0;
      for (final op in ops) {
        final len = op.length!;
        if (op.data is String &&
            position.offset >= at &&
            position.offset < at + len) {
          inline = op.attributes;
          break;
        }
        at += len;
      }
    }
    final i = inline ?? const {};
    if (i.containsKey(WonkyAttr.mention)) return ThemeElement.mention;
    if (i.containsKey(WonkyAttr.link)) return ThemeElement.link;
    if (i.containsKey(WonkyAttr.code)) return ThemeElement.inlineCode;
    if (i.containsKey(WonkyAttr.strike)) return ThemeElement.strike;
    if (i.containsKey(WonkyAttr.bold)) return ThemeElement.bold;
    if (i.containsKey(WonkyAttr.italic)) return ThemeElement.italic;
    final first = ops.isEmpty ? null : ops.first.data;
    if (first is Map) {
      if (first.containsKey('table')) return ThemeElement.table;
      if (first.containsKey('divider')) return ThemeElement.rule;
      if (first.containsKey('image')) return ThemeElement.image;
    }
    final block = ops.isEmpty ? null : ops.last.attributes;
    final b = block ?? const {};
    final header = b[WonkyAttr.header];
    if (header is int && header >= 1 && header <= 6) {
      return ThemeElement.heading(header);
    }
    if (b.containsKey(WonkyAttr.codeBlock)) return ThemeElement.codeBlock;
    if (b.containsKey(WonkyAttr.blockquote)) return ThemeElement.blockquote;
    final list = b[WonkyAttr.list];
    if (list == 'checked' || list == 'unchecked') return ThemeElement.task;
    if (list != null) return ThemeElement.list;
    return ThemeElement.body;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final resolved = c.resolved();
        unawaited(
          WriteFonts.ensureLoaded(EditorThemeAdapter.screenFamilies(resolved)),
        );
        final theme = const EditorThemeAdapter().adapt(resolved);
        final dark = c.variant == ThemeVariant.dark;
        final pages = c.layout == ThemePreviewLayout.pages;
        // Task checkboxes are Material widgets: give them the preview's
        // brightness too, not the app's.
        return Theme(
          data: dark ? _darkMaterial : _lightMaterial,
          child: ShadTheme(
            data: dark ? WonkyTheme.dark() : WonkyTheme.light(),
            child: ValueListenableBuilder<int>(
              valueListenable: WriteFonts.generation,
              builder: (context, _, _) => ColoredBox(
                key: const ValueKey<String>('write.themeEditor.preview'),
                color: pages ? theme.canvasColor : theme.paperColor,
                child: WonkyEditor(
                  key: const ValueKey<String>(
                    'write.themeEditor.previewEditor',
                  ),
                  controller: _editor,
                  theme: theme,
                  scrollController: _scroll,
                  documentTitle: writeL10n(context).themeEditorPreviewTitle,
                  hint: '',
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static final _lightMaterial = ThemeData(brightness: Brightness.light);
  static final _darkMaterial = ThemeData(brightness: Brightness.dark);
}
