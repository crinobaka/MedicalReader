# Windows 工具

MedicalReader 1.5 的开发/DIY 工具以 PowerShell 为主要入口，避免为了几个离线工具再维护一套 Dart CLI。

## 1. 目录生成器

```powershell
.\tools\directory_generator.ps1 -InputFile .\my-book.txt -OutputFile .\book.json
```

输入使用 2 个空格表示一级缩进；空行和 `#` 开头的行会忽略。

可选元数据：

```text
第一章 {pdf=1-20}
  第一节 {pdf=1-8}
  第二节 {book=9-15}
```

## 2. 阅读模板生成器

```powershell
.\tools\reader_template_generator.ps1 -OutputFile .\assets\book_templates\my-book.json
```

脚本会询问模板 ID、名称、别名、页码偏移、裁剪模式和搜索上下文。

## 3. DIY 配置检查

提交自定义主题或模板前运行：

```powershell
.\tools\validate_diy.ps1
```

它会检查 UI 主题必填字段、颜色格式、布局布尔值以及书籍模板的基本结构。

## 4. 应用图标

品牌源固定为：

```text
assets/branding/favicon.ico
```

运行：

```powershell
.\tools\generate_icons.ps1
```

脚本会先执行 `flutter pub get`，再运行 `flutter_launcher_icons`，并从脚本自身目录定位仓库根目录，因此从任意 PowerShell 当前目录调用都不会因为相对路径而找错文件。

> 注意：`flutter_launcher_icons` 官方配置示例以 PNG 为主。如果当前 ICO 在本机生成时出现图像解码错误，应先把 ICO 转成 PNG，再保持 PNG 作为生成源；不要修改 Android/Windows 原生资源路径来绕过工具。

## 5. 发布前检查

```powershell
.\tools\verify_release.ps1
```

推荐顺序：

```text
validate_diy.ps1
    ↓
generate_icons.ps1
    ↓
flutter analyze
    ↓
flutter build apk --release
    ↓
flutter build windows
```
