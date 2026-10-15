/// The file-type tables of uploaded files (Drive 02 §1.2, §5, §6, §7),
/// pure Dart so the server (sniffing, categories), the apps (icons,
/// previews, *Open with*) and MCP share one definition.
library;

/// Category of an uploaded file. The names equal the generated
/// `FileCategory` enum of the protocol (`serialized: byName`), so
/// `FileCategory.values.byName(category.name)` converts.
enum FileTypeCategory {
  image,
  pdf,
  text,
  audio,
  video,
  archive,
  document,
  spreadsheet,
  presentation,
  other,
}

/// The app an uploaded file can be converted into (*Open with*, Drive 02
/// §7.1). The names equal `WonkyAppKind` / the app path segment.
enum ConvertTarget { write, sheets }

/// File-type tables and helpers (Drive 02).
abstract final class FileTypes {
  /// The generic binary type (no signature, not text).
  static const octetStream = 'application/octet-stream';

  /// Images the preview renders (Drive 02 §6.2). HEIC/TIFF/ICO are images
  /// that are not rendered; SVG is shown as text.
  static const renderableImageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
  };

  /// Active types that are never rendered, only shown as source text or
  /// downloaded (Drive 02 §5).
  static const activeMimeTypes = {
    'text/html',
    'image/svg+xml',
    'application/xhtml+xml',
    'text/xml',
    'application/xml',
    'text/javascript',
    'application/javascript',
  };

  /// Lower-case extension → MIME type of the types the suite knows by name.
  /// Used for the text type of a sniffed text file (Drive 02 §5 step 2) and
  /// as the tie-breaker for `text/plain` / `application/octet-stream`.
  static const mimeTypesByExtension = <String, String>{
    // Images
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'tif': 'image/tiff',
    'tiff': 'image/tiff',
    'ico': 'image/vnd.microsoft.icon',
    'svg': 'image/svg+xml',
    // PDF
    'pdf': 'application/pdf',
    // Audio
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'oga': 'audio/ogg',
    'opus': 'audio/opus',
    'wav': 'audio/wav',
    'flac': 'audio/flac',
    // Video
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'mkv': 'video/x-matroska',
    'avi': 'video/x-msvideo',
    // Archives
    'zip': 'application/zip',
    'tar': 'application/x-tar',
    'gz': 'application/gzip',
    'tgz': 'application/gzip',
    '7z': 'application/x-7z-compressed',
    'rar': 'application/vnd.rar',
    // Documents
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'doc': 'application/msword',
    'odt': 'application/vnd.oasis.opendocument.text',
    'rtf': 'application/rtf',
    'pages': 'application/vnd.apple.pages',
    // Spreadsheets
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'xls': 'application/vnd.ms-excel',
    'ods': 'application/vnd.oasis.opendocument.spreadsheet',
    'numbers': 'application/vnd.apple.numbers',
    'csv': 'text/csv',
    'tsv': 'text/tab-separated-values',
    // Presentations
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'ppt': 'application/vnd.ms-powerpoint',
    'odp': 'application/vnd.oasis.opendocument.presentation',
    'key': 'application/vnd.apple.keynote',
    // Text, data and source code
    'txt': 'text/plain',
    'text': 'text/plain',
    'log': 'text/plain',
    'md': 'text/markdown',
    'markdown': 'text/markdown',
    'json': 'application/json',
    'jsonc': 'application/json',
    'yaml': 'application/yaml',
    'yml': 'application/yaml',
    'toml': 'application/toml',
    'ini': 'text/plain',
    'cfg': 'text/plain',
    'conf': 'text/plain',
    'env': 'text/plain',
    'xml': 'text/xml',
    'html': 'text/html',
    'htm': 'text/html',
    'css': 'text/css',
    'scss': 'text/x-scss',
    'js': 'text/javascript',
    'mjs': 'text/javascript',
    'cjs': 'text/javascript',
    'jsx': 'text/javascript',
    'ts': 'text/x-typescript',
    'tsx': 'text/x-typescript',
    'dart': 'text/x-dart',
    'py': 'text/x-python',
    'rb': 'text/x-ruby',
    'go': 'text/x-go',
    'rs': 'text/x-rust',
    'java': 'text/x-java',
    'kt': 'text/x-kotlin',
    'kts': 'text/x-kotlin',
    'swift': 'text/x-swift',
    'c': 'text/x-c',
    'h': 'text/x-c',
    'cpp': 'text/x-c++',
    'cc': 'text/x-c++',
    'hpp': 'text/x-c++',
    'cs': 'text/x-csharp',
    'php': 'text/x-php',
    'sh': 'text/x-shellscript',
    'bash': 'text/x-shellscript',
    'zsh': 'text/x-shellscript',
    'sql': 'application/sql',
    'graphql': 'application/graphql',
    'lua': 'text/x-lua',
    'r': 'text/x-r',
    'diff': 'text/x-diff',
    'patch': 'text/x-diff',
    'dockerfile': 'text/plain',
    'gitignore': 'text/plain',
    'spy.yaml': 'application/yaml',
  };

  /// Extensions shown with the text/code viewer (Drive 02 §6.4) even when
  /// the declared or sniffed type is generic. Every text-like extension of
  /// [mimeTypesByExtension].
  static final Set<String> textExtensions = {
    for (final e in mimeTypesByExtension.entries)
      if (isTextMimeType(e.value)) e.key,
  };

  /// Extension → language id of the shared code language list (Write 04
  /// §15.1, `wonky_code` `CodeLanguages`), for syntax highlighting in the
  /// text viewer (Drive 02 §6.4). Unlisted text files are plain text.
  static const languagesByExtension = <String, String>{
    'dart': 'dart',
    'py': 'python',
    'js': 'javascript',
    'mjs': 'javascript',
    'cjs': 'javascript',
    'jsx': 'javascript',
    'ts': 'typescript',
    'tsx': 'typescript',
    'json': 'json',
    'jsonc': 'json',
    'yaml': 'yaml',
    'yml': 'yaml',
    'html': 'html',
    'htm': 'html',
    'css': 'css',
    'sql': 'sql',
    'go': 'go',
    'rs': 'rust',
    'java': 'java',
    'kt': 'kotlin',
    'kts': 'kotlin',
    'swift': 'swift',
    'md': 'markdown',
    'markdown': 'markdown',
    'spy.yaml': 'serverpod',
  };

  /// Extensions converted by *Open with* (Drive 02 §7.1). Presentations
  /// (`pptx`, `key`, `odp`) are never offered (no Slides import).
  static const convertTargetsByExtension = <String, ConvertTarget>{
    'csv': ConvertTarget.sheets,
    'tsv': ConvertTarget.sheets,
    'xlsx': ConvertTarget.sheets,
    'xls': ConvertTarget.sheets,
    'ods': ConvertTarget.sheets,
    'docx': ConvertTarget.write,
    'odt': ConvertTarget.write,
    'rtf': ConvertTarget.write,
    'md': ConvertTarget.write,
    'markdown': ConvertTarget.write,
    'txt': ConvertTarget.write,
    'html': ConvertTarget.write,
    'htm': ConvertTarget.write,
  };

  /// Multi-part extensions recognized before the last dot.
  static const _compoundExtensions = ['spy.yaml', 'tar.gz'];

  /// The lower-case extension of [fileName] without the dot (`spy.yaml`
  /// and `tar.gz` are kept whole; a dot file like `.gitignore` gives
  /// `gitignore`; `Dockerfile` gives `dockerfile`); '' when there is none.
  static String extensionOf(String fileName) {
    final name = fileName.split(RegExp(r'[/\\]')).last.toLowerCase();
    for (final c in _compoundExtensions) {
      if (name.endsWith('.$c') && name.length > c.length + 1) return c;
    }
    if (name == 'dockerfile') return 'dockerfile';
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1);
  }

  /// The essence of [mimeType]: lower case, without parameters
  /// (`text/plain; charset=utf-8` → `text/plain`).
  static String essence(String mimeType) =>
      mimeType.split(';').first.trim().toLowerCase();

  /// Whether [mimeType] is text (shown in the text viewer when the bytes
  /// decode): `text/*` and the textual `application/*` types.
  static bool isTextMimeType(String mimeType) {
    final m = essence(mimeType);
    if (m.startsWith('text/')) return true;
    if (m.endsWith('+json') || m.endsWith('+xml')) return true;
    return const {
      'application/json',
      'application/yaml',
      'application/x-yaml',
      'application/toml',
      'application/xml',
      'application/javascript',
      'application/sql',
      'application/graphql',
      'application/x-sh',
      'image/svg+xml',
      'application/xhtml+xml',
    }.contains(m);
  }

  /// Whether the preview may render [mimeType] as an image.
  static bool isRenderableImage(String mimeType) =>
      renderableImageMimeTypes.contains(essence(mimeType));

  /// Whether [mimeType] is active content that is never rendered.
  static bool isActive(String mimeType) =>
      activeMimeTypes.contains(essence(mimeType));

  /// The MIME type known for [fileName]'s extension, or null.
  static String? mimeTypeForName(String fileName) =>
      mimeTypesByExtension[extensionOf(fileName)];

  /// The category of a file with the effective (sniffed) [mimeType]; the
  /// extension of [fileName] breaks ties for `text/plain` and
  /// `application/octet-stream` (Drive 02 §1.2).
  static FileTypeCategory categoryOf(String mimeType, {String? fileName}) {
    var m = essence(mimeType);
    if ((m == 'text/plain' || m == octetStream || m.isEmpty) &&
        fileName != null) {
      final byName = mimeTypeForName(fileName);
      if (byName != null) {
        // A sniffed binary never becomes text by its name, and a sniffed
        // text file never becomes binary (e.g. `notes.docx` that is text).
        final nameIsText = isTextMimeType(byName);
        if (m == 'text/plain' ? nameIsText : !nameIsText) m = byName;
      }
    }
    return _categoryOfMime(m);
  }

  static FileTypeCategory _categoryOfMime(String m) {
    if (m == 'application/pdf') return FileTypeCategory.pdf;
    if (m == 'image/svg+xml') return FileTypeCategory.text;
    if (m.startsWith('image/')) return FileTypeCategory.image;
    if (m.startsWith('audio/')) return FileTypeCategory.audio;
    if (m.startsWith('video/')) return FileTypeCategory.video;
    if (_spreadsheetMimeTypes.contains(m)) return FileTypeCategory.spreadsheet;
    if (_documentMimeTypes.contains(m)) return FileTypeCategory.document;
    if (_presentationMimeTypes.contains(m)) {
      return FileTypeCategory.presentation;
    }
    if (_archiveMimeTypes.contains(m)) return FileTypeCategory.archive;
    if (isTextMimeType(m)) return FileTypeCategory.text;
    return FileTypeCategory.other;
  }

  static const _documentMimeTypes = {
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/msword',
    'application/vnd.oasis.opendocument.text',
    'application/rtf',
    'text/rtf',
    'application/vnd.apple.pages',
  };

  static const _spreadsheetMimeTypes = {
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-excel',
    'application/vnd.oasis.opendocument.spreadsheet',
    'application/vnd.apple.numbers',
    'text/csv',
    'text/tab-separated-values',
  };

  static const _presentationMimeTypes = {
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.ms-powerpoint',
    'application/vnd.oasis.opendocument.presentation',
    'application/vnd.apple.keynote',
  };

  static const _archiveMimeTypes = {
    'application/zip',
    'application/x-zip-compressed',
    'application/x-tar',
    'application/gzip',
    'application/x-gzip',
    'application/x-7z-compressed',
    'application/vnd.rar',
    'application/x-rar-compressed',
  };

  /// The highlighting language of [fileName] (shared language ids), or null
  /// for plain text.
  static String? languageOf(String fileName) =>
      languagesByExtension[extensionOf(fileName)];

  /// The app *Open with* offers for [fileName], or null when the type is
  /// not convertible (Drive 02 §7.1).
  static ConvertTarget? convertTargetOf(String fileName) =>
      convertTargetsByExtension[extensionOf(fileName)];

  /// The convertible extensions of [target] (an app home's *Import file…*
  /// accepts these).
  static Set<String> convertibleExtensions(ConvertTarget target) => {
    for (final e in convertTargetsByExtension.entries)
      if (e.value == target) e.key,
  };
}
