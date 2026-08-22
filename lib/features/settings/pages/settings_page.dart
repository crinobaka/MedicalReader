import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/file_manager/providers/file_manager_provider.dart';
import '../../library/providers/library_provider.dart';

class SettingsPage
    extends ConsumerWidget {
  const SettingsPage({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final storage =
        ref.read(
          libraryStorageServiceProvider,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '设置',
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          const Text(
            '文件管理',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: FutureBuilder<Directory>(
              future:
                  storage.getLibraryDirectory(),
              builder: (
                context,
                snapshot,
              ) {
                final path =
                    snapshot.data?.path ??
                        '正在读取……';

                return ListTile(
                  leading: const Icon(
                    Icons.folder,
                  ),
                  title: const Text(
                    '文件库路径',
                  ),
                  subtitle: Text(
                    path,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () async {
                    final selected =
                        await storage
                            .pickLibraryDirectory();

                    if (selected == null) {
                      return;
                    }

                    await ref
                        .read(
                          libraryProvider
                              .notifier,
                        )
                        .reload();

                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            '文件库已切换到：${selected.path}',
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Reader UI',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(
                Icons.menu_book,
              ),
              title: const Text(
                '阅读器显示设置',
              ),
              subtitle: const Text(
                '顶部位置、页码栏、搜索、目录等',
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: () {
                _showReaderOptions(
                  context,
                  ref,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showReaderOptions(
    BuildContext context,
    WidgetRef ref,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Reader UI 设置将在 Commit 4 中继续接入。\n\n'
            'Commit 3 先完成 Library 文件管理和路径管理。',
          ),
        );
      },
    );
  }
}