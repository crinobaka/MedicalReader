import '../models/book_template.dart';

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
        'bookTree': <Map<String, dynamic>>[],
      },
    ),
  ];
}