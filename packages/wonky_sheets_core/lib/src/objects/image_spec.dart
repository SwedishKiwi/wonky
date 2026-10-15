import 'dart:convert';

import 'package:wonky_charts/wonky_charts.dart'
    show JsonReader, JsonWriter, SpecNode, jsonNum;

/// How an image fills its box (08 §10.1).
enum ImageFit { stretch, contain, cover }

/// Crop fractions (P2).
final class ImageCrop extends SpecNode {
  /// Creates a crop (fractions 0..1 cut from each edge).
  const ImageCrop({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  /// Parses JSON leniently.
  factory ImageCrop.fromJson(Object? json) {
    final r = JsonReader(json);
    double f(String k) => r.dblOr(k, 0).clamp(0.0, 1.0);
    return ImageCrop(left: f('l'), top: f('t'), right: f('r'), bottom: f('b'));
  }

  final double left;
  final double top;
  final double right;
  final double bottom;

  @override
  Map<String, Object?> toJson() => {
    'l': jsonNum(left),
    't': jsonNum(top),
    'r': jsonNum(right),
    'b': jsonNum(bottom),
  };
}

/// `specJson` of image objects (08 §10.1).
final class ImageSpec extends SpecNode {
  /// Creates an image spec.
  const ImageSpec({
    required this.fileUuid,
    this.mime = 'image/png',
    this.naturalWidth = 0,
    this.naturalHeight = 0,
    this.crop,
    this.fit = ImageFit.stretch,
    this.sourceUrl,
    this.extras = const {},
  });

  /// Parses a spec (map or JSON string) leniently.
  factory ImageSpec.fromJson(Object? jsonOrString) {
    Object? m = jsonOrString;
    if (m is String) {
      try {
        m = jsonDecode(m);
      } on FormatException {
        m = null;
      }
    }
    final r = JsonReader(m);
    final crop = r.obj('crop');
    return ImageSpec(
      fileUuid: r.strOr('fileUuid', ''),
      mime: r.strOr('mime', 'image/png'),
      naturalWidth: r.intOr('naturalWidth', 0),
      naturalHeight: r.intOr('naturalHeight', 0),
      crop: crop == null ? null : ImageCrop.fromJson(crop),
      fit: r.enumOr('fit', ImageFit.values, ImageFit.stretch),
      sourceUrl: r.str('sourceUrl'),
      extras: r.extras(_keys),
    );
  }

  static const _keys = {
    'v',
    'fileUuid',
    'mime',
    'naturalWidth',
    'naturalHeight',
    'crop',
    'fit',
    'sourceUrl',
  };

  /// Schema version.
  static const int currentVersion = 1;

  /// StoredFile UUID (client-generated UUIDv7 while the upload is pending).
  final String fileUuid;
  final String mime;
  final int naturalWidth;
  final int naturalHeight;
  final ImageCrop? crop;
  final ImageFit fit;

  /// Informational source URL (inserted by URL).
  final String? sourceUrl;
  final Map<String, Object?> extras;

  /// `wonky-file://` URL of the stored file.
  String get fileUrl => 'wonky-file://$fileUuid';

  /// Copy with changes.
  ImageSpec copyWith({
    String? fileUuid,
    String? mime,
    int? naturalWidth,
    int? naturalHeight,
    ImageCrop? crop,
    ImageFit? fit,
    String? sourceUrl,
  }) => ImageSpec(
    fileUuid: fileUuid ?? this.fileUuid,
    mime: mime ?? this.mime,
    naturalWidth: naturalWidth ?? this.naturalWidth,
    naturalHeight: naturalHeight ?? this.naturalHeight,
    crop: crop ?? this.crop,
    fit: fit ?? this.fit,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter(extras)
            ..put('v', currentVersion)
            ..put('fileUuid', fileUuid)
            ..put('mime', mime)
            ..put('naturalWidth', naturalWidth)
            ..put('naturalHeight', naturalHeight)
            ..put('crop', crop?.toJson())
            ..put('fit', fit.name)
            ..put('sourceUrl', sourceUrl))
          .json;

  /// `specJson` string.
  String encode() => jsonEncode(toJson());
}
