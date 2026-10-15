# wonky_charts

Pure-Dart chart engine of Wonky Work, shared by Wonky Sheets, Wonky Slides and the server
(specs/wonky_sheets/08-charts-and-objects.md, specs/wonky_slides/08-charts-from-sheets.md §2).

`ChartSpec` (JSON, versioned) + `ChartData` (the engine's only data input) → `ChartPipeline.layout`
→ `ChartScene` → SVG (`SvgChartRenderer`), PDF (`PdfChartRenderer`) or PNG
(`RasterChartRenderer`); Flutter paints scenes with `wonky_charts_flutter`.

| Area | API |
|------|-----|
| Spec | `ChartSpec`, `ChartDataSpec` (`DataRangeRef` opaque source references), `ChartType`, series/axis/legend parts, `ThreeDOptions`, `ChartSpecSchema` |
| Data | `ChartData`, `ChartDomain`, `ChartSeries`, aggregation, histogram buckets, LTTB downsampling, pie grouping, `ChartValueFormatter` / `DefaultChartValueFormatter` (on `wonky_numfmt`) |
| Layout | `ChartPipeline`, `ChartLayoutEngine`, `ChartTheme` from a `ChartThemeSource`, scales, `TextMeasurer` |
| Scene | `ChartScene`, primitives, `ChartRect`/`ChartSize`, paths |
| 3D | `Chart3DModel`, mesher, camera, shading, `Chart3DScene` (software rendering) |
| Render | SVG, PDF (+ `PdfTextMeasurer`), raster PNG (+ `RasterTextMeasurer`) |
| Stats | `Regression`, `LeastSquares` (trendlines; Sheets `LINEST`) |
| Describe | `ChartDescriber` (accessible summaries) |

Cell data resolution (`ChartDataResolver`, `SheetsChartPipeline`), recommendations, sparklines
and header detection stay in `wonky_sheets_core`.
