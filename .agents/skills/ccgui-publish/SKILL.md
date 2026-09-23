---
name: 'ccgui-publish'
description: 'Publish the custom VSIX of custom-vscode-cc-gui to GitHub Release (release notes, annotated tag, upload). Invoke when user asks to publish, release, upload, tag, or push a release to GitHub. 本地打包请用 ccgui-release skill。'
---

# custom-vscode-cc-gui 发布 Skill

把版本号 + VSIX 产物**发布成 GitHub Release**，终点是 `https://github.com/zouv/custom-vscode-cc-gui/releases/tag/v<版本>`。

**本地打包（源码 → `.vsix`）在 `ccgui-release` skill** —— 如果产物还没打出来，先去那边。

## 触发条件

- 用户说"发布"、"发版"、"上传 release"、"打个 tag 推上去"
- release notes 已写好、VSIX 已打好，要把它们挂到 GitHub

## 参数收集

1. **版本号**：`v<上游版本>-custom.<N>`（如 `v0.1.5-custom.1`）。tag 带 `v` 前缀，`package.json` 里的 version **不带**。
2. **是否预发布**：基线若不是正式 tag（而是 `main@<hash>`），按规范标 `--prerelease`。

## 前置检查

```bash
git branch --show-current          # 必须是 custom/main
git status --porcelain             # 必须干净（发布提交前的状态由本流程自己产生）
sh CUSTOMIZATIONS/scripts/check-registry.sh    # 必须全绿
node -p "require('./package.json').version"    # 应等于去掉 v 的版本号
ls dist/vsix/                      # 应已有 <name>-<version>.vsix 与 SHA256SUMS.txt
```

**gh 仓库解析**（pitfall #7）：本仓库有 `origin` 与 `upstream` 两个 remote，不带 `--repo` 的 gh 命令**默认打到上游**。发布前先确认：

```bash
gh repo view --json nameWithOwner      # 必须是 zouv/custom-vscode-cc-gui
```

若输出上游仓库：`gh repo set-default zouv/custom-vscode-cc-gui`（或 `git config remote.origin.gh-resolved base`，`init-repo.ps1` 已自动设置，重新 clone 后需重做）。

## 执行流程

### 第一步：确认产物已就绪

若 `dist/vsix/` 为空，先走 `ccgui-release` skill 打包。**不要**在发布流程里顺手 build——那条链路的检查更完整。

### 第二步：写 release notes

新建 `CUSTOMIZATIONS/release-notes/<版本>.md`（如 `v0.1.5-custom.1.md`）。正文首行必须注明基于的上游版本：

```markdown
基于上游 vscode-cc-gui main@8ba39913（v0.1.5）

## 本次自定义内容

- …

## 已知问题

- 上游既有基线：`tsc --noEmit` 8 个错误、`ai-bridge` 2 个测试失败（见 pitfalls #9）
```

### 第三步：更新 registry.md frontmatter

在 `CUSTOMIZATIONS/registry.md` 顶部 frontmatter 更新（字段职责见 CUSTOMIZATIONS/README.md）：

- `custom_version`: `'v<版本>'`
- `last_release_version` / `last_release_date`

这属于登记动作，按 `ccgui-record-change` skill 的规范同时补一条变更日志。

### 第四步：提交并打 tag

```bash
git add -A
git commit -m "chore(release): bump version to v<版本>"

git tag -a v<版本> -m "Release v<版本>"
```

**tag 必须是 annotated**（`-a`），轻量 tag 在 release 流程里会缺元数据。

### 第五步：推送（**需用户明确同意**）

```bash
git push origin custom/main
git push origin v<版本>
```

### 第六步：发布 release

```bash
# 先干跑校验（不发任何网络请求）
node CUSTOMIZATIONS/scripts/publish-release.mjs v<版本> --prerelease --dry-run

# 正式发布
node CUSTOMIZATIONS/scripts/publish-release.mjs v<版本> --prerelease
```

