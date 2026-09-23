# 坑点库（docs/pitfalls.md）

> 现象 → 根因 → 解法 → 教训。**排查问题前先扫标题**；解决新坑后回写一条。
> 编号只增不改（历史是事实）。

---

## #1 上游整目录忽略 `.claude/`，而 `.agents/` 未被忽略

- **现象**：想跟踪项目级 `.claude/settings.json` 或 `.agents/skills/**` 时，git 不认。
- **根因**：上游 `.gitignore` 第 47 行是 `.claude/`（整目录），**没有** `.agents/`。
- **解法**：本仓库 **不需要** `!.agents/` 反向豁免——`.agents/skills/**` 本来就是可跟踪的（`git check-ignore .agents/skills/...` 无输出即正确）。
- **教训**：参考项目 custom-marktext 必须写 `!.agents/` + `!.agents/**`，因为它上游忽略 `.agents/`；**照抄参考项目的 `.gitignore` 块会引入无意义的豁免**。务必先用 `git check-ignore -v` 验证自己上游的实际情况。
- **若将来要加 `!.claude/`**：git 无法重新纳入「被排除目录」下的文件，必须同时显式再忽略 `.claude/explore-results/`（CUSTOM-20260923-001 已预置该行）。

## #2 `core.autocrlf=true` 制造幻影改动 + 破坏 `*.sh`

- **现象（实测）**：`npm run build` 后 `git status` 显示 `webview/src/version/{version,changelog}.ts` 为 ` M`，但 `git diff` 无内容、`git add` 后 blob 哈希**不变**（`c39bc1ae…`）。同时警告 `LF will be replaced by CRLF the next time Git touches it`。
- **根因**：本机 `core.autocrlf=true`（**系统级 + 用户级都有**）。构建脚本按 LF 写文件，而 git 期望检出为 CRLF，双方僵持 → stat 缓存判定为"已修改"。真正的危害在重新 clone：`*.sh` 会被检出成 CRLF，`sh script.sh` 静默出错。
- **解法**：fork 自带 `.gitattributes`（`* text=auto eol=lf`），在初始化时就加。加完 `git status` 立刻干净，`git add --renormalize .` 无内容变化（证明上游 blob 本来就是 LF，零 renormalize 噪音）。
- **教训**：`git status` 说改了、`git diff` 说没改，先怀疑换行符而不是自己写错了代码。参考项目 custom-marktext 至今没踩到，只是因为它的脚本从未被重新 checkout 过——**这是潜伏 bug，不是已解决问题**。

## #3 三个 npm 包必须分别 install

- **现象**：`npm run build` 或打包 VSIX 失败/产物缺文件。
- **根因**：本仓库是三个独立 npm 包（根 / `webview/` / `ai-bridge/`），**没有 workspace 根**，根目录 `npm install` 不会装子包。
- **解法**：`sh CUSTOMIZATIONS/scripts/manager.sh install`（依次装三个）。`package-vsix.sh` 内置依赖预检，缺包会直接提示该跑哪条命令。
- **教训**：漏装 `ai-bridge` 的后果最隐蔽——`ai-bridge/node_modules/sql.js` 靠 `.vscodeignore` 白名单进 VSIX，少了它打出的包**能装上但运行期崩**（daemon 崩在 `read-cc-switch-db.js` 的顶层 `import initSqlJs from 'sql.js'`）。所以 `package-vsix.sh` 用 `unzip -l` 断言 `sql-wasm.wasm` 必须存在。

## #4 `.vscodeignore` 不排除 fork 目录 → 自定义文档打进 VSIX

- **现象**：VSIX 体积异常，解包后能看到 `CUSTOMIZATIONS/`、`AGENTS.md`。
- **根因**：上游 `.vscodeignore` 只排除 `src/**`、`scripts/**`、`node_modules/**` 等，不认得 fork 新增的目录。
- **解法**：CUSTOM-20260923-001 追加排除块（`CUSTOMIZATIONS/**`、`.agents/**`、`AGENTS.md`、`.gitattributes`、`dist/vsix/**`），`package-vsix.sh` 内置 `unzip -l` 双向断言。
- **教训**：注意 `.vscodeignore` 的 `!` 是**强制包含**（vsce 语义与 gitignore 不同），本文件的排除块**只用普通模式、不用 `!`**，避免与既有的 `!webview/dist/**` 打架。也别加宽泛的 `dist/` 规则——`dist/extension.js` 必须留在包里。

## #5 `vsce package` 会自动跑 `vscode:prepublish`（= `npm run build`）

- **现象**：打包耗时翻倍；或"我明明 build 过了还报构建错"。
- **根因**：`vsce package` 总会先执行 `package.json` 的 `vscode:prepublish` 脚本，本仓库该脚本就是 `npm run build`。
- **解法**：`package-vsix.sh` 里**不**重复构建。若构建失败，失败点通常在 esbuild/vite 而不是 vsce——先看依赖预检的报错。
- **教训**：耗时翻倍只是表象；真正的坑是"缺 `webview/node_modules` 时报错信息指向 vsce"，容易查错方向。

