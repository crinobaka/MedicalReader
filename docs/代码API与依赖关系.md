# MedicalReader 代码 API、依赖关系与预留接口

> 本文按当前 `main` 代码整理。目标是让新开发者能够先找到入口，再理解参数、返回值、继承关系和扩展边界，而不是靠搜索整棵代码树。

## 1. 总体依赖关系

```text
lib/main.dart
    ↓
MedicalReaderApp
    ↓
MainShell
    ├── HomePage
    ├── LibraryPage
    ├── SearchPage
    ├── KnowledgePage
    └── SettingsPage

ReaderPage
    ├── ReaderViewOptionsProvider
    ├── ReaderEngineService
    │   ├── MedicalCore (FFI)
    │   ├── PageCache
    │   ├── PageCropService
    │   ├── CropEngineService
    │   └── CropConfigurationStore
    ├── ReaderAnnotationService
    ├── ReaderNoteService
    ├── ReaderProgressService
    ├── ReaderSearchService
    └── PagePreloader

LibraryPage
    ↓
LibraryProvider
    ↓
LibraryRepository
    ├── LibraryMetadataStorage
    └── DocumentFilesProvider

Rust
MedicalCore Dart FFI
    ↓
core/medical_core/src/ffi/api.rs
    ↓
reader/document.rs + renderer.rs
    ↓
MuPDF
```

## 2. 应用层

### `lib/app/app.dart`

#### `MedicalReaderApp extends StatelessWidget`

作用：创建 Material 3 应用、主题和主壳。

主要引用：`HomePage`、`LibraryPage`、`SearchPage`、`KnowledgePage`、`SettingsPage`。

#### `MainShell extends StatefulWidget`

作用：根据窗口宽度选择移动端 `NavigationBar` 或桌面/平板 `NavigationRail`。

关键参数：无。

内部状态：

- `int index`：当前主导航索引。
- `constraints.maxWidth >= 900`：桌面导航断点。

预留接口：

- 导航项应继续保持 `NavigationDestination` / `NavigationRailDestination` 对称。
- 若以后增加平板双栏布局，应在 `900` 附近增加独立 breakpoint，而不是把平台判断写进各 Page。

## 3. FFI / Rust 核心

### `lib/core/ffi/medical_core.dart`

#### `MedicalCore`

作用：Dart 到 Rust `medical_core` 的唯一阅读核心入口。

核心职责：

- 加载动态库
- 打开文档
- 获取页数
- 渲染页面
- 管理 Native handle

所有 PDF 页面渲染业务应优先经过 `MedicalCore`，不要在 Widget 中直接操作动态库。

### `lib/core/ffi/medical_core_image.dart`

#### `MedicalCoreImage.decode(...)`

作用：将 Native 页面输出解码为 Flutter `ui.Image`。

约束：

- 调用方获得 `ui.Image` 后负责生命周期。
- 不要把未经缓存预算控制的高 DPI 图片长期放在 State 中。

### Rust

位置：`core/medical_core/src/ffi/api.rs`

作用：定义 C ABI/FFI 导出函数；`types.rs` 定义跨语言结构。

引用关系：

```text
ffi/api.rs
  → reader/document.rs
  → reader/renderer.rs
```

扩展要求：

- FFI 参数使用稳定、可明确释放的 ABI 类型。
- 字符串必须明确所有权。
- Native handle 必须有对应 destroy/release API。
- 新增函数必须同步更新 Dart FFI 声明和本文档。

## 4. Library / 文件系统

### `lib/core/file_manager/services/library_storage_service.dart`

#### `LibraryStorageService.getLibraryDirectory() -> Future<Directory>`

作用：返回当前 Library 目录；配置目录失效时回退到默认目录。

参数：无。

#### `pickLibraryDirectory() -> Future<Directory?>`

作用：让用户选择新的 Library 目录并验证真实读写权限。

返回：成功为目录，取消或权限不足为 `null`。

#### `getDefaultLibraryDirectory() -> Future<Directory>`

作用：取得平台默认 Library 目录。

