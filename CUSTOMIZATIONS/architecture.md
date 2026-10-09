# 代码链路图谱（architecture.md）

> 面向 AI 的加速索引：**先按 §0.5 确定作用域，再用 §2 按函数名定位**，不要通读仓库。
> **本图谱过期时以代码为准，并顺手订正**。锚点一律用函数/类名，**不写行号**（行号会漂移）。
> 维护规则：超过 ~400 行即拆分到 `docs/arch/<module>.md`。

---

## §0 一句话架构

VS Code 扩展（`zouv.custom-vscode-cc-gui`，`onStartupFinished` 激活），由**三个互不依赖的 npm 包**组成，**没有 workspace 根**：

```
扩展宿主 (root src/ → esbuild → dist/extension.js, CJS, --external:vscode)
  src/extension.ts      activate()：注册 12 个命令 + 2 个 view provider + QuickFix provider
  src/panel.ts          CcGuiPanel：侧栏 view 与编辑器 tab 的宿主，拼 HTML/CSP/message 绑定
  src/bridge.ts         BridgeServer：spawn 并监管 ai-bridge 守护进程；消息分发；
                        ── spawn ──▶ ai-bridge/daemon.js
  └─ webview 侧 ◀── JCEF 风格 window.sendToJava / window.onXxx（**不是** VS Code postMessage API）

守护进程 (ai-bridge/ → 被 spawn 的纯 Node ESM 子进程，NDJSON over stdin/stdout)
  daemon.js             processRequest 分发 → channels/* 与 services/<provider>/*
  每 provider 一个 channel：claude / codex / grok / kimi / opencode / pi
  唯一运行时依赖：sql.js（仅 read-cc-switch-db.js 用）

UI (webview/ → React 19 + Vite 7 + antd 6 + Tailwind 4 → webview/dist/ 单包 IIFE)
  由 panel.ts 的 _getHtml 读取 webview/dist/index.html 并重写 CSP 与资源 URI
```

**关键数据流（详见 §3）**：

```
webview 用户操作 → window.sendToJava('event:content')
  → panel.ts::_bindWebview 的 onDidReceiveMessage
  → bridge.ts::handleWebviewMessage → MessageDispatcher.dispatch → handlers/*
  → bridge.ts::_sendToBridge 写 stdin（JSON.stringify({id,method,params}) + '\n'）
  → daemon.js::processRequest → channel/service → SDK 或 CLI 子进程
  → daemon stdout 每行 {id, line} → bridge.ts::_handleDaemonLine 解析 [TAG] 标记
  → broadcast / _postToActiveWebview → webview 的 window.onXxx 回调
```

## §0.5 任务作用域路由表（**只读该读的**）

| 任务类型 | 该读 | 可以忽略 |
| --- | --- | --- |
| Webview UI / 交互 / 样式 | `webview/src/components/`、`webview/src/hooks/`、`webview/src/contexts/`、`webview/src/styles/` | `ai-bridge/`、根 `src/` |
| Webview ↔ 宿主协议 | `webview/src/utils/bridge.ts`、`webview/src/global.d.ts`、`src/panel.ts`（`_getHtml` 引导脚本）、`src/bridge.ts`（`handleWebviewMessage`） | 各 provider service |
| 扩展宿主命令 / 菜单 / 视图 | `package.json` 的 `contributes`、`src/extension.ts`、`src/panel.ts`、`package.nls*.json`（3 份） | `webview/`、`ai-bridge/` 内部 |
| 会话发送 / 流式 / 中断 | `src/bridge/handlers/SessionHandler.ts`、`src/bridge.ts`（`_sendToBridge`/`_handleDaemonLine`/`_emitStream*`）、`webview/src/hooks/useStreamingMessages.ts` | 设置类 handler |
| provider / CLI 适配 | `ai-bridge/channels/<provider>-channel.js`、`ai-bridge/services/<provider>/message-service.js`、`ai-bridge/utils/cli-spawn.js`、`src/cli/cliTools.ts` | webview 组件 |
| 设置 / 持久化 | `src/bridge/services/SettingsStore.ts`、`src/bridge/services/ProviderStore.ts`、`src/bridge/services/codemossJsonStore.ts`、`webview/src/components/settings/` | `ai-bridge/` |
| 历史 / Codex 迁移 | `src/bridge/services/HistoryService.ts`、`codexHistoryTransform.ts`、`GrokHistoryReader.ts`、`historyEntrypoint.ts` | UI 组件 |
| 权限 / 审批 | `ai-bridge/permission-*.js`、`ai-bridge/services/claude/permission-mode.js`、`src/bridge/services/PermissionIpcService.ts`、`src/permissionApprovalUtils.ts` | 打包脚本 |
| 打包 / 发布 | `CUSTOMIZATIONS/scripts/manager.sh`、`package-vsix.sh`、`.vscodeignore`、`AGENTS.md` | 除 `package.json` 版本外的所有源码 |
| 起开发宿主 / 本地验收 | `CUSTOMIZATIONS/scripts/dev-host.mjs`（`npm run dev:host`，`build:debug` + 启动宿主，宿主环境对齐 `.vscode/launch.json`）、`package.json` 的 `scripts` | `webview/`、`ai-bridge/` 内部 |
| **i18n** | **两套系统，别混**：宿主侧 `package.nls*.json`（仅清单文案）；webview 侧 `webview/src/i18n/`（i18next，10 语言，默认 zh） | 另一侧的对应文件 |

