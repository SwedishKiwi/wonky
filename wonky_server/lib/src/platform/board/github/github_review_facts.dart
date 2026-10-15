import 'github_client.dart';

/// Facts about a pull request computed in code, not by the AI (specs/16
/// §13.5): passed to the model and shown in the review comment.
class PrFacts {
  const PrFacts({
    required this.files,
    required this.testsChanged,
    required this.specsChanged,
    required this.pubspecs,
    required this.dependencyLines,
    required this.migrationsAdded,
    required this.workflowFiles,
    required this.sensitiveFiles,
  });

  final List<PrFileFact> files;
  final bool testsChanged;
  final bool specsChanged;

  /// Changed `pubspec.yaml` files.
  final List<String> pubspecs;

  /// Added or removed dependency lines in those (`+ http: ^1.6.0`).
  final List<String> dependencyLines;

  /// Migration folders added under `wonky_server/migrations/`.
  final List<String> migrationsAdded;

  /// Changes in `.github/` or `tool/`.
  final List<String> workflowFiles;

  /// Security-sensitive paths.
  final List<String> sensitiveFiles;

  int get additions => files.fold(0, (s, f) => s + f.additions);
  int get deletions => files.fold(0, (s, f) => s + f.deletions);

  static const maxDependencyLines = 30;

  /// Paths whose changes need a closer look (specs/16 §13.5).
  static const sensitiveSegments = [
    'platform/users/',
    'platform/sharing/',
    'platform/files/',
    'platform/mcp/',
    'board/github/',
  ];

  static bool isTest(String path) =>
      path.startsWith('test/') ||
      path.startsWith('integration_test/') ||
      path.contains('/test/') ||
      path.contains('/integration_test/');

  static bool isSensitive(String path) =>
      sensitiveSegments.any(path.contains) ||
      path == 'server.dart' ||
      path.endsWith('/server.dart');

  static bool isWorkflow(String path) =>
      path.startsWith('.github/') || path.startsWith('tool/');

  static final _migration = RegExp(r'(^|/)migrations/([^/]+)/');
  static final _dependencyLine = RegExp(
    r'^[+-]\s{2,}[a-z_][a-z0-9_]*:\s*\S',
    caseSensitive: false,
  );

  factory PrFacts.of(List<GithubPrFile> files) {
    final pubspecs = <String>[];
    final dependencyLines = <String>[];
    final migrations = <String>{};
    for (final f in files) {
      if (f.path == 'pubspec.yaml' || f.path.endsWith('/pubspec.yaml')) {
        pubspecs.add(f.path);
        for (final line in (f.patch ?? '').split('\n')) {
          if (line.startsWith('+++') || line.startsWith('---')) continue;
          if (_dependencyLine.hasMatch(line) &&
              dependencyLines.length < maxDependencyLines) {
            dependencyLines.add('${f.path}: ${line.trimRight()}');
          }
        }
      }
      final m = _migration.firstMatch(f.path);
      if (m != null && f.status == 'added' && f.path.contains('_server/')) {
        migrations.add(m.group(2)!);
      }
    }
    return PrFacts(
      files: [
        for (final f in files)
          PrFileFact(
            path: f.path,
            status: f.status,
            additions: f.additions,
            deletions: f.deletions,
          ),
      ],
      testsChanged: files.any((f) => isTest(f.path)),
      specsChanged: files.any((f) => f.path.startsWith('specs/')),
      pubspecs: pubspecs,
      dependencyLines: dependencyLines,
      migrationsAdded: migrations.toList()..sort(),
      workflowFiles: [
        for (final f in files)
          if (isWorkflow(f.path)) f.path,
      ],
      sensitiveFiles: [
        for (final f in files)
          if (isSensitive(f.path)) f.path,
      ],
    );
  }

  /// The facts as plain text for the model.
  String toPromptText() {
    final b = StringBuffer()
      ..writeln(
        'Changed files: ${files.length} (+$additions −$deletions lines)',
      );
    for (final f in files.take(300)) {
      b.writeln('- ${f.path} (${f.status}, +${f.additions} −${f.deletions})');
    }
    if (files.length > 300) b.writeln('- … ${files.length - 300} more');
    b
      ..writeln('Tests changed: ${testsChanged ? 'yes' : 'no'}')
      ..writeln('specs/ changed: ${specsChanged ? 'yes' : 'no'}')
      ..writeln(
        'pubspec.yaml changed: ${pubspecs.isEmpty ? 'no' : pubspecs.join(', ')}',
      );
    for (final l in dependencyLines) {
      b.writeln('  $l');
    }
    b
      ..writeln(
        'Migrations added: '
        '${migrationsAdded.isEmpty ? 'none' : migrationsAdded.join(', ')}',
      )
      ..writeln(
        'Workflow or tooling changes: '
        '${workflowFiles.isEmpty ? 'none' : workflowFiles.join(', ')}',
      )
      ..writeln(
        'Security-sensitive paths: '
        '${sensitiveFiles.isEmpty ? 'none' : sensitiveFiles.join(', ')}',
      );
    return b.toString().trim();
  }

