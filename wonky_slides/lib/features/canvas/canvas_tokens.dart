import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// The canvas chrome tokens of 03 §20 A-03-7 (light/dark): selection
/// outline and handles, adjust handles, smart guides, user guides, empty
/// placeholder outlines and the slide shadow. Chrome follows the app theme;
/// the slide itself renders in the deck's appearance (03 §2.1).
@immutable
class CanvasTokens {
  const CanvasTokens({
    required this.dark,
    required this.selection,
    required this.handleFill,
    required this.adjustHandle,
    required this.guide,
    required this.userGuide,
    required this.placeholderBorder,
    required this.slideShadow,
    required this.marqueeFill,
    required this.lockBadge,
    required this.labelText,
    required this.tableSelection,
  });

  /// The tokens of [context]'s app theme.
  factory CanvasTokens.of(BuildContext context) =>
      CanvasTokens.forBrightness(ShadTheme.of(context).brightness);

  /// The tokens of a light or dark app theme.
  factory CanvasTokens.forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark_ : light;

  static const light = CanvasTokens(
    dark: false,
    selection: Color(0xFF2563EB),
    handleFill: Color(0xFFFFFFFF),
    adjustHandle: Color(0xFFF59E0B),
    guide: Color(0xFFE5389B),
    userGuide: Color(0xFF0D9488),
    placeholderBorder: Color(0x8094A3B8),
    slideShadow: Color(0x33000000),
    marqueeFill: Color(0x1A2563EB),
    lockBadge: Color(0xFF71717A),
    labelText: Color(0xFFFFFFFF),
    tableSelection: Color(0x262563EB),
  );

  // ignore: constant_identifier_names
  static const dark_ = CanvasTokens(
    dark: true,
    selection: Color(0xFF60A5FA),
    handleFill: Color(0xFF18181B),
    adjustHandle: Color(0xFFFBBF24),
    guide: Color(0xFFF472B6),
    userGuide: Color(0xFF2DD4BF),
    placeholderBorder: Color(0x8094A3B8),
    slideShadow: Color(0x80000000),
    marqueeFill: Color(0x2660A5FA),
    lockBadge: Color(0xFFA1A1AA),
    labelText: Color(0xFF0B0B0D),
    tableSelection: Color(0x3360A5FA),
  );

  final bool dark;

  /// `slidesSelection`: selection outlines, handle strokes.
  final Color selection;

  /// `slidesHandleFill`: inside of resize/rotation handles.
  final Color handleFill;

  /// `slidesAdjustHandle`: shape adjust handles (yellow diamonds).
  final Color adjustHandle;

  /// `slidesGuide`: smart guides and equal-spacing bars.
  final Color guide;

  /// `slidesUserGuide`: user guides (teal).
  final Color userGuide;

  /// `placeholderBorder`: dashed outline of empty placeholders.
  final Color placeholderBorder;

  /// `slideShadow`: the slide's drop shadow.
  final Color slideShadow;

  /// Marquee rectangle fill.
  final Color marqueeFill;

  /// The lock badge of locked elements selected from the Layers panel.
  final Color lockBadge;

  /// Text on guide-colored labels (distance and dimension badges).
  final Color labelText;

  /// `slidesTableSelection`: the fill of a selected table cell range
  /// (03 §6.6, SL-15).
  final Color tableSelection;
}