## §1 文件职责表

### 扩展宿主（根 `src/`）

| 文件 | 主要符号 | 职责 |
| --- | --- | --- |
| `src/extension.ts` | `activate` / `deactivate` | 组装 `BridgeServer`+`CcGuiPanel`+`SessionTemplateService`，注册 12 个命令、2 个 view provider、QuickFix provider。`deactivate` 为空，全靠 `context.subscriptions` |
| `src/panel.ts` | `CcGuiPanel` | view/tab 宿主。`_getHtml` 拼 HTML+CSP+**注入 webview 引导脚本**；`_bindWebview` 是入站消息唯一入口；`_postToActiveWebview` 出站 |
| `src/bridge.ts` | `BridgeServer` | 守护进程监管与总控：`_startBridge`（spawn）、`_handleDaemonLine`（stdout 解析）、`_sendToBridge`（出站）、`_createDispatcher`、`_restartBridgeDaemon`、`broadcast` |
| `src/bridge/MessageDispatcher.ts` | `MessageDispatcher` | 按注册顺序线性匹配 `supportedEvents` 分发到 25 个 handler；返回 `true` 即消费 |
| `src/bridge/activeFileSync.ts` | `shouldSyncActiveFileToWebview` / `formatActiveFileSelectionInfo` | 纯函数：当前文件同步策略与展示文案 |
| `src/cli/cliTools.ts` | `CliToolId` / `CLI_ONLY_PROVIDERS` / `CLI_TOOL_DEFINITIONS` | CLI 型 provider 的分类学（只定义，不安装） |
| `src/cli/CliStatusDetector.ts` | `CliStatusDetector` | 探测各 CLI 是否安装与版本（5s 超时、30s 缓存） |
| `src/nodeDetector.ts` | `NodeDetector.find` / `.findNpm` | 解析 Node 二进制：`ccgc.nodePath` → 常见路径 → PATH |
| `src/nodeRequirements.ts` | `MIN_NODE_MAJOR_VERSION`(=20) / `isNodeVersionSupported` | **Node 版本要求的唯一来源**，`_startBridge` 据此拒绝启动 |
| `src/setupWizard.ts` | `SetupWizardService` / `registerSetupWizard` | 首启向导；注册第 13 个命令 `ccgc.runSetupWizard` |
| `src/commitMessage.ts` | `CommitMessageService` | 经 `bridge.requestAiText` 生成提交信息 |
| `src/quickFix.ts` / `quickFixPrompt.ts` | `ClaudeQuickFixProvider` / `buildQuickFixPrompt` | 诊断 → CodeAction → 命令 |
| `src/sessionTemplate.ts` | `SessionTemplateService` | 会话模板（globalState `ccg.session_templates`） |
| `src/language.ts` | `SUPPORTED_UI_LANGUAGES` / `resolveLanguageConfig` | VS Code locale → 10 种 UI 语言的映射 |
| `src/debugOutputChannel.ts` | `createDebugGatedOutputChannel` | 受 `ccgc.enableDebugLog` 门控的输出通道 |

