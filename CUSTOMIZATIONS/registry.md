---
current_upstream_version: 'main@8ba39913'
current_upstream_commit: '8ba39913b8cc2bef4c0ad3ea975f078e2ca5f1a9'
custom_version: 'v0.1.5-custom.1'
last_merge_date: '2026-09-23'
last_release_version: ''
last_release_date: ''
vendor_branch: 'vendor/main'
upstream_remote: 'https://github.com/hpstream/vscode-cc-gui.git'
---

# custom-vscode-cc-gui 自定义改动登记

> **本文件是改动登记账本（纯数据）**。机制与规则（冲突策略、标记格式、类型/状态字典、frontmatter 字段职责）见 [`CUSTOMIZATIONS/README.md`](./README.md)。
>
> **两层结构（怎么用）**：
>
> - **改动总览（按文件）**——查"某个文件现在改了什么、上游合并时怎么处理"：**只读这一节**，每个文件一条，多轮演进已合并为当前状态，无需读历史轮次。
> - **变更日志（按次）**——查"某次改动何时发生、为什么、怎么验证"：按时间倒序的 append-only 流水，只增不改（历史是事实）。
>
> **AI Agent 注意**：
>
> 1. 开发前读**改动总览**定位相关文件与冲突策略（不必通读变更日志）
> 2. 完成改动后调用 `ccgui-record-change` skill：**总览里已有该文件就更新那一节**（合并描述、追加演进链 id），没有就新增一节；变更日志追加一轮记录
> 3. 合并上游时按总览的冲突策略列处理
> 4. 不要删除历史（总览条目整体废弃时标 deprecated，变更日志永不删改）
> 5. 一致性自检：`sh CUSTOMIZATIONS/scripts/check-registry.sh`（代码标记 ↔ 总览表双向比对）

---

## 仓库信息

- **上游仓库**：https://github.com/hpstream/vscode-cc-gui
- **当前基于上游版本**：main@8ba39913（v0.1.5）
- **当前基于上游 Commit**：8ba39913b8cc2bef4c0ad3ea975f078e2ca5f1a9
- **当前 Vendor 分支**：vendor/main
- **最近一次上游合并**：2026-09-23（初始化）
- **最近一次发布版本**：（尚未发布）

---

## 改动总览（按文件）

> **每个文件一条**：该文件当前生效的全部自定义改动（多轮演进已合并）；「标记」列为代码中 `[CUSTOM-BEGIN]` 的 change-id（即该文件自定义区的当前真相），演进链标注历轮 id。代码位置速查见 [`architecture.md`](./architecture.md) §1。
>
> **状态字典**：`active`（生效中）/ `deprecated`（已废弃）/ `merged-upstream`（上游已原生支持）。**冲突策略**字典见 README.md。

