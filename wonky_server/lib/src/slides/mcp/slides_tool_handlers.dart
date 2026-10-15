import 'package:wonky_core/wonky_core.dart' show McpToolDefinition, SlidesTools;

import '../../platform/mcp/tool_executor.dart';
import '../../platform/mcp/tool_support.dart';
import 'slides_deck_handlers.dart';
import 'slides_element_handlers.dart';
import 'slides_media_handlers.dart';
import 'slides_read_handlers.dart';

/// The headless `slides.*` tools (Slides 11 §3) and the handler of
/// `drive.create_presentation`, registered in the MCP server like the
/// Write and Sheets tools.
abstract final class SlidesToolHandlers {
  static List<RegisteredMcpTool> get all => [
    _t(SlidesTools.getDeck, SlidesReadHandlers.getDeck),
    _t(SlidesTools.getSlide, SlidesReadHandlers.getSlide),
    _t(SlidesTools.getElement, SlidesReadHandlers.getElement),
    _t(SlidesTools.listLayouts, SlidesReadHandlers.listLayouts),
    _t(SlidesTools.listThemes, SlidesReadHandlers.listThemes),
    _t(SlidesTools.search, SlidesReadHandlers.search),
    _t(SlidesTools.renderSlide, SlidesReadHandlers.renderSlide),
    _t(SlidesTools.createPresentation, SlidesDeckHandlers.createPresentation),
    _t(SlidesTools.setDeckProperties, SlidesDeckHandlers.setDeckProperties),
    _t(SlidesTools.applyTheme, SlidesDeckHandlers.applyTheme),
    _t(SlidesTools.addSlides, SlidesDeckHandlers.addSlides),
    _t(
      SlidesTools.addSlidesFromMarkdown,
      SlidesDeckHandlers.addSlidesFromMarkdown,
    ),
    _t(SlidesTools.updateSlide, SlidesDeckHandlers.updateSlide),
    _t(SlidesTools.setSpeakerNotes, SlidesDeckHandlers.setSpeakerNotes),
    _t(SlidesTools.moveSlides, SlidesDeckHandlers.moveSlides),
    _t(SlidesTools.duplicateSlides, SlidesDeckHandlers.duplicateSlides),
    _t(SlidesTools.deleteSlides, SlidesDeckHandlers.deleteSlides),
    _t(SlidesTools.createGroup, SlidesDeckHandlers.createGroup),
    _t(SlidesTools.updateGroup, SlidesDeckHandlers.updateGroup),
    _t(SlidesTools.moveGroup, SlidesDeckHandlers.moveGroup),
    _t(SlidesTools.duplicateGroup, SlidesDeckHandlers.duplicateGroup),
    _t(SlidesTools.ungroup, SlidesDeckHandlers.ungroup),
    _t(SlidesTools.deleteGroup, SlidesDeckHandlers.deleteGroup),
    _t(SlidesTools.addElements, SlidesElementHandlers.addElements),
    _t(SlidesTools.updateElements, SlidesElementHandlers.updateElements),
    _t(SlidesTools.setText, SlidesElementHandlers.setText),
    _t(SlidesTools.formatText, SlidesElementHandlers.formatText),
    _t(SlidesTools.replaceText, SlidesElementHandlers.replaceText),
    _t(SlidesTools.deleteElements, SlidesElementHandlers.deleteElements),
    _t(SlidesTools.duplicateElements, SlidesElementHandlers.duplicateElements),
    _t(SlidesTools.groupElements, SlidesElementHandlers.groupElements),
    _t(SlidesTools.ungroupElements, SlidesElementHandlers.ungroupElements),
    _t(SlidesTools.alignElements, SlidesElementHandlers.alignElements),
    _t(SlidesTools.setTableCells, SlidesElementHandlers.setTableCells),
    _t(SlidesTools.listSheetCharts, SlidesMediaHandlers.listSheetCharts),
    _t(SlidesTools.insertLinkedChart, SlidesMediaHandlers.insertLinkedChart),
    _t(
      SlidesTools.refreshLinkedCharts,
      SlidesMediaHandlers.refreshLinkedCharts,
    ),
    _t(SlidesTools.updateChartStyle, SlidesMediaHandlers.updateChartStyle),
    _t(SlidesTools.unlinkChart, SlidesMediaHandlers.unlinkChart),
    _t(SlidesTools.addCodeBlock, SlidesMediaHandlers.addCodeBlock),
    _t(SlidesTools.setCodeStates, SlidesMediaHandlers.setCodeStates),
    _t(SlidesTools.updateCodeBlock, SlidesMediaHandlers.updateCodeBlock),
    _t(SlidesTools.setBuilds, SlidesMediaHandlers.setBuilds),
    _t(SlidesTools.updateBuild, SlidesMediaHandlers.updateBuild),
    _t(SlidesTools.deleteBuilds, SlidesMediaHandlers.deleteBuilds),
    _t(SlidesTools.setTransition, SlidesMediaHandlers.setTransition),
    _t(SlidesTools.exportPdf, SlidesMediaHandlers.exportPdf),
  ];

  static RegisteredMcpTool _t(McpToolDefinition d, ToolHandler h) =>
      RegisteredMcpTool(d, h);
}
