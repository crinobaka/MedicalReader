# MedicalReader 1.5 阅读器交互架构

## 目标

1. 阅读画布优先：工具栏覆盖而不是挤占 PDF 空间。
2. 同一套命令在 Android 与 Windows 上复用，平台只负责把原始输入转换成命令。
3. 高频操作保持可发现，低频操作进入“更多”菜单；不要求用户记快捷键才能完成基本任务。
4. 所有可滚动内容必须提供完整可触摸的滚动区域，禁止依赖窄滚动条拖动。
5. 触摸目标遵循至少约 44dp 的可操作面积；桌面端保留 tooltip 与键盘入口。
6. PDF、笔记、搜索、书签使用稳定 document/page 标识互相定位，而不是依赖 Widget 状态。

## 输入层

```text
Pointer / Touch / Keyboard
          ↓
ReaderInteractionController
          ↓
Reader intents / commands
          ↓
ReaderPage coordinator
          ↓
PDF / search / bookmark / note services
```

### 推荐命令

- `previousPage`
- `nextPage`
- `firstPage`
- `lastPage`
- `jumpToPage`
- `toggleControls`
- `toggleBookmark`
- `openSearch`
- `openOutline`
- `zoomIn`
- `zoomOut`
- `resetZoom`
- `pan`
- `openNote`

Widget 不应该直接决定业务行为。

## 触摸策略

- 单指拖动：页面平移。
- 双指：缩放。
- 未缩放时的明显水平滑动：翻页。
- 双击：在 fit/当前缩放之间切换，或恢复默认缩放。
- 点击空白画布：浮动控件显示/隐藏。
- 控件显示时，控件自身点击不得触发画布隐藏逻辑。

## 桌面策略

- 鼠标滚轮：默认翻页；Ctrl+滚轮：缩放。
- 左右方向键：翻页。
- PageUp/PageDown：翻页。
- Home/End：首尾页。
- G：页码跳转。
- B：书籍页跳转。
- Ctrl+F：搜索。
- Escape：关闭临时面板/退出临时模式。

快捷键必须作为命令入口，而不是业务逻辑的另一套实现。

## 视觉系统

ReaderUiTheme 是阅读器 chrome 的 design-token 层：

- Google / Material：清晰层级、较大的圆角、强调色。
- Apple：更轻的分组、圆润控件、系统蓝。
- GitHub：紧凑布局、细边框、低 elevation、暗色支持。
- Custom：保留 token 接口。

PDF canvas 与 chrome 分离。修改主题不能重新渲染 PDF。

## 验收原则

### Android

- 手指按在设置内容任意主体区域都可以滚动。
- 浮动工具栏不遮挡页面主要阅读区域；隐藏后 PDF 可以使用整个窗口。
- 横屏/竖屏均不出现 RenderBox unbounded 或 overflow。
- 触摸目标不会小到需要精确点击图标中心。

### Windows

- 鼠标、滚轮、键盘均可完成主要阅读动作。
- 浮动控件不会因窗口尺寸改变产生越界。
- 搜索、书签、目录、笔记等入口均可用键盘辅助。

## 后续 A-E 分块

- A：阅读核心、人机交互、主题与输入统一。
- B：可视化 PDF 裁剪画布、吸附、区域模型。
- C：笔记解耦、导出、附件、代码高亮。
- D：DIY、模板、PowerShell 工具、资源与图标。
- E：LRU/预加载、Android/Windows 全面验证与工程清扫。