| 文件 | 标记（当前） | 演进链 | 当前效果（合并后） | 冲突策略 | 状态 |
| --- | --- | --- | --- | --- | --- |
| package.json | （无标记，json 无法注释） | 20260923-001 | fork 标识：`name` → `custom-vscode-cc-gui`、`publisher` → `zouv`（⇒ 扩展 ID `zouv.custom-vscode-cc-gui`）、`displayName` 加 `custom fork` 后缀、`version` → `0.1.5-custom.1`。**内部 `ccGui.*` / `cc-gui-*` 命名空间、`scripts`、`devDependencies`、`contributes` 全部沿用上游**（用户选择最小改动项：解决"被当成上游版本升级"，但不追求与上游插件真正共存）；`repository`/`author` 仍指向上游（归属声明，改市场链接时再动） | merge-manual | active |
| .vscodeignore | 20260923-001 | 20260923-001 | 新增排除 `CUSTOMIZATIONS/**`、`.agents/**`、`AGENTS.md`、`.gitattributes`、`dist/vsix/**`，以及本地工具/会话目录 `.claude/**`、`.zcode/**`、`.cursor/**`、`.codex/**`、`.mossx/**`、`.ace-tool/**`、`.continue/**`、`.windsurf/**`。**后者是关键**：vsce 打的是工作树而非 git（不读 `.gitignore`），首次打包实测混入了 5 个 `.claude/explore-results/` 子代理 transcript（~142 KB）。全部用普通模式、不用 `!`，避免与 vsce 的 force-include 语义打架 | merge-manual | active |
| .gitignore | 20260923-001 | 20260923-001 | 末尾追加窄口径忽略 `.claude/explore-results/` 与 `.zcode/plans/`。**注意本仓库不需要 `!.agents/` 反向豁免**——本上游已整目录忽略 `.claude/`，且未忽略 `.agents/`（与 custom-marktext 情况相反，不可照抄）；这两行是防御性再断言，防止将来有人加 `!.claude/` 时把会话产物暴露出来 | keep-ours | active |
| .gitattributes | （纯自定义文件） | 20260923-001 | fork 自建：`* text=auto eol=lf` + 二进制类型显式声明 + `*.bat`/`*.cmd` 保持 CRLF。应对本机 `core.autocrlf=true`（系统级+用户级）：不加会让重新 clone 的 `*.sh` 变成 CRLF 导致 `sh script.sh` 静默出错，并让构建生成的 `version.ts`/`changelog.ts` 出现幻影 `M`（`git diff` 为空、`git add` 后 blob 哈希不变）。实测加完后 `git add --renormalize .` 无内容变化（上游 blob 本就是 LF） | keep-ours | active |
| package-lock.json | （无标记，lock 随 install 重新生成） | 20260923-001 | 随根 `package.json` 的 name/version 变更重新生成（仅 root 的 `name`/`version` 两处字段，依赖解析不变） | 接受上游后 `npm install` 重新生成 | active |
| webview/src/version/version.ts | （无标记，构建自动生成） | 20260923-001 | 由 `webview/scripts/extract-version.mjs` 从根 `package.json` 的 version 生成 → `APP_VERSION = '0.1.5-custom.1'`。**勿手改**，每次 webview 构建无条件重写 | keep-ours | active |
| CUSTOMIZATIONS/（README.md、architecture.md、registry.md、docs/pitfalls.md、scripts/、src/、patches/、release-notes/） | （纯自定义目录） | 20260923-001 | 自定义机制（规则/账本/代码地图/坑点库）+ 脚本套件：`manager.sh`（三 npm 包统一入口，npm/VSIX 适配）、`package-vsix.sh`（打包 + `unzip -Z1` 内容断言 + SHA256SUMS）、`check-registry.sh`（三包布局扫描目标）、`init-repo.ps1` / `list-custom.ps1` / `sync-vendor.ps1`（vendor/main 分支模型 + 上游无 v 前缀 tag 的正则）、`publish-release.mjs`（GCM token + REST API，幂等；已剥离参考项目专为 CI 抢正文写的 `--body-only`/`--wait`）。**不移植** 7za-shim 与 `build-*.bat`（Electron/winCodeSign 专有问题，VSIX 打包不需要） | keep-ours | active |
| AGENTS.md | （纯自定义文件） | 20260923-001 | 会话级硬约束 + 工作流 + 技术栈 + 构建命令 + 分支规则 + skill 触发表 + 文档更新职责表。首行为沿袭参考项目的个性化指令 | keep-ours | active |
| .agents/skills/* | （纯自定义文件） | 20260923-001 | 4 个 skill：`ccgui-record-change` / `ccgui-merge-upstream` / `ccgui-release`（源码→VSIX）/ `ccgui-publish`（VSIX→GitHub Release） | keep-ours | active |

---

## 变更日志

### 2026-09-23 - CUSTOM-20260923-001（初始化 custom-vscode-cc-gui 仓库）

- **功能**：初始化自定义 fork 仓库（自定义开发文档体系 + 脚本套件 + 首个构建基线）
- **改动文件**：`.gitignore`、`.vscodeignore`、`.gitattributes`（新增）、`package.json`、`package-lock.json`、`webview/src/version/version.ts`；`AGENTS.md`（新增）、`CUSTOMIZATIONS/`（README.md、architecture.md、registry.md、docs/pitfalls.md、scripts/×7、src/.gitkeep、patches/.gitkeep、release-notes/.gitkeep）、`.agents/skills/ccgui-{record-change,merge-upstream,release,publish}/SKILL.md`（新增）
- **详细说明**：
  - **仓库结构**：目标目录非空（含活跃的 `.claude/explore-results/` 会话产物），故**不能用 `git clone`**——改用 `git init -b main` + `git fetch upstream --tags`，再建 `vendor/main`（= upstream/main HEAD，只读基线）与 `custom/main`。**不建本地 `main`**（与 `vendor/main` 语义重复）。`git config remote.origin.gh-resolved base` 防「双 remote 下 gh 默认打到上游」（pitfalls #7）
  - **扩展标识**：`MossX.vscode-cc-gui` → `zouv.custom-vscode-cc-gui`。**刻意不改**内部 `ccGui.*` 命令/配置与 `cc-gui-*` 视图容器共 20+ 个 ID——改它们要同步动 `src/extension.ts` 注册代码、三份 `package.nls*.json` 与 webview 引用，且此后每次合并上游都要重贴标记；代价是两插件无法真正共存（同时启用会有重复贡献告警）。用户明确选择最小改动项
  - **三包 npm 构建**：本仓库是根/`webview`/`ai-bridge` 三个独立 npm 包，无 workspace 根，依赖必须分别安装。`ai-bridge` 的 `sql.js` 靠 `.vscodeignore` 白名单进 VSIX（非依赖检测），漏装会打出"能装上但运行期崩"的包（pitfalls #3）
  - **测试执行器**：`manager.sh` **不委托 `npm run test:ext`**，改为直接 `node --test "<glob>"`。因为 Windows 下 npm 经 `cmd.exe` 执行脚本，单引号不是引号字符，node 收到带引号的字面 glob → 匹配 0 文件 → 输出 `1..0` 并**以 0 退出**（静默假绿）。同一条命令 Git Bash 直跑 236 用例全过、`cmd //c` 跑 0 用例，已实证（pitfalls #10）
  - **打包断言**：`package-vsix.sh` 用 `unzip -Z1`（只列文件名）而非 `unzip -l`——后者头部 `Archive:` 行会让 `dist/vsix/` 关键字误命中（首次实测的假阳性）；同时把 `.claude/`、`.zcode/` 等本地目录加入 deny 列表（首次实测的真漏包）
  - **与参考项目的差异**：不移植 `7za-shim.{cs,exe}` 与 `build-{unpacked,setup}.bat`（Electron `electron-builder`+`winCodeSign` 在无 symlink 权限机器上的专有问题，VSIX 打包链路不经过它）；`publish-release.mjs` 剥离 `--body-only`/`--wait` 及轮询（参考项目用它对付上游 CI 抢写 release 正文，本仓库上游**零 CI**，不存在该问题），改为默认上传 `dist/vsix/<name>-<version>.vsix` + `SHA256SUMS.txt`
  - **修正参考项目一处潜伏 bug**：`list-custom.ps1` 读 frontmatter 的正则用双引号匹配，而 frontmatter 实为单引号，正则从未命中、一直静默走硬编码默认值。本仓库改为兼容两种引号（pitfalls #11）
- **验证方式**：
  - 纯净基线（`vendor/main` = `upstream/main` = `8ba39913`）实测：根 `src/__tests__` **236 通过/0 失败**；`subagentSidechain.test.mts` 3 通过；`scripts/**` 4 通过；`ai-bridge/**` 233 跑/**2 失败**；根 `tsc --noEmit` **8 错误**；webview vitest 107 文件/**925 全通过**，但其 `npm test` 的第二段类型检查有 4 错误故退出码 2。以上既有缺口均**原样记录、不在初始化提交里修**（见 pitfalls #9）
  - 三个包 `npm install` 成功（webview 545 MB）；`npm run build` 成功（`dist/extension.js` 310.8 KB + webview 单包 IIFE）
  - `sh CUSTOMIZATIONS/scripts/manager.sh package` 产出 `dist/vsix/custom-vscode-cc-gui-0.1.5-custom.1.vsix`（**177 文件 / 3.48 MB**，sha256 `f72b4612…`），`unzip -Z1` 内容断言 **14/14 全过**（6 项必含：`dist/extension.js`、`webview/dist/index.html`、`ai-bridge/daemon.js`、`sql.js/dist/sql-wasm.wasm`、`media/icon.png`、`package.json`；8 项必不含：`CUSTOMIZATIONS/`、`.agents/`、`AGENTS.md`、`dist/vsix/`、`src/`、`node_modules/`、`.claude/`、`.zcode/` 等），`SHA256SUMS.txt` 已生成
  - **内容断言真实拦下两类缺陷**（这正是它存在的意义）：① 假阳性——`unzip -l` 头部 `Archive:` 行让 `dist/vsix/` 关键字误命中，改用 `unzip -Z1` 修正；② **真漏包**——首轮产出 182 文件，其中 5 个 `.claude/explore-results/` 子代理 transcript（~142 KB）被打进公开 VSIX，因为 vsce 打的是**工作树而非 git**（不读 `.gitignore`）。补 `.vscodeignore` 规则后降至 177 文件
  - `webview/src/version/version.ts` 出现 `APP_VERSION = '0.1.5-custom.1'`，证明版本链路贯通
  - `git check-ignore -v .claude/explore-results/<f>` 命中上游 `.gitignore:47:.claude/`；`git check-ignore .agents/skills/...` 无输出（可跟踪）
- **基于上游版本**：main@8ba39913

### _(初始创建)_

- 基于上游 vscode-cc-gui（main@8ba39913）创建自定义分支
- 初始化 CUSTOMIZATIONS 目录结构和追踪体系
