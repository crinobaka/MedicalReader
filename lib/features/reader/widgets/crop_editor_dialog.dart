import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/crop_configuration.dart';
import '../services/crop_engine_service.dart';
import 'crop_region_canvas.dart';

/// 图形化裁剪编辑器。
///
/// 区域可以直接拖动、调整大小；长按区域切换参与/排除。
/// 排除区域保留分隔几何信息，但不会参与最终编号和输出。
class CropEditorDialog extends StatefulWidget {
  final CropConfiguration initial;
  final ui.Image? previewImage;

  const CropEditorDialog({
    super.key,
    required this.initial,
    this.previewImage,
  });

  @override
  State<CropEditorDialog> createState() => _CropEditorDialogState();
}

class _CropEditorDialogState extends State<CropEditorDialog> {
  final CropEngineService _engine = const CropEngineService();

  late CropTemplate _template;
  late CropLayout _layout;
  late CropPageBasis _pageBasis;
  late bool _inheritPrevious;
  late double _left;
  late double _right;
  late double _top;
  late double _bottom;
  late int? _pageStart;
  late int? _pageEnd;
  late List<CropPageRange> _pageRanges;
  late List<CropRegion> _regions;

  final _pageStartController = TextEditingController();
  final _pageEndController = TextEditingController();
  final _pageRangesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    _template = value.template;
    _layout = value.layout;
    _pageBasis = value.pageBasis;
    _inheritPrevious = value.inheritPrevious;
    _left = value.adjustment.left;
    _right = value.adjustment.right;
    _top = value.adjustment.top;
    _bottom = value.adjustment.bottom;
    _pageStart = value.pageStart;
    _pageEnd = value.pageEnd;
    _pageRanges = List.of(value.pageRanges);
    _regions = List.of(value.regions);
    _pageStartController.text = value.pageStart?.toString() ?? '';
    _pageEndController.text = value.pageEnd?.toString() ?? '';
    _pageRangesController.text =
        value.pageRanges.map((range) => range.label).join(', ');
  }

  @override
  void dispose() {
    _pageStartController.dispose();
    _pageEndController.dispose();
    _pageRangesController.dispose();
    super.dispose();
  }

  void _selectTemplate(CropTemplate value) {
    setState(() {
      _template = value;
      _regions = List.of(_engine.defaultRegions(value));
    });
  }

  void _materializeRegions() {
    if (_regions.isEmpty) {
      _regions = List.of(_engine.defaultRegions(_template));
    }
  }

  void _toggleExcluded(int index) {
    setState(() {
      _materializeRegions();
      _template = CropTemplate.custom;
      _regions[index] =
          _regions[index].copyWith(excluded: !_regions[index].excluded);
    });
  }

  void _addRegion() {
    setState(() {
      _regions = [
        ..._regions,
        const CropRegion(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
      ];
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
    final regions =
        _regions.isNotEmpty ? _regions : _engine.defaultRegions(_template);
    return regions
        .map(
          (region) => region.adjust(
            CropAdjustment(
              left: _left,
              right: _right,
              top: _top,
              bottom: _bottom,
            ),
          ),
        )
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
        return '直接拖动矩形调整位置和大小；长按切换参与/排除。';
      case CropTemplate.bookTemplate:
        return '使用书籍模板提供的区域；没有区域时按整页处理。';
    }
  }

  List<CropPageRange> _parseRanges(String text) {
    final result = <CropPageRange>[];
    for (final token in text.split(',')) {
      final value = token.trim();
      if (value.isEmpty) continue;
      final parts = value.split(RegExp(r'[-~:]'));
      final start = int.tryParse(parts.first.trim());
      if (start == null || start <= 0) continue;
      final end = parts.length > 1 ? int.tryParse(parts[1].trim()) : start;
      if (end == null || end <= 0) continue;
      result.add(CropPageRange(
        start: start < end ? start : end,
        end: start < end ? end : start,
      ));
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  void _submit() {
    _pageStart = int.tryParse(_pageStartController.text.trim());
    _pageEnd = int.tryParse(_pageEndController.text.trim());
    _pageRanges = _parseRanges(_pageRangesController.text);

    Navigator.of(context).pop(
      CropConfiguration(
        template: _template,
        layout: _layout,
        regions: _regions.map((region) => region.clamp()).toList(),
        pageStart: _pageStart,
        pageEnd: _pageEnd,
        pageBasis: _pageBasis,
        pageRanges: _pageRanges,
        inheritPrevious: _inheritPrevious,
        adjustment: CropAdjustment(
          left: _left,
          right: _right,
          top: _top,
          bottom: _bottom,
        ),
        sourceDocumentId: widget.initial.sourceDocumentId,
        temporarySessionId: widget.initial.temporarySessionId,
        createdAt: widget.initial.createdAt,
      ),
    );
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
              SizedBox(
                height: 300,
                width: double.infinity,
                child: CropRegionCanvas(
                  image: widget.previewImage,
                  regions: _previewRegions,
                  onLongPressRegion: _toggleExcluded,
                  onChanged: _updateRegion,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '拖动区域移动，拖动右下角调整大小；长按区域切换参与/排除。排除区域保留分隔线，但不编号、不输出。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CropTemplate>(
                initialValue: _template,
                decoration: const InputDecoration(labelText: '裁剪模板'),
                items: const [
                  DropdownMenuItem(value: CropTemplate.single, child: Text('单栏')),
                  DropdownMenuItem(value: CropTemplate.doubleColumn, child: Text('双栏')),
                  DropdownMenuItem(value: CropTemplate.tripleColumn, child: Text('三栏')),
                  DropdownMenuItem(value: CropTemplate.custom, child: Text('自定义')),
                  DropdownMenuItem(value: CropTemplate.bookTemplate, child: Text('书籍模板')),
                ],
                onChanged: (value) {
                  if (value != null) _selectTemplate(value);
                },
              ),
              const SizedBox(height: 6),
              Text(_templateDescription,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              DropdownButtonFormField<CropLayout>(
                initialValue: _layout,
                decoration: const InputDecoration(labelText: '多区域排列'),
                items: const [
                  DropdownMenuItem(value: CropLayout.horizontal, child: Text('横向拼接')),
                  DropdownMenuItem(value: CropLayout.grid, child: Text('自动网格')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _layout = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CropPageBasis>(
                initialValue: _pageBasis,
                decoration: const InputDecoration(labelText: '页码依据'),
                items: const [
                  DropdownMenuItem(value: CropPageBasis.pdf, child: Text('PDF 页码')),
                  DropdownMenuItem(value: CropPageBasis.book, child: Text('书籍页码')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _pageBasis = value);
                },
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _pageRangesController,
                decoration: const InputDecoration(
                  labelText: '指定组合页（可选）',
                  hintText: '例如 12-15, 30-55, 80',
                  helperText: '填写后优先使用这些范围；支持 PDF 页或书籍页。',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('套用上一页裁剪'),
                subtitle: const Text('下一页优先继承当前裁剪，再应用下面的增量调整'),
                value: _inheritPrevious,
                onChanged: (value) => setState(() => _inheritPrevious = value),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pageStartController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '起始页'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _pageEndController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '结束页'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('当前裁剪基础上的增量调整',
                  style: Theme.of(context).textTheme.titleMedium),
              _buildAdjustmentSlider('左边', _left, (value) => setState(() => _left = value)),
              _buildAdjustmentSlider('右边', _right, (value) => setState(() => _right = value)),
              _buildAdjustmentSlider('上边', _top, (value) => setState(() => _top = value)),
              _buildAdjustmentSlider('下边', _bottom, (value) => setState(() => _bottom = value)),
              if (_template == CropTemplate.custom) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('自定义区域',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      tooltip: '添加区域',
                      onPressed: _addRegion,
                      icon: const Icon(Icons.add_box_outlined),
                    ),
                  ],
                ),
                if (_regions.isEmpty)
                  const Text('暂无区域，点击右侧 + 添加。')
                else
                  ...List.generate(
                    _regions.length,
                    (index) => _buildRegionEditor(index, _regions[index]),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存并应用')),
      ],
    );
  }

  Widget _buildAdjustmentSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(-0.20, 0.20).toDouble(),
            min: -0.20,
            max: 0.20,
            divisions: 80,
            label: '${(value * 100).toStringAsFixed(1)}%',
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 60, child: Text('${(value * 100).toStringAsFixed(1)}%')),
      ],
    );
  }

  Widget _buildRegionEditor(int index, CropRegion region) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Text(region.excluded ? '排除区域' : '区域 ${index + 1}'),
                const Spacer(),
                IconButton(
                  tooltip: region.excluded ? '恢复区域' : '排除区域',
                  onPressed: () => _toggleExcluded(index),
                  icon: Icon(
                    region.excluded
                        ? Icons.check_box_outline_blank
                        : Icons.block_outlined,
                  ),
                ),
                IconButton(
                  tooltip: '删除区域',
                  onPressed: () => _removeRegion(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            _buildRegionSlider('X', region.x, 0, 1, (value) => _updateRegion(
                  index,
                  region.copyWith(x: value),
                )),
            _buildRegionSlider('Y', region.y, 0, 1, (value) => _updateRegion(
                  index,
                  region.copyWith(y: value),
                )),
            _buildRegionSlider('宽', region.width, 0.01, 1, (value) => _updateRegion(
                  index,
                  region.copyWith(width: value),
                )),
            _buildRegionSlider('高', region.height, 0.01, 1, (value) => _updateRegion(
                  index,
                  region.copyWith(height: value),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 32, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 52, child: Text('${(value * 100).toStringAsFixed(0)}%')),
      ],
    );
  }
}