## #6 vsce 的 secretlint 可能对大 bundle 误报

- **现象**：`vsce package` 报 `[SECRET_NAME]` 之类的错误。
- **根因**：vsce 4 会对打包内容跑 `@secretlint` 规则；本仓库的 `webview/dist/assets/index.js` 是个 ~6.6 MB 的压缩 bundle，`ai-bridge/config/api-config.js` 也是现实误报面。
- **解法**：用 vsce 打印出的具名规则避开：`--allow-package-secrets <NAME>`。`package-vsix.sh` 提供了 `--allow-secrets` 粗粒度开关（等价 `--allow-package-all-secrets`），**优先取具名**。
- **教训**：初始化时打包未触发该问题（CUSTOM-20260923-001 实测通过），但上游代码增长后会遇到。

## #7 双 remote 下 `gh` 默认解析到上游

- **现象**：`gh release list` 列出的是上游的 release；`gh` 命令操作到了 `hpstream/vscode-cc-gui`。
- **根因**：本仓库有 `origin`(zouv/custom-vscode-cc-gui) 与 `upstream`(hpstream/vscode-cc-gui) 两个 remote，gh 选择了 upstream 作为 base。
- **解法**：`git config remote.origin.gh-resolved base`（只写 `.git/config`，不随仓库分发）。`init-repo.ps1` 已自动设置；人工排查前先 `gh repo view --json nameWithOwner` 确认。
- **教训**：重新 clone 后必须重做——所以把它写进了 init 脚本而不是只写文档。

## #8 上游 tag 大多没有 `v` 前缀

- **现象**：`sync-vendor.ps1` 传 `0.1.5` 时推不出 `vendor/v0.1.x` 分支名。
- **根因**：上游 tag 是 `0.1.1` ~ `0.1.5`，只有最早的 `v0.1` 带 `v`。
- **解法**：tag 正则写成 `^v?(\d+)\.(\d+)\.`。fork 自己的发布 tag 统一用 `v` 前缀（`v0.1.5-custom.1`）以区分。
- **教训**：参考项目的正则 `^v(\d+)\.(\d+)\.` 在这里会静默不匹配。

## #9 本机既有测试/类型基线（**不是**本仓库引入的）

- **现象**：`tsc --noEmit` 报错、部分测试失败。
- **根因**：上游 `main@8ba39913` 本身如此。**初始化时如实测量，不在初始化提交里修**（修会给 fork 的首个 diff 制造无标记噪音）。
- **实测基线**（2026-09-23，node v22.22.3，Windows 10）：

| 套件 | 命令 | 结果 |
| --- | --- | --- |
| 扩展宿主测试 | `node --experimental-strip-types --no-warnings --test "src/__tests__/**/*.test.mts"` | **236 通过 / 0 失败** |
| 补充（上游 glob 漏） | `src/bridge/services/subagentSidechain.test.mts` | 3 通过 |
| scripts 测试 | `node --test scripts/**/*.test.mjs` | 4 通过 |
| ai-bridge 测试 | `node --test "ai-bridge/**/*.test.js" "ai-bridge/**/*.test.mjs"` | 233 跑 / 231 通过 / **2 失败** |
| 根 typecheck | `npx tsc --noEmit -p tsconfig.json` | **8 错误** |
| webview vitest | `cd webview && npm test` | 107 文件 / **925 全通过** |
| webview 类型检查 | 同上（`npm test` 的第二段 `tsc -p tsconfig.test.json`） | **4 错误 → `npm test` 退出码 2** |

- **ai-bridge 的 2 个失败**：`getContextUsagePersistent reuses runtime and calls setModel when model changes`、`getContextUsagePersistent acquires new runtime when none exists`。
- **根 typecheck 的 8 个错误**：`src/bridge.ts(175,13)` TS2322、`src/sessionTemplate.ts(49,7)` TS2322（`RuntimeProviderId` 未含 `grok`）；`src/bridge/services/{codexHistoryTransform,GrokHistoryReader,ProviderStore}.ts`、`src/setupWizardHelpers.ts`（×2）、`src/bridge/services/subagentSidechain.test.mts` 的 TS5097（`.ts` 扩展名 import）。
- **webview 的 4 个错误**：`src/components/ChatInputBox/utils/dropPathUtils.test.ts(17,7)` TS2783、`src/hooks/useWindowCallbacks.test.ts(20,105)` TS2322 及 (427,24)(464,48) TS2339。
- **教训**：判断"是不是我弄坏的"必须先有这组数字。`manager.sh` 把各套件**拆成独立子命令**，就是为了让红色可见，而不是被一个笼统的 `test` 掩盖。

## #10 `npm run test:ext` 在 Windows 上静默跑 0 个用例（**假绿**）

