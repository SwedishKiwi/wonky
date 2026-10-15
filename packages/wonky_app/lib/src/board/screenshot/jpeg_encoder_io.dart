import '../../mcp_bridge/app_screenshot.dart' show ScreenshotJpegEncoder;

/// No JPEG encoder off the web (`wonky_app` has no `package:image`).
ScreenshotJpegEncoder? get jpegEncoder => null;