  Map<String, Object?> toJson() => {
    'files': [for (final f in files) f.toJson()],
    'additions': additions,
    'deletions': deletions,
    'testsChanged': testsChanged,
    'specsChanged': specsChanged,
    'pubspecs': pubspecs,
    'dependencyLines': dependencyLines,
    'migrationsAdded': migrationsAdded,
    'workflowFiles': workflowFiles,
    'sensitiveFiles': sensitiveFiles,
  };
}

class PrFileFact {
  const PrFileFact({
    required this.path,
    required this.status,
    this.additions = 0,
    this.deletions = 0,
  });

  final String path;
  final String status;
  final int additions;
  final int deletions;

  Map<String, Object?> toJson() => {
    'path': path,
    'status': status,
    'additions': additions,
    'deletions': deletions,
  };
}

/// The diff the model reads: generated, binary and lock files left out,
/// cut at the token budget (≈ 4 characters per token) at file
/// boundaries.
class PrDiff {
  const PrDiff({
    required this.text,
    this.excluded = const [],
    this.truncated = const [],
  });

  final String text;

  /// Files left out as generated, binary or lock files.
  final List<String> excluded;

  /// Files left out because the budget was used up.
  final List<String> truncated;

  static const charsPerToken = 4;

  static const _binaryExtensions = {
    'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'ico', 'svgz', 'pdf', //
    'ttf', 'otf', 'woff', 'woff2', 'wasm', 'zip', 'gz', 'jar', 'mp4', 'mp3',
    'wav', 'webm', 'mov', 'aff', 'dic', 'bin', 'so', 'dylib', 'dll', 'exe',
  };

  /// Whether [path] is left out of the review diff: the generated client,
  /// generated folders, images and goldens, lock files and other binaries.
  static bool isExcluded(String path) {
    final p = path.toLowerCase();
    if (p.startsWith('wonky_client/') || p.contains('/wonky_client/')) {
      return true;
    }
    if (p.contains('/generated/') || p.startsWith('generated/')) return true;
    if (p.contains('/goldens/')) return true;
    if (p.endsWith('.lock')) return true;
    final dot = p.lastIndexOf('.');
    final ext = dot < 0 ? '' : p.substring(dot + 1);
    return _binaryExtensions.contains(ext);
  }

  /// Splits a unified diff into (path, chunk) per file.
  static List<(String, String)> split(String diff) {
    final result = <(String, String)>[];
    final lines = diff.split('\n');
    String? path;
    var chunk = StringBuffer();
    void flush() {
      if (path != null) result.add((path, chunk.toString()));
      chunk = StringBuffer();
    }

    for (final line in lines) {
      if (line.startsWith('diff --git ')) {
        flush();
        final b = line.lastIndexOf(' b/');
        path = b < 0 ? line.substring(11) : line.substring(b + 3);
      }
      if (path != null) chunk.writeln(line);
    }
    flush();
    return result;
  }

  /// A diff of [files]' patches, for when GitHub won't produce the full
  /// diff (too large).
  static String fromFiles(List<GithubPrFile> files) {
    final b = StringBuffer();
    for (final f in files) {
      final old = f.previousPath ?? f.path;
      b.writeln('diff --git a/$old b/${f.path}');
      final patch = f.patch;
      if (patch == null) {
        b.writeln('Binary files a/$old and b/${f.path} differ');
        continue;
      }
      b
        ..writeln(f.status == 'added' ? '--- /dev/null' : '--- a/$old')
        ..writeln(f.status == 'removed' ? '+++ /dev/null' : '+++ b/${f.path}')
        ..writeln(patch);
    }
    return b.toString();
  }

  /// [diff] without excluded and binary files, cut after [maxTokens].
  factory PrDiff.filter(String diff, {required int maxTokens}) {
    final budget = maxTokens * charsPerToken;
    final excluded = <String>[];
    final truncated = <String>[];
    final out = StringBuffer();
    var used = 0;
    for (final (path, chunk) in split(diff)) {
      if (isExcluded(path) || chunk.contains('\nBinary files ')) {
        excluded.add(path);
        continue;
      }
      if (used + chunk.length > budget) {
        truncated.add(path);
        continue;
      }
      used += chunk.length;
      out.write(chunk);
    }
    return PrDiff(
      text: out.toString(),
      excluded: excluded,
      truncated: truncated,
    );
  }
}
