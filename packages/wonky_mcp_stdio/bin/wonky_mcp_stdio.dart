import 'dart:io';

import 'package:args/args.dart';
import 'package:wonky_mcp_stdio/wonky_mcp_stdio.dart';

const _defaultUrl = 'http://localhost:8082/mcp';

const _usageHeader = '''
wonky_mcp_stdio: proxies MCP over stdio to the Wonky Work MCP server
(Streamable HTTP), for MCP clients that only support stdio.

Usage:
  dart run wonky_mcp_stdio --url http://localhost:8082/mcp --token wkpat_xxx

The token is a personal access token (Settings > Developer/MCP). It may also
be given in the WONKY_TOKEN environment variable, and the URL in WONKY_MCP_URL.

Claude Code:
  claude mcp add wonky -- dart run /path/to/wonky/packages/wonky_mcp_stdio/bin/wonky_mcp_stdio.dart --url http://localhost:8082/mcp --token wkpat_…

Options:''';

Future<void> main(List<String> arguments) async {
  final env = Platform.environment;
  final parser = ArgParser()
    ..addOption(
      'url',
      help: 'The MCP endpoint (env: WONKY_MCP_URL).',
      valueHelp: 'url',
      defaultsTo: env['WONKY_MCP_URL'] ?? _defaultUrl,
    )
    ..addOption(
      'token',
      help: 'Personal access token, wkpat_… (env: WONKY_TOKEN).',
      valueHelp: 'token',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Log every request and response status to stderr.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

  void usage(IOSink sink) => sink
    ..writeln(_usageHeader)
    ..writeln(parser.usage);

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('wonky_mcp_stdio: ${e.message}\n');
    usage(stderr);
    exit(64);
  }

  if (args.flag('help')) {
    // Help goes to stderr too: stdout is reserved for JSON-RPC.
    usage(stderr);
    exit(0);
  }

  final url = Uri.tryParse(args.option('url')!);
  if (url == null ||
      !(url.isScheme('http') || url.isScheme('https')) ||
      url.host.isEmpty) {
    stderr.writeln('wonky_mcp_stdio: --url must be an http(s) URL.\n');
    usage(stderr);
    exit(64);
  }

  final token = args.option('token') ?? env['WONKY_TOKEN'] ?? '';
  if (token.isEmpty) {
    stderr.writeln(
      'wonky_mcp_stdio: a token is required (--token or WONKY_TOKEN).\n',
    );
    usage(stderr);
    exit(64);
  }

  final proxy = StdioHttpProxy(
    url: url,
    token: token,
    verbose: args.flag('verbose'),
  );
  final code = await proxy.run();
  await stderr.flush();
  exit(code);
}
