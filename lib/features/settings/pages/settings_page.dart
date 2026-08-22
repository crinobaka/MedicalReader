import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/file_manager/providers/file_manager_provider.dart';
import '../../library/providers/library_provider.dart';
import '../../reader/models/book_template.dart';
import '../../reader/providers/reader_view_options_provider.dart';
import '../../reader/services/book_template_service.dart';
import '../../reader/widgets/reader_settings_panel.dart';
import '../services/user_template_service.dart';

/// MedicalReader 设置页。
///
/// Commit 4 先把“真正能用”的设置基础设施落下来：
/// - 文件库路径查看与切换
/// - 应用数据目录查看
/// - 阅读器顶部/底部/搜索/目录/裁边等 UI 显示开关
/// - 阅读器设置恢复默认
/// - 官方/内置/用户书籍模板查看
/// - 用户模板 JSON 创建、编辑、删除
///
/// 这里不直接修改 ReaderPage 的布局逻辑，只通过已有的
/// ReaderViewOptionsProvider 修改显示配置，因此 Windows 和 Android
/// 共用同一套设置协议。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final BookTemplateService _templateService = BookTemplateService();
  final UserTemplateService _userTemplateService = UserTemplateService();

  List<BookTemplate> _templates = const [];
  bool _templatesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    await _templateService.loadAvailableTemplates();

    if (!mounted) {
      return;
    }

    setState(() {
      _templates = _templateService.templates;
      _templatesLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.read(libraryStorageServiceProvider);
    final readerOptions = ref.watch(readerViewOptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildSectionTitle('文件与存储'),
          const SizedBox(height: 8),
          Card(
            child: FutureBuilder<Directory>(
              future: storage.getLibraryDirectory(),
              builder: (context, snapshot) {
                final path = snapshot.data?.path ?? '正在读取……';

                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('文件库路径'),
                  subtitle: Text(path),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _changeLibraryDirectory(storage),
                );
              },
            ),
          ),
          Card(
            child: FutureBuilder<Directory>(
              future: getApplicationSupportDirectory(),
              builder: (context, snapshot) {
                return ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('应用数据目录'),
                  subtitle: Text(
                    snapshot.data?.path ?? '正在读取……',
                  ),
                );
              },
            ),
          ),
          Card(
            child: FutureBuilder<Directory>(
              future: getTemporaryDirectory(),
              builder: (context, snapshot) {
                return ListTile(
                  leading: const Icon(Icons.cleaning_services),
                  title: const Text('临时目录'),
                  subtitle: Text(
                    snapshot.data?.path ?? '正在读取……',
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('阅读器显示'),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ReaderSettingsPanel(
              options: readerOptions,
              onChanged: (options) {
                ref
                    .read(readerViewOptionsProvider.notifier)
                    .update(options);
              },
              onReset: () async {
                await ref
                    .read(readerViewOptionsProvider.notifier)
                    .reset();

                if (!mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('阅读器显示设置已恢复默认值'),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('书籍模板'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.add_box),
                  title: const Text('创建自定义模板'),
                  subtitle: const Text(
                    '直接编辑 BookTemplate JSON，保存后 Reader 下次打开书籍即可使用',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editTemplate(),
                ),
                const Divider(height: 1),
                if (_templatesLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  )
                else if (_templates.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('暂无模板'),
                  )
                else
                  ..._templates.map(_buildTemplateTile),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('应用'),
          const SizedBox(height: 8),
          Card(
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('MedicalReader'),
              subtitle: Text(
                'PDF 阅读、知识整理与医学文献管理\n版本 1.0.0',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTemplateTile(BookTemplate template) {
    return FutureBuilder<bool>(
      future: _userTemplateService.getDirectory().then(
        (directory) => File(
          '${directory.path}${Platform.pathSeparator}${template.id}.json',
        ).exists(),
      ),
      builder: (context, snapshot) {
        final isUserTemplate = snapshot.data == true;

        return ListTile(
          leading: Icon(
            isUserTemplate ? Icons.edit_note : Icons.menu_book,
          ),
          title: Text(template.name),
          subtitle: Text(
            [
              if (template.description != null) template.description!,
              'ID: ${template.id}',
              if (isUserTemplate) '用户模板' else '内置/官方模板',
            ].join('\n'),
          ),
          isThreeLine: true,
          trailing: isUserTemplate
              ? PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await _editTemplate(template);
                    } else if (value == 'delete') {
                      await _deleteTemplate(template);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('编辑'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('删除'),
                    ),
                  ],
                )
              : IconButton(
                  tooltip: '复制为自定义模板',
                  icon: const Icon(Icons.copy),
                  onPressed: () => _editTemplate(template),
                ),
        );
      },
    );
  }

  Future<void> _changeLibraryDirectory(dynamic storage) async {
    final selected = await storage.pickLibraryDirectory();

    if (selected == null || !mounted) {
      return;
    }

    await ref.read(libraryProvider.notifier).reload();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('文件库已切换到：${selected.path}'),
      ),
    );

    setState(() {});
  }

  Future<void> _editTemplate([BookTemplate? source]) async {
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(
        source?.toJson() ??
            {
              'id': 'my-medical-template',
              'name': '我的医学书模板',
              'version': '1.0.0',
              'description': '用户自定义模板',
              'author': 'Me',
              'data': {
                'metadata': {
                  'category': 'medical',
                  'language': 'zh-CN',
                },
                'aliases': <String>[],
                'defaults': {
                  'bookPageMapping': {
                    'enabled': true,
                    'strategy': 'manual',
                  },
                  'searchContext': {
                    'showContext': true,
                    'showChapter': true,
                    'showBookPage': true,
                    'contextBefore': 80,
                    'contextAfter': 120,
                  },
                },
              },
            },
      ),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            source == null ? '创建自定义模板' : '编辑自定义模板',
          ),
          content: SizedBox(
            width: 720,
            child: TextField(
              controller: controller,
              minLines: 18,
              maxLines: 28,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '在这里编辑完整 BookTemplate JSON',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final decoded = jsonDecode(controller.text);

                  if (decoded is! Map<String, dynamic>) {
                    throw const FormatException('模板根节点必须是 JSON 对象');
                  }

                  final template = BookTemplate.fromJson(decoded);

                  if (template.id.trim().isEmpty ||
                      template.name.trim().isEmpty) {
                    throw const FormatException('模板 id 和 name 不能为空');
                  }

                  await _userTemplateService.save(template);

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } catch (error) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('模板 JSON 无效：$error'),
                    ),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (saved == true) {
      await _loadTemplates();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('模板已保存到应用数据目录'),
        ),
      );
    }
  }

  Future<void> _deleteTemplate(BookTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除模板'),
          content: Text('确定删除“${template.name}”吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _userTemplateService.delete(template.id);
    await _loadTemplates();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除用户模板：${template.name}'),
      ),
    );
  }
}
