---
current_upstream_version: 'main@8ba39913'
current_upstream_commit: '8ba39913b8cc2bef4c0ad3ea975f078e2ca5f1a9'
custom_version: 'v0.1.5-custom.1'
last_merge_date: '2026-09-23'
last_release_version: 'v0.1.5-custom.1'
last_release_date: '2026-10-09'
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
- **最近一次发布版本**：v0.1.5-custom.1（2026-10-09，首个发布）

---

## 改动总览（按文件）

> **每个文件一条**：该文件当前生效的全部自定义改动（多轮演进已合并）；「标记」列为代码中 `[CUSTOM-BEGIN]` 的 change-id（即该文件自定义区的当前真相），演进链标注历轮 id。代码位置速查见 [`architecture.md`](./architecture.md) §1。
>
> **状态字典**：`active`（生效中）/ `deprecated`（已废弃）/ `merged-upstream`（上游已原生支持）。**冲突策略**字典见 README.md。

| 文件 | 标记（当前） | 演进链 | 当前效果（合并后） | 冲突策略 | 状态 |
| --- | --- | --- | --- | --- | --- |
| package.json | （无标记，json 无法注释） | 20260923-001→20261009-002→20261009-003 | fork 标识：`name` → `custom-vscode-cc-gui`、`publisher` → `zouv`（⇒ 扩展 ID `zouv.custom-vscode-cc-gui`）、`displayName` → **`CC GUI (Custom)`**、`description` 标注 custom fork、`version` → `0.1.5-custom.1`。**CUSTOM-20261009-003 起内部命名空间全量改名**（与上游 vscode-cc-gui 同时安装不再冲突）：命令 id / 视图 id / 配置键 / 菜单 group / 上下文键一律 `ccGui.*` → `ccgc.*`，视图容器 `cc-gui-activity`/`cc-gui-secondary` → `ccgc-activity`/`ccgc-secondary`，提交菜单 group `1_ccgui@1` → `1_ccgc@1`。`scripts`、`devDependencies`、其余 `contributes` 仍沿用上游；`repository`/`author` 仍指向上游（归属声明，改市场链接时再动）。**CUSTOM-20261009-002** 在 `scripts` 新增 `dev:host`（→ `node CUSTOMIZATIONS/scripts/dev-host.mjs`）。**合并上游时注意**：`scripts` 块 + `contributes` 的所有 id + 三份 nls 键名是最可能冲突的区域，冲突时**一律保留 `ccgc.*` 侧**（映射见下节） | merge-manual | active |
| .vscodeignore | 20260923-001 | 20260923-001 | 新增排除 `CUSTOMIZATIONS/**`、`.agents/**`、`AGENTS.md`、`.gitattributes`、`dist/vsix/**`，以及本地工具/会话目录 `.claude/**`、`.zcode/**`、`.cursor/**`、`.codex/**`、`.mossx/**`、`.ace-tool/**`、`.continue/**`、`.windsurf/**`。**后者是关键**：vsce 打的是工作树而非 git（不读 `.gitignore`），首次打包实测混入了 5 个 `.claude/explore-results/` 子代理 transcript（~142 KB）。全部用普通模式、不用 `!`，避免与 vsce 的 force-include 语义打架 | merge-manual | active |
| .gitignore | 20260923-001 | 20260923-001 | 末尾追加窄口径忽略 `.claude/explore-results/` 与 `.zcode/plans/`。**注意本仓库不需要 `!.agents/` 反向豁免**——本上游已整目录忽略 `.claude/`，且未忽略 `.agents/`（与 custom-marktext 情况相反，不可照抄）；这两行是防御性再断言，防止将来有人加 `!.claude/` 时把会话产物暴露出来 | keep-ours | active |
| .gitattributes | （纯自定义文件） | 20260923-001 | fork 自建：`* text=auto eol=lf` + 二进制类型显式声明 + `*.bat`/`*.cmd` 保持 CRLF。应对本机 `core.autocrlf=true`（系统级+用户级）：不加会让重新 clone 的 `*.sh` 变成 CRLF 导致 `sh script.sh` 静默出错，并让构建生成的 `version.ts`/`changelog.ts` 出现幻影 `M`（`git diff` 为空、`git add` 后 blob 哈希不变）。实测加完后 `git add --renormalize .` 无内容变化（上游 blob 本就是 LF） | keep-ours | active |
| package-lock.json | （无标记，lock 随 install 重新生成） | 20260923-001 | 随根 `package.json` 的 name/version 变更重新生成（仅 root 的 `name`/`version` 两处字段，依赖解析不变） | 接受上游后 `npm install` 重新生成 | active |
| webview/src/version/version.ts | （无标记，构建自动生成） | 20260923-001 | 由 `webview/scripts/extract-version.mjs` 从根 `package.json` 的 version 生成 → `APP_VERSION = '0.1.5-custom.1'`。**勿手改**，每次 webview 构建无条件重写 | keep-ours | active |
| src/extension.ts、src/bridge.ts、src/panel.ts、src/quickFix.ts、src/setupWizard.ts、src/nodeDetector.ts、src/nodeRequirements.ts、src/bridge/services/SettingsStore.ts、src/bridge/handlers/ProviderHandler.ts | 20261009-003（均为**文件头标记**：整文件参与重命名，非某一段） | 20261009-003 | 上游文件内全部 `ccGui.*` 引用改名为 `ccgc.*`：`registerCommand`/`executeCommand`（含 `ccgc.mainView.focus`）、`getConfiguration('ccgc')`、`setContext('ccgc.enableDebugLog')`、`registerWebviewViewProvider('ccgc.mainView'/'ccgc.secondaryView')`、面板 viewType `ccgc.chatTab`、状态栏与 QuickFix 的命令 id、以及报错/提示文案里的配置键名。`src/bridge.ts` 另把输出通道名改为 `CC GUI (Custom)`（`[CC GUI]` 日志前缀保留为品牌名）。**零逻辑改动**，纯标识符改名 | merge-manual | active |
| package.nls.json、package.nls.zh-cn.json、package.nls.zh-tw.json | （无标记，json 无法注释） | 20261009-003 | 22 个键名全部 `ccGui.*` → `ccgc.*`（**必须与 `package.json` 的 `%...%` 占位符逐字一致**，否则命令面板/视图标题显示成 `%ccgc.x%`）；6 个身份类键的值（两个 viewsContainer 标题、两个 view name、`command.category`、`configuration.title`）改为 `CC GUI (Custom)`；命令标题正文里的 "CC GUI"（如 `Open CC GUI`）保持品牌词不变——命令面板靠 category 前缀区分，不必逐条加后缀 | merge-manual | active |
| CUSTOMIZATIONS/（README.md、architecture.md、registry.md、docs/pitfalls.md、scripts/、src/、patches/、release-notes/） | （纯自定义目录） | 20260923-001→20261009-002→20261009-003 | 自定义机制（规则/账本/代码地图/坑点库）+ 脚本套件：`manager.sh`（三 npm 包统一入口，npm/VSIX 适配）、`package-vsix.sh`（打包 + `unzip -Z1` 内容断言 + SHA256SUMS）、`check-registry.sh`（三包布局扫描目标）、**`dev-host.mjs`（`npm run dev:host`：构建 + 启动 Extension Development Host，宿主环境对齐 `.vscode/launch.json` 的 `.vscode-dev` 隔离 profile，可传任意工作区目录；参照 custom-vscode-acp 同名脚本）**、`init-repo.ps1` / `list-custom.ps1` / `sync-vendor.ps1`（vendor/main 分支模型 + 上游无 v 前缀 tag 的正则）、`publish-release.mjs`（GCM token + REST API，幂等；已剥离参考项目专为 CI 抢正文写的 `--body-only`/`--wait`）。**不移植** 7za-shim 与 `build-*.bat`（Electron/winCodeSign 专有问题，VSIX 打包不需要），**也不移植** acp 的 `check-webview-client.mjs`（那个问题源自 acp 的内联客户端脚本模板；本仓库 webview 是 Vite 构建，不经此路） | keep-ours | active |
| AGENTS.md | （纯自定义文件） | 20260923-001 | 会话级硬约束 + 工作流 + 技术栈 + 构建命令 + 分支规则 + skill 触发表 + 文档更新职责表。首行为沿袭参考项目的个性化指令 | keep-ours | active |
| .agents/skills/* | （纯自定义文件） | 20260923-001 | 4 个 skill：`ccgui-record-change` / `ccgui-merge-upstream` / `ccgui-release`（源码→VSIX）/ `ccgui-publish`（VSIX→GitHub Release） | keep-ours | active |

### 命名空间映射（CUSTOM-20261009-003）

上游 `vscode-cc-gui` 与本 fork 的标识符一律按下表替换。**合并上游后若任何非注释行出现左列形态，即为漏改**（`grep -rn "ccGui\|cc-gui-" src package.json package.nls*.json | grep -v "重命名"`）：

- `ccGui.` → `ccgc.`：命令 id、配置键、上下文键、view id（`ccGui.mainView` → `ccgc.mainView`）、nls 占位符与键名（`%ccGui.command.x.title%` → `%ccgc.command.x.title%`）
- `cc-gui-activity` → `ccgc-activity`、`cc-gui-secondary` → `ccgc-secondary`（视图容器 id）
- `1_ccgui@1` → `1_ccgc@1`（SCM 菜单 group）、`ccGui@N` → `ccgc@N`（编辑器右键菜单 group）
- 显示名：`CCGUI / CC GUI（custom fork · …）` → `CC GUI (Custom)`；输出通道名 `CC GUI` → `CC GUI (Custom)`

**刻意不改**（不是 VS Code 全局命名空间，改了只是徒增上游 diff）：webview 内部的 CSS 变量与 id（`--cc-gui-*-font-family`、`cc-gui-ui-font-face-style`）、拖拽 MIME（`application/x-cc-gui-provider-sort`）、临时目录名（`cc-gui-diff`）、MCP User-Agent（`vscode-cc-gui-mcp-marketplace`）、日志前缀（`[CC GUI]`）、去掉 `ui` 的品牌词（`Open CC GUI`）。

---

## 变更日志

### 2026-10-09 - CUSTOM-20261009-004（发布 `v0.1.5-custom.1`：首个 GitHub Release）

- **功能**：首个自定义版本发布（不是代码改动，是登记动作）
- **改动文件**：`CUSTOMIZATIONS/release-notes/v0.1.5-custom.1.md`（新增）、`CUSTOMIZATIONS/registry.md`（frontmatter 的 `last_release_version`/`last_release_date` + 仓库信息节）
- **详细说明**：
  - 版本号取 `<上游版本>-custom.<N>`，N 从 1 起（此前无任何 `v*-custom.*` tag）；`package.json` 的 `version` 早在初始化时就是 `0.1.5-custom.1`，本次**无需 bump**
  - **标 `--prerelease`**：基线 `main@8ba39913` 不是正式 tag——`git describe --tags 8ba39913` = `0.1.5-1-g8ba3991`（tag `0.1.5` 之后的一个 merge commit）
  - 发布走 `CUSTOMIZATIONS/scripts/publish-release.mjs`（从 `origin` 推导仓库，避开双 remote 下 gh 默认打到上游的坑；pitfall #7）
  - 本次发布覆盖 CUSTOM-20260923-001（基建）、20261009-002（`dev:host`）、20261009-003（改名 `CC GUI (Custom)` + `ccgc.*` 命名空间）三批改动
- **验证方式**：
  - `manager.sh typecheck`：上游基线 8 错、无新增；root 测试 236 + 239 + 4 全过；`check-registry.sh` 全绿
  - 打包产物内容断言 14/14 通过：177 文件 / 3.48 MB，sha256 `d51cc1db…`；**解包核验 manifest**——`displayName=CC GUI (Custom)`、13 个 `ccgc.*` 命令、3 个 `ccgc.*` 配置键、容器 `ccgc-activity`/`ccgc-secondary`、`ccGui` 残留 0
  - `gh repo view` 确认解析到 `zouv/custom-vscode-cc-gui`
  - `publish-release.mjs --dry-run` 先干跑，正式发布后 `gh release view` 核对（draft=false / prerelease=true / 2 个资产 uploaded）
- **基于上游版本**：main@8ba39913

### 2026-10-09 - CUSTOM-20261009-003（显示名 `CC GUI (Custom)` + 内部命名空间全量改名 `ccGui.*` → `ccgc.*`）

- **功能**：显示名改为 `CC GUI (Custom)`；把内部**全局可冲突标识符**从上游的 `ccGui.*` / `cc-gui-*` 全量改名为 `ccgc.*` / `ccgc-*`，使本 fork 可与上游 vscode-cc-gui 同时安装而不互相干扰（推翻 CUSTOM-20260923-001 的「刻意不改」决定，用户明确选择 acp 式全量改名）
- **改动文件**：`package.json`、`package.nls.json`、`package.nls.zh-cn.json`、`package.nls.zh-tw.json`、`src/{extension,bridge,panel,quickFix,setupWizard,nodeDetector,nodeRequirements}.ts`、`src/bridge/services/SettingsStore.ts`、`src/bridge/handlers/ProviderHandler.ts`（后 9 个加**文件头标记**）；`CUSTOMIZATIONS/{README,architecture,registry}.md`、`AGENTS.md`、`CUSTOMIZATIONS/scripts/dev-host.mjs`（提示文案）
- **详细说明**：
  - **改名范围**（映射表见总览「命名空间映射」节）：命令 id 13 个、配置键 3 个、上下文键 1 个、view id 2 个、视图容器 id 2 个、菜单 group、面板 viewType `ccgc.chatTab`；三份 nls 的 22 个**键名**同步改（必须与 `package.json` 的 `%...%` 占位符逐字一致，否则标题会原样显示 `%ccgc.x%`）
  - **身份类文案**：显示名、两个 viewsContainer 标题、两个 view name、`command.category`、`configuration.title` → `CC GUI (Custom)`；输出通道名 → `CC GUI (Custom)`。命令标题正文里的品牌词（`Open CC GUI` 等）**保持不动**——命令面板的区分靠 category 前缀，逐条加后缀只会让标题变长
  - **刻意不改**：webview 内部的 CSS 变量/元素 id、拖拽 MIME、临时目录名、MCP User-Agent、日志前缀 `[CC GUI]`——它们不是 VS Code 命名空间，跨插件不冲突，改了纯属制造上游 diff
  - **标记策略**：整文件参与重命名的上游 `.ts` 沿用 acp 的**文件头标记**（`[CUSTOM-BEGIN] CUSTOM-20261009-003 - 全局命名空间重命名…`），而不是逐处包裹——20+ 个标识符散在各处，逐处标记既不可读也无意义；三份 nls 与 `package.json` 是 JSON，**无标记**（已知缺口，总览已注）
  - **合并上游时的判断口诀**：`grep -rn "ccGui\|cc-gui-" src package.json package.nls*.json | grep -v "重命名"` — 除标记注释自身外有任何命中即漏改
- **验证方式**：
  - 残留扫描：`src/`、`webview/src/`、`ai-bridge/`、`scripts/`、`package.json`、三份 `package.nls*.json` 内 `ccGui` **零命中**（只剩 9 个 .ts 文件头部标记注释里描述本次改名的那两行，属预期）
  - **占位符 ↔ 键名机械比对**：`package.json` 的 22 个 `%...%` 占位符与三份 nls 的 22 个键**一一对应（缺 0 / 多余 0）**——这是"标题显示成 `%ccgc.x%`"这类错误的唯一判据，比肉眼看窗口可靠
  - **配置键一致性**：代码里 `getConfiguration('ccgc')` + `affectsConfiguration('ccgc.enableDebugLog')` + `setContext('ccgc.enableDebugLog')` 与 `package.json` 声明的 3 个 `ccgc.*` 属性对得上（`ccgc.autoSyncActiveFile` 仍是上游遗留的"声明但没人读"，见 §3 已知缺口）
  - `manager.sh typecheck`：**仍是上游基线的 8 个错误、无新增**（pitfalls #9）——改名未引入类型问题
  - **实跑宿主激活**：重新 `npm run dev:host` 后进程表出现**新的** `node ...ai-bridge/daemon.js`（PID 与上一次不同）——该进程只可能由改名后的 `dist/extension.js` 里 `BridgeServer._startBridge` spawn，证明改名后的扩展在真实宿主里照常激活
  - `sh CUSTOMIZATIONS/scripts/check-registry.sh` 全绿
- **基于上游版本**：main@8ba39913

### 2026-10-09 - CUSTOM-20261009-002（`npm run dev:host`：一条命令构建 + 启动开发宿主）

- **功能**：新增 `npm run dev:host`，一条命令完成「构建 → 拉起 Extension Development Host」，可指定任意目录当工作区（供手工点击验收，与 F5 等价但不下断点）
- **改动文件**：`CUSTOMIZATIONS/scripts/dev-host.mjs`（新增）、`package.json`（`scripts` 新增一行）、`AGENTS.md`（构建命令节）、`CUSTOMIZATIONS/README.md`（目录结构注释）、`CUSTOMIZATIONS/architecture.md`（§0.5 路由表）
- **详细说明**：
  - **参照 custom-vscode-acp 的同名脚本**移植，写 Node 而非 shell 的理由相同：npm 在 Windows 走 cmd.exe、POSIX 走 sh，`%CD%`/`$PWD` 互不通用，而 `--extensionDevelopmentPath` 要**绝对路径**；再者本脚本还要支持「把任意相对路径解析成绝对路径」（`resolve(positional[0])`），写在 shell 里就是两套方言
  - **适配本仓库的三处差异**：①构建命令用 `npm run build:debug`（宿主 sourcemap + webview），而非 acp 的 `npm run compile`——与本仓库 `.vscode/launch.json` 的 `preLaunchTask` 对齐；②默认带**隔离 profile**（`--user-data-dir`/`--extensions-dir` 指向 `.vscode-dev/`、`--disable-extensions`），即「F5 的环境、只是没有调试器」，`--no-isolate` 可关掉；③自动补 `--disable-workspace-trust`——本扩展未声明 `capabilities.untrustedWorkspaces`，**在不受信任的工作区会被 VS Code 静默禁用**，而本脚本的典型用法正是「打开一个别的项目目录」（首个用例 `D:\Git\zdev\zdev_ai_goal_loop\ai-storyforge`），不关这道门会表现为「窗口起来了但扩展像没装」
  - 额外做了 acp 没有的两处小加固：位置参数多于一个时报错退出；工作区目录不存在时报错退出（挡住路径拼错/被 shell 吃掉的情况）
  - acp 的另一个自定义 npm 脚本 `precompile`（`check-webview-client.mjs`）**不移植**：它拦的是 acp 里内联进 HTML 的客户端脚本模板中的反引号问题，本仓库 webview 是 React + Vite 构建，不存在那条路径
- **验证方式**：
  - `npm run dev:host -- --help` 正常打印用法（确认 npm → Node 链路通）
  - 实跑 `npm run dev:host -- "D:\Git\zdev\zdev_ai_goal_loop\ai-storyforge"`：构建成功（webview `✓ built in 26.89s`）→ 打印扩展路径/工作区/隔离状态 → 宿主窗口起来
  - **扩展确实激活**（不只是窗口打开）：进程表里出现 `node ...\custom-vscode-cc-gui\ai-bridge\daemon.js`——该进程只可能由 `BridgeServer._startBridge` spawn，而本机并未安装任何 cc-gui 扩展，故必然是 dev-path 扩展加载后所为（`.vscode-dev/` 也是本次首次创建）
  - 新脚本为 LF（`grep -c $'\r'` = 0），符合 `.gitattributes` 的 `eol=lf`
  - `sh CUSTOMIZATIONS/scripts/check-registry.sh` 全绿
- **基于上游版本**：main@8ba39913

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
