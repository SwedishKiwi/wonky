import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// Keys of the custom color tokens registered in `ShadColorScheme.custom`
/// (suite 02 §2).
abstract final class WonkyColorKeys {
  static const canvas = 'canvas';
  static const page = 'page';
  static const gridLine = 'gridLine';
  static const gridHeaderBg = 'gridHeaderBg';
  static const gridHeaderFg = 'gridHeaderFg';
  static const gridHeaderSelectedBg = 'gridHeaderSelectedBg';
  static const selectionFill = 'selectionFill';
  static const selectionBorder = 'selectionBorder';
  static const fillHandle = 'fillHandle';
  static const commentHighlight = 'commentHighlight';
  static const commentHighlightActive = 'commentHighlightActive';
  static const suggestionInsert = 'suggestionInsert';
  static const suggestionDelete = 'suggestionDelete';
  static const findMatch = 'findMatch';
  static const findMatchActive = 'findMatchActive';
  static const success = 'success';
  static const warning = 'warning';
  static const info = 'info';
  static const offline = 'offline';
  static const offlineForeground = 'offlineForeground';

  /// `presence1` … `presence12`.
  static String presence(int n) => 'presence$n';
}

/// The light and dark values of every custom token.
abstract final class WonkyPalette {
  static const presenceLight = [
    Color(0xff2563eb),
    Color(0xffdc2626),
    Color(0xff16a34a),
    Color(0xffd97706),
    Color(0xff7c3aed),
    Color(0xff0d9488),
    Color(0xffdb2777),
    Color(0xff0891b2),
    Color(0xff65a30d),
    Color(0xffea580c),
    Color(0xff4f46e5),
    Color(0xffc026d3),
  ];

  static const presenceDark = [
    Color(0xff60a5fa),
    Color(0xfff87171),
    Color(0xff4ade80),
    Color(0xfffbbf24),
    Color(0xffa78bfa),
    Color(0xff2dd4bf),
    Color(0xfff472b6),
    Color(0xff22d3ee),
    Color(0xffa3e635),
    Color(0xfffb923c),
    Color(0xff818cf8),
    Color(0xffe879f9),
  ];

  static const Map<String, Color> light = {
    WonkyColorKeys.canvas: Color(0xfff4f4f5),
    WonkyColorKeys.page: Color(0xffffffff),
    WonkyColorKeys.gridLine: Color(0xffe2e3e5),
    WonkyColorKeys.gridHeaderBg: Color(0xfff8f9fa),
    WonkyColorKeys.gridHeaderFg: Color(0xff52525b),
    WonkyColorKeys.gridHeaderSelectedBg: Color(0xffd3e3fd),
    WonkyColorKeys.selectionFill: Color(0x1f1a73e8),
    WonkyColorKeys.selectionBorder: Color(0xff1a73e8),
    WonkyColorKeys.fillHandle: Color(0xff1a73e8),
    WonkyColorKeys.commentHighlight: Color(0x59fbbc04),
    WonkyColorKeys.commentHighlightActive: Color(0xa6fbbc04),
    WonkyColorKeys.suggestionInsert: Color(0xff15803d),
    WonkyColorKeys.suggestionDelete: Color(0xffb91c1c),
    WonkyColorKeys.findMatch: Color(0x66fde047),
    WonkyColorKeys.findMatchActive: Color(0xb3fb923c),
    WonkyColorKeys.success: Color(0xff15803d),
    WonkyColorKeys.warning: Color(0xffb45309),
    WonkyColorKeys.info: Color(0xff1d4ed8),
    WonkyColorKeys.offline: Color(0xff3f3f46),
    WonkyColorKeys.offlineForeground: Color(0xfffafafa),
  };

