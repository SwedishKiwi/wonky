import 'highlight_js/highlight_js_tokenizer.dart';

/// Code languages shared by Write code blocks, Slides code elements and
/// Drive text previews (Slides 07 §2.4; moved from Write, Write 04 §15.1).
///
/// Language ids are normalized ([normalize]): lowercase, aliases resolved,
/// `''` for plain text. Unknown languages are kept verbatim (lowercased) and
/// render plain.
abstract final class CodeLanguages {
  /// Aliases normalized on input.
  static const aliases = {
    'js': 'javascript',
    'jsx': 'javascript',
    'ts': 'typescript',
    'tsx': 'typescript',
    'py': 'python',
    'sh': 'bash',
    'shell': 'bash',
    'zsh': 'bash',
    'yml': 'yaml',
    'md': 'markdown',
    'c++': 'cpp',
    'cc': 'cpp',
    'hpp': 'cpp',
    'h': 'c',
    'c#': 'csharp',
    'cs': 'csharp',
    'kt': 'kotlin',
    'rb': 'ruby',
    'rs': 'rust',
    'golang': 'go',
    'htm': 'html',
    'mjs': 'javascript',
    'cjs': 'javascript',
    'python3': 'python',
    'py3': 'python',
    'kts': 'kotlin',
    'jsonc': 'json',
    'spy': 'serverpod',
    'serverpod_protocol': 'serverpod',
    'docker': 'dockerfile',
    'gql': 'graphql',
    'patch': 'diff',
    'svg': 'xml',
    'plist': 'xml',
    'plain': '',
    'text': '',
    'plaintext': '',
  };

  /// Languages with a TextMate grammar → their grammar id (Write 04 §15.4,
  /// `TextMateTokenizer`). Write's language picker offers these (its editor
  /// also highlights the highlight.js languages, `DefaultCodeTokenizer`).
  static const grammars = {
    'css': 'css',
    'dart': 'dart',
    'go': 'go',
    'html': 'html',
    'java': 'java',
    'javascript': 'javascript',
    'json': 'json',
    'kotlin': 'kotlin',
    'python': 'python',
    'rust': 'rust',
    'serverpod': 'serverpod_protocol',
    'sql': 'sql',
    'swift': 'swift',
    'typescript': 'typescript',
    'yaml': 'yaml',
  };

  /// Languages highlighted by highlight.js (no TextMate grammar), in picker
  /// order (Slides 07 §2.4).
  static const highlightJsLanguages = [
    'bash',
    'c',
    'cpp',
    'csharp',
    'diff',
    'dockerfile',
    'graphql',
    'markdown',
    'php',
    'ruby',
    'scala',
    'xml',
    'lua',
    'perl',
    'r',
    'haskell',
    'elixir',
    'erlang',
    'objectivec',
    'powershell',
    'protobuf',
    'ini',
    'makefile',
    'nginx',
    'scss',
    'less',
    'groovy',
    'gradle',
    'matlab',
    'clojure',
    'http',
  ];

  /// The TextMate grammar id that highlights [language] (normalized), or
  /// `null` when it has none.
  static String? grammarFor(String language) => grammars[language];

  /// Display names of languages (chip labels). Includes common languages
  /// without highlighting so typed fences (```` ```toml ````) get a label.
  static const displayNames = {
    'bash': 'Bash',
    'c': 'C',
    'clojure': 'Clojure',
    'cpp': 'C++',
    'csharp': 'C#',
    'css': 'CSS',
    'dart': 'Dart',
    'diff': 'Diff',
    'dockerfile': 'Dockerfile',
    'elixir': 'Elixir',
    'erlang': 'Erlang',
    'go': 'Go',
    'gradle': 'Gradle',
    'graphql': 'GraphQL',
    'groovy': 'Groovy',
    'haskell': 'Haskell',
    'html': 'HTML',
    'http': 'HTTP',
    'ini': 'INI',
    'java': 'Java',
    'javascript': 'JavaScript',
    'json': 'JSON',
    'kotlin': 'Kotlin',
    'less': 'Less',
    'lua': 'Lua',
    'makefile': 'Makefile',
    'markdown': 'Markdown',
    'matlab': 'MATLAB',
    'nginx': 'Nginx',
    'objectivec': 'Objective-C',
    'perl': 'Perl',
    'php': 'PHP',
    'powershell': 'PowerShell',
    'protobuf': 'Protocol Buffers',
    'python': 'Python',
    'r': 'R',
    'ruby': 'Ruby',
    'rust': 'Rust',
    'scala': 'Scala',
    'scss': 'SCSS',
    'serverpod': 'Serverpod model',
    'sql': 'SQL',
    'swift': 'Swift',
    'toml': 'TOML',
    'typescript': 'TypeScript',
    'xml': 'XML',
    'yaml': 'YAML',
  };

