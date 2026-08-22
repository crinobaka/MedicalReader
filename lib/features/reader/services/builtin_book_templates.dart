import '../models/book_template.dart';

/// 代码级 fallback。
///
/// 正常情况下官方模板来自 assets/book_templates/*.json。
/// 只有官方模板资源加载失败时才使用这里。
List<BookTemplate> buildBuiltinBookTemplates() {
  return const [
    BookTemplate(
      id: 'generic-medical-book',
      name: '通用医学专业书籍',
      version: '1.0.0',
      description: 'MedicalReader 通用医学专业书籍官方基础模板。',
      author: 'MedicalReader',
      data: {
        'metadata': {
          'category': 'medical',
          'language': 'zh-CN',
        },
        'aliases': [
          '内科学',
          '外科学',
          '诊断学',
          '病理学',
          '药理学',
        ],
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
          'crop': {
            'template': 'single',
            'layout': 'horizontal',
            'regions': [],
            'inheritPrevious': false,
            'adjustment': {
              'left': 0,
              'right': 0,
              'top': 0,
              'bottom': 0,
            },
          },
        },
      },
    ),
  ];
}
