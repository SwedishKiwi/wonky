/// Cross-package contracts of Wonky Slides implemented elsewhere
/// (specs/wonky_slides/12 §5.3, §5.7, 10 §11): image resolution, the PDF
/// renderer with its options and resources, and the server-side change-log
/// consumer and headless deck (generic over the server's context type).
///
/// Pure Dart.
library;

export 'src/interfaces/images.dart';
export 'src/interfaces/pdf.dart';
export 'src/interfaces/server.dart';
