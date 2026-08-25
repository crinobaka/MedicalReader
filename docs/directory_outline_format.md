# MedicalReader 目录缩进文件规范 v1

目录生成器接受普通 UTF-8 文本。

- 每层固定使用 2 个空格缩进。
- 一行一个目录节点。
- 空行和 # 开头的行会被忽略。
- 行尾可使用 `{pdf=1-20,book=1-18}` 提供页码范围。
- pdf 是 1-based PDF 物理页；book 是 1-based 书籍印刷页。
- 只写单个数字等同于单页范围。

示例：

```text
绪论 {pdf=1-8,book=1-6}
  背景 {pdf=2-3}
  方法 {pdf=4-8,book=2-6}
第一章 基础
  第一节 概念 {pdf=9-18,book=7-16}
    定义 {pdf=10-12}
    分类 {pdf=13-18}
第二章 临床
  症状 {pdf=19-30,book=17-28}
  诊断 {pdf=31-45,book=29-43}
```

生成：

```powershell
dart run tools/directory_generator.dart outline.txt book.json
```

无页码节点仍然合法，会作为纯结构节点保存，并由有页码的子节点提供定位能力。
