## 重要

每次回复开头都要先喊一声"啊唯"

## 项目概述

本项目是基于 hpstream/vscode-cc-gui 的自定义二次开发版本（custom-vscode-cc-gui）。AI Agent 在本仓库工作时，必须严格遵循以下规则。

## 必读文件（开始任何任务前）

1. **CUSTOMIZATIONS/README.md**——自定义开发机制的完整规则（冲突策略、标记格式、frontmatter 职责）
2. **CUSTOMIZATIONS/registry.md**——自定义改动登记账本（开发前读「改动总览」节）
3. **CUSTOMIZATIONS/architecture.md**——面向 AI 的代码地图（本项目是 VS Code 扩展，不是 Electron 应用，别照搬其他项目的结构直觉）

## 工作流（写代码 / 排查问题前）

1. **先读 `CUSTOMIZATIONS/architecture.md`**：按 §0.5 任务作用域路由表确定该读哪些文件、忽略哪些；按 §2 任务→代码位置表用**函数名**定位（不依赖行号）。图谱过期时以代码为准并顺手订正。
2. **排查 bug 前先扫 `CUSTOMIZATIONS/docs/pitfalls.md` 标题**：历史坑点避免重复踩；解决新坑后回写一条。
3. 上游文件改动区域必须用 `[CUSTOM-BEGIN]/[CUSTOM-END]` 标记包裹（`.json` 无法注释的文件在 registry.md 总览标注「无标记」）。

## 技术栈

**本仓库是 VS Code 扩展，由三个互不依赖的 npm 包组成，没有 workspace 根**：

- **根 `src/`**：扩展宿主，TypeScript，esbuild 打成 `dist/extension.js`（CJS，`--external:vscode`）
- **`ai-bridge/`**：纯 Node ESM 守护进程，被扩展 spawn，NDJSON over stdin/stdout；唯一运行时依赖 `sql.js`
- **`webview/`**：React 19 + Vite 7 + antd 6 + Tailwind 4，打成单包 IIFE → `webview/dist/`
- 包管理器：**npm**（禁 pnpm/yarn——三份 `package-lock.json`）；Node ≥ 22（实测 v22.22.3）
- 上游**无 linter**，唯一的静态门是 `tsc --noEmit`
- 协议：MIT

**最容易搞错的一点**：webview 与宿主之间**不是** VS Code 的 `acquireVsCodeApi`/`postMessage`，而是 JCEF 风格的 `window.sendToJava(...)` + 一批 `window.onXxx` 全局回调（由 `src/panel.ts` 的 `_getHtml` 注入）。见 architecture.md §0/§3.1。

## 构建命令（全部在仓库根执行）

```bash
sh CUSTOMIZATIONS/scripts/manager.sh install   # 依次装三个包（根/webview/ai-bridge）
sh CUSTOMIZATIONS/scripts/manager.sh build     # 扩展 + webview 构建
sh CUSTOMIZATIONS/scripts/manager.sh test      # 全量 node:test 套件（分套件报告）
sh CUSTOMIZATIONS/scripts/manager.sh typecheck # tsc --noEmit
sh CUSTOMIZATIONS/scripts/manager.sh package   # 打 VSIX（含内容断言 + SHA256SUMS）
sh CUSTOMIZATIONS/scripts/manager.sh check     # typecheck + test
sh CUSTOMIZATIONS/scripts/check-registry.sh    # 登记一致性自检（必须全绿）
npm run dev:host [-- <工作区目录>]              # 构建 + 启动开发宿主窗口（手工验收，不下断点）
```

真实开发用 **VS Code 按 F5**（`.vscode/launch.json`，preLaunchTask 走 `build:debug`）。`npm run dev:host` 是它的无调试器版（同一套 `.vscode-dev/` 隔离 profile），可传任意目录当工作区；`manager.sh watch` 只监听扩展宿主。

**不要直接用 `npm run test:ext`**：Windows 下 npm 经 cmd.exe 执行，单引号被当字面量，glob 匹配 0 文件 → **静默假绿**（输出 `1..0` 但退出码 0）。见 pitfalls #10。

## Git 分支规则

| 分支             | 用途                          | 谁可以写入                             |
| ---------------- | ----------------------------- | -------------------------------------- |
| `upstream/main`  | 跟踪 hpstream/vscode-cc-gui   | 只读（仅 fetch）                       |
| `vendor/main`    | 上游版本基线                  | 只读（仅 merge-upstream skill 可更新） |
| `vendor/vX.Y.x`  | 上游版本线分支（锚定 tag 时） | 只读（同上）                           |
| `custom/main`    | 自定义开发主分支              | AI Agent 开发合并                      |
| `feature/<name>` | 功能开发分支                  | AI Agent 临时分支                      |

