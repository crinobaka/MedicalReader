# MedicalReader UI / UX 原则

本项目的默认界面以“拿起来就会用”为验收标准，而不是“功能存在”。

## 1. 单一、明确的滚动区域

- 一个纵向内容区域只保留一个主要纵向 ScrollView。
- 不要求用户去寻找边缘、滚动条或特定空白区才能拖动。
- 设置、目录、笔记列表等长内容优先使用标准列表滚动。
- 不用自定义手势替代系统已有的滚动手势。

依据：Apple HIG 建议支持系统默认滚动手势，并避免同方向嵌套 ScrollView；Flutter 的 DraggableScrollableSheet 也要求把它提供的 ScrollController 交给实际 ScrollView。

## 2. 设置遵循“列表 + 详情”的心智模型

手机屏幕窄时，设置优先按类别进入下一层；大屏再使用双栏或 list-detail。不要把几十项设置压成一张巨长表单。

类别应回答“我想改哪一类东西”，详情页才回答“具体怎么改”。每一项尽量提供标题 + 简短说明，避免只放图标或神秘开关。

## 3. 默认值优先，自定义其次

默认配置必须适合大多数人。DIY 接口提供自由度，但不能把开发者配置项直接暴露给普通用户。

原则：

1. 第一次打开，不需要读教程也能开始阅读。
2. 高级设置不会干扰主任务。
3. 自定义不会破坏默认交互模型。

## 4. 三种主题不是换颜色

- Google：Material 层级、较明显的主色、圆润控件、适中的密度。
- Apple：轻量表面、更多留白、柔和圆角、弱边框。
- GitHub：紧凑密度、明确边框、低阴影、适合桌面长时间使用。

主题只改变阅读器周边 chrome，不改变 PDF 正文，避免“换主题导致内容不可读”。

## 5. 阅读优先

阅读器的主要内容永远是 PDF。工具栏、页码、设置、注释等属于 supporting UI，应尽量浮在内容上方或在需要时出现，而不是永久占据正文空间。

## 6. 熟悉的交互优先

- 返回使用标准返回/关闭。
- 搜索使用常见搜索图标与 Ctrl+F。
- 书签用明显的未选中/已选中状态。
- 设置项使用标题、摘要、控件三段式结构。
- 手机使用触摸习惯；桌面使用鼠标、滚轮和键盘习惯。

## 7. 参考资料

- Apple Human Interface Guidelines — Scroll Views / Accessibility / Design Principles
- Android Developers — Settings / Adaptive UI / List-detail
- GitHub Primer — Layout / Navigation / Responsive foundations
- Flutter API — DraggableScrollableSheet / Scrollable

这些资料不是要求 MedicalReader 复制某家公司，而是用来约束“不要让用户学习一套本来没有必要的新操作”。
