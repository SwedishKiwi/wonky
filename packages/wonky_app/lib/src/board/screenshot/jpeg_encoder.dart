import '../../mcp_bridge/app_screenshot.dart' show ScreenshotJpegEncoder;
import 'jpeg_encoder_io.dart'
    if (dart.library.js_interop) 'jpeg_encoder_web.dart'
    as impl;

/// The platform's JPEG encoder for `encodeScreenshot` (specs/16 §5.2): the
/// browser's canvas (`toBlob('image/jpeg')`) on the web, none elsewhere
/// (screenshots then stay PNG and are downscaled when too large).
ScreenshotJpegEncoder? get platformJpegEncoder => impl.jpegEncoder;
