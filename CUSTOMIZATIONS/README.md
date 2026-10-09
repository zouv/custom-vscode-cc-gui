# CUSTOMIZATIONS —— 自定义开发机制说明

本目录是本仓库（custom-vscode-cc-gui）所有自定义开发内容的唯一家园。规则以本文档为唯一完整版（single source of truth），根目录 `AGENTS.md` 只保留会话级硬约束摘要。

## 项目背景

本仓库是 [hpstream/vscode-cc-gui](https://github.com/hpstream/vscode-cc-gui) 的自定义二次开发版，通过 git 历史与 `upstream` remote 与上游保持可合并关系。上游是 VS Code 扩展（Claude Code / Codex / OpenCode / Kimi / Grok 的图形界面），MIT 协议。

**与上游的三个结构性差异**（决定了很多规则）：

1. 本仓库是**三个独立的 npm 包**（根 / `webview/` / `ai-bridge/`），没有 workspace 根——依赖必须分别安装（见 pitfalls #3）。
2. 上游**零 CI**（无 `.github/`），发布完全靠本地脚本（见「发布路径」）。
3. 扩展 ID 已改为 `zouv.custom-vscode-cc-gui`，内部命名空间也从上游的 `ccGui.*` / `cc-gui-*` 全量改名为 `ccgc.*` / `ccgc-*`（CUSTOM-20261009-003，见 registry 总览 `package.json` 行）——显示名 `CC GUI (Custom)`，可与上游插件同时安装而不冲突。

## 目录结构

```
CUSTOMIZATIONS/
├── README.md        # 本文件：机制与规则完整版（唯一规则源）
├── architecture.md  # 代码链路图谱：文件职责 / 任务→代码位置 / 重点链路（面向 AI 的加速索引）
├── registry.md      # 账本：frontmatter 元数据 + 改动总览（按文件）+ 变更日志（按次）
├── docs/
│   └── pitfalls.md  # 历史坑点沉淀：现象→根因→解法→教训（动手前先扫标题）
├── release-notes/   # 各自定义版本的发布说明归档
├── src/             # 新增的自定义源码（独立模块，通过入口挂载）
├── patches/         # 对上游文件的补丁
└── scripts/         # manager / package-vsix / check-registry / dev-host / init-repo / list-custom / sync-vendor / publish-release
```

核心约定：**一处规则（README.md）、一处账本（registry.md）、一份代码地图（architecture.md）、一份坑点库（docs/pitfalls.md）**。规则改动只改本文件；改动登记只写 registry.md；代码结构变化同步 architecture.md；踩坑沉淀进 docs/pitfalls.md；自定义代码优先放 src/。

## registry.md 的两层结构

| 层           | 组织方式                           | 回答什么                           | 更新方式                            |
| ------------ | ---------------------------------- | ---------------------------------- | ----------------------------------- |
| **改动总览** | 按文件（一文件一节，多轮演进合并） | "这个文件现在改了什么？冲突策略？" | 已有该文件就更新该节，演进链追加 id |
| **变更日志** | 按次（时间倒序 append-only）       | "何时/为何/怎么验证"               | 顶部追加，永不改写历史              |

总览与代码 `[CUSTOM-BEGIN]` 标记一一对应（同一文件的"当前状态"镜像），`sh CUSTOMIZATIONS/scripts/check-registry.sh` 做双向一致性自检——**每次登记后必须跑到全绿**。

## 必须遵守的铁律

1. **开发前先读 `registry.md` 的改动总览**（不必通读变更日志）：了解相关文件已有什么改动、合并时怎么处理。
2. **改动后必须登记**：调用 `ccgui-record-change` skill（总览按文件合并更新 + 日志按次追加 + check-registry 全绿）。
3. **变更日志只增不改**；总览条目整体废弃时标 `deprecated` 而非删除。
4. **禁止手动 git merge/rebase**：跨上游合并必须走 `ccgui-merge-upstream` skill；禁止 rebase 改写 custom/main 历史。
5. **写代码前先读 `architecture.md`**：按 §0.5 任务路由只读相关文件，省上下文；改了代码结构后同步该文件。
6. **排查问题前先扫 `docs/pitfalls.md`**：新踩的坑解决后回写一条（现象→根因→解法→教训）。

## change-id 与代码标记

每个逻辑改动分配唯一 id：`CUSTOM-YYYYMMDD-NNN`（日期+序号），不可复用（同一标记块内追加修改除外）。

修改上游文件时，改动区域必须用标记包裹：

```
// [CUSTOM-BEGIN] CUSTOM-YYYYMMDD-NNN - <简要描述>
... 自定义代码 ...
// [CUSTOM-END] CUSTOM-YYYYMMDD-NNN
```

按文件类型选择注释语法：`.ts`/`.js`/`.mjs` 用 `//`，`.gitignore`/`.vscodeignore`/`.sh` 用 `#`，`.ps1` 用 `#`。`.json` / `.yaml` 等不支持注释的文件在 registry.md 总览标注「无标记（json 无法注释）」。

合并上游时：标记外的区域优先使用上游版本；`[CUSTOM-BEGIN]...[CUSTOM-END]` 块必须保留，上游重构导致位置漂移时按函数/组件名找新位置。

## 冲突策略速查

合并上游时，对冲突文件按以下策略处理（按优先级从高到低）：

| 优先级 | 条件                                        | 策略                                      |
| ------ | ------------------------------------------- | ----------------------------------------- |
| 1      | 文件在 `CUSTOMIZATIONS/src/` 目录下         | `keep-ours`（保留我们的）                 |
| 2      | 文件在 `CUSTOMIZATIONS/patches/` 目录下     | `keep-ours`                               |
| 3      | registry.md 条目标记 `keep-ours`            | `keep-ours`                               |
| 4      | registry.md 条目标记 `keep-theirs`          | `keep-theirs`（使用上游的）               |
| 5      | 文件是三份 `package-lock.json` 之一         | 接受上游版本后 `npm install` 重新生成     |
| 6      | 文件包含 `[CUSTOM-BEGIN]` 标记              | `merge-manual`（按标记块保留自定义代码）  |
| 7      | 其他文件                                    | `merge-manual`（AI 分析后合并）           |

- `keep-ours`：始终保留自定义版本，上游改动放弃
- `keep-theirs`：始终使用上游版本，自定义改动放弃
- `merge-manual`：需要 AI 逐块分析合并（默认）

`registry.md` 自身冲突必须人工决策后手动合并，并检查 frontmatter 合法性。本文件（README.md）策略为 `keep-ours`。

## 条目类型与状态字典

改动总览以文件为单位，不使用独立的 type 字段；纯自定义路径（`CUSTOMIZATIONS/`、`.agents/`、`AGENTS.md` 等）按 keep-ours 处理，上游文件按标记逐块合并。

状态（status）字段：

- `active`：当前生效中
- `deprecated`：已废弃/被替代
- `merged-upstream`：已被上游原生支持，无需保留
- `needs-migration`：跨大版本升级时需要适配迁移

## registry.md frontmatter 字段职责

| 字段                                                   | 更新时机                 | 负责方                  |
| ------------------------------------------------------ | ------------------------ | ----------------------- |
| `current_upstream_version` / `current_upstream_commit` | 上游合并后               | ccgui-merge-upstream    |
| `vendor_branch`                                        | 上游合并后（跨版本线时） | ccgui-merge-upstream    |
| `last_merge_date`                                      | 上游合并后               | ccgui-merge-upstream    |
| `last_release_version` / `last_release_date`           | 发布后                   | ccgui-publish           |
| `custom_version`                                       | 发布后                   | ccgui-publish           |
| `upstream_remote`                                      | 首次 clone 初始化        | init-repo.ps1           |

## 分支模型

上游开发在 `main` 分支，发布走 tag。基线采用 **commit 跟踪**（默认跟随 `upstream/main` 最新；也可用 tag 精确锚定）。

| 分支            | 用途                          | 对应上游                        |
| --------------- | ----------------------------- | ------------------------------- |
| `vendor/main`   | 跟踪上游 main（当前基线）     | upstream/main                   |
| `vendor/vX.Y.x` | 跟踪上游版本线（锚定 tag 时） | tag（如 0.1.5）                 |
| `custom/main`   | 自定义开发主分支              | 基于 vendor 分支演进            |
| `feature/<name>`| 功能开发临时分支              | —                               |

- **remote**：`origin` → https://github.com/zouv/custom-vscode-cc-gui；`upstream` → https://github.com/hpstream/vscode-cc-gui
- **不建本地 `main`**：与 `vendor/main` 语义重复
- **上游 tag 大多无 `v` 前缀**（`0.1.1`~`0.1.5`，仅 `v0.1` 例外）；**fork 自己的发布 tag 用 `v` 前缀**（`v0.1.5-custom.1`）以示区分
- 推送后 GitHub 默认分支需设为 `custom/main`：`gh repo edit zouv/custom-vscode-cc-gui --default-branch custom/main`

## 发布路径

**本仓库没有 CI**，与参考项目（marktext 走「推 tag → 上游 CI 全平台构建」）不同，这里只有一条路径：

```
源码 → ccgui-release skill（版本号 + 预发布检查 + manager.sh package）→ 本地 VSIX
     → ccgui-publish skill（release notes + 提交 + annotated tag + publish-release.mjs）→ GitHub Release
```

产物落在 `dist/vsix/`（已 gitignore）：`<name>-<version>.vsix` + `SHA256SUMS.txt`。

## 辅助脚本

```bash
# 统一入口（install/build/test/typecheck/package/artifacts/sums/registry/clean）
sh ./CUSTOMIZATIONS/scripts/manager.sh help

# 打包 VSIX（含内容断言 + SHA256SUMS）
sh ./CUSTOMIZATIONS/scripts/manager.sh package

# 初始化仓库（首次 clone 后；仓库已初始化过则跳过）
pwsh ./CUSTOMIZATIONS/scripts/init-repo.ps1 -BaseRef upstream/main

# 查看当前自定义改动（读 registry.md 的 vendor_branch 定位基线）
pwsh ./CUSTOMIZATIONS/scripts/list-custom.ps1

# 同步 vendor 分支到指定上游 ref（tag 或 upstream/main）
pwsh ./CUSTOMIZATIONS/scripts/sync-vendor.ps1 -Ref upstream/main

# 登记一致性自检（每次 record-change 后必须全绿）
sh ./CUSTOMIZATIONS/scripts/check-registry.sh

# 发布到 GitHub Release（幂等；--dry-run 只校验不发请求）
node ./CUSTOMIZATIONS/scripts/publish-release.mjs v0.1.5-custom.1 --dry-run
```

打包脚本要点：`vsce package` 会自动执行 `vscode:prepublish`（= `npm run build`），**不要在外面重复构建**；`--no-dependencies` 是对的（根包零运行时依赖，全部由 esbuild 打包；`ai-bridge/node_modules/sql.js` 靠 `.vscodeignore` 白名单入包）；打包后用 `unzip -l` 断言 fork 文档/脚本没有混进 VSIX。