#### `changeLibraryDirectory()`

调用链：

```text
SettingsPage
 → LibraryProvider
 → LibraryStorageService
 → DocumentFilesProvider
 → LibraryRepository
```

Android 特别约束：共享存储目前依赖原生 `medicalreader/storage` channel；如果未来改成 Storage Access Framework，应替换这里和 `MainActivity.kt`，不要让 UI 感知权限细节。

### `lib/features/library/providers/library_provider.dart`

#### `LibraryNotifier extends StateNotifier<List<LibraryDocument>>`

作用：Library 状态入口。

主要 API：

- `addFile() -> Future<void>`：导入 PDF。
- `removeDocument(String documentId) -> Future<void>`：删除文档及关联文件。
- `reload() -> Future<void>`：重新扫描 / 重建 Library 状态。
- `libraryPath() -> Future<String>`：返回当前路径。
- `changeLibraryDirectory() -> Future<void>`：切换 Library。

状态：`List<LibraryDocument>`。

## 5. Reader 数据模型

### `lib/features/reader/models/reader_view_options.dart`

#### `ReaderViewOptions`

核心参数：

- `bool showLocationBar`
- `bool showSearchLocation`
- `bool showPageControls`
- `bool showBookTreeButton`
- `bool showSearchButton`
- `bool showPageJumpButton`
- `bool showCropMargins`
- `String themePreset`：`google | apple | github | custom`
- `bool floatingControls`
- `String toolbarPosition`：`top | bottom | auto`
- `String canvasBackground`：`inherit | paper | dark | custom`
- `int? customCanvasColor`：ARGB

主要 API：

- `copyWith(...) -> ReaderViewOptions`
- `toJson() -> Map<String, dynamic>`
- `ReaderViewOptions.fromJson(Map<String, dynamic>) -> ReaderViewOptions`

扩展规则：新增设置必须同时加入构造器、`copyWith`、`toJson`、`fromJson`，并保持旧 JSON 缺失字段可回退到默认值。

### `BookTemplate`

位置：`lib/features/reader/models/book_template.dart`

作用：定义书籍匹配、页码映射、搜索上下文和默认行为。

### `CropConfiguration`

位置：`lib/features/reader/models/crop_configuration.dart`

作用：定义裁切区域、布局、页面范围和继承规则。

### `ReaderAnnotation`

位置：`lib/features/reader/models/reader_annotation.dart`

作用：统一 Highlight / Note / Bookmark 等阅读层对象。

## 6. Reader Engine

### `lib/features/reader/services/reader_engine_service.dart`

#### `ReaderEngineService`

依赖：

- `MedicalCore`
- `PageCache`
- `PageCropService`
- `CropEngineService`
- `CropConfigurationStore`

#### `openDocument({required String id, required String path}) -> MedicalCoreDocument`

作用：清空旧页面缓存、切换裁切配置上下文并打开 PDF。

#### `renderPage({required MedicalCoreDocument document, required int pageIndex, int dpi = 150, bool cropMargins = false, CropConfiguration? cropConfiguration, List<CropRegion>? previousCropRegions}) -> Future<ui.Image>`

作用：渲染、裁切、缓存并返回当前调用方拥有的 `ui.Image` clone。

参数要求：

- `document`：已打开的 Native 文档。
- `pageIndex`：0-based PDF 页号。
- `dpi`：建议普通移动端 150；高清模式可更高，但必须考虑缓存预算。
- `cropMargins`：旧式自动白边裁切开关。
- `cropConfiguration`：显式指定的高级裁切配置；为空时从当前文档配置读取。
- `previousCropRegions`：用于页面间继承裁切区域。

#### `clearPageCache({ui.Image? keepImage})`

作用：清理 L2 缓存，同时可保留当前图片。

#### `dispose()`

作用：移除配置监听器并释放全部缓存图片。

## 7. 页面缓存与预加载

### `lib/features/reader/services/page_cache.dart`

#### `PageCacheKey`

字段：

