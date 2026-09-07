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
import '../services/user_template_service.dart';
import '../widgets/reader_appearance_settings.dart';
import '../widgets/settings_category_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _templateService = BookTemplateService();
  final _userTemplateService = UserTemplateService();
  List<BookTemplate> _templates = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      await _templateService.loadAvailableTemplates();
      if (!mounted) return;
      setState(() {
        _templates = _templateService.templates;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
              child: Text('设置', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            SettingsSection(title: '阅读', children: [
              SettingsNavigationTile(icon: Icons.palette_outlined, title: '外观', subtitle: '主题、布局、画布与阅读界面', onTap: _openAppearance),
              SettingsNavigationTile(icon: Icons.menu_book_outlined, title: '阅读器', subtitle: '翻页、控件、目录与阅读行为', onTap: _openControls),
            ]),
            SettingsSection(title: '书库', children: [
              SettingsNavigationTile(icon: Icons.folder_outlined, title: '文件与存储', subtitle: '文件库位置与应用数据', onTap: _openStorage),
              SettingsNavigationTile(icon: Icons.style_outlined, title: '书籍模板', subtitle: '管理 BookTemplate 与默认配置', onTap: _openTemplates),
            ]),
            const SettingsSection(title: '关于', children: [
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('MedicalReader'),
                subtitle: Text('PDF 阅读、知识整理与医学文献管理 · 版本 1.5.0'),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
            ]),
          ],
        ),
      );

  Future<void> _openAppearance() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AppearancePage()));
  Future<void> _openControls() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ControlsPage()));
  Future<void> _openStorage() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _StoragePage()));
  Future<void> _openTemplates() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _TemplatesPage(
          templates: _templates,
          loading: _loading,
          onEdit: _editTemplate,
          onDelete: _deleteTemplate,
          onCreate: () => _editTemplate(),
        )));
    await _loadTemplates();
  }

  Future<void> _editTemplate([BookTemplate? source]) async {
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(source?.toJson() ?? {
        'id': 'my-medical-template', 'name': '我的医学书模板', 'version': '1.0.0',
        'description': '用户自定义模板', 'author': 'Me',
        'data': {'metadata': {'category': 'medical', 'language': 'zh-CN'}, 'aliases': <String>[], 'defaults': {
          'bookPageMapping': {'enabled': true, 'strategy': 'manual'},
          'searchContext': {'showContext': true, 'showChapter': true, 'showBookPage': true, 'contextBefore': 80, 'contextAfter': 120},
        }},
      }),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(source == null ? '创建自定义模板' : '编辑自定义模板'),
        content: SizedBox(width: 720, child: TextField(controller: controller, minLines: 18, maxLines: 28, keyboardType: TextInputType.multiline, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '在这里编辑完整 BookTemplate JSON'))),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () async {
            try {
              final decoded = jsonDecode(controller.text);
              if (decoded is! Map<String, dynamic>) throw const FormatException('模板根节点必须是 JSON 对象');
              final template = BookTemplate.fromJson(decoded);
              if (template.id.trim().isEmpty || template.name.trim().isEmpty) throw const FormatException('模板 id 和 name 不能为空');
              await _userTemplateService.save(template);
              if (c.mounted) Navigator.of(c).pop(true);
            } catch (e) {
              if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('模板 JSON 无效：$e')));
            }
          }, child: const Text('保存')),
        ],
      ),
    );
    controller.dispose();
    if (saved == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('模板已保存')));
  }

  Future<void> _deleteTemplate(BookTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确定删除“${template.name}”吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _userTemplateService.delete(template.id);
    await _loadTemplates();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已删除：${template.name}')));
  }
}

class _AppearancePage extends ConsumerWidget {
  const _AppearancePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(readerViewOptionsProvider);
    return SettingsCategoryPage(
      title: '外观',
      subtitle: '把主题、页面布局和控件显示拆成清晰的小组，避免一个“大设置面板”塞满整页。',
      children: [
        ReaderAppearanceSettings(
          options: options,
          onChanged: (value) => ref.read(readerViewOptionsProvider.notifier).update(value),
          onReset: () => ref.read(readerViewOptionsProvider.notifier).reset(),
        ),
      ],
    );
  }
}

