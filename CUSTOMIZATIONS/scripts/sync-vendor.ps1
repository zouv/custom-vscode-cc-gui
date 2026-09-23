#!/usr/bin/env pwsh
<#
.SYNOPSIS
    快速同步 vendor 分支到指定上游 ref。
.DESCRIPTION
    AI Agent 在合并上游前可以先用此脚本查看/同步 vendor 分支。
    ccgui 上游开发在 main 分支；ref 可以是：
      - upstream/main（默认，跟随主线）
      - tag（如 0.1.5，锚定版本线时同时创建 vendor/v0.1.x）
    注意：上游 tag **大多没有 v 前缀**（0.1.1 ~ 0.1.5，仅 v0.1 例外），
    所以 tag 正则必须写成 ^v?(\d+)\.(\d+)\.；fork 自己的发布 tag 用 v 前缀区分。
.PARAMETER Ref
    目标 ref。留空则使用 upstream/main 最新。
.PARAMETER Push
    是否自动推送到 origin
#>

param(
    [string]$Ref = "",
    [switch]$Push
)

$ErrorActionPreference = "Stop"

Write-Host "=== Vendor 分支同步 ===" -ForegroundColor Cyan

git fetch upstream --tags

if (-not $Ref) {
    $Ref = "upstream/main"
    Write-Host "未指定 ref，使用: $Ref"
}

# tag 则推导版本线分支名（0.1.5 / v0.1.5 → vendor/v0.1.x），否则用 vendor/main
if ($Ref -match '^v?(\d+)\.(\d+)\.') {
    $vendorBranch = "vendor/v$($Matches[1]).$($Matches[2]).x"
} else {
    $vendorBranch = "vendor/main"
}

Write-Host "目标 ref: $Ref"
Write-Host "Vendor 分支: $vendorBranch"

$currentBranch = git branch --show-current
git rev-parse --verify "$vendorBranch" 2>$null | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "创建新 vendor 分支 $vendorBranch ..." -ForegroundColor Yellow
    git switch -c $vendorBranch $Ref
} else {
    git switch $vendorBranch
    Write-Host "合并 $Ref 到 $vendorBranch ..." -ForegroundColor Yellow
    git merge --no-edit $Ref
}

if ($Push) {
    git push origin $vendorBranch
    Write-Host "已推送到 origin/$vendorBranch" -ForegroundColor Green
}

git switch $currentBranch
Write-Host "`n完成。Vendor 分支 $vendorBranch 已同步到 $Ref" -ForegroundColor Green
Write-Host "合并到 custom/main 必须走 ccgui-merge-upstream skill，禁止手动 merge" -ForegroundColor Yellow
