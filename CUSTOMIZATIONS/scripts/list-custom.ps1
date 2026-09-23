#!/usr/bin/env pwsh
<#
.SYNOPSIS
    列出当前 custom/main 相对于 vendor 分支的所有自定义提交和改动文件。
.DESCRIPTION
    供 AI Agent 快速查看当前有哪些自定义改动。vendor 分支名从
    CUSTOMIZATIONS/registry.md 的 frontmatter 读取。
#>

$ErrorActionPreference = "Stop"

# 从 CUSTOMIZATIONS/registry.md 读取 vendor branch
# 注意：frontmatter 用单引号，也可能被改成双引号，两种都要认
# （参考项目只匹配双引号，而它的 frontmatter 是单引号——正则实际从未命中，
#   一直静默走默认值。这里修正为兼容两种引号。）
$vendorBranch = "vendor/main"
if (Test-Path "CUSTOMIZATIONS/registry.md") {
    $content = Get-Content "CUSTOMIZATIONS/registry.md" -Raw
    if ($content -match "vendor_branch:\s*['\x22]?([^'\x22\r\n]+)") {
        $vendorBranch = $Matches[1].Trim()
    }
}

$vendorExists = git rev-parse --verify "$vendorBranch" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Vendor 分支 $vendorBranch 不存在，请先初始化或 sync" -ForegroundColor Red
    exit 1
}

Write-Host "=== 自定义改动清单（相对于 $vendorBranch）===" -ForegroundColor Cyan
Write-Host ""

Write-Host "--- 自定义提交 ---" -ForegroundColor Yellow
git log --oneline "$vendorBranch..HEAD"

Write-Host ""
Write-Host "--- 改动文件统计 ---" -ForegroundColor Yellow
git diff --stat "$vendorBranch..HEAD"

Write-Host ""
Write-Host "--- 改动文件列表 ---" -ForegroundColor Yellow
git diff --name-status "$vendorBranch..HEAD"

Write-Host ""
$count = (git log --oneline "$vendorBranch..HEAD" | Measure-Object -Line).Lines
Write-Host "共 $count 个自定义提交" -ForegroundColor Green
