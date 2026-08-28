# B / C 收尾验收

> 目的：在 ReaderPage A 阶段拆分完成后，把剩余的交互边界、工程质量和发布前验证固定下来。

## B：交互与架构边界

### ReaderPage

`lib/features/reader/pages/reader_page.dart` 应保持为入口/组装层：

- 创建并释放 `ReaderPageController`
- 连接 Riverpod provider
- 把文档状态交给 `ReaderPageLayout`
- 把搜索、书签、笔记、目录、设置等命令连接到对应服务/控制器
- 不承担 PDF 渲染、缓存、手势策略和布局策略

现有职责分层：

```text
ReaderPage
  ├─ ReaderPageController      文档生命周期与当前页
  ├─ ReaderInteractionController 输入 → reader intent
  ├─ ReaderLayoutController      UI slot 状态模型
  ├─ ReaderCropController        裁切状态与模板
  ├─ ReaderNavigationController  页面导航命令
  └─ ReaderPageLayout            展示与组合
```

### 输入规则

- 触摸横向翻页必须明显横向占优，避免纵向阅读手势误翻页。
- 鼠标滚轮默认翻页。
- Ctrl + 滚轮缩放。
- 双指缩放由 `InteractiveViewer` 负责。
- 键盘左右 / PageUp / PageDown 导航；Home / End 到首尾。

这些规则应继续由 `ReaderInteractionController` 维护，不在页面中复制平台判断。

### 设置页

设置面板必须拥有自己的有限 viewport；嵌入 `DraggableScrollableSheet` 时使用 sheet 提供的 `ScrollController`。禁止在无限高度父布局中直接放裸 `ListView`。

## C：工程与发布验收

### 自动检查

Windows PowerShell：

```powershell
.\tools\verify_release.ps1
```

跳过某一阶段：

```powershell
.\tools\verify_release.ps1 -SkipPubGet
.\tools\verify_release.ps1 -SkipAnalyze
.\tools\verify_release.ps1 -SkipTest
```

脚本会检查：

1. Flutter 依赖
2. Dart analyzer
3. Flutter tests
4. 品牌资源
5. Reader 输入 / 布局控制器
6. Search controller
7. 桌面端工具脚本

### 平台验收

Android：

- 外部存储 Library 重启后仍可识别
- PDF 导入后可重新打开
- 竖屏 / 横屏均可滑动翻页
- 双指缩放不触发翻页
- 设置页整个内容区域均可拖动
- 书签、笔记和附件重启后保持

Windows：

- `medical_core.dll` 与应用架构一致
- 滚轮翻页
- Ctrl + 滚轮缩放
- 键盘导航
- 文件选择与笔记导出

## 已知刻意保留到后续版本

以下项目没有为了“看起来完成”而伪造实现：

- 真正 GPU shader 玻璃珠放大镜
- OCR provider
- 高级语义裁切 / 智能吸附
- MRIF 大规模知识索引
- 云同步
- EPUB / MOBI
- AI 功能
- 手写笔

它们的接口可以提前预留，但实现应作为独立工程任务，避免污染阅读器核心。

## 回归原则

每次修改阅读器时优先执行：

```powershell
flutter analyze
flutter test
```

如果修改涉及 Windows / Android 原生核心，再执行对应平台构建。

任何“看起来更漂亮”但增加阅读区域、手势或启动路径负担的改动，不应直接合入默认配置。