  static const Map<String, Color> dark = {
    WonkyColorKeys.canvas: Color(0xff111113),
    WonkyColorKeys.page: Color(0xff1e1e1e),
    WonkyColorKeys.gridLine: Color(0xff2f2f35),
    WonkyColorKeys.gridHeaderBg: Color(0xff1b1b1f),
    WonkyColorKeys.gridHeaderFg: Color(0xffa1a1aa),
    WonkyColorKeys.gridHeaderSelectedBg: Color(0xff1e3a5f),
    WonkyColorKeys.selectionFill: Color(0x2960a5fa),
    WonkyColorKeys.selectionBorder: Color(0xff60a5fa),
    WonkyColorKeys.fillHandle: Color(0xff60a5fa),
    WonkyColorKeys.commentHighlight: Color(0x40fbbf24),
    WonkyColorKeys.commentHighlightActive: Color(0x80fbbf24),
    WonkyColorKeys.suggestionInsert: Color(0xff4ade80),
    WonkyColorKeys.suggestionDelete: Color(0xfff87171),
    WonkyColorKeys.findMatch: Color(0x4dfacc15),
    WonkyColorKeys.findMatchActive: Color(0x99f97316),
    WonkyColorKeys.success: Color(0xff4ade80),
    WonkyColorKeys.warning: Color(0xfffbbf24),
    WonkyColorKeys.info: Color(0xff60a5fa),
    WonkyColorKeys.offline: Color(0xff27272a),
    WonkyColorKeys.offlineForeground: Color(0xfffafafa),
  };

  /// All custom tokens (including presence colors) for [brightness].
  static Map<String, Color> tokens(Brightness brightness) {
    final base = brightness == Brightness.light ? light : dark;
    final presence = brightness == Brightness.light
        ? presenceLight
        : presenceDark;
    return {
      ...base,
      for (var i = 0; i < presence.length; i++)
        WonkyColorKeys.presence(i + 1): presence[i],
    };
  }
}

/// Typed access to the custom tokens: `ShadTheme.of(context).colorScheme.canvas`.
extension WonkyColors on ShadColorScheme {
  Color _token(String key) =>
      custom[key] ??
      WonkyPalette.tokens(
        background.computeLuminance() > 0.5
            ? Brightness.light
            : Brightness.dark,
      )[key]!;

  Color get canvas => _token(WonkyColorKeys.canvas);
  Color get page => _token(WonkyColorKeys.page);
  Color get gridLine => _token(WonkyColorKeys.gridLine);
  Color get gridHeaderBg => _token(WonkyColorKeys.gridHeaderBg);
  Color get gridHeaderFg => _token(WonkyColorKeys.gridHeaderFg);
  Color get gridHeaderSelectedBg => _token(WonkyColorKeys.gridHeaderSelectedBg);
  Color get selectionFill => _token(WonkyColorKeys.selectionFill);
  Color get selectionBorder => _token(WonkyColorKeys.selectionBorder);
  Color get fillHandle => _token(WonkyColorKeys.fillHandle);
  Color get commentHighlight => _token(WonkyColorKeys.commentHighlight);
  Color get commentHighlightActive =>
      _token(WonkyColorKeys.commentHighlightActive);
  Color get suggestionInsert => _token(WonkyColorKeys.suggestionInsert);
  Color get suggestionDelete => _token(WonkyColorKeys.suggestionDelete);
  Color get findMatch => _token(WonkyColorKeys.findMatch);
  Color get findMatchActive => _token(WonkyColorKeys.findMatchActive);
  Color get success => _token(WonkyColorKeys.success);
  Color get warning => _token(WonkyColorKeys.warning);
  Color get info => _token(WonkyColorKeys.info);
  Color get offline => _token(WonkyColorKeys.offline);
  Color get offlineForeground => _token(WonkyColorKeys.offlineForeground);

  /// Presence color for slot [index] (0-based, wraps at 12). Use
  /// `presenceColorIndex(userId)` from `wonky_core` to pick the slot.
  Color presence(int index) =>
      _token(WonkyColorKeys.presence((index % 12) + 1));

  /// All twelve presence colors.
  List<Color> get presenceColors => [for (var i = 0; i < 12; i++) presence(i)];
}
