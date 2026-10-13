/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// How a template card draws its miniature page (specs/05 §3.1): the
/// colors of the template's document theme (light and dark) and a few
/// layout traits, so templates with different themes look different.
/// Colors are "#rrggbb".
abstract class TemplatePreviewStyle
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  TemplatePreviewStyle._({
    required this.paper,
    required this.text,
    required this.heading,
    required this.accent,
    required this.darkPaper,
    required this.darkText,
    required this.darkHeading,
    required this.darkAccent,
    required this.banner,
    required this.centeredHeadings,
    required this.uppercaseHeadings,
    required this.fontCategory,
  });

  factory TemplatePreviewStyle({
    required String paper,
    required String text,
    required String heading,
    required String accent,
    required String darkPaper,
    required String darkText,
    required String darkHeading,
    required String darkAccent,
    required bool banner,
    required bool centeredHeadings,
    required bool uppercaseHeadings,
    required String fontCategory,
  }) = _TemplatePreviewStyleImpl;

  factory TemplatePreviewStyle.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return TemplatePreviewStyle(
      paper: jsonSerialization['paper'] as String,
      text: jsonSerialization['text'] as String,
      heading: jsonSerialization['heading'] as String,
      accent: jsonSerialization['accent'] as String,
      darkPaper: jsonSerialization['darkPaper'] as String,
      darkText: jsonSerialization['darkText'] as String,
      darkHeading: jsonSerialization['darkHeading'] as String,
      darkAccent: jsonSerialization['darkAccent'] as String,
      banner: _isc.BoolJsonExtension.fromJson(jsonSerialization['banner']),
      centeredHeadings: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['centeredHeadings'],
      ),
      uppercaseHeadings: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['uppercaseHeadings'],
      ),
      fontCategory: jsonSerialization['fontCategory'] as String,
    );
  }

  String paper;

  String text;

  String heading;

  String accent;

  String darkPaper;

  String darkText;

  String darkHeading;

  String darkAccent;

  /// A band in the accent color across the top of the page.
  bool banner;

  /// Headings centered (otherwise start-aligned).
  bool centeredHeadings;

  /// Headings in capitals.
  bool uppercaseHeadings;

  /// "serif", "sans" or "mono": the character of the theme's fonts.
  String fontCategory;

  /// Returns a shallow copy of this [TemplatePreviewStyle]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  TemplatePreviewStyle copyWith({
    String? paper,
    String? text,
    String? heading,
    String? accent,
    String? darkPaper,
    String? darkText,
    String? darkHeading,
    String? darkAccent,
    bool? banner,
    bool? centeredHeadings,
    bool? uppercaseHeadings,
    String? fontCategory,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'TemplatePreviewStyle',
      'paper': paper,
      'text': text,
      'heading': heading,
      'accent': accent,
      'darkPaper': darkPaper,
      'darkText': darkText,
      'darkHeading': darkHeading,
      'darkAccent': darkAccent,
      'banner': banner,
      'centeredHeadings': centeredHeadings,
      'uppercaseHeadings': uppercaseHeadings,
      'fontCategory': fontCategory,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'TemplatePreviewStyle',
      'paper': paper,
      'text': text,
      'heading': heading,
      'accent': accent,
      'darkPaper': darkPaper,
      'darkText': darkText,
      'darkHeading': darkHeading,
      'darkAccent': darkAccent,
      'banner': banner,
      'centeredHeadings': centeredHeadings,
      'uppercaseHeadings': uppercaseHeadings,
      'fontCategory': fontCategory,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _TemplatePreviewStyleImpl extends TemplatePreviewStyle {
  _TemplatePreviewStyleImpl({
    required String paper,
    required String text,
    required String heading,
    required String accent,
    required String darkPaper,
    required String darkText,
    required String darkHeading,
    required String darkAccent,
    required bool banner,
    required bool centeredHeadings,
    required bool uppercaseHeadings,
    required String fontCategory,
  }) : super._(
         paper: paper,
         text: text,
         heading: heading,
         accent: accent,
         darkPaper: darkPaper,
         darkText: darkText,
         darkHeading: darkHeading,
         darkAccent: darkAccent,
         banner: banner,
         centeredHeadings: centeredHeadings,
         uppercaseHeadings: uppercaseHeadings,
         fontCategory: fontCategory,
       );

  /// Returns a shallow copy of this [TemplatePreviewStyle]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  TemplatePreviewStyle copyWith({
    String? paper,
    String? text,
    String? heading,
    String? accent,
    String? darkPaper,
    String? darkText,
    String? darkHeading,
    String? darkAccent,
    bool? banner,
    bool? centeredHeadings,
    bool? uppercaseHeadings,
    String? fontCategory,
  }) {
    return TemplatePreviewStyle(
      paper: paper ?? this.paper,
      text: text ?? this.text,
      heading: heading ?? this.heading,
      accent: accent ?? this.accent,
      darkPaper: darkPaper ?? this.darkPaper,
      darkText: darkText ?? this.darkText,
      darkHeading: darkHeading ?? this.darkHeading,
      darkAccent: darkAccent ?? this.darkAccent,
      banner: banner ?? this.banner,
      centeredHeadings: centeredHeadings ?? this.centeredHeadings,
      uppercaseHeadings: uppercaseHeadings ?? this.uppercaseHeadings,
      fontCategory: fontCategory ?? this.fontCategory,
    );
  }
}