`src/bridge/handlers/`（25 个，每个一类事件）：`SessionHandler`(chat 传输)、`SettingsHandler`(最大，~70 事件)、`ProviderHandler`(provider CRUD)、`McpServerHandler`/`McpMarketplaceHandler`、`HistoryHandler`、`DiffHandler`、`UndoFileHandler`、`FileHandler`、`AgentHandler`、`SkillHandler`、`PromptHandler`、`PermissionHandler`、`DependencyHandler`、`NodeProcessHandler`、`ClipboardHandler`、`WindowEventHandler`、`CliStatusHandler`/`CliModelsHandler`、`ContextUsageHandler`、`RewindHandler`、`UsageStatisticsHandler`、`CustomModelPricingHandler`、`TokenTrackerHandler`、`PromptEnhancerHandler`、`helpers.ts`。

`src/bridge/services/`（25 个）：`SettingsStore`、`ProviderStore`、`CodexSettingsStore`、`HistoryService`、`DiffService`、`PermissionIpcService`、`RuntimeContextService`、`SlashCommandService`、`UsageStatisticsService`、`mcpMarketplaceClient`/`mcpMarketplaceHttp`、`codemossJsonStore`、`customPricingStore`、`customContextWindowStore`、`codexHistoryTransform`/`codexImageTags`、`GrokHistoryReader`、`historyEntrypoint`、`subagentSidechain`、`claudeImageRestore`、`claudeSettingsSync`、`copilotMcpImport`、`textChunkDedupe`、`userMessageSanitizer`、`StateStore`。

### 守护进程（`ai-bridge/`）

| 文件 | 主要符号 | 职责 |
| --- | --- | --- |
| `ai-bridge/daemon.js` | `processRequest` / `sendDaemonEvent` | 入口与主循环。**改写了 `process.stdout.write`**（包装成 `{id,line}`）与 `process.exit`（改为抛错）；`AsyncLocalStorage` 做并发请求解复用 |
| `ai-bridge/channel-manager.js` | `providerHandlers` | **不是类/注册表**，是「一次性 CLI」入口（`node channel-manager.js <provider> <command>`）。`daemon.js` 里的 `switch(provider)` 是**第二份重复的**分发表，改动要同步 |
| `ai-bridge/channels/<p>-channel.js` | `handle<P>Command` | 每个 provider 的**命令名 → 实现**映射（无状态函数，不是对象） |
| `ai-bridge/services/claude/persistent-query-service.js` | `sendMessagePersistent` / `getContextUsagePersistent` | Claude 常驻 Query 复用（最大 Claude 文件） |
| `ai-bridge/services/claude/{runtime-registry,runtime-lifecycle}.js` | `acquireRuntime` / `disposeRuntime` | 运行时生命周期与 TTL 回收 |
| `ai-bridge/services/codex/codex-event-handler.js` | `processCodexEventStream` | Codex 事件流主循环（全包最大文件） |
| `ai-bridge/services/<p>/message-service.js` | `sendMessage` | 各 provider 的实际发送实现 |
| `ai-bridge/config/api-config.js` | `setupApiKey` / `buildCliEnv` / `configureCliIdentity` | 认证与环境变量策略中心（**无硬编码密钥**；仅测试固件有 `sk-` 字面量） |
| `ai-bridge/read-cc-switch-db.js` | — | 独立脚本，被 `ProviderHandler` spawn；**sql.js 的唯一消费者** |
| `ai-bridge/utils/marker-protocol.js` | `beginStream` / `emitUsage` / `emitToolUseMessage` | daemon→扩展的 `[TAG]` 标记协议定义（注意：CLI provider 多为 `console.log` 直写，此文件是**约定**而非唯一收口） |
| `ai-bridge/utils/cli-process-registry.js` | `registerCliProcess` / `abortCliProcesses` | CLI 子进程 kill 注册表（Stop 靠它） |

### UI（`webview/`）