  /// Normalizes a typed language: lowercase, trimmed, aliases resolved.
  /// Unknown languages are kept verbatim (lowercased).
  static String normalize(String language) {
    final lower = language.trim().toLowerCase();
    return aliases[lower] ?? lower;
  }

  /// Display name of [language] (`Plain text` for `""`; unknown → itself).
  static String displayName(String language) {
    if (language.isEmpty) return 'Plain text';
    return displayNames[language] ?? language;
  }

  /// Whether [language] (normalized) gets syntax highlighting from the
  /// default tokenizer (TextMate or highlight.js).
  static bool isHighlighted(String language) {
    if (grammars.containsKey(language)) return true;
    final id = HighlightJsTokenizer.instance.canonicalLanguage(language);
    return id != null && id != HighlightJsTokenizer.plaintext;
  }

  /// The languages a language picker offers after *Plain text* and the
  /// recently used ones: the TextMate languages, then the highlight.js ones
  /// (Slides 07 §2.4).
  static List<String> get pickerLanguages => _pickerLanguages;

  static final List<String> _pickerLanguages = List.unmodifiable([
    ...grammars.keys,
    ...highlightJsLanguages,
  ]);

  /// File extensions (lowercase, with the dot) → language (Slides 07 §2.4;
  /// Drive text previews, Drive 02 §6.4).
  static const extensions = {
    '.css': 'css',
    '.dart': 'dart',
    '.go': 'go',
    '.html': 'html',
    '.htm': 'html',
    '.java': 'java',
    '.js': 'javascript',
    '.jsx': 'javascript',
    '.mjs': 'javascript',
    '.cjs': 'javascript',
    '.json': 'json',
    '.kt': 'kotlin',
    '.kts': 'kotlin',
    '.py': 'python',
    '.rs': 'rust',
    '.sql': 'sql',
    '.swift': 'swift',
    '.ts': 'typescript',
    '.tsx': 'typescript',
    '.yaml': 'yaml',
    '.yml': 'yaml',
    '.sh': 'bash',
    '.bash': 'bash',
    '.zsh': 'bash',
    '.c': 'c',
    '.h': 'c',
    '.cpp': 'cpp',
    '.cc': 'cpp',
    '.hpp': 'cpp',
    '.cs': 'csharp',
    '.diff': 'diff',
    '.patch': 'diff',
    '.graphql': 'graphql',
    '.md': 'markdown',
    '.php': 'php',
    '.rb': 'ruby',
    '.scala': 'scala',
    '.xml': 'xml',
    '.svg': 'xml',
  };

  /// The language of a file named [name] (a file name or path), or `null`
  /// when unknown: `.spy.yaml` → `serverpod`, `Dockerfile` → `dockerfile`,
  /// else by extension ([extensions]).
  static String? fromFileName(String name) {
    final slash = name.lastIndexOf(RegExp(r'[/\\]'));
    final base = name.substring(slash + 1).toLowerCase();
    if (base.endsWith('.spy.yaml') || base.endsWith('.spy.yml')) {
      return 'serverpod';
    }
    if (base == 'dockerfile' || base.startsWith('dockerfile.')) {
      return 'dockerfile';
    }
    if (base == 'makefile') return 'makefile';
    final dot = base.lastIndexOf('.');
    if (dot < 0) return null;
    return extensions[base.substring(dot)];
  }
}
