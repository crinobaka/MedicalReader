import 'package:flutter/material.dart';

import '../models/crop_configuration.dart';
import '../services/crop_engine_service.dart';

/// 裁剪编辑器。
///
/// 页面分隔出来的区域可以独立标记为“排除”。排除区域仍保留在配置中，
/// 但不会参与最终编号和拼接；长按区域即可在参与/排除之间切换。
class CropEditorDialog extends StatefulWidget {
  final CropConfiguration initial;

  const CropEditorDialog({super.key, required this.initial});

  @override
  State<CropEditorDialog> createState() => _CropEditorDialogState();
}

class _CropEditorDialogState extends State<CropEditorDialog> {
  final CropEngineService _engine = const CropEngineService();
  late CropTemplate _template;
  late CropLayout _layout;
  late bool _inheritPrevious;
  late double _left;
  late double _right;
  late double _top;
  late double _bottom;
  late int? _pageStart;
  late int? _pageEnd;
  late List<CropRegion> _regions;

  final _pageStartController = TextEditingController();
  final _pageEndController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    _template = value.template;
    _layout = value.layout;
    _inheritPrevious = value.inheritPrevious;
    _left = value.adjustment.left;
    _right = value.adjustment.right;
    _top = value.adjustment.top;
    _bottom = value.adjustment.bottom;
    _pageStart = value.pageStart;
    _pageEnd = value.pageEnd;
    _regions = List.of(value.regions);
    _pageStartController.text = value.pageStart?.toString() ?? '';
    _pageEndController.text = value.pageEnd?.toString() ?? '';
  }

  @override
  void dispose() {
    _pageStartController.dispose();
    _pageEndController.dispose();
    super.dispose();
  }

  void _selectTemplate(CropTemplate value) {
    setState(() {
      _template = value;
      _regions = List.of(_engine.defaultRegions(value));
    });
  }

  void _materializeRegions() {
    if (_regions.isEmpty) _regions = List.of(_engine.defaultRegions(_template));
  }

  void _toggleExcluded(int index) {
    setState(() {
      _materializeRegions();
      _template = CropTemplate.custom;
      _regions[index] = _regions[index].copyWith(excluded: !_regions[index].excluded);
    });
  }

  void _addRegion() {
    setState(() {
      _regions = [..._regions, const CropRegion(x: 0.1, y: 0.1, width: 0.8, height: 0.8)];
      _template = CropTemplate.custom;
    });
  }

  void _removeRegion(int index) {
    setState(() => _regions = List<CropRegion>.of(_regions)..removeAt(index));
  }

  void _updateRegion(int index, CropRegion region) {
    setState(() {
      _materializeRegions();
      _template = CropTemplate.custom;
      _regions[index] = region.clamp();
    });
  }

  List<CropRegion> get _previewRegions {
    final regions = _regions.isNotEmpty ? _regions : _engine.defaultRegions(_template);
    return regions
        .map((region) => region.adjust(CropAdjustment(left: _left, right: _right, top: _top, bottom: _bottom)))
        .where((region) => region.width > 0 && region.height > 0)
        .toList();
  }

  String get _templateDescription {
    switch (_template) {
      case CropTemplate.single:
        return '整页显示，不拆分页面。';
      case CropTemplate.doubleColumn:
        return '一页 PDF 拆成左、右两个区域，再横向拼接。';
      case CropTemplate.tripleColumn:
        return '一页 PDF 拆成三个区域，再按当前布局排列。';
      case CropTemplate.custom:
        return '长按区域可切换是否参与编号和输出；斜线区域不会参与。';
      case CropTemplate.bookTemplate:
        return '使用书籍模板提供的区域；没有区域时按整页处理。';
    }
  }

  void _submit() {
    _pageStart = int.tryParse(_pageStartController.text.trim());
    _pageEnd = int.tryParse(_pageEndController.text.trim());
    Navigator.of(context).pop(CropConfiguration(
      template: _template,
      layout: _layout,
      regions: _regions.map((region) => region.clamp()).toList(),
      pageStart: _pageStart,
      pageEnd: _pageEnd,
      inheritPrevious: _inheritPrevious,
      adjustment: CropAdjustment(left: _left, right: _right, top: _top, bottom: _bottom),
      sourceDocumentId: widget.initial.sourceDocumentId,
      temporarySessionId: widget.initial.temporarySessionId,
      createdAt: widget.initial.createdAt,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('裁剪设置'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPreview(context),
              const SizedBox(height: 8),
              Text('长按区域：切换参与/排除。排除区域保留分隔线，但不编号、不输出。', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              DropdownButtonFormField<CropTemplate>(
                value: _template,
                decoration: const InputDecoration(labelText: '裁剪模板'),
                items: const [
                  DropdownMenuItem(value: CropTemplate.single, child: Text('单栏')),
                  DropdownMenuItem(value: CropTemplate.doubleColumn, child: Text('双栏')),
                  DropdownMenuItem(value: CropTemplate.tripleColumn, child: Text('三栏')),
                  DropdownMenuItem(value: CropTemplate.custom, child: Text('自定义')),
                  DropdownMenuItem(value: CropTemplate.bookTemplate, child: Text('书籍模板')),
                ],
                onChanged: (value) { if (value != null) _selectTemplate(value); },
              ),
              const SizedBox(height: 6),
              Text(_templateDescription, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              DropdownButtonFormField<CropLayout>(
                value: _layout,
                decoration: const InputDecoration(labelText: '多区域排列'),
                items: const [
                  DropdownMenuItem(value: CropLayout.horizontal, child: Text('横向拼接')),
                  DropdownMenuItem(value: CropLayout.grid, child: Text('自动网格')),
                ],
                onChanged: (value) { if (value != null) setState(() => _layout = value); },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('套用上一页裁剪'),
                subtitle: const Text('下一页优先继承当前裁剪，再应用下面的增量调整'),
                value: _inheritPrevious,
                onChanged: (value) => setState(() => _inheritPrevious = value),
              ),
              Row(children: [
                Expanded(child: TextField(controller: _pageStartController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '起始页'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _pageEndController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '结束页'))),
              ]),
              const SizedBox(height: 16),
              Text('当前裁剪基础上的增量调整', style: Theme.of(context).textTheme.titleMedium),
              _buildAdjustmentSlider('左边', _left, (value) => setState(() => _left = value)),
              _buildAdjustmentSlider('右边', _right, (value) => setState(() => _right = value)),
              _buildAdjustmentSlider('上边', _top, (value) => setState(() => _top = value)),
              _buildAdjustmentSlider('下边', _bottom, (value) => setState(() => _bottom = value)),
              if (_template == CropTemplate.custom) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Text('自定义区域', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(tooltip: '添加区域', onPressed: _addRegion, icon: const Icon(Icons.add_box_outlined)),
                ]),
                if (_regions.isEmpty)
                  const Text('暂无区域，点击右侧 + 添加。')
                else
                  ...List.generate(_regions.length, (index) => _buildRegionEditor(index, _regions[index])),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('保存并应用')),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final regions = _previewRegions;
          var includedNumber = 0;
          return Stack(children: [
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border.all(color: Theme.of(context).dividerColor)))),
            ...regions.asMap().entries.map((entry) {
              final index = entry.key;
              final region = entry.value.clamp();
              final excluded = region.excluded;
              final number = excluded ? null : ++includedNumber;
              return Positioned(
                left: region.x * constraints.maxWidth,
                top: region.y * constraints.maxHeight,
                width: region.width * constraints.maxWidth,
                height: region.height * constraints.maxHeight,
                child: GestureDetector(
                  onLongPress: () => _toggleExcluded(index),
                  child: Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      border: Border.all(color: excluded ? Theme.of(context).colorScheme.outline : Theme.of(context).colorScheme.primary, width: 2),
                      color: excluded ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    ),
                    child: Stack(children: [
                      if (excluded) Positioned.fill(child: _CropHatch(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3))),
                      Center(child: Text(excluded ? '排除' : '区域 $number', style: TextStyle(fontWeight: FontWeight.w600, decoration: excluded ? TextDecoration.lineThrough : null))),
                    ]),
                  ),
                ),
              );
            }),
          ]);
        },
      ),
    );
  }

  Widget _buildAdjustmentSlider(String label, double value, ValueChanged<double> onChanged) {
    return Row(children: [
      SizedBox(width: 48, child: Text(label)),
      Expanded(child: Slider(value: value.clamp(-0.20, 0.20).toDouble(), min: -0.20, max: 0.20, divisions: 80, label: '${(value * 100).toStringAsFixed(1)}%', onChanged: onChanged)),
      SizedBox(width: 60, child: Text('${(value * 100).toStringAsFixed(1)}%')),
    ]);
  }

  Widget _buildRegionEditor(int index, CropRegion region) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          Row(children: [
            Text(region.excluded ? '排除区域' : '区域 $index'),
            const Spacer(),
            IconButton(tooltip: region.excluded ? '恢复区域' : '排除区域', onPressed: () => _toggleExcluded(index), icon: Icon(region.excluded ? Icons.check_box_outline_blank : Icons.block_outlined)),
            IconButton(tooltip: '删除区域', onPressed: () => _removeRegion(index), icon: const Icon(Icons.delete_outline)),
          ]),
          _buildRegionSlider('X', region.x, 0, 1, (value) => _updateRegion(index, CropRegion(x: value, y: region.y, width: region.width, height: region.height, excluded: region.excluded))),
          _buildRegionSlider('Y', region.y, 0, 1, (value) => _updateRegion(index, CropRegion(x: region.x, y: value, width: region.width, height: region.height, excluded: region.excluded))),
          _buildRegionSlider('宽', region.width, 0.01, 1, (value) => _updateRegion(index, CropRegion(x: region.x, y: region.y, width: value, height: region.height, excluded: region.excluded))),
          _buildRegionSlider('高', region.height, 0.01, 1, (value) => _updateRegion(index, CropRegion(x: region.x, y: region.y, width: region.width, height: value, excluded: region.excluded))),
        ]),
      ),
    );
  }

  Widget _buildRegionSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(children: [
      SizedBox(width: 32, child: Text(label)),
      Expanded(child: Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, divisions: 100, onChanged: onChanged)),
      SizedBox(width: 52, child: Text('${(value * 100).toStringAsFixed(0)}%')),
    ]);
  }
}

class _CropHatch extends StatelessWidget {
  final Color color;
  const _CropHatch({required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CropHatchPainter(color));
}

class _CropHatchPainter extends CustomPainter {
  final Color color;
  const _CropHatchPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    for (var offset = -size.height; offset < size.width; offset += 10) {
      canvas.drawLine(Offset(offset, 0), Offset(offset + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropHatchPainter oldDelegate) => oldDelegate.color != color;
}
