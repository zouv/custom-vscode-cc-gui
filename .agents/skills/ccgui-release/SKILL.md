---
name: 'ccgui-release'
description: 'Build and package the custom VSIX of custom-vscode-cc-gui (version bump, pre-release checks, vsce packaging via manager.sh). Invoke when user asks to build, package, or make a .vsix of the custom extension. 发布到 GitHub 请用 ccgui-publish skill。'
---

# custom-vscode-cc-gui 打包 Skill

把自定义源码**构建打包成本地 VSIX**，终点是 `dist/vsix/<name>-<version>.vsix`。

**发布到 GitHub（提交 / tag / Release / 上传产物）已拆到 `ccgui-publish` skill** —— 打完包后走那边。

## 与 ccgui-publish 的分工

| Skill                  | 职责                        | 起点 → 终点                                                    |
| ---------------------- | --------------------------- | -------------------------------------------------------------- |
| **`ccgui-release`（本）** | 从源码到**本地 VSIX**       | 干净工作区 → `dist/vsix/custom-vscode-cc-gui-<版本>.vsix`      |
| `ccgui-publish`        | 从版本号到 **GitHub Release** | 版本号 + release notes → release 上线（含 vsix + SHA256SUMS）   |

> 与参考项目（marktext/chatbox）不同：**本仓库上游零 CI**（没有 `.github/`），不存在"推 tag 触发全平台构建"的路径。发布只有一条路：先在这里打本地 VSIX，再去 `ccgui-publish`。

## 触发条件

- 用户说"打包"、"打个包"、"生成 vsix"、"build"、"package"
- 需要本地安装验证（`code --install-extension`）
- 发布前需要本地 VSIX 产物

## 参数收集

1. **版本号**：格式 `v<上游版本>-custom.<N>`（tag 带 `v`，`package.json` 里的 version 不带 `v`）。未指定时读已有 tag 取最大序号 +1：

   ```bash
   git tag -l "v*-custom.*" --sort=-v:refname | head -5
   ```

2. **是否跳过检查**：默认跑，除非用户明确跳过。

## 前置检查

```bash
git branch --show-current      # 必须是 custom/main
git status --porcelain         # 建议干净
node --version                 # >= 22（实测 v22.22.3）
```

## 执行流程

### 第一步：定版本号并更新

改根 `package.json` 的 `version`（**唯一版本源**，不带 `v` 前缀）。JSON 无法注释，改动记入 registry.md 总览的 `package.json` 行（**无标记**）。

`webview/src/version/version.ts` 会在下次 webview 构建时自动跟着变，**不要手改**。

### 第二步：发布前检查

```bash
sh CUSTOMIZATIONS/scripts/manager.sh typecheck
sh CUSTOMIZATIONS/scripts/manager.sh test
sh CUSTOMIZATIONS/scripts/check-registry.sh    # 必须全绿
```

**已知既有基线，不是本次引入**（见 `CUSTOMIZATIONS/docs/pitfalls.md` #9）：根 `tsc --noEmit` 有 8 个错误；`ai-bridge` 有 2 个失败用例；`webview npm test` 的类型检查段有 4 个错误导致退出码 2。

**不要为了让检查变绿去修这些上游问题**——那会给 fork 制造无标记的上游 diff。判定"是不是本次改动引入的"：`git diff vendor/main..HEAD -- <相关测试文件>` 为空 ⇒ 不可能影响该子系统。确认是基线后**向用户报告、由用户决定是否继续**。

### 第三步：打包

```bash
sh CUSTOMIZATIONS/scripts/manager.sh package
```

脚本内部流程（`package-vsix.sh`）：三包依赖预检 → `vsce package --no-dependencies` → **自动执行 `vscode:prepublish` = `npm run build`** → `unzip -Z1` 内容断言 → 生成 `SHA256SUMS.txt`。

```bash
sh CUSTOMIZATIONS/scripts/manager.sh artifacts   # 查看产物
```

### 第四步：产物核验

内容断言已在脚本内自动跑。必含 `extension/dist/extension.js`、`extension/webview/dist/index.html`、`extension/ai-bridge/daemon.js`、`extension/ai-bridge/node_modules/sql.js/dist/sql-wasm.wasm`、`extension/media/icon.png`；必不含 `CUSTOMIZATIONS/`、`.agents/`、`AGENTS.md`、`.claude/` 等。

可选端到端验证（**会改变用户的 VS Code 状态，需先征得同意**）：

```bash
code --install-extension dist/vsix/custom-vscode-cc-gui-<版本>.vsix
```

## 坑点与经验

### 1. 不要在外面重复跑 `npm run build`

`vsce package` 总会先执行 `package.json` 的 `vscode:prepublish`（= `npm run build`）。外面再跑一次是重复构建，且构建失败时错误信息会指向 vsce（见 pitfalls #5）。

### 2. 三个包的依赖必须装全

根目录 `npm install` 不会装 `webview/` 与 `ai-bridge/`。漏装 `ai-bridge` 会打出**缺 `sql.js` 的 VSIX**——能装上、但运行期 daemon 崩在 `read-cc-switch-db.js` 的顶层 import（pitfalls #3）。`package-vsix.sh` 有预检与断言。

### 3. `--no-dependencies` 是正确的，别去掉

根 `package.json` **零运行时依赖**（全部由 esbuild 打包进 `dist/extension.js`）。`ai-bridge/node_modules/sql.js` 是靠 `.vscodeignore` 白名单进的包，与依赖检测无关。

### 4. `unzip -l` 会让内容断言假阳性

`unzip -l` 头部会打印 `Archive:  dist/vsix/xxx.vsix`，任何以 `dist/vsix/` 为关键字的断言都会误命中。**用 `unzip -Z1`**（只列文件名）。脚本已如此实现。

### 5. vsce 打的是**工作树**，不是 git

vsce 不读 `.gitignore`。任何本机未跟踪的工具/会话目录都会漏进 VSIX——首次打包实测混入 5 个 `.claude/explore-results/` 子代理 transcript（~142 KB）。`.vscodeignore` 已排除 `.claude/**`、`.zcode/**` 等，**新增本地工具目录时要同步补进去**。

### 6. vsce 的 secretlint 可能误报

报 `[SECRET_NAME]` 时用 vsce 打印出的具名规则 `--allow-package-secrets <NAME>`；`package-vsix.sh --allow-secrets` 是粗粒度兜底，**优先取具名**（pitfalls #6）。

### 7. 管道会吃掉退出码

```bash
sh CUSTOMIZATIONS/scripts/manager.sh test 2>&1 | tail -60   # ❌ 退出码是 tail 的
sh CUSTOMIZATIONS/scripts/manager.sh test > /tmp/t.log 2>&1 # ✅ 重定向到文件再读
```

## 重要约束

1. **不跳过 typecheck / test / check-registry 检查**
2. **版本号必须在打包前改**（内嵌在 VSIX 文件名与 `extension/package.json` 里，事后改无效）
3. **产物不提交 git**：`dist/` 已在 `.gitignore`
4. **不手改 `package-lock.json`**：改完 `package.json` 后跑 `npm install` 重新生成
5. **不手改 `webview/src/version/version.ts`**：构建自动生成
6. **不为让检查变绿而修上游既有问题**（pitfalls #9）
7. **本 skill 各步骤中的 commit / push 仅在用户明确发起时执行**；打完包停在本地，报告产物路径、大小、sha256 与验证结果，等用户决定
