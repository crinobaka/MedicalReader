# MedicalReader UI 大重构 · 功能保全与映射方案

## 0. 重构原则

本次不是“重新做一个 PDF 阅读器”，而是对现有 MedicalReader 做功能保全式 UI 重构。

设计规范负责“怎么呈现”，现有业务能力负责“呈现什么”。Theme 可以整体重做；布局、颜色、图标、动效、密度都允许重构，但已有阅读、搜索、定位、目录、标注、手绘、裁剪、模板、统计、书库等能力不能因为换 UI 而消失。

来源基础：
- 当前 main 分支代码结构。
- 《继续完善手绘功能》中的 Book → Document → Position → Reader Runtime → Annotation 方向，以及 PDF/EPUB 双 Runtime、semantic locator、统一 Reader 上层模型规划。

## 1. 当前功能资产地图

### 1.1 App / 一级入口

当前 MainShell 已存在：
- 首页
- 书库
- 搜索
- 知识
- 设置
- 小屏使用底部 NavigationBar，大屏使用 NavigationRail。

保全要求：
- “知识”属于现有能力，不因为新的四项底部导航视觉规范而直接删除。
- UI 重构阶段保持五项能力可达；后续可把知识能力重新归入信息架构，但必须先有替代入口再调整一级导航。

### 1.2 首页

现有能力：
- 最近阅读。
- 继续阅读。
- 书库入口。
- 阅读统计入口。
- 批注库入口。
- 同步与备份状态说明。
- 阅读进度展示。
- PDF / EPUB 类型展示。
- 空书库引导。

新 UI 映射：
- 首页成为“阅读工作台”。
- 最近阅读 → 横向/响应式卡片。
- 继续阅读 → 第一优先级内容。
- 阅读统计、批注库、同步备份 → 功能入口卡片。
- 不删除现有入口，只改变视觉层级和布局。

### 1.3 书库

现有能力：
- PDF / EPUB 导入。
- 文件库路径。
- 书架分类/Collection。
- 最近阅读/最近添加/标题/进度/页数/文件大小排序。
- 详细列表/紧凑列表/网格。
- 删除书籍。
- 刷新。
- 打开 Reader。

新 UI 映射：
- 书库采用统一 Book Card。
- L 断点保留高效双栏/网格。
- 导入作为主要动作。
- 分类、排序、视图切换进入顶部操作区。
- 不删除现有三种视图能力。

### 1.4 PDF Reader

现有核心能力：
- PDF 页面渲染。
- 上一页/下一页。
- 首页/末页。
- 页码跳转。
- 书籍页码跳转。
- 目录/BookTree。
- 搜索。
- 搜索命中高亮。
- 书签。
- 笔记。
- 页面裁剪。
- 页面布局：单页/双页/三页。
- 页面缩放。
- 长按放大镜。
- 手写层。
- 手写笔/高亮相关 Annotation。
- Ink 橡皮擦。
- 阅读位置持久化。
- BookTemplate / BookPageMapping。
- PageBlock 模式。
- 页面块编辑、移动、缩放、排序。
- 页面块自适应布局。
- 页面块导航。
- 页面块滚动位置持久化。
- 录音、图片附件、笔记附件。
- Annotation 列表。
- 阅读统计。
- Reader Settings。

新 UI 映射：
- Reader Chrome 固定为 TopBar + Content + BottomBar。
- PDF Renderer 不承担 UI Chrome。
- 手写不作为普通“装饰按钮”，而作为 Reader 的编辑工具状态。
- PageBlock 作为独立阅读模式入口，进入后仍保留返回原页能力。
- 裁剪属于 PDF 能力，不从 UI 中删除。
- 书签/笔记/高亮统一进入 Annotation 工作流。

### 1.5 EPUB Reader

现有能力：
- EPUB archive / chapter。
- OPF / manifest / spine / navigation 基础模型。
- WebView Runtime。
- XHTML/CSS/资源渲染。
- 分页 / continuous。
- LTR / RTL / vertical。
- 页面位置恢复。
- semantic progress。
- 文本选择。
- selection context。
- 字典查询。
- 高亮。
- 目录。
- 书签。
- 笔记。
- Annotation 列表。
- Anki mining 接口。
- media bridge。
- chapter boundary。
- HOSHI compatibility。
- 原生 WebView 分页运行时。

新 UI 映射：
- EPUB 与 PDF 共用 Reader Chrome。
- EPUB Runtime 继续独立，不把 HTML 内容重新搬到 Flutter 排版。
- Position / Locator 作为业务定位基础。
- 主题、字体、行距、阅读方向等属于 Reader Experience，不破坏 runtime。

### 1.6 搜索

现有能力：
- PDF 全文搜索。
- contextBefore/contextAfter。
- 搜索命中次数。
- 章节路径。
- 书籍页 / PDF 页。
- 裁剪区域结果。
- 当前页标记。
- 搜索结果回跳。
- BookTemplate searchContext。

