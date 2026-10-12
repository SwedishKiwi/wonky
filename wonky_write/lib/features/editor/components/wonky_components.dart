import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import '../mapping/wonky_embed_node.dart';
import '../mapping/wonky_schema.dart';
import '../model/code_languages.dart';
import '../model/embeds.dart';
import '../styles/editor_theme.dart';
import 'editor_services.dart';

/// Stable widget keys (specs/15 §7).
abstract final class WonkyEditorKeys {
  static const editor = ValueKey<String>('write.editor');
  static const codeLanguageChip = 'write.editor.codeLanguage';
  static const codeCopy = 'write.editor.codeCopy';
  static const tableEdit = 'write.editor.tableEdit';
  static const imageRetry = 'write.editor.imageRetry';
  static const blockHandle = 'write.editor.blockHandle';
}

// -----------------------------------------------------------------------------
// Images (Write 04 §17.3).

class WonkyImageViewModel extends SingleColumnLayoutComponentViewModel with SelectionAwareViewModelMixin {
  WonkyImageViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    required this.src,
    required this.alt,
    this.title,
    DocumentNodeSelection? selection,
    Color selectionColor = Colors.transparent,
  }) {
    this.selection = selection;
    this.selectionColor = selectionColor;
  }

  String src;
  String alt;
  String? title;

  @override
  WonkyImageViewModel copy() => WonkyImageViewModel(
        nodeId: nodeId,
        maxWidth: maxWidth,
        padding: padding,
        src: src,
        alt: alt,
        title: title,
        selection: selection,
        selectionColor: selectionColor,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is WonkyImageViewModel &&
          other.src == src &&
          other.alt == alt &&
          other.title == title &&
          other.selection == selection &&
          other.selectionColor == selectionColor;

  @override
  int get hashCode => Object.hash(super.hashCode, src, alt, title, selection);
}

/// Renders image embeds: `wonky-file://` through [EditorImageServices], upload
/// progress / pending / failed / broken states, alt text as semantics label,
/// and the block-selection ring.
class WonkyImageComponentBuilder implements ComponentBuilder {
  const WonkyImageComponentBuilder({required this.services, required this.theme, this.callbacks = const EditorBlockCallbacks()});

