# MedicalReader

> 面向医学 PDF 的跨平台阅读、检索与知识整理工具。

MedicalReader 的目标不是做一个“能打开 PDF”的播放器，而是把 **导入 → 书库 → 搜索 → 定位 → 阅读 → 标注/笔记 → 知识整理** 做成一个连续、低摩擦的工作流。

当前工程采用 Flutter + Riverpod 作为应用层，Rust `medical_core` + MuPDF 作为阅读核心，并把阅读布局、主题、书籍模板和缓存策略保留为可扩展接口。

## 当前状态

### 已可用

- PDF 导入与书库管理
- 阅读位置恢复
- PDF 页 / 书籍页定位
- 鼠标滚轮、键盘、触摸滑动翻页
- 双指缩放、Ctrl + 滚轮缩放
- 基础白边裁切与自定义区域裁切基础
- 书签、标注、Markdown / HTML 笔记
- 图片与音频附件
- 书籍目录树与页码映射
- 搜索结果定位与最近搜索记录暂存
- Google / Apple / GitHub 三套阅读器视觉预设
- 悬浮阅读工具栏与可配置画布背景
- 手机 / 平板 / 桌面自适应主导航
- 用户书籍模板
- 缩进文本目录生成器
- 文字冒险式书籍模板生成器
- LRU 页面缓存与基于估算像素内存的缓存预算

## 平台

当前重点验证：

- Android
- Windows

项目仍保留 iOS / macOS / Linux / Web 的 Flutter 工程骨架，但 v0.1 发布验收以 Android 与 Windows 为主。

## 快速开始

### Flutter

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

也可以使用统一的 Windows 验证脚本：

```powershell
.\tools\verify_release.ps1
```

它会依次执行依赖、analyze、test，并检查发布所需的关键工程文件。

Android：

```powershell
flutter run -d <android-device>
```

### Rust Core

Rust 核心位于 `core/medical_core`。

Android 构建辅助脚本：

```powershell
.\tool\build_medical_core_android.ps1
```

Windows 构建时必须确保最终程序目录包含与当前架构匹配的 `medical_core.dll`。

## 目录结构

```text
MedicalReader/
├── lib/
│   ├── app/                  # 应用壳与响应式主导航
│   ├── core/                 # Flutter 基础设施、FFI、文件管理
│   └── features/
│       ├── library/          # 书库
│       ├── reader/           # 阅读器、裁切、模板、缓存、标注
│       ├── knowledge/        # 笔记与知识页面
│       ├── search/           # 搜索入口与搜索历史
│       └── settings/         # 设置与用户模板
├── core/medical_core/        # Rust PDF / FFI 核心
├── assets/                   # 内置模板与品牌资源
├── doc/                      # 产品、技术、数据、工程设计文档
├── docs/                     # 实施、验收、DIY 与 API 文档
└── tools/                    # PowerShell 模板 / 目录生成与发布验证工具
```

## DIY 与扩展

普通用户不需要修改代码即可使用默认配置。愿意折腾的用户可以从以下入口扩展：

- `assets/book_templates/`：内置书籍模板
- `ReaderViewOptions`：阅读器显示与画布配置
- `ReaderUiTheme`：视觉主题
- `BookTemplate`：书籍结构与定位规则
- `CropConfiguration`：裁切区域与布局
- `PageCache`：缓存容量与估算内存预算

详细操作请阅读 `docs/用户与DIY指南.md`；开发者 API、参数、继承与引用关系见 `docs/代码API与依赖关系.md`；B/C 阶段的工程验收边界见 `docs/BC收尾验收.md`。

## 设计边界

v0.1 明确不为了“看起来高级”加入高风险依赖。以下功能保留接口或设计文档，但不伪装成已经完成：

- 真正的 GPU shader 玻璃珠式放大镜
- 高级自动吸附与语义裁切
- OCR Provider 实际接入
- MRIF 大规模知识索引
- 云同步
- EPUB / MOBI
- AI 功能
- 手写笔

这些属于后续版本的独立工程任务。

## 文档入口

- `doc/技术路线/`：PRD、ER、TDD、CAD、DSS、MRKL、MSE 等设计资料
- `docs/v0.1收尾验收与未完成项对照.md`：v0.1 验收边界
- `docs/BC收尾验收.md`：Reader B/C 阶段工程与交互验收
- `docs/用户与DIY指南.md`：普通用户操作与 DIY
- `docs/ui_ux_principles.md`：交互原则
- `docs/代码API与依赖关系.md`：代码入口、函数参数、引用关系与预留接口

## 发布前验证

真实设备上优先验证：

1. Android 外部存储授权、重启后的 Library 与 PDF 打开
2. Android 竖屏 / 横屏、滑动翻页、双指缩放
3. Windows PDF 打开、滚轮翻页、Ctrl + 滚轮缩放、键盘操作
4. `medical_core.dll` / Android `.so` 随发布产物正确部署
5. 书签与阅读进度退出后仍然存在
6. Markdown / HTML / 图片 / 音频附件可访问
7. 用户模板保存后可被 Reader 加载
8. 目录生成器可以正确解析 2 空格缩进格式

## License

项目当前仍处于 v0.1 Alpha 工程阶段；许可证策略以仓库后续正式发布配置为准。