新 UI 映射：
- 搜索框固定。
- 候选结果整行点击。
- 完全匹配 > 部分匹配 > 相关章节。
- 现有 chapter / page / region / context 信息保留。
- 后续可把搜索模型升级为 ReaderSearchHit + Locator，但当前搜索能力不删除。

### 1.7 目录 / BookTree

现有能力：
- 树形节点。
- 自动展开当前路径。
- 章节页码。
- PDF 页码 / 书籍页码。
- 编辑目录。
- 点击节点跳转。
- EPUB navigation → spine 绑定。

新 UI 映射：
- 目录成为 Reader 的一级上下文面板。
- 每级缩进 16u。
- 整行可点。
- L 断点可变为侧栏。
- 编辑能力保留。

### 1.8 Selection / Dictionary / Mining

现有能力：
- 原生文本选择。
- selectedText。
- sentence。
- href。
- start/end offset。
- textQuote/prefix/suffix。
- DictionaryEntry。
- DictionaryRegistry。
- 高亮。
- Anki Card Draft。
- Anki 服务接口。

新 UI 映射：
- Selection Context Sheet。
- 高亮是第一类操作。
- 查词是第一类操作。
- Anki 作为词条后续动作。
- 不把选词能力降级为普通全局搜索。

### 1.9 Annotation

现有能力：
- bookmark。
- note。
- highlight。
- tag。
- ink。
- PDF locator。
- EPUB locator。
- 文本引用上下文。
- Annotation 持久化。
- Annotation 列表。
- 跳转到 Annotation。

新 UI 映射：
- 统一 Annotation Center。
- Reader 内用轻量 contextual action。
- 独立页面负责浏览、筛选和跳转。
- PDF/EPUB 定位模型继续分开实现，但 UI 使用统一语言。

### 1.10 手绘 / Ink

现有能力：
- 普通 ink stroke。
- typed ink stroke。
- pen/highlighter/eraser。
- 标准化坐标。
- 页面级保存。
- 橡皮擦按线段邻近删除。
- PageBlock 模式下仍可保留页面身份。
- 手绘作为 AnnotationType.ink。

新 UI 映射：
- Reader 中进入“手绘状态”。
- 工具条提供笔、荧光、橡皮擦、退出。
- 手写层不参与普通翻页手势。
- Ink 数据继续使用 normalized coordinates，不因视觉重构改变数据格式。

### 1.11 PageBlock / 阅读块

现有能力：
- 默认四块。
- 自适应分块。
- 手工分块。
- 块排序。
- 块移动。
- 块缩放。
- 块导航。
- 当前块。
- 块内滚动。
- 预取。
- 手工块持久化。
- 关闭模式后返回原 PDF 页。

新 UI 映射：
- 定义为“阅读块模式”，而非普通页面布局。
- 入口放入 Reader 工具菜单。
- 模式内采用编辑器式 UI。
- 块编号、选中状态、拖拽手柄遵守 48u 热区。
- 不改变 PageBlock 数据和导航语义。

### 1.12 裁剪 / BookTemplate

现有能力：
- CropConfiguration。
- 页面裁剪。
- 可视化 Crop Editor。
- BookTemplate。
- 用户自定义模板。
- 搜索上下文配置。
- BookPageMapping。

新 UI 映射：
- 裁剪归入“页面工具”。
- 模板归入“书籍/阅读规则”。
- BookTemplate 不与主题 Token 混淆。

### 1.13 设置

现有能力：
- ReaderSettings。
- ReaderViewOptions bridge。
- 外观。
- Reader controls。
- 页面布局。
- 工具栏位置。
- 画布。
- 目录/搜索/页码入口显示。
- 浮动控件。
- 自定义模板。
- 文件与存储。

新 UI 映射：
- 设置重新按“阅读体验 / 阅读工具 / 书库 / 数据 / 关于”组织。
- Theme 可以彻底重做。
- 现有配置字段继续兼容。

## 2. 数据与架构保全契约

### 必须保留

- LibraryDocument 现有数据兼容。
- ReaderPosition。
- ReaderLocator。
- PdfReaderLocator。
- EpubReaderLocator。
- ReaderSettings 持久化。
- ReaderViewOptions bridge。
- Annotation 数据。
- Ink 数据。
- BookTree。
- BookPageMapping。
- BookTemplate。
- SearchContext。
- PageBlock 数据。
- PDF Renderer。
- EPUB WebView Runtime。
- HOSHI compatibility layer。
- 阅读进度恢复。

### 可以大改

- Theme。
- AppBar / Toolbar 外观。
- BottomBar。
- Search UI。
- Card。
- ListTile。
- Settings 页面布局。
- Reader Menu。
- 颜色。
- 圆角。
- 阴影。
- 图标细节。
- 动效。
- Responsive layout。
- 信息层级。

### 暂不做破坏性架构迁移

虽然规划文件提出 Book → Document → Position → Reader Runtime → Annotation 的长期目标，本轮 UI 大改不以重写整个 Domain 为前置条件。

优先让现有 PDF / EPUB 能力完整落入新的 UI Shell；随后逐步把 Search / Bookmark / Annotation / Statistics 等统一到 Reader Domain。

## 3. 新 UI 功能映射

