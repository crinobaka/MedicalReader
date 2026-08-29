import 'package:flutter/material.dart';

enum CropEditorTool { select, rectangle, line, polygon }

class CropEditorToolbar extends StatelessWidget {
  final CropEditorTool selected;
  final ValueChanged<CropEditorTool> onSelected;
  final VoidCallback? onFitPage;
  final VoidCallback? onClear;

  const CropEditorToolbar({super.key, required this.selected, required this.onSelected, this.onFitPage, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(18),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Wrap(spacing: 2, children: [
          _tool(CropEditorTool.select, Icons.pan_tool_outlined, '选择/移动'),
          _tool(CropEditorTool.rectangle, Icons.rectangle_outlined, '矩形区域'),
          _tool(CropEditorTool.line, Icons.horizontal_rule, '分隔线'),
          _tool(CropEditorTool.polygon, Icons.pentagon_outlined, '多边形区域'),
          if (onFitPage != null) IconButton(tooltip: '适应页面', onPressed: onFitPage, icon: const Icon(Icons.fit_screen_outlined)),
          if (onClear != null) IconButton(tooltip: '清空区域', onPressed: onClear, icon: const Icon(Icons.layers_clear_outlined)),
        ]),
      ),
    );
  }

  Widget _tool(CropEditorTool tool, IconData icon, String label) => Tooltip(
    message: label,
    child: IconButton.filledTonal(isSelected: selected == tool, onPressed: () => onSelected(tool), icon: Icon(icon)),
  );
}
