param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    [string]$OutputFile = "book.json"
)

# 解析一行，返回节点哈希表（id 后面设置）
function Parse-Line {
    param([string]$line, [int]$id)
    # 匹配 name 和 {metadata}
    if ($line -match '^(.*?)(?:\s*\{([^}]*)\})?$') {
        $name = $Matches[1].Trim()
        $metadata = $Matches[2]
        $node = @{
            id = "node_$id"
            name = $name
            children = @()
        }
        if ($metadata) {
            $pairs = $metadata -split ','
            foreach ($pair in $pairs) {
                $parts = $pair -split '=' | ForEach-Object { $_.Trim() }
                if ($parts.Count -ne 2) { continue }
                $key = $parts[0]
                $value = $parts[1]
                if ($key -eq 'pdf' -or $key -eq 'book') {
                    $range = $value -split '-'
                    if ($range.Count -eq 0) { continue }
                    $start = 0
                    $end = 0
                    if (-not [int]::TryParse($range[0], [ref]$start)) { continue }
                    if ($range.Count -gt 1) {
                        if (-not [int]::TryParse($range[1], [ref]$end)) { $end = $start }
                    } else {
                        $end = $start
                    }
                    if ($key -eq 'pdf') {
                        $node['page_start'] = $start
                        $node['page_end'] = $end
                    } elseif ($key -eq 'book') {
                        $node['book_page_start'] = $start
                        $node['book_page_end'] = $end
                    }
                }
            }
        }
        return $node
    }
    return $null
}

# 读取文件（按行）
$lines = Get-Content -Path $InputFile -Encoding UTF8
$roots = @()
$stack = @()          # 元素: @{ level = $level; node = $node }
$id = 0

foreach ($raw in $lines) {
    $trim = $raw.Trim()
    # 跳过空行或注释（行首可含空白）
    if ($trim -eq '' -or $trim.StartsWith('#')) { continue }

    # 计算缩进（必须为偶数个空格）
    $leading = $raw.Length - $raw.TrimStart().Length
    if ($leading % 2 -ne 0) {
        throw "缩进必须使用 2 个空格：$raw"
    }
    $level = $leading / 2

    $id++
    $node = Parse-Line -line $trim -id $id
    if (-not $node) { continue }

    # 弹出栈中层级 >= 当前层级的节点
    while ($stack.Count -gt 0 -and $stack[-1].level -ge $level) {
        $stack = $stack[0..($stack.Count-2)]
    }

    if ($stack.Count -eq 0) {
        $roots += $node
    } else {
        $parent = $stack[-1].node
        $parent.children += $node
    }

    $stack += @{ level = $level; node = $node }
}

# 构建最终 JSON
$output = @{
    version = 1
    bookTree = $roots
}

$json = $output | ConvertTo-Json -Depth 10
$json | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Host "目录已生成：$OutputFile"