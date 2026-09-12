import 'package:flutter/material.dart';

import '../../domain/models/reader_settings.dart';
import '../../widgets/reader_unified_settings_panel.dart';
import '../models/epub_book.dart';

class EpubReaderSettingsSheet extends StatefulWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;
  final List<EpubNavItem> navigation;
  final int currentChapter;
  final ValueChanged<EpubNavItem>? onNavigationSelected;
  final VoidCallback? onBookmark;
  final VoidCallback? onNote;
  final VoidCallback? onAnnotations;
  final VoidCallback? onSearch;

  const EpubReaderSettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
    this.navigation = const [],
    this.currentChapter = 0,
    this.onNavigationSelected,
    this.onBookmark,
    this.onNote,
    this.onAnnotations,
    this.onSearch,
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
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .5,
        maxChildSize: .96,
        builder: (context, controller) => Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 38, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Expanded(
              child: ReaderUnifiedSettingsPanel(
                settings: _settings,
                onChanged: _update,
                navigation: widget.navigation,
                currentChapter: widget.currentChapter,
                onNavigationSelected: widget.onNavigationSelected,
                onBookmark: widget.onBookmark,
                onNote: widget.onNote,
                onAnnotations: widget.onAnnotations,
                onSearch: widget.onSearch,
                scrollController: controller,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