- **remote**：`origin` → https://github.com/zouv/custom-vscode-cc-gui；`upstream` → https://github.com/hpstream/vscode-cc-gui
- **不建本地 `main`**（与 `vendor/main` 语义重复）
- **上游 tag 大多无 `v` 前缀**（`0.1.1`~`0.1.5`）；fork 自己的发布 tag 用 `v` 前缀（`v0.1.5-custom.1`）
- **禁止操作**：
  - **禁止未经用户明确指示 commit / push**：完成改动后只汇报结果（改了什么、验证情况），由用户决定何时提交；用户明确说"提交"/"commit"/"push"时才执行
  - 禁止手动 `git merge` 合并 vendor 到 custom/main（必须通过 `ccgui-merge-upstream` skill）
  - 禁止 `git rebase` 改写 custom/main 的历史
  - 禁止直接 push 到 vendor 分支

## 自定义代码规范（硬约束）

1. **代码隔离优先**：新功能尽量放在 `CUSTOMIZATIONS/src/` 下，通过独立模块挂载
2. **修改上游文件时必须加标记**：
   ```
   // [CUSTOM-BEGIN] CUSTOM-YYYYMMDD-NNN - 描述
   ... 自定义代码 ...
   // [CUSTOM-END] CUSTOM-YYYYMMDD-NNN
   ```
3. **每次改动必须记录**：完成后调用 `ccgui-record-change` skill 更新 CUSTOMIZATIONS/registry.md
4. **不要删除 registry.md 中的历史条目**（标记 deprecated 即可）
5. **合并冲突**：按 CUSTOMIZATIONS/README.md 的冲突策略速查处理
6. **合并上游完成后、发布前**必须运行 `manager.sh install && manager.sh build && manager.sh test`，并 `sh CUSTOMIZATIONS/scripts/check-registry.sh` 到全绿

## AI Skills 触发条件

Skill 定义位于 `.agents/skills/`（跨工具共享的工作区级标准路径）。

| Skill                   | 何时调用                                                                |
| ----------------------- | ----------------------------------------------------------------------- |
| `ccgui-record-change`   | 完成任何自定义功能/修改后                                               |
| `ccgui-merge-upstream`  | 用户要求合并上游/升级版本/同步原仓库时                                  |
| `ccgui-release`         | 用户要求打包/生成 VSIX/build 时（本地打包，终点是 `.vsix`）             |
| `ccgui-publish`         | 用户要求发布/上传 release/打 tag/推 release 到 GitHub 时                |

详细触发场景见各 skill 的 `.agents/skills/<name>/SKILL.md`。

## 项目结构速查

```
src/                        # 扩展宿主（esbuild → dist/extension.js）
  extension.ts              # activate：13 个 ccgc.* 命令、2 个 view provider
  panel.ts                  # CcGuiPanel：webview 宿主、HTML/CSP/引导脚本注入
  bridge.ts                 # BridgeServer：spawn 守护进程、消息总控
  bridge/{handlers,services}/  # 25 handler + 25 service
  cli/ nodeDetector.ts nodeRequirements.ts setupWizard.ts …
ai-bridge/                  # 被 spawn 的 Node 守护进程（NDJSON over stdio）
  daemon.js channel-manager.js channels/ services/ config/ utils/
webview/                    # React 19 + Vite 7 UI → webview/dist/（单包 IIFE）
  src/{components,hooks,contexts,utils,types,i18n,version}/
dist/                       # extension.js + vsix/（已 gitignore）
CUSTOMIZATIONS/             # 自定义开发内容（规则、账本、代码地图、坑点库、代码、脚本）
├── README.md               # 机制与规则唯一完整版
├── architecture.md         # 代码链路图谱（AI 加速索引）
├── registry.md             # 改动登记账本
├── docs/pitfalls.md        # 历史坑点沉淀
├── release-notes/
├── src/ patches/ scripts/
.agents/skills/             # AI Agent 项目级 skills（4 个）
AGENTS.md                   # 本文件
```

上游**没有** `CLAUDE.md`，也没有 `.github/`（零 CI）——本项目的一切自动化为本地脚本 + skill。

## 文档更新职责（改完代码必须同步）

| 改动类型                       | 更新哪里                                                            |
| ------------------------------ | ------------------------------------------------------------------- |
| 任何自定义功能/修改            | `CUSTOMIZATIONS/registry.md`（record-change skill）                 |
| 新增/移动函数、改数据流或接口  | `CUSTOMIZATIONS/architecture.md`（§1 职责表 / §2 反查表 / §3 链路） |
| 解决了一个反复折腾才定位的问题 | `CUSTOMIZATIONS/docs/pitfalls.md`（现象→根因→解法→教训）            |
| 机制/规则变更                  | `CUSTOMIZATIONS/README.md`                                          |

## 代码风格

- 不添加注释（除非用户明确要求）
- 遵循现有代码风格（上游无 linter/格式化配置，以所在文件既有风格为准）
- 提交前运行 `sh CUSTOMIZATIONS/scripts/manager.sh typecheck`
- **已知既有缺口**：上游 `main@8ba39913` 本身有 8 个 tsc 错误与 2 个 ai-bridge 测试失败（见 pitfalls #9）。**不要**在自定义改动里顺手修它们——那会产生无标记的上游 diff。
