/// Code block languages (Write 04 §15.1).
abstract final class CodeLanguages {
  /// Aliases normalised on input.
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
    'plain': '',
    'text': '',
    'plaintext': '',
  };

  /// Highlighted languages → their `syntax_highlight` grammar (Write 04
  /// §15.4). The language picker offers exactly these; other languages are
  /// kept and rendered as plain text.
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

  /// The grammar that highlights [language] (normalised), or `null` when it
  /// is shown as plain text.
  static String? grammarFor(String language) => grammars[language];

  /// Display names of languages (chip labels). Includes common languages
  /// without highlighting so typed fences (```` ```bash ````) get a label.
  static const displayNames = {
    'bash': 'Bash',
    'c': 'C',
    'cpp': 'C++',
    'csharp': 'C#',
    'css': 'CSS',
    'dart': 'Dart',
    'diff': 'Diff',
    'dockerfile': 'Dockerfile',
    'go': 'Go',
    'graphql': 'GraphQL',
    'html': 'HTML',
    'ini': 'INI',
    'java': 'Java',
    'javascript': 'JavaScript',
    'json': 'JSON',
    'kotlin': 'Kotlin',
    'lua': 'Lua',
    'makefile': 'Makefile',
    'markdown': 'Markdown',
    'objectivec': 'Objective-C',
    'perl': 'Perl',
    'php': 'PHP',
    'powershell': 'PowerShell',
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

  /// Normalises a typed language: lowercase, trimmed, aliases resolved.
  /// Unknown languages are kept verbatim (lowercased).
  static String normalize(String language) {
    final lower = language.trim().toLowerCase();
    return aliases[lower] ?? lower;
  }

  /// Display name of [language] (`Plain text` for `""`).
  static String displayName(String language) {
    if (language.isEmpty) return 'Plain text';
    return displayNames[language] ?? language;
  }
}