脚本行为：从 Git Credential Manager 取 token（`git credential fill`，**不落盘、不回显**）→ 创建或复用 release（幂等）→ 正文按 release notes 覆盖 → 上传默认产物集（`dist/vsix/<name>-<version>.vsix` + `SHA256SUMS.txt`）→ 上传后校验远端字节数 → 打印远端资产清单。

`--sha256` 可在上传前重算 `SHA256SUMS.txt`，避免发出过期散列。

### 第七步：核对

```bash
gh release view v<版本> --repo zouv/custom-vscode-cc-gui
```

确认：`draft=false`、`prerelease` 符合预期、资产 2 个且 `state=uploaded`、正文前几行与 `release-notes/<版本>.md` 一致。

## 坑点与经验

### 1. gh 在双 remote 仓库默认解析到上游

本仓库 `origin`=zouv/custom-vscode-cc-gui、`upstream`=hpstream/vscode-cc-gui。不加 `--repo` 的 gh 命令会操作**上游**。人工排查一律带 `--repo zouv/custom-vscode-cc-gui`，或先 `gh repo set-default`。自动化发布走 `publish-release.mjs`（从 `git remote get-url origin` 推导仓库），不受此坑影响。

### 2. 本仓库上游零 CI，不存在"CI 抢写正文"问题

参考项目（marktext）需要 `--body-only --wait` 轮询，是因为它推 tag 会触发上游 CI 先创建 release 并覆盖正文。**本项目上游没有 `.github/`**，release 由脚本一次创建到位，故这些参数**已刻意不移植**。若将来本项目自己加了 CI 且会创建 release，需要重新引入该机制。

### 3. 匿名轮询 GitHub API 会撞限流

60 次/小时。`publish-release.mjs` 的 `--dry-run` 不发请求；正式发布只做少量调用，不要写轮询脚本。

### 4. tag 必须打在当前 HEAD 且已推送

脚本会自检：本地 tag 不存在时提示 `git tag -a`；tag 不是 HEAD 祖先时警告（多半是 amend 过提交）；`origin` 上没有该 tag 时提示 `git push origin <tag>`。这些警告**不要忽略**——发布出去的 tag 指向错误提交是难回滚的事故。

### 5. 管道会吃掉退出码

```bash
sh CUSTOMIZATIONS/scripts/manager.sh test 2>&1 | tail -60   # ❌ 退出码是 tail 的
```

### 6. 版本号两处一致性

`package.json` 的 `version`（不带 `v`）与 tag（带 `v`）必须对应。脚本用 `version.replace(/^v/,'')` 推导 vsix 文件名，对不上时会报"产物不存在"。

## 失败处理与回滚

| 阶段 | 失败现象 | 处置 |
| --- | --- | --- |
| 前置检查 | check-registry 不绿 | 先补登记，见 `ccgui-record-change` |
| 打包 | 内容断言不过 | 修 `.vscodeignore`，**不要**绕过断言上传 |
| 提交后 | push 被拒 | 拉取后重试；**禁止** `--force` 到 custom/main |
| tag 打错 | 指向了错误提交 | 本地 `git tag -d v<版本>` 重打；已推送则 `git push origin :refs/tags/v<版本>` 删除远端后重推（需用户确认） |
| release 挂了 | 资产缺失/正文错 | 脚本幂等，修好后**直接重跑**同一条命令即可 |

## 重要约束

1. **发布是外向操作**：`git push` 与创建 GitHub Release **必须由用户明确指示**才执行。本 skill 的流程本身就是用户发起的发布请求，流程内按步骤推送是预期行为；但流程中止（检查不通过、需要人工决策）时停在未提交状态，先报告再等指示
2. **不跳过 check-registry 与内容断言**
3. **不 force push 到 custom/main**
4. **tag 用 annotated（`-a`），且带 `v` 前缀**（上游 tag 大多无 `v`，前缀用于区分）
5. **release notes 必须归档**到 `CUSTOMIZATIONS/release-notes/<版本>.md`，且首行注明基于的上游版本
6. **baseline 不是正式 tag 时标 `--prerelease`**
