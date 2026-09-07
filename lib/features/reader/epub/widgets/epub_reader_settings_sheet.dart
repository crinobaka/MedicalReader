import 'package:flutter/material.dart';

import '../../domain/models/reader_settings.dart';

class EpubReaderSettingsSheet extends StatefulWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  const EpubReaderSettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<EpubReaderSettingsSheet> createState() => _EpubReaderSettingsSheetState();
}

class _EpubReaderSettingsSheetState extends State<EpubReaderSettingsSheet> {
  late ReaderSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _update(ReaderSettings value) {
    setState(() => _settings = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 18),
            const Text('阅读设置', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            _label('主题'),
            SegmentedButton<ReaderTheme>(
              segments: const [
                ButtonSegment(value: ReaderTheme.system, label: Text('系统')),
                ButtonSegment(value: ReaderTheme.light, label: Text('浅色')),
                ButtonSegment(value: ReaderTheme.dark, label: Text('深色')),
                ButtonSegment(value: ReaderTheme.sepia, label: Text('护眼')),
              ],
              selected: {_settings.theme},
              onSelectionChanged: (value) => _update(_settings.copyWith(theme: value.first)),
            ),
            const SizedBox(height: 18),
            _slider('字号', _settings.fontSize, 12, 30, (v) => _update(_settings.copyWith(fontSize: v))),
            _slider('行高', _settings.lineHeight, 1, 2.4, (v) => _update(_settings.copyWith(lineHeight: v))),
            _slider('段落间距', _settings.paragraphSpacing, 0, 32, (v) => _update(_settings.copyWith(paragraphSpacing: v))),
            _slider('左右边距', _settings.horizontalPadding, 8, 56, (v) => _update(_settings.copyWith(horizontalPadding: v))),
            _slider('上下边距', _settings.verticalPadding, 8, 48, (v) => _update(_settings.copyWith(verticalPadding: v))),
            const SizedBox(height: 8),
            _label('阅读方向'),
            SegmentedButton<ReaderReadingDirection>(
              segments: const [
                ButtonSegment(value: ReaderReadingDirection.ltr, label: Text('从左到右')),
                ButtonSegment(value: ReaderReadingDirection.rtl, label: Text('从右到左')),
                ButtonSegment(value: ReaderReadingDirection.vertical, label: Text('竖排')),
              ],
              selected: {_settings.readingDirection},
              onSelectionChanged: (value) => _update(_settings.copyWith(readingDirection: value.first)),
            ),
            const SizedBox(height: 18),
            _label('阅读模式'),
            SegmentedButton<ReaderReadingMode>(
              segments: const [
                ButtonSegment(value: ReaderReadingMode.paginated, label: Text('分页')),
                ButtonSegment(value: ReaderReadingMode.continuous, label: Text('连续')),
              ],
              selected: {_settings.readingMode},
              onSelectionChanged: (value) => _update(_settings.copyWith(readingMode: value.first)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label  ${value.toStringAsFixed(label == '行高' ? 1 : 0)}'),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
