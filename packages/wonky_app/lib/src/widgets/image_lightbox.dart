import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../l10n/wonky_app_localizations.dart';
import '../l10n/wonky_app_localizations_en.dart';

/// Stable keys of the lightbox (specs/15 §7).
abstract final class LightboxKeys {
  static const overlay = ValueKey<String>('shell.lightbox');
  static const close = ValueKey<String>('shell.lightbox.close');
  static const zoomIn = ValueKey<String>('shell.lightbox.zoomIn');
  static const zoomOut = ValueKey<String>('shell.lightbox.zoomOut');
  static const fit = ValueKey<String>('shell.lightbox.fit');
  static const zoomLabel = ValueKey<String>('shell.lightbox.zoom');
}

/// The lightbox's strings (English when the shell's localizations are not
/// installed, e.g. in an app's widget tests).
WonkyAppLocalizations _l10n(BuildContext context) =>
    Localizations.of<WonkyAppLocalizations>(context, WonkyAppLocalizations) ??
    WonkyAppLocalizationsEn();

/// Shows [image] full screen inside the app (Write 04 §17.4, shared with the
/// board's screenshots, specs/16 §4.5): zoom 25–400 %
/// (buttons, Mod +/−/0, wheel or pinch), pan by dragging, Esc or the close
/// button (or a click on the backdrop) closes it. It never opens a tab.
Future<void> showImageLightbox(
  BuildContext context, {
  required ImageProvider image,
  String alt = '',
  String? title,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: _l10n(context).lightboxCloseImage,
    barrierColor: const Color(0xe6000000),
    transitionDuration: MediaQuery.maybeDisableAnimationsOf(context) == true
        ? Duration.zero
        : const Duration(milliseconds: 150),
    pageBuilder: (context, _, _) =>
        ImageLightbox(image: image, alt: alt, title: title),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// The lightbox content (see [showImageLightbox]).
class ImageLightbox extends StatefulWidget {
  const ImageLightbox({
    super.key,
    required this.image,
    this.alt = '',
    this.title,
  });

  final ImageProvider image;
  final String alt;
  final String? title;

  /// Zoom bounds relative to the image's natural size.
  static const minZoom = 0.25;
  static const maxZoom = 4.0;

  @override
  State<ImageLightbox> createState() => ImageLightboxState();
}

class ImageLightboxState extends State<ImageLightbox> {
  final _transform = TransformationController();
  final _focus = FocusNode(debugLabel: 'lightbox');
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _natural;
  Size _viewport = Size.zero;
  bool _failed = false;

  /// The current zoom (1 = natural size).
  double get zoom => _scaleOf(_transform.value) * _baseScale;

  /// The x scale of [m] (no rotation; `getMaxScaleOnAxis` would include z).
  static double _scaleOf(Matrix4 m) => m.entry(0, 0);

  /// Scale of the laid-out image (fit) relative to the natural size.
  double _baseScale = 1;

  @override
  void initState() {
    super.initState();
    _resolve();
    _transform.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(ImageLightbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  void _resolve() {
    _stopListening();
    final stream = widget.image.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() {
          _natural = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      },
      onError: (_, _) {
        if (mounted) setState(() => _failed = true);
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _stopListening() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopListening();
    _transform.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The size the image is laid out at (fit to the viewport, never upscaled).
  Size _fitted() {
    final natural = _natural;
    if (natural == null || natural.isEmpty || _viewport.isEmpty) {
      return Size.zero;
    }
    final scale = math.min(
      1.0,
      math.min(
        (_viewport.width - 64) / natural.width,
        (_viewport.height - 128) / natural.height,
      ),
    );
    _baseScale = scale <= 0 ? 1 : scale;
    return natural * _baseScale;
  }

  /// Sets the zoom (1 = natural size), clamped to 25–400 %, about the centre.
  void setZoom(double value) {
    final clamped = value.clamp(ImageLightbox.minZoom, ImageLightbox.maxZoom);
    final scale = clamped / _baseScale;
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final current = _scaleOf(_transform.value);
    final focal = _transform.toScene(center);
    final next = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
    if (current == scale) return;
    _transform.value = next;
  }

  void _zoomBy(double factor) => setZoom(zoom * factor);

  /// Back to "fit".
  void fit() => _transform.value = Matrix4.identity();

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      _zoomBy(1.25);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _zoomBy(0.8);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      fit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = _l10n(context);
    final label = widget.alt.isEmpty ? l.lightboxImage : widget.alt;
    return Focus(
      key: LightboxKeys.overlay,
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          label: label,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewport = constraints.biggest;
              final fitted = _fitted();
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _transform,
                      minScale: ImageLightbox.minZoom / _baseScale,
                      maxScale: ImageLightbox.maxZoom / _baseScale,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      child: Center(
                        child: _failed
                            ? Text(
                                l.lightboxLoadFailed,
                                style: theme.textTheme.p.copyWith(
                                  color: const Color(0xffffffff),
                                ),
                              )
                            : fitted.isEmpty
                            ? const ShadSpinner(size: 24)
                            : GestureDetector(
                                // Taps on the image don't close the lightbox.
                                onTap: () {},
                                child: SizedBox.fromSize(
                                  size: fitted,
                                  child: Image(
                                    image: widget.image,
                                    fit: BoxFit.contain,
                                    semanticLabel: label,
                                    filterQuality: FilterQuality.medium,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _Button(
                      key: LightboxKeys.close,
                      icon: LucideIcons.x,
                      label: l.lightboxClose,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(child: _toolbar(context)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final l = _l10n(context);
    final caption = widget.title?.isNotEmpty == true
        ? widget.title!
        : widget.alt;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xcc1f2125),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Button(
              key: LightboxKeys.zoomOut,
              icon: LucideIcons.zoomOut,
              label: l.lightboxZoomOut,
              onPressed: zoom <= ImageLightbox.minZoom + 0.001
                  ? null
                  : () => _zoomBy(0.8),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '${(zoom * 100).round()}%',
                key: LightboxKeys.zoomLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xffffffff),
                  fontSize: 13,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _Button(
              key: LightboxKeys.zoomIn,
              icon: LucideIcons.zoomIn,
              label: l.lightboxZoomIn,
              onPressed: zoom >= ImageLightbox.maxZoom - 0.001
                  ? null
                  : () => _zoomBy(1.25),
            ),
            _Button(
              key: LightboxKeys.fit,
              icon: LucideIcons.minimize,
              label: l.lightboxFit,
              onPressed: fit,
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xffe6e8eb),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadTooltip(
      builder: (_) => Text(label),
      child: ShadIconButton.ghost(
        width: 32,
        height: 32,
        iconSize: 16,
        semanticLabel: label,
        foregroundColor: const Color(0xffffffff),
        hoverForegroundColor: const Color(0xffffffff),
        hoverBackgroundColor: const Color(0x33ffffff),
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

/// Resolves an image source and shows the lightbox (Write's
/// `write.image.preview`).
Future<bool> openLightbox(
  BuildContext context, {
  required FutureOr<ImageProvider?> Function() resolve,
  String alt = '',
  String? title,
}) async {
  final provider = await resolve();
  if (provider == null || !context.mounted) return false;
  await showImageLightbox(context, image: provider, alt: alt, title: title);
  return true;
}