  final EditorImageServices services;
  final EditorTheme theme;
  final EditorBlockCallbacks callbacks;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ImageNode) return null;
    final data = EmbedNodes.embedDataOf(node);
    return WonkyImageViewModel(
      nodeId: node.id,
      src: node.imageUrl,
      alt: node.altText,
      title: data?['title'] as String?,
    );
  }

  @override
  Widget? createComponent(SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel viewModel) {
    if (viewModel is! WonkyImageViewModel) return null;
    final selection = viewModel.selection?.nodeSelection as UpstreamDownstreamNodeSelection?;
    final isSelected = selection != null && !selection.isCollapsed;
    return Semantics(
      image: true,
      label: viewModel.alt.isEmpty ? 'image, no description' : viewModel.alt,
      child: GestureDetector(
        onDoubleTap: callbacks.onImageDoubleTap == null ? null : () => callbacks.onImageDoubleTap!(viewModel.nodeId),
        child: Center(
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: isSelected ? Border.all(color: theme.ringColor, width: 2) : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: BoxComponent(
              key: componentContext.componentKey,
              child: _WonkyImage(
                nodeId: viewModel.nodeId,
                src: viewModel.src,
                alt: viewModel.alt,
                title: viewModel.title,
                services: services,
                theme: theme,
                callbacks: callbacks,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WonkyImage extends StatefulWidget {
  const _WonkyImage({
    required this.nodeId,
    required this.src,
    required this.alt,
    required this.title,
    required this.services,
    required this.theme,
    required this.callbacks,
  });

  final String nodeId;
  final String src;
  final String alt;
  final String? title;
  final EditorImageServices services;
  final EditorTheme theme;
  final EditorBlockCallbacks callbacks;

  @override
  State<_WonkyImage> createState() => _WonkyImageState();
}

class _WonkyImageState extends State<_WonkyImage> {
  ImageProvider? _provider;
  bool _resolving = true;
  bool _broken = false;
  late ValueListenable<ImageUploadStatus?> _upload;

  @override
  void initState() {
    super.initState();
    _upload = widget.services.uploadStatus(widget.src);
    _resolve();
  }

  @override
  void didUpdateWidget(_WonkyImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src || oldWidget.services != widget.services) {
      _upload = widget.services.uploadStatus(widget.src);
      _broken = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    final src = widget.src;
    ImageProvider? provider;
    try {
      provider = await widget.services.resolve(src);
    } catch (_) {
      provider = null;
    }
    if (!mounted || widget.src != src) return;
    setState(() {
      _provider = provider;
      _resolving = false;
    });
  }

  void _retry() {
    widget.services.retry(widget.src);
    setState(() => _broken = false);
    _resolve();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 640.0;
        return ValueListenableBuilder<ImageUploadStatus?>(
          valueListenable: _upload,
          builder: (context, upload, _) {
            final provider = upload?.localPreview ?? _provider;
            Widget content;
            if (_broken || (provider == null && !_resolving && upload == null)) {
              content = _placeholder(maxWidth, icon: Icons.broken_image_outlined, label: widget.alt.isEmpty ? 'Image unavailable' : widget.alt, retry: true);
            } else if (provider == null) {
              content = _placeholder(
                maxWidth,
                icon: Icons.image_outlined,
                label: upload?.phase == ImageUploadPhase.pending
                    ? 'Waiting for upload${upload?.uploaderName == null ? '' : ' from ${upload!.uploaderName}'}'
                    : null,
              );
            } else {
              content = ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Image(
                  image: provider,
                  fit: BoxFit.contain,
                  semanticLabel: widget.alt,
                  errorBuilder: (context, error, stack) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_broken) setState(() => _broken = true);
                    });
                    return _placeholder(maxWidth, icon: Icons.broken_image_outlined, label: widget.alt, retry: true);
                  },
                  frameBuilder: (context, child, frame, sync) => frame == null && !sync ? _placeholder(maxWidth) : child,
                ),
              );
            }
            final title = widget.title;
            return Stack(
              alignment: Alignment.center,
              children: [
                if (title != null && title.isNotEmpty) Tooltip(message: title, child: content) else content,
                if (upload != null && upload.phase == ImageUploadPhase.uploading)
                  Positioned.fill(child: _UploadOverlay(progress: upload.progress, onCancel: () => widget.services.cancel(widget.src))),
                if (upload != null && upload.phase == ImageUploadPhase.failed)
                  Positioned.fill(
                    child: _FailedOverlay(
                      onRetry: _retry,
                      onRemove: widget.callbacks.onRemoveImage == null ? null : () => widget.callbacks.onRemoveImage!(widget.nodeId),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _placeholder(double width, {IconData? icon, String? label, bool retry = false}) {
    final theme = widget.theme;
    return SizedBox(
      width: width,
      height: width * 9 / 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.mutedColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, color: theme.mutedColor, size: 32),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label, style: TextStyle(color: theme.mutedColor, fontSize: 13)),
                ),
              if (retry)
                TextButton(
                  key: const ValueKey(WonkyEditorKeys.imageRetry),
                  onPressed: _retry,
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadOverlay extends StatelessWidget {
  const _UploadOverlay({required this.progress, required this.onCancel});

  final double? progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x55000000),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(value: progress, color: Colors.white, strokeWidth: 3),
            ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${(progress! * 100).round()} %', style: const TextStyle(color: Colors.white)),
              ),
            IconButton(
              tooltip: 'Cancel upload',
              onPressed: onCancel,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedOverlay extends StatelessWidget {
  const _FailedOverlay({required this.onRetry, this.onRemove});

  final VoidCallback onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99b91c1c),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Upload failed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(color: Colors.white))),
                if (onRemove != null)
                  TextButton(onPressed: onRemove, child: const Text('Remove', style: TextStyle(color: Colors.white))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tables (Write 04 §18.2).

/// Wraps super_editor's Markdown table component with an "Edit table" button
/// and the block-selection ring; double-click opens the table editor.
class WonkyTableComponentBuilder implements ComponentBuilder {
  const WonkyTableComponentBuilder({required this.theme, this.callbacks = const EditorBlockCallbacks(), this.editable = true});

  final EditorTheme theme;
  final EditorBlockCallbacks callbacks;
  final bool editable;
  static const _inner = MarkdownTableComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) =>
      node is TableBlockNode ? _inner.createViewModel(document, node) : null;

  @override
  Widget? createComponent(SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel viewModel) {
    final table = _inner.createComponent(componentContext, viewModel);
    if (table == null || viewModel is! MarkdownTableViewModel) return null;
    final selection = viewModel.selection?.nodeSelection;
    final isSelected = selection is UpstreamDownstreamNodeSelection && !selection.isCollapsed;
    final rows = viewModel.cells.length;
    final columns = rows == 0 ? 0 : viewModel.cells.first.length;
    return Semantics(
      label: 'table, $columns columns, $rows rows',
      child: GestureDetector(
        onDoubleTap: !editable || callbacks.onEditTable == null ? null : () => callbacks.onEditTable!(viewModel.nodeId),
        child: _HoverChrome(
          showAlways: isSelected,
          chrome: !editable || callbacks.onEditTable == null
              ? null
              : _ChromeButton(
                  key: ValueKey('${WonkyEditorKeys.tableEdit}.${viewModel.nodeId}'),
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit table',
                  onTap: (_) => callbacks.onEditTable!(viewModel.nodeId),
                ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(border: isSelected ? Border.all(color: theme.ringColor, width: 2) : null),
            child: table,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Code blocks and quotes (Write 04 §14, §15).

/// Paragraph components with Wonky chrome: code blocks get a language chip
/// and a copy button; quote lines get a continuous left bar.
class WonkyParagraphComponentBuilder implements ComponentBuilder {
  const WonkyParagraphComponentBuilder({
    required this.document,
    required this.theme,
    required this.zoom,
    this.callbacks = const EditorBlockCallbacks(),
    this.editable = true,
  });

  final Document document;
  final EditorTheme theme;
  final double zoom;
  final EditorBlockCallbacks callbacks;
  final bool editable;
  static const _inner = ParagraphComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode) return null;
    return _inner.createViewModel(document, node);
  }

  @override
  Widget? createComponent(SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel viewModel) {
    if (viewModel is! ParagraphComponentViewModel) return null;
    final component = _inner.createComponent(componentContext, viewModel);
    if (component == null) return null;
    final blockType = viewModel.blockType;
    if (blockType == blockquoteAttribution) {
      return Semantics(
        label: 'quote',
        child: CustomPaint(
          painter: _QuoteBarPainter(color: theme.quoteBarColor, width: theme.quoteBarWidth * zoom),
          child: component,
        ),
      );
    }
    if (blockType == codeAttribution) {
      final node = document.getNodeById(viewModel.nodeId);
      return _CodeBlockChrome(
        nodeId: viewModel.nodeId,
        node: node,
        theme: theme,
        zoom: zoom,
        callbacks: callbacks,
        editable: editable,
        child: component,
      );
    }
    final level = headingLevelOf(blockType);
    if (level != null) {
      return Semantics(header: true, headingLevel: level, child: component);
    }
    return component;
  }
}

class _QuoteBarPainter extends CustomPainter {
  _QuoteBarPainter({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, width, size.height), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_QuoteBarPainter oldDelegate) => oldDelegate.color != color || oldDelegate.width != width;
}

class _CodeBlockChrome extends StatelessWidget {
  const _CodeBlockChrome({
    required this.nodeId,
    required this.node,
    required this.theme,
    required this.zoom,
    required this.callbacks,
    required this.editable,
    required this.child,
  });

  final String nodeId;
  final DocumentNode? node;
  final EditorTheme theme;
  final double zoom;
  final EditorBlockCallbacks callbacks;
  final bool editable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final node = this.node;
    final language = node == null ? '' : codeLanguageOf(node);
    final label = CodeLanguages.displayName(language);
    return Semantics(
      label: 'code block, $label',
      child: _HoverChrome(
        chrome: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (chipContext) => _ChromeButton(
                key: ValueKey('${WonkyEditorKeys.codeLanguageChip}.$nodeId'),
                label: label,
                tooltip: 'Code language',
                onTap: !editable || callbacks.onCodeLanguageTap == null
                    ? null
                    : (rect) => callbacks.onCodeLanguageTap!(nodeId, rect),
              ),
            ),
            const SizedBox(width: 4),
            _ChromeButton(
              key: ValueKey('${WonkyEditorKeys.codeCopy}.$nodeId'),
              icon: Icons.copy_outlined,
              tooltip: 'Copy code',
              onTap: (_) {
                if (callbacks.onCopyCode != null) {
                  callbacks.onCopyCode!(nodeId);
                } else if (node is TextNode) {
                  unawaited(Clipboard.setData(ClipboardData(text: node.text.toPlainText())));
                }
              },
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Shows [chrome] at the top-right corner while hovered (or [showAlways]).
class _HoverChrome extends StatefulWidget {
  const _HoverChrome({required this.child, this.chrome, this.showAlways = false});

  final Widget child;
  final Widget? chrome;
  final bool showAlways;

  @override
  State<_HoverChrome> createState() => _HoverChromeState();
}

class _HoverChromeState extends State<_HoverChrome> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    if (chrome == null) return widget.child;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            top: 4,
            right: 4,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _hovered || widget.showAlways ? 1 : 0,
              child: IgnorePointer(ignoring: !(_hovered || widget.showAlways), child: chrome),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChromeButton extends StatelessWidget {
  const _ChromeButton({super.key, this.icon, this.label, required this.tooltip, required this.onTap});

  final IconData? icon;
  final String? label;
  final String tooltip;
  final void Function(Rect globalRect)? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = brightness == Brightness.dark ? const Color(0xff2b2f36) : const Color(0xffffffff);
    final foreground = brightness == Brightness.dark ? const Color(0xffe6e8eb) : const Color(0xff374151);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        elevation: 1,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap == null
              ? null
              : () {
                  final box = context.findRenderObject() as RenderBox?;
                  final rect = box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;
                  onTap!(rect);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: icon != null
                ? Icon(icon, size: 14, color: foreground)
                : Text(label ?? '', style: TextStyle(fontSize: 12, color: foreground)),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tasks (Write 04 §13.5).

/// super_editor's task component with the checkbox routed through the
/// `write.list.toggleChecked {nodeId}` command (one labelled undo step).
class WonkyTaskComponentBuilder implements ComponentBuilder {
  WonkyTaskComponentBuilder(this._editor, {required this.onToggle, this.editable = true}) : _inner = TaskComponentBuilder(_editor);

  final Editor _editor;
  final TaskComponentBuilder _inner;
  final void Function(String nodeId) onToggle;
  final bool editable;

  Editor get editor => _editor;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    final model = _inner.createViewModel(document, node);
    if (model == null) return null;
    model.setComplete = editable ? (_) => onToggle(node.id) : null;
    return model;
  }

  @override
  Widget? createComponent(SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel viewModel) {
    final component = _inner.createComponent(componentContext, viewModel);
    if (component == null || viewModel is! TaskComponentViewModel) return component;
    return Semantics(checked: viewModel.isComplete, label: 'checkbox', child: component);
  }
}

// -----------------------------------------------------------------------------
// Unknown embeds.

class WonkyEmbedComponentBuilder implements ComponentBuilder {
  const WonkyEmbedComponentBuilder({required this.theme});

  final EditorTheme theme;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! WonkyEmbedNode) return null;
    return _EmbedViewModel(nodeId: node.id, type: node.embedType);
  }

  @override
  Widget? createComponent(SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel viewModel) {
    if (viewModel is! _EmbedViewModel) return null;
    return BoxComponent(
      key: componentContext.componentKey,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: theme.tableBorderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('Unsupported content (${viewModel.type})', style: TextStyle(color: theme.mutedColor)),
      ),
    );
  }
}

class _EmbedViewModel extends SingleColumnLayoutComponentViewModel with SelectionAwareViewModelMixin {
  _EmbedViewModel({
    required super.nodeId,
    required this.type,
    super.createdAt,
    super.padding = EdgeInsets.zero,
    super.maxWidth,
  });

  final String type;

  @override
  _EmbedViewModel copy() => _EmbedViewModel(nodeId: nodeId, type: type, padding: padding, maxWidth: maxWidth)
    ..selection = selection
    ..selectionColor = selectionColor;
}

// -----------------------------------------------------------------------------
// Horizontal rules.

class WonkyRuleComponentBuilder implements ComponentBuilder {
  const WonkyRuleComponentBuilder({required this.theme});

  final EditorTheme theme;
  static const _inner = HorizontalRuleComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) =>
      _inner.createViewModel(document, node);

  @override
  Widget? createComponent(SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel viewModel) {
    if (viewModel is! HorizontalRuleComponentViewModel) return null;
    final selection = viewModel.selection?.nodeSelection;
    final isSelected = selection is UpstreamDownstreamNodeSelection && !selection.isCollapsed;
    return Semantics(
      label: 'separator',
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(border: isSelected ? Border.all(color: theme.ringColor, width: 2) : null),
        child: HorizontalRuleComponent(
          componentKey: componentContext.componentKey,
          color: theme.ruleColor,
          thickness: theme.ruleThickness,
          selection: selection is UpstreamDownstreamNodeSelection ? selection : null,
          selectionColor: Colors.transparent,
          caretColor: theme.caretColor,
        ),
      ),
    );
  }
}
