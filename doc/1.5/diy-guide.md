# 1.5 DIY 指南

本指南把 MedicalReader 的“可改”范围说清楚。普通用户只需要改 JSON/运行 PS1；不需要修改 Dart。

## 1. UI 外观

编辑 `assets/ui/reader_theme.json`。

| 字段 | 类型 | 作用 |
|---|---|---|
| `preset` | string | `google`、`apple`、`github`、`custom` |
| `brightness` | string | `system`、`light`、`dark` |
| `canvas.background` | string | PDF 周边画布背景色 |
| `chrome.surface` | string | 浮动控件表面色 |
| `chrome.foreground` | string | 文字/图标色 |
| `chrome.accent` | string | 强调色、选中态 |
| `chrome.muted` | string | 次要文字 |
| `chrome.border` | string | 边框色 |
| `chrome.radius` | number | 容器圆角 |
| `chrome.buttonRadius` | number | 按钮圆角 |
| `chrome.elevation` | number | 浮层视觉层级 |
| `chrome.toolbarHeight` | number | 工具栏高度 |

颜色支持 `#RRGGBB` 或 `#AARRGGBB`。

## 2. 布局

`layout` 下的区域契约可以独立组合：

```text
layout
├── topBar
├── bottomBar
├── leftPanel
├── rightPanel
└── floatingControls
```

区域对象统一使用：

```json
{"visible": true, "collapsed": false, "overlay": true, "persistent": false}
```

这样未来增加阅读器控件时，不需要重新设计用户的主题文件。

## 3. 书籍模板

书籍模板放在 `assets/book_templates/`，运行：

```powershell
./tools/reader_template_generator.ps1 -OutputFile ./assets/book_templates/my_book.json
```

生成后可手工修改。模板至少应该包含 `id`、`name`、`version`、`data.aliases`、`data.defaults`。

## 4. 目录文件

推荐使用 UTF-8 文本 + 2 空格一级缩进。例如：

```text
第一章 基础
  1.1 解剖学 {pdf=12}
  1.2 生理学 {pdf=15-18}
第二章 临床
  2.1 病例 {book=30-55}
```

规则：

- 空行和 `#` 开头的行会被忽略。
- 每一级必须增加 2 个空格。
- `{pdf=N}` 或 `{pdf=N-M}` 指 PDF 页。
- `{book=N}` 或 `{book=N-M}` 指书籍页。
- 同一节点只建议使用一种页码基准，避免歧义。

生成：

```powershell
./tools/directory_generator.ps1 -InputFile ./directory.txt -OutputFile ./book.json
```

## 5. 图标

正式品牌源固定为 `assets/branding/favicon.ico`。

生成 Android/Windows 图标：

```powershell
./tools/generate_icons.ps1
```

脚本只负责调用 `flutter_launcher_icons`，不把平台图标尺寸硬编码进应用代码。

## 6. 安全护栏

DIY 文件是配置，不是 Dart 代码。不要在模板中放脚本、命令或动态表达式。未知字段应保留在文件中，但应用不得因为未知字段而崩溃。
