import 'dart:io';

import 'package:flutter/material.dart';

import '../models/library_document.dart';

enum DocumentCardLayout { list, compact, grid }

class DocumentCard extends StatelessWidget {
  final LibraryDocument document;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onManageCollections;
  final DocumentCardLayout layout;

  const DocumentCard({super.key, required this.document, this.onTap, this.onDelete, this.onManageCollections, this.layout = DocumentCardLayout.list});

  @override
  Widget build(BuildContext context) => switch (layout) {
        DocumentCardLayout.grid => _buildGrid(context),
        DocumentCardLayout.compact => _buildCompact(context),
        DocumentCardLayout.list => _buildList(context),
      };

  Widget _buildList(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _Cover(document: document, width: 68, height: 92),
              const SizedBox(width: 14),
              Expanded(child: _Details(document: document)),
              _Menu(onDelete: onDelete, onManageCollections: onManageCollections),
            ]),
          ),
        ),
      );

  Widget _buildCompact(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: _Cover(document: document, width: 42, height: 56),
          title: Text(document.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(_metaText(), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: _Menu(onDelete: onDelete, onManageCollections: onManageCollections),
        ),
      );

  Widget _buildGrid(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.all(6),
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _Cover(document: document, width: double.infinity, height: double.infinity)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
              child: Row(children: [
                Expanded(child: Text(document.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                _Menu(onDelete: onDelete, onManageCollections: onManageCollections),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), child: Text(_metaText(), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );

  String _metaText() {
    final parts = <String>[];
    if (document.pages != null) parts.add('${document.pages} 页');
    parts.add(_formatSize(document.file.size));
    final author = document.metadata['author']?.toString().trim();
    if (author != null && author.isNotEmpty) parts.add(author);
    return parts.join(' · ');
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _Cover extends StatelessWidget {
  final LibraryDocument document;
  final double width;
  final double height;
  const _Cover({required this.document, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final cover = document.metadata['coverPath']?.toString();
    final file = cover == null || cover.isEmpty ? null : File(cover);
    final hasCover = file != null && file.existsSync();
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: hasCover
          ? Image.file(file, fit: BoxFit.cover)
          : Center(child: LayoutBuilder(builder: (context, constraints) => Icon(Icons.menu_book_rounded, size: constraints.biggest.shortestSide.clamp(24, 54).toDouble(), color: theme.colorScheme.primary))),
    );
  }
}

class _Details extends StatelessWidget {
  final LibraryDocument document;
  const _Details({required this.document});
  @override
  Widget build(BuildContext context) {
    final author = document.metadata['author']?.toString().trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(document.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      if (author != null && author.isNotEmpty) ...[const SizedBox(height: 4), Text(author, maxLines: 1, overflow: TextOverflow.ellipsis)],
      const SizedBox(height: 8),
      Text('${document.pages ?? '-'} 页 · ${_formatSize(document.file.size)}'),
      const SizedBox(height: 4),
      Text(document.file.path, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _Menu extends StatelessWidget {
  final VoidCallback? onDelete;
  final VoidCallback? onManageCollections;
  const _Menu({required this.onDelete, required this.onManageCollections});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'collections') onManageCollections?.call();
          if (value == 'delete') onDelete?.call();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'collections', child: Row(children: [Icon(Icons.folder_copy_outlined), SizedBox(width: 8), Text('整理到书架')])),
          PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline), SizedBox(width: 8), Text('删除')])),
        ],
      );
}
