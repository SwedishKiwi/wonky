/// stdio to Streamable HTTP proxy for the Wonky Work MCP server
/// (`specs/09-mcp.md` §1).
///
/// Local MCP clients that only speak stdio launch the `wonky_mcp_stdio`
/// command; it forwards every newline-delimited JSON-RPC message from stdin
/// to the server's Streamable HTTP endpoint and writes the responses (and
/// server-initiated messages) to stdout, one JSON object per line.
///
/// ```sh
/// dart run wonky_mcp_stdio --url http://localhost:8082/mcp --token wkpat_xxx
/// ```
///
/// The token may also come from the `WONKY_TOKEN` environment variable and
/// the URL from `WONKY_MCP_URL`. Register it with Claude Code:
///
/// ```sh
/// claude mcp add wonky -- dart run /path/to/wonky/packages/wonky_mcp_stdio/bin/wonky_mcp_stdio.dart --url http://localhost:8082/mcp --token wkpat_…
/// ```
///
/// Use [StdioHttpProxy] to embed the proxy in other programs or tests.
library;

export 'src/stdio_http_proxy.dart';
