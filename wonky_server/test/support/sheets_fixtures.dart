import 'mcp_harness.dart';

/// Spreadsheet fixtures created through the MCP tools themselves (Sheets 12
/// §10).
abstract final class SheetsFixtures {
  /// Creates a spreadsheet (one sheet per entry of [sheets], default one
  /// "Sheet1") and returns its drive item uuid.
  static Future<String> create(
    McpHarness mcp, {
    String name = 'Spreadsheet',
    Map<String, List<List<Object?>>> sheets = const {},
  }) async {
    final r = await mcp.call('drive.create_spreadsheet', {
      'name': name,
      if (sheets.isNotEmpty)
        'sheets': [
          for (final e in sheets.entries) {'name': e.key, 'values': e.value},
        ],
    });
    return (r['item'] as Map)['uuid'] as String;
  }

  /// Shares [spreadsheet] with [email] as [role] (viewer, commenter,
  /// editor) through `drive.share`.
  static Future<void> share(
    McpHarness owner,
    String spreadsheet,
    String email,
    String role,
  ) => owner.call('drive.share', {
    'uuid': spreadsheet,
    'email': email,
    'role': role,
    'notify': false,
  });

  /// A small sales table on "Data" (header + 6 rows).
  static const sales = <List<Object?>>[
    ['Region', 'Product', 'Revenue', 'Units'],
    ['North', 'Apples', 120, 10],
    ['South', 'Pears', 80, 4],
    ['North', 'Pears', 60, 3],
    ['East', 'Apples', 200, 16],
    ['South', 'Apples', 90, 7],
    ['East', 'Pears', 40, 2],
  ];

  /// Reads one range with `sheets.get_values` and returns its values.
  static Future<List<Object?>> read(
    McpHarness mcp,
    String spreadsheet,
    String range, {
    String render = 'formatted',
  }) async {
    final r = await mcp.call('sheets.get_values', {
      'spreadsheet': spreadsheet,
      'ranges': [range],
      'render': render,
    });
    return ((r['ranges'] as List).first as Map)['values'] as List<Object?>;
  }
}