| 现有能力 | 新 UI 位置 | 交互 |
|---|---|---|
| 搜索 | 固定顶部 Search | 点击独占 |
| 搜索结果 | Candidate List | 整行点击 |
| 目录 | Reader TopBar / L 侧栏 | 整行跳转 |
| 页码跳转 | BottomBar / Reader Menu | 点击独占 |
| Bookmark | TopBar / Reader Menu | 单击 |
| Note | Reader Menu / Annotation | 单击 |
| Highlight | Selection Context | 单击 |
| Dictionary | Selection Context | 单击 |
| Anki | Dictionary 后续动作 | 单击 |
| Ink | Reader Tool Mode | 状态切换 |
| PageBlock | Reader Tool Mode | 状态切换 |
| Crop | Reader Menu | 设置/切换 |
| Statistics | Home / Reader Menu | 页面入口 |
| Annotation Center | Home / Settings | 列表跳转 |
| BookTemplate | Settings / Book tools | 页面入口 |
| Sync/Backup | Home / Settings | 页面入口 |
| Knowledge | 一级导航保留 | 不删除现有功能 |

## 4. Reader 新结构

统一采用：

Reader Shell
→ Safe Area
→ TopBar
→ Reader Viewport
→ BottomBar

其中：
- TopBar / BottomBar / Search 是 UI Interaction Zone。
- Reader Viewport 是内容 Interaction Zone。
- UI Zone 永远不参与正文翻页。
- 内容区点击、左右滑、上下滑按照落点优先级处理。
- 隐藏工具栏时视觉隐藏，但保留对应固定热区。
- PDF / EPUB Runtime 只接收 Reader Runtime 需要的输入，不负责绘制 Flutter Chrome。

## 5. Theme 重构方向

旧 ReaderUiTheme 允许完全重做。

新 Theme 直接支持四套：
- material
- apple
- github
- heike

兼容旧持久化值：
- google → material
- custom → material fallback

四套主题共享：
- 页面结构。
- 按钮位置。
- 热区。
- 手势。
- 信息顺序。

但允许分别改变：
- Color。
- Radius。
- Elevation。
- Typography。
- Icon stroke。
- Motion。
- Density。
- Feedback。

夜班模式作为 Theme modifier，不成为第五套布局。

## 6. 响应式契约

断点：
- XS < 360pt
- S 360–389pt
- M 390–429pt
- L >= 430pt

L：
- Reader 正文限制最大宽度。
- 目录/工具可转侧栏。
- 书库可双栏/网格。
- 不无限拉伸正文。

系统字体缩放：
- 文字可变高度。
- 列表高度跟随文字。
- 不裁切。
- 热区保持 >= 44u，核心操作推荐 48u。

## 7. 本轮实施顺序

P0 Design DNA：
- 四主题。
- Responsive tokens。
- 全局 MaterialApp Theme。

P1 Reader Chrome：
- TopBar。
- BottomBar。
- Search。
- IconButton。
- Safe Area。
- 点击独占区域。

P2 PDF Reader：
- 保全搜索/目录/书签/笔记/裁剪/手绘/PageBlock。
- 重新组织工具菜单。

P3 EPUB Reader：
- 保全 WebView Runtime。
- 保全 Selection / Dictionary / Highlight / Position。
- UI 与 Runtime 解耦。

P4 Home / Library / Search：
- 统一卡片、列表、搜索语言。
- 保留所有现有业务入口。

P5 Settings：
- 四主题。
- 夜班。
- Reader 控件。
- 模板/存储等现有功能。

P6 Responsive：
- XS/S/M/L。
- 字体缩放。
- Safe Area。
- L 双栏/最大正文宽度。

P7 最终清理：
- 图标统一。
- 动效统一。
- 主题切换无布局漂移。
- 功能入口逐项核对。

## 8. 明确禁止

- 为了新 UI 删除 Knowledge。
- 为了四项导航删除现有功能。
- 删除 PageBlock。
- 删除 Ink。
- 删除 Dictionary。
- 删除 Anki 接口。
- 删除 Annotation。
- 删除 Crop。
- 删除 BookTemplate。
- 删除 BookPageMapping。
- 删除 EPUB Selection。
- 删除 EPUB semantic Position。
- 删除 HOSHI runtime。
- 把 EPUB 强行改成 pageIndex 模型。
- 把 PDF/EPUB 底层 renderer 合并成一个错误的实现。
- 用一个全屏 GestureDetector 抢走 TopBar/BottomBar/Search 的手势。
- 主题切换导致页面结构改变。
- 为视觉统一修改既有持久化数据格式。

## 9. 完成定义

最终验收不是“页面看起来漂亮”，而是：

新设计语言覆盖整个 App，同时现有功能资产全部仍然可达、可用、可持久化。

其中 Reader 是最高优先级，因为它同时承载：
PDF、EPUB、Search、TOC、Selection、Dictionary、Highlight、Bookmark、Note、Ink、PageBlock、Crop、Position、Progress、Statistics。

因此 Reader Chrome 是本轮重构的核心母版，其余页面围绕同一 Design DNA 组合。
