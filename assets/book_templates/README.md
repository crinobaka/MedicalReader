# Book templates

这里放可以被用户复制、修改、分享的书籍模板。模板是普通 JSON，不包含 Dart 或 PowerShell 代码。

## 现有模板

- `generic_medical_book.json`：通用医学书籍起点
- `two_column_medical.json`：双栏医学论文起点
- `three_column_medical.json`：三栏参考资料起点

## 自定义

在仓库根目录执行：

```powershell
./tools/reader_template_generator.ps1 -OutputFile ./assets/book_templates/my_book.json
```

然后根据自己的 PDF 修改 `data.defaults`。未知字段可以保留，但不要放可执行内容。

目录文本格式与 UI DIY 配置见 `doc/1.5/diy-guide.md`。
