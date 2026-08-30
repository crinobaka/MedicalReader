# MedicalReader UI DIY

`reader_theme.json` 是阅读器 Chrome 的用户可编辑契约。PDF 本身不读取这些颜色，因此换主题不会触发 PDF 重渲染。

## 最简单的改法

只改这几个字段即可：

- `preset`: `google` / `apple` / `github` / `custom`
- `brightness`: `system` / `light` / `dark`
- `canvas.background`: 阅读区背景
- `chrome.surface`: 浮动工具栏背景
- `chrome.foreground`: 文字与图标
- `chrome.accent`: 强调色

颜色必须使用 `#RRGGBB`；带透明度时使用 `#AARRGGBB`。

## 布局契约

每个区域都有四个开关：

- `visible`: 是否允许显示
- `collapsed`: 初始是否折叠
- `overlay`: 是否覆盖在 PDF 上而不是占用 PDF 布局空间
- `persistent`: 是否保持常驻

可用区域：`topBar`、`bottomBar`、`leftPanel`、`rightPanel`，以及总开关 `floatingControls`。

移动端建议保持 `topBar` 和 `bottomBar` 可用，把左右面板设为不可见；桌面端可以按个人习惯打开侧栏。

## 设计原则

1. 不要把重要功能藏在只有图标的按钮里；桌面端提供 tooltip，移动端提供足够大的触摸区域。
2. 不要把滚动交互绑定到窄滚动条；整个设置/目录内容区域都应可拖动滚动。
3. 不要修改 `canvas` 的 PDF 渲染尺寸来模拟主题。
4. 自定义颜色应保证普通文字与背景有明显对比。
5. 修改后如果应用仍在运行，重新进入阅读页即可看到新的 Chrome 配置；无需重新生成 PDF。

完整字段说明见 `doc/1.5/diy-guide.md`。
