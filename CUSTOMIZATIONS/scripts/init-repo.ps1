#!/usr/bin/env pwsh
<#
.SYNOPSIS
    初始化 custom-vscode-cc-gui 自定义开发仓库结构。
.DESCRIPTION
    用于在 clone 本仓库后一键配置 upstream remote、创建分支结构、校验
    CUSTOMIZATIONS 目录完整性。幂等：已存在的配置跳过。
    （首次初始化已由 2026-09-23 完成，此脚本主要供重新 clone 后使用。）
.PARAMETER UpstreamUrl
    上游仓库 URL
.PARAMETER BaseRef
    基线 ref，默认 upstream/main
#>

param(
    [string]$UpstreamUrl = "https://github.com/hpstream/vscode-cc-gui.git",
    [string]$BaseRef = "upstream/main"
)

$ErrorActionPreference = "Stop"

Write-Host "=== custom-vscode-cc-gui 自定义仓库初始化 ===" -ForegroundColor Cyan

if (-not (Test-Path ".git")) {
    Write-Error "当前目录不是 git 仓库"
    exit 1
}
if (-not (Test-Path "CUSTOMIZATIONS/registry.md")) {
    Write-Error "未找到 CUSTOMIZATIONS/registry.md（本仓库应从 zouv/custom-vscode-cc-gui clone，含完整机制目录）"
    exit 1
}

# [1] 配置 upstream
Write-Host "`n[1/5] 配置 upstream remote..." -ForegroundColor Yellow
$existingUpstream = git remote get-url upstream 2>$null
if ($LASTEXITCODE -eq 0 -and $existingUpstream) {
    Write-Host "  upstream 已存在: $existingUpstream"
    if ($existingUpstream -ne $UpstreamUrl) {
        git remote set-url upstream $UpstreamUrl
        Write-Host "  已更新为: $UpstreamUrl"
    }
} else {
    git remote add upstream $UpstreamUrl
    Write-Host "  已添加 upstream: $UpstreamUrl"
}

# [2] gh 仓库解析（pitfall #7）
# 本仓库有 origin(zouv/custom-vscode-cc-gui) 与 upstream(hpstream/vscode-cc-gui) 两个
# remote，不带 --repo 的 gh 命令默认解析到**上游**。此配置写在 .git/config，不随仓库
# 分发，重新 clone 后必须重做——所以放在 init 脚本里每次自动兜住。
Write-Host "`n[2/5] 配置 gh 仓库解析（防止 gh 命令打到上游）..." -ForegroundColor Yellow
$ghResolved = git config --get remote.origin.gh-resolved 2>$null
if ($LASTEXITCODE -eq 0 -and $ghResolved) {
    Write-Host "  remote.origin.gh-resolved 已设置: $ghResolved"
} else {
    git config remote.origin.gh-resolved base
    Write-Host "  已设置 remote.origin.gh-resolved=base"
}

# [3] Fetch 上游
Write-Host "`n[3/5] 获取上游信息（main + tags）..." -ForegroundColor Yellow
git fetch upstream main --tags
if ($LASTEXITCODE -ne 0) { Write-Error "git fetch upstream 失败"; exit 1 }

# [4] 校验分支结构
Write-Host "`n[4/5] 校验分支结构..." -ForegroundColor Yellow
foreach ($b in @("vendor/main", "custom/main")) {
    git rev-parse --verify $b 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        if ($b -eq "vendor/main") {
            git branch vendor/main upstream/main
            Write-Host "  已创建 vendor/main (基于 upstream/main)"
        } else {
            git branch custom/main vendor/main
            Write-Host "  已创建 custom/main"
        }
    } else {
        Write-Host "  $b 已存在"
    }
}
git switch custom/main

# [5] 一致性自检
Write-Host "`n[5/5] registry 一致性自检..." -ForegroundColor Yellow
sh CUSTOMIZATIONS/scripts/check-registry.sh

Write-Host "`n=== 初始化完成 ===" -ForegroundColor Green
Write-Host "当前分支: $(git branch --show-current)"
Write-Host "基线: $BaseRef ($(git rev-parse --short $BaseRef))"
Write-Host ""
Write-Host "下一步："
Write-Host "  - 在 custom/main 上开发，完成后用 ccgui-record-change 记录改动"
Write-Host "  - 合并上游版本时用 ccgui-merge-upstream"
Write-Host "  - 打包 VSIX 用 ccgui-release，发布到 GitHub 用 ccgui-publish"
Write-Host ""
Write-Host "注意：若尚未推送过，GitHub 默认分支 main 会指向不存在的分支，推送后执行：" -ForegroundColor Yellow
Write-Host "  gh repo edit zouv/custom-vscode-cc-gui --default-branch custom/main"
