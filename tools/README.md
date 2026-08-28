# Windows 工具

当前项目的模板 / 目录生成工具以 PowerShell 为唯一入口，避免维护一套没有接入 Flutter 构建链的 Dart CLI。

## 目录生成器

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

## 阅读模板生成器

```powershell
.\tools\reader_template_generator.ps1
```

PowerShell 脚本可以直接在 Windows Terminal 中运行，不需要把 `tools/` 当作 Dart package，也不参与 App 的 Dart 编译。
