param(
    [string]$OutputFile = "reader_template.json"
)

Write-Host "MedicalReader · Template Adventure"
Write-Host "像创建一本书的角色卡一样回答几个问题。"

function Ask {
    param([string]$label, [string]$fallback)
    Write-Host "$label [$fallback]: " -NoNewline
    $input = Read-Host
    if ([string]::IsNullOrWhiteSpace($input)) { return $fallback }
    return $input.Trim()
}

$id = Ask "模板 ID" "my-book"
$name = Ask "模板名称" "My Medical Book"
$description = Ask "一句话描述" "Generated reader template"
$aliasesInput = Ask "书名匹配别名（逗号分隔，可空）" ""
$pageOffsetInput = Ask "PDF 到书籍页码偏移（PDF - offset = book）" "0"
$cropMode = Ask "默认裁剪：none / double / triple" "none"
$searchPrefix = Ask "搜索上下文前缀（可空）" ""

# 解析页码偏移
$pageOffset = 0
if (-not [int]::TryParse($pageOffsetInput, [ref]$pageOffset)) {
    $pageOffset = 0
}

# 处理别名
$aliases = @()
if (-not [string]::IsNullOrWhiteSpace($aliasesInput)) {
    $aliases = $aliasesInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
}

# 获取当前用户
$author = $env:USERNAME
if ([string]::IsNullOrWhiteSpace($author)) { $author = $env:USER }
if ([string]::IsNullOrWhiteSpace($author)) { $author = "local" }

# 构建 JSON 对象
$json = @{
    id = $id
    name = $name
    version = "1.0.0"
    description = $description
    author = $author
    data = @{
        aliases = $aliases
        metadata = @{
            title = $name
        }
        defaults = @{
            bookPageMapping = @{
                mode = "offset"
                offset = $pageOffset
            }
            searchContext = @{
                prefix = $searchPrefix
            }
            crop = @{
                mode = $cropMode
            }
        }
    }
}

$json | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Host "模板已生成：$OutputFile"