- **现象（实测）**：`npm run test:ext` 输出 `1..0`、`# tests 0`、`# fail 0` 并**以 0 退出**。看起来通过，实际一个用例都没跑。
- **根因**：npm 在 Windows 上经 `cmd.exe` 执行脚本，而**单引号在 cmd.exe 里不是引号字符**。node 收到的是字面量 `'src/__tests__/**/*.test.mts'`（**带引号**），glob 匹配不到任何文件；node:test 对 0 个用例正常退出 0。
- **实证**：同一条命令 —— Git Bash 直接跑 → 236 用例全过；`cmd //c "…"` 跑 → 0 用例。
- **解法**：`manager.sh` **不**委托 `npm run test:ext`，改为直接 `node --experimental-strip-types --no-warnings --test "<双引号 glob>"`（bash 不展开、node 自己 glob）。
- **教训**：这是本项目最危险的一类坑——**CI/脚本绿灯不代表测试跑过**。凡见到 `1..0` 或耗时异常短（本次基线 A 仅 10 ms），一律先数用例数。参考项目 chatbox 的 pitfalls #11「管道吃退出码」是同一族问题。

## #11 `list-custom.ps1` 的 frontmatter 引号不匹配（参考项目的潜伏 bug）

- **现象**：脚本读到的 `vendor_branch` 永远是默认值，忽略 registry.md 里实际写的值。
- **根因**：参考项目用正则 `vendor_branch:\s*"([^"]+)"`（**双引号**），而它的 frontmatter 实际写的是**单引号** `vendor_branch: 'vendor/develop'`——正则从未命中，一直静默走硬编码默认值。默认值恰好正确，所以从未暴露。
- **解法**：本仓库改为兼容两种引号：`vendor_branch:\s*['\x22]?([^'\x22\r\n]+)`。
- **教训**："默认值恰好等于期望值"会长期掩盖读取逻辑失效。写这类脚本时，用一个与默认值不同的值做一次验证。

## #12 同一脚本在 Git Bash 与 pwsh 下调起时路径写法不同（盘符冒号吃解析）

- **现象**：`sh CUSTOMIZATIONS/scripts/check-registry.sh` 从 Git Bash 直跑全绿，但由 `pwsh -File CUSTOMIZATIONS/scripts/init-repo.ps1` 内部调起时报假失败：`[MISSING-IN-DOC] D  (标记: CUSTOM-20260923-001)`——文件名只剩一个 `D`。
- **根因**：两种调用环境下 `pwd` 的写法不同。Git Bash 直跑给 POSIX 风格 `/d/Git/...`；**pwsh 调起的是 `C:\Program Files\Git\usr\bin\sh.exe`，其 `pwd` 给 Windows 风格 `D:/Git/...`**。脚本用绝对路径调 `grep -rn`，输出的行形如 `D:/Git/.../.gitignore:103:...`，而解析用的是 `file="${line%%:*}"`（取第一个冒号之前）→ 得到盘符 `D`。参考项目只从 Git Bash 跑过，所以这个潜伏 bug 一直没暴露；但它的 skill 同样是经 `sh`（可能由 pwsh 调起）执行，属于迟早会踩。
- **解法**：`cd "${PROJECT_ROOT}"` 后用**相对路径**调 grep（`src ai-bridge webview/src scripts CUSTOMIZATIONS .gitignore .vscodeignore package.json`），再 `sed 's|^\./||'` 兜底。相对路径不含盘符，`%%:*` 恢复正常，且与 registry.md 里登记的仓库根相对路径天然对齐。
- **教训**：**判断"脚本能不能用"要在两种入口各跑一次**（Git Bash 直跑 + pwsh→sh），只测一种会漏掉这一类。凡是把绝对路径拼进「带分隔符的结构化输出」再解析的地方，都要先问一句"这个路径里会不会有冒号"。

## #13 vsce 打的是工作树而非 git，未跟踪目录会漏进 VSIX

- **现象（实测）**：首次 `manager.sh package` 产出的 VSIX 有 182 个文件，其中 5 个是 `extension/.claude/explore-results/*.md`（AI 子代理 transcript，~142 KB）。
- **根因**：**vsce 不读 `.gitignore`**，它打包的是**工作树**。`.claude/` 虽被 git 忽略（本机未跟踪），但 `.vscodeignore` 里没有它，于是照打不误。任何本地工具/会话目录（`.claude/`、`.zcode/`、`.cursor/`…）都有同样风险。
- **解法**：`.vscodeignore` 显式排除 `.claude/**`、`.zcode/**`、`.cursor/**`、`.codex/**`、`.mossx/**`、`.ace-tool/**`、`.continue/**`、`.windsurf/**`；`package-vsix.sh` 的内容断言把 `.claude/`、`.zcode/` 等列入 deny 列表。修后 182 → 177 文件。
- **教训**：「git 忽略了」≠「不会被打包」。新增任何本地工具目录时，**要同时补 `.gitignore` 和 `.vscodeignore`**。这道断言不是在防假想问题——它第一次运行就抓到了真漏包。