| 文件 | 主要符号 | 职责 |
| --- | --- | --- |
| `webview/src/utils/bridge.ts` | `sendToJava` / `sendBridgeEvent` | **与宿主通信的唯一出口**（`window.sendToJava`），含路径安全校验（`isValidMutatingPath` 等） |
| `webview/src/global.d.ts` | `window.onXxx` | 宿主→webview 的 ~40 个回调声明（入站协议） |
| `webview/src/hooks/useWindowCallbacks.ts` | `registerWindowCallbacks` | 入站消息总入口；按域拆到 `hooks/windowCallbacks/registerCallbacks/*` |
| `webview/src/main.tsx` | `__pendingXxx` | React 挂载前的水合暂存区（宿主消息可能早于挂载到达） |
| `webview/src/contexts/` | `SessionProvider` / `MessagesProvider` / `TaskEventProvider` / `UIStateProvider` / `DialogProvider` | **状态层就是 React Context，没有 zustand/redux**；行为逻辑在 `webview/src/hooks/` |
| `webview/src/i18n/config.ts` | `i18n` / `getInitialLanguage` | webview 自己的 i18next（10 语言，默认 `zh`），与 `package.nls*.json` **是两套** |
| `webview/src/version/version.ts` | `APP_VERSION` | **构建自动生成，勿手改**（源：根 `package.json` 的 version） |
| `webview/src/version/changelog.ts` | `CHANGELOG_DATA` | **构建自动生成**（源：根 `CHANGELOG.md`） |

## §2 任务 → 代码位置反查（按名字定位，勿依赖行号）

| 想做什么 | 去哪 |
| --- | --- |
| 加一个命令 | `package.json` `contributes.commands` + `src/extension.ts` `activate` 内注册（或 `setupWizard.ts` 那样单独注册）+ `package.nls{,.zh-cn,.zh-tw}.json` **三份** |
| 加一个配置项 | `package.json` `contributes.configuration` + 三份 nls；读取处用 `getConfiguration('ccgc')`（见 `SettingsStore`） |
| 加一个 provider | `ai-bridge/channels/<name>-channel.js` + `ai-bridge/services/<name>/message-service.js` + `channel-manager.js` 的 `providerHandlers` **与** `daemon.js` 的 `switch(provider)`（两处！）+ `src/cli/cliTools.ts` |
| 改 webview ↔ 宿主协议 | 出站 `webview/src/utils/bridge.ts` + `global.d.ts`；入站 `src/bridge.ts` `handleWebviewMessage` + `MessageDispatcher` + 对应 handler；HTML 侧引导脚本在 `panel.ts` `_getHtml` |
| 改流式输出 / 重复内容 | `src/bridge.ts` `_handleDaemonLine` + `src/bridge/services/textChunkDedupe.ts` + `scripts/bridge-streaming-invariant.test.mjs` |
| 改权限弹窗 | `ai-bridge/services/claude/permission-mode.js`（daemon 侧）↔ `src/bridge/services/PermissionIpcService.ts` + `src/permissionApprovalUtils.ts`（宿主侧，走**文件 IPC 轮询**，不是 NDJSON） |
| 改 Node 版本要求 | `src/nodeRequirements.ts`（唯一常量）+ `src/setupWizardHelpers.ts` 的 `evaluateNodeStatus` + `src/bridge/handlers/DependencyHandler.ts` |
| 改 UI 主题 / 字体 | `webview/src/hooks/useThemeInit.ts` + `webview/src/styles/` + `src/bridge/services/SettingsStore.ts` 的字体配置方法 |
| 改会话历史 / Codex 迁移 | `src/bridge/services/HistoryService.ts` + `codexHistoryTransform.ts` + `historyEntrypoint.ts` |
| 改打包内容 | `.vscodeignore` + `CUSTOMIZATIONS/scripts/package-vsix.sh`（内含内容断言） |

## §3 重点链路深挖

### 3.1 webview 加载链
`CcGuiPanel._getHtml` → `path.join(extensionPath,'webview','dist','index.html')` → 用 `asWebviewUri` 把 `./assets/` 重写为 webview URI → 替换掉 JCEF 的 `<meta CSP>` 为本地的 `default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval' ${cspSource}; …` → 注入引导脚本，定义 **`window.sendToJava`**、`TYPE_TO_FN` 映射和 `window.__pendingLanguageConfig`。文件缺失时回退 `_getLoadingHtml`。