- `int pageIndex`
- `int dpi`
- `bool cropMargins`
- `String cropSignature`

#### `PageCache`

构造参数：

- `int capacity = 11`
- `int maxBytes = 64 * 1024 * 1024`

核心 API：

- `get(...) -> ui.Image?`
- `put(...) -> void`
- `remove(...) -> ui.Image?`
- `trim() -> List<ui.Image>`
- `clear() -> void`
- `clearExcept(ui.Image? keepImage) -> void`
- `contains(...) -> bool`
- `estimatedBytes -> int`

缓存策略：LRU + 页数上限 + RGBA 4 bytes/pixel 保守估算内存上限。

重要所有权规则：缓存持有原始 `ui.Image`；`get()` 返回 clone，调用方负责释放 clone。这样 Widget 销毁不会把 L2 缓存一起释放。

### `PagePreloader`

位置：`lib/features/reader/services/page_preloader.dart`

#### `preloadAround(...) -> Future<void>`

参数：

- `document`
- `currentPage`
- `pageCount`
- `dpi = 150`
- `cropMargins = false`
- `radius = 3`，允许 `1..5`

默认只预加载当前页前后 3 页，避免在手机上为了追求命中率过度占用 GPU 内存。

#### `cancel() -> void`

通过 generation token 使旧预加载任务停止继续写入。

## 8. Crop

### `ReaderCropController`

位置：`lib/features/reader/controllers/reader_crop_controller.dart`

作用：管理当前裁切会话与 UI 交互状态。

### `CropRegionCanvas`

位置：`lib/features/reader/widgets/crop_region_canvas.dart`

输入：

- `ui.Image? image`
- `List<CropRegion> regions`
- `ValueChanged<int> onLongPressRegion`
- `void Function(int index, CropRegion region) onChanged`
- `double minRegionSize = 0.04`

行为：

- 区域坐标以 PDF 页面归一化坐标为基准。
- 长按切换区域参与编号状态。
- 被排除区域使用斜线显示。
- 右下角拖拽调整大小。
- 页面实际显示区域使用 `BoxFit.contain` 对齐，因此手机小屏不会把裁切框画到 PDF 页面之外。

## 9. Note / Knowledge

### `lib/features/knowledge/services/note_renderer.dart`

负责 Markdown 与 Markdown-HTML 的渲染入口。

### `NoteDocument`

位置：`lib/features/knowledge/models/note_document.dart`

作用：保存笔记内容、格式和关联信息。

### `AnnotationNoteAttachmentService`

位置：`lib/features/reader/services/annotation_note_attachment_service.dart`

作用：管理笔记图片 / 音频附件的复制、路径和生命周期。

扩展要求：附件引用必须使用稳定的相对文档标识或应用数据路径，禁止把临时目录绝对路径直接写入长期笔记数据。

## 10. Settings / DIY

### `SettingsPage`

位置：`lib/features/settings/pages/settings_page.dart`

作用：提供 Library、阅读器显示、书籍模板和应用信息设置。

### `UserTemplateService`

位置：`lib/features/settings/services/user_template_service.dart`

作用：保存、读取、删除用户 `BookTemplate`。

模板扩展原则：

1. 内置模板只读。
2. 用户模板复制后独立保存。
3. JSON 根节点必须是对象。
4. `id` 与 `name` 必须非空。
5. 新字段必须向后兼容。

## 11. UI Theme

### `ReaderUiTheme`

位置：`lib/features/reader/services/reader_ui_theme.dart`

作用：把 `google / apple / github / custom` 转换成阅读器颜色、圆角、阴影和画布策略。

预留 DIY 参数：

```text
ReaderUiTheme
├── canvasColor
├── surfaceColor
├── primaryColor
├── textColor
├── borderColor
├── radius
├── elevation
└── toolbar placement
```

如果以后增加完整主题编辑器，应新增 `ReaderThemeConfig` 数据模型，而不是在 Widget 中继续增加大量 `if (preset == ...)`。

## 12. 搜索 / 标注 / 进度

### `ReaderSearchService`

