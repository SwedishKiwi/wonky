import 'file_downloader_io.dart'
    if (dart.library.js_interop) 'file_downloader_web.dart'
    as platform;

/// Starts a browser download of a URL (Drive 02 §8).
abstract class FileDownloader {
  /// Starts downloading [url] as [fileName]. Returns false when downloads
  /// aren't available on this platform.
  Future<bool> download(String url, String fileName);
}

/// Web: a hidden `<a download>` anchor clicked in the same tab — the
/// server answers with `Content-Disposition: attachment`, so the page
/// stays (single window, suite 03 §1). Desktop: not available yet (suite
/// 01 A13; returns false).
class PlatformFileDownloader implements FileDownloader {
  const PlatformFileDownloader();

  @override
  Future<bool> download(String url, String fileName) async =>
      platform.downloadUrl(url, fileName);
}