### 3.2 会话发送链
webview `sendToJava('send_message:…')` → `_bindWebview` 的 `onDidReceiveMessage` → `BridgeServer.handleWebviewMessage`（解析 `event:content`）→ `MessageDispatcher.dispatch` → `SessionHandler` → `_sendToBridge`，按 `METHOD_MAP` 变成 `<provider>.send` 写 stdin → daemon `processRequest` 按第一个 `.` 拆 provider/command → channel → SDK 或 CLI 子进程 → stdout 每行 `{id,line}` → `_handleDaemonLine` 按 `[CONTENT_DELTA]`/`[THINKING_DELTA]`/`[STREAM_START]`/`[SESSION_ID]` 等标记分发 → `broadcast`/`_postToActiveWebview` → webview 的 `window.onStreamXxx`。

### 3.3 守护进程生命周期与 Node 探测
`BridgeServer._startBridge` → `NodeDetector.find`（优先 `ccgc.nodePath`）→ `readNodeVersion` + `isNodeVersionSupported`（`MIN_NODE_MAJOR_VERSION=20`，不满足直接拒绝 spawn）→ 剥掉 `HTTP(S)_PROXY*` → `cp.spawn(nodePath,[ai-bridge/daemon.js])`。`_restartBridgeDaemon` 由 webview 的 `set_node_path`/`set_claude_cli_path`、以及 `restart_node_daemon` 触发——**直接改 VS Code 设置里的 `ccgc.nodePath` 并不会重启 daemon**（只有 `enableDebugLog` 变了才走 `onDidChangeConfiguration`）。daemon 侧有 PPID 轮询自杀，防孤儿进程。

### 3.4 打包链
`manager.sh package` → `package-vsix.sh`（三包依赖预检）→ `vsce package --no-dependencies` → **自动执行 `vscode:prepublish` = `npm run build`**（esbuild 打 `src/extension.ts` → `dist/extension.js`；`webview` 内先 `prebuild` 生成 version/changelog，再 `tsc && vite build`）→ 输出 `dist/vsix/<name>-<version>.vsix` → **`unzip -Z1` 内容断言**（必须含 dist/webview-dist/ai-bridge/sql.js；必须不含 fork 文档与本地工具目录）→ 生成 `SHA256SUMS.txt`。

## §4 数据契约铁律

1. **`ccgc.*` 配置节名与 `ccgc-*` view id 必须保持稳定**（CUSTOM-20261009-003 起，取代上游的 `ccGui.*` / `cc-gui-*`）——`getConfiguration('ccgc')`、`contributes`、三份 nls 的键名、用户已有设置都依赖它。**不要改回 `ccGui.*`**：那会与上游 vscode-cc-gui 撞命名空间（同时安装时重复贡献、互相抢配置）。上游合并若带回 `ccGui.*` 引用，按文件头标记块重贴重命名。
2. **`package.nls{,.zh-cn,.zh-tw}.json` 三份必须键对齐**——新增清单文案要同时补三份。
3. **webview 的 i18n 是另一套**（`webview/src/i18n/locales/*.json`，10 语言，默认 zh），别把两套混在一起改。
4. **打包时 `ai-bridge/node_modules` 与 `webview/dist/**` 必须存在**——前者靠 `.vscodeignore` 白名单（非依赖检测），后者靠 `!webview/dist/**`；`package-vsix.sh` 已断言。
5. **webview 里的 `version.ts` / `changelog.ts` 是生成物**——改版本改根 `package.json` 的 version，改 changelog 改根 `CHANGELOG.md`（表头格式 `##### **<日期>（v<版本>）**`）。
6. **`[CUSTOM-BEGIN]` 块必须在上游合并后存活**——按函数/组件名重定位，不按行号。
7. **已知既有缺口**（非本 fork 引入，勿顺手"修"成无标记改动）：`ccgc.autoSyncActiveFile` 在 `package.json` 中声明但代码里无人读取（真正的开关是 globalState 的 `auto_open_file`）；`panelHelpers.parseBridgeEvent`/`isBridgeEvent` 仅有测试引用；`webview/scripts/copy-dist.mjs` 是自我拷贝的空操作。
