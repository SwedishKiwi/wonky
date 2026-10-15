# wonky_numfmt

Pure-Dart spreadsheet number formats (`#,##0.00`, `0%`, `[$€]#,##0`, `yyyy-mm-dd`, `preset:*`),
shared by Wonky Sheets (cell display) and the chart engine `wonky_charts` (axes, labels,
tooltips). Specs: `specs/wonky_sheets/06-formatting.md` §5, `specs/wonky_slides/08-charts-from-sheets.md` §2.5.

| API | What |
|-----|------|
| `NumberPatternFormatter` | Cached formatter: `formatNumber(double, pattern, locale:)`, `formatString`, `formatNumberText` |
| `NumberFormatParser`, `NumberFormatAst` | Pattern parser and AST |
| `NumberFormatRenderer`, `AutomaticFormatter` | Uncached rendering of numbers and text |
| `NumberFormatPresets`, `NumberFormatMenuItem` | `preset:` ids and their locale resolution |
| `LocaleFormatData` | CLDR number/date symbols per locale |
| `SerialCalendar`, `DateSerial` | Spreadsheet date serials (days since 1899-12-30) |
| `FormattedValue`, `FormatSegment` | Formatted output (text, spacer and repeat segments, color) |

Wonky Sheets keeps the cell adapters (`NumberFormatter` over `CellValue`, format hints,
`CellTextFormatter`, input inference, decimals adjustment) in `wonky_sheets_core`.