class _ControlsPage extends ConsumerWidget {
  const _ControlsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(readerViewOptionsProvider);
    return SettingsCategoryPage(title: '阅读器', subtitle: '控制阅读时显示哪些操作，以及页面导航行为。', children: [
      SettingsSection(title: '阅读界面', children: [
        SwitchListTile.adaptive(title: const Text('显示页码控件'), subtitle: const Text('显示翻页与页码信息'), value: o.showPageControls, onChanged: (v) => ref.read(readerViewOptionsProvider.notifier).updatePartial(showPageControls: v)),
        SwitchListTile.adaptive(title: const Text('显示位置栏'), subtitle: const Text('显示当前阅读位置'), value: o.showLocationBar, onChanged: (v) => ref.read(readerViewOptionsProvider.notifier).updatePartial(showLocationBar: v)),
        SwitchListTile.adaptive(title: const Text('浮动控制栏'), subtitle: const Text('以浮动卡片形式显示工具栏'), value: o.floatingControls, onChanged: (v) => ref.read(readerViewOptionsProvider.notifier).updatePartial(floatingControls: v)),
      ]),
      SettingsSection(title: '工具', children: [
        SwitchListTile.adaptive(title: const Text('显示目录按钮'), value: o.showBookTreeButton, onChanged: (v) => ref.read(readerViewOptionsProvider.notifier).updatePartial(showBookTreeButton: v)),
        SwitchListTile.adaptive(title: const Text('显示搜索按钮'), value: o.showSearchButton, onChanged: (v) => ref.read(readerViewOptionsProvider.notifier).updatePartial(showSearchButton: v)),
        SwitchListTile.adaptive(title: const Text('显示跳页按钮'), value: o.showPageJumpButton, onChanged: (v) => ref.read(readerViewOptionsProvider.notifier).updatePartial(showPageJumpButton: v)),
      ]),
      SettingsSection(title: '恢复', children: [
        ListTile(leading: const Icon(Icons.restore), title: const Text('恢复阅读器默认设置'), subtitle: const Text('只恢复阅读器显示与控件配置'), onTap: () async {
          await ref.read(readerViewOptionsProvider.notifier).reset();
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已恢复默认设置')));
        }),
      ]),
    ]);
  }
}

class _StoragePage extends ConsumerWidget {
  const _StoragePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.read(libraryStorageServiceProvider);
    return SettingsCategoryPage(title: '文件与存储', children: [
      SettingsSection(title: '文件库', children: [
        FutureBuilder<Directory>(future: storage.getLibraryDirectory(), builder: (context, snapshot) => ListTile(
          leading: const Icon(Icons.folder_outlined), title: const Text('文件库路径'), subtitle: Text(snapshot.data?.path ?? '正在读取……'), trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final selected = await storage.pickLibraryDirectory();
            if (selected == null || !context.mounted) return;
            await ref.read(libraryProvider.notifier).reload();
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('文件库已切换到：${selected.path}')));
          },
        )),
      ]),
      SettingsSection(title: '应用数据', children: [
        FutureBuilder<Directory>(future: getApplicationSupportDirectory(), builder: (context, snapshot) => ListTile(leading: const Icon(Icons.storage_outlined), title: const Text('应用数据目录'), subtitle: Text(snapshot.data?.path ?? '正在读取……'))),
        FutureBuilder<Directory>(future: getTemporaryDirectory(), builder: (context, snapshot) => ListTile(leading: const Icon(Icons.cleaning_services_outlined), title: const Text('临时目录'), subtitle: Text(snapshot.data?.path ?? '正在读取……'))),
      ]),
    ]);
  }
}

class _TemplatesPage extends StatelessWidget {
  final List<BookTemplate> templates;
  final bool loading;
  final Future<void> Function([BookTemplate?]) onEdit;
  final Future<void> Function(BookTemplate) onDelete;
  final VoidCallback onCreate;

  const _TemplatesPage({required this.templates, required this.loading, required this.onEdit, required this.onDelete, required this.onCreate});

  @override
  Widget build(BuildContext context) => SettingsCategoryPage(title: '书籍模板', subtitle: '管理 BookTemplate。', children: [
        SettingsSection(title: '模板', children: [
          SettingsNavigationTile(icon: Icons.add_box_outlined, title: '创建自定义模板', subtitle: '直接编辑完整 BookTemplate JSON', onTap: onCreate),
          if (loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (templates.isEmpty) const ListTile(leading: Icon(Icons.info_outline), title: Text('暂无模板'))
          else ...templates.map((template) => ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(template.name),
                subtitle: Text(template.description ?? 'ID: ${template.id}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') await onEdit(template);
                    if (v == 'delete') await onDelete(template);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              )),
        ]),
      ]);
}