位置：`lib/features/reader/services/reader_search_service.dart`

作用：阅读器内搜索并产生 `ReaderSearchHit`。

### `ReaderAnnotationService`

位置：`lib/features/reader/services/reader_annotation_service.dart`

作用：创建、更新、删除阅读层 Annotation。

### `ReaderProgressService`

位置：`lib/features/reader/services/reader_progress_service.dart`

作用：持久化最后阅读页、缩放等阅读状态。

### `ReaderAnnotationRepository`

位置：`lib/features/reader/repositories/reader_annotation_repository.dart`

作用：Annotation 持久化边界。

## 13. 工具

### `tools/reader_template_generator.dart`

文字冒险式模板生成器入口。

### `tools/directory_generator.dart`

缩进文本 → 书籍目录 JSON 生成器。

输入格式默认使用 **2 个空格表示一级缩进**，禁止混用 Tab 与空格。

示例：

```text
第一章 总论
  第一节 病因
    1. 发病机制
    2. 危险因素
  第二节 临床表现
第二章 诊断
  第一节 实验室检查
```

## 14. 预留接口清单

### A. GPU Magnifier

推荐位置：`lib/features/reader/widgets/reader_magnifier.dart`

建议接口：

```dart
class ReaderMagnifierConfig {
  final bool enabled;
  final double magnification; // 1.5..4.0
  final double radius;         // logical px
  final double distortion;     // 0..1
}
```

实现要求：只变换当前渲染纹理，不重新调用 PDF renderer，不生成截图。

### B. Layout / Crop Provider

推荐位置：`lib/features/reader/services/crop_layout_provider.dart`

```dart
Future<List<CropRegion>> resolve({
  required ui.Image page,
  required int pageIndex,
  required CropConfiguration configuration,
});
```

返回区域必须使用 0..1 归一化坐标；不得依赖屏幕像素。

### C. Annotation Provider

推荐接口：

```dart
Future<ReaderAnnotation> create(ReaderAnnotationDraft draft);
Future<void> update(ReaderAnnotation annotation);
Future<void> delete(String annotationId);
Stream<List<ReaderAnnotation>> watch(String documentId);
```

### D. OCR Provider

推荐位置：`lib/core/ocr/`。

```dart
Future<TextLayer> recognize({
  required ui.Image image,
  required OcrOptions options,
});
```

Provider 必须异步；禁止在 Flutter UI isolate 上同步执行大 OCR。

### E. Storage Provider

未来若迁移 Android SAF：

```dart
Future<StorageHandle?> pickLibrary();
Future<Uint8List> read(StorageHandle handle);
Future<void> write(StorageHandle handle, Uint8List data);
Future<bool> exists(StorageHandle handle);
```

UI 只能看到 `StorageHandle`，不要依赖 Android 原始绝对路径。

## 15. 继承关系速查

```text
StatelessWidget
├── MedicalReaderApp
├── MainShell? (StatefulWidget，例外)
├── HomePage
├── LibraryPage
├── ReaderViewport
├── CropRegionCanvas
└── 各类展示 Widget

StatefulWidget
├── MainShell
├── ReaderPage
├── SettingsPage
├── CropRegionCanvas 内部 _RegionGesture
└── 各类需要生命周期的页面

StateNotifier
└── LibraryNotifier

ConsumerStatefulWidget / ConsumerWidget
└── 需要 Riverpod 状态的 Reader / Settings 页面
```

## 16. 开发规则

1. UI 不直接访问 FFI。
2. Widget 不负责长期文件路径规则。
3. 页面渲染必须经过 `ReaderEngineService`。
4. 新缓存必须明确所有权与释放责任。
5. 新设置必须可序列化并提供旧版本默认值。
6. 移动端适配优先通过布局层解决，不在业务代码里散落 `Platform.isAndroid`。
7. 新第三方依赖必须先证明 Flutter 原生能力不能稳定解决问题。
8. 每个新的公开服务 / 模型都必须补充本文档的“位置、参数、返回值、依赖关系”。
