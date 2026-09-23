---
name: 'ccgui-merge-upstream'
description: 'Merge upstream hpstream/vscode-cc-gui updates into the custom repository. Invoke when user asks to sync/merge/update from upstream, upgrade to a new version, or pull upstream changes.'
---

# custom-vscode-cc-gui 上游合并 Skill

本 Skill 用于将 hpstream/vscode-cc-gui 上游仓库的更新合并到自定义仓库中。**所有跨上游/自定义分支的合并操作必须通过本 Skill 执行，禁止手动 git merge。**

## 触发条件

- 用户说"合并上游"、"更新到最新版本"、"升级到 v0.1.x"、"sync upstream"
- 需要将上游的 bugfix/新功能合入自定义版本
- 用户要求"同步原仓库"

## 上游分支模型（先理解）

- 上游开发与发布都在 **`main`** 分支，发布走 tag
- **上游 tag 大多没有 `v` 前缀**（`0.1.1` ~ `0.1.5`，仅最早的 `v0.1` 例外）——这与其他项目不同，正则与命令里要注意
- 本仓库对应：`vendor/main`（默认基线，跟踪 `upstream/main`）与 `vendor/vX.Y.x`（锚定 tag 时可选）

## 参数收集

开始前确认（从用户输入或询问获取）：

1. **目标版本**：
   - `upstream/main` 最新（**默认**，跟随主线）
   - tag（如 `0.1.5`）→ 精确版本锚定
   - 指定 commit hash
   - 未指定时默认取 `upstream/main` 最新并展示待合并提交数
2. **是否需要构建验证**：默认需要，除非用户明确跳过

## 前置检查

### 1. 确认仓库状态

```bash
git branch --show-current        # 必须在 custom/main 上
git status --porcelain           # 必须干净
```

不干净时先处理（stash/commit），或：

```bash
git stash push -m "auto-stash before upstream merge $(date -Iseconds)"
```

**如果工作区不干净且无法自动 stash，必须暂停并告知用户。**

### 2. 确认 remote 配置

```bash
git remote -v
# 必须有 upstream → https://github.com/hpstream/vscode-cc-gui
```

### 3. 读取 CUSTOMIZATIONS/registry.md

通读所有 `active` 状态的改动总览条目，特别是「冲突策略」列（完整优先级表见 `CUSTOMIZATIONS/README.md`）。这是冲突解决的依据。

### 4. 获取上游最新信息

```bash
git fetch upstream --tags
git log --oneline vendor/main..upstream/main | head -30   # 待合并提交
```

展示给用户确认规模。

---

## 流程：合并（update 型）

适用：`vendor/main` 同线推进到 `upstream/main` 新 HEAD，或 `vendor/vX.Y.x` 推进到新 tag。

### 1. 预检查报告

```
=== 上游合并预检查 ===
当前自定义基线：<registry.md 的 current_upstream_version>
目标上游版本：<target>
预计改动文件数：<git diff --stat vendor/main <target> 估算>
自定义改动条目数：<registry.md 总览 active 条目数>
已知冲突风险文件：<总览中 merge-manual 的文件 ∩ 上游变更文件>
```

本仓库当前的冲突风险面**极小**：自定义改动只有 `package.json`（fork 标识）、`.gitignore`、`.vscodeignore`、`.gitattributes`、`package-lock.json`、`webview/src/version/version.ts`。除 `package.json` 与两个 ignore 文件外，其余都是纯自定义路径或不参与冲突。

### 2. 更新 vendor 分支

```bash
git switch vendor/main
git merge --no-edit upstream/main        # 或 <tag>
git push origin vendor/main
```

**首次锚定某版本线**（如合并 `0.1.5` 正式 tag 时）：
`git switch -c vendor/v0.1.x 0.1.5 && git push -u origin vendor/v0.1.x`

### 3. 合并到 custom/main

```bash
git switch custom/main
git switch -c merge/upstream-<version>-$(date +%Y%m%d)
git merge --no-edit vendor/main
```

### 4. 处理冲突（AI 最关键的步骤）

```bash
git diff --name-only --diff-filter=U    # 列出冲突文件
```

对每个冲突文件，按 `CUSTOMIZATIONS/README.md` 优先级表处理：

**阶段 1（自动解析）**：

- registry.md 总览条目标 `keep-ours` → `git checkout --ours <file> && git add <file>`
- 标 `keep-theirs` → `git checkout --theirs <file> && git add <file>`
- `CUSTOMIZATIONS/`、`.agents/`、`AGENTS.md` 下的纯自定义文件 → 必然 keep-ours
- 其余（含 `[CUSTOM-BEGIN]` 标记的上游文件）→ 阶段 2

**阶段 2（智能手动合并）**：

1. 读取冲突文件完整内容
2. `[CUSTOM-BEGIN]...[CUSTOM-END]` 块必须保留；标记外区域优先采用上游版本
3. 上游重构导致标记位置漂移时，按函数/组件名找新位置重放标记块
4. 用编辑工具精确清除 `<<<<<<< / ======= / >>>>>>>` 标记
5. **三份 `package-lock.json`**（根 / `webview` / `ai-bridge`）冲突：接受上游版本 → 在各目录跑 `npm install` 重新生成，**不要手编 lock**

**阶段 3（无法自动处理 → 暂停并向用户报告）**：

- 上游重构了 `package.json` 的 `contributes` 或 `scripts`（本 fork 在此有 fork 标识改动）
- `.vscodeignore` 冲突（fork 在此有承重改动，见 pitfalls #4）
- `CUSTOMIZATIONS/registry.md` 自身冲突（人工决策）

报告格式：文件 / 原因 / 建议（两方关键差异）/ 上游改动概要 / 我们的改动概要。

### 5. 合并后验证

```bash
git diff --name-only --diff-filter=U        # 必须为空

sh CUSTOMIZATIONS/scripts/manager.sh install   # 上游可能更新了依赖（三个包都要）
sh CUSTOMIZATIONS/scripts/manager.sh build
sh CUSTOMIZATIONS/scripts/manager.sh test
sh CUSTOMIZATIONS/scripts/check-registry.sh    # 必须全绿
```

**上游无 linter**，唯一的静态门是 `tsc --noEmit`（`manager.sh typecheck`），而它**在纯净上游上本来就有 8 个错误**（pitfalls #9）——验证时对比的是"合并前后错误集合是否一致"，不是"是否为零"。

改了 Node 版本要求时注意 `src/nodeRequirements.ts` 的 `MIN_NODE_MAJOR_VERSION`。

### 6. 更新 registry.md 并完成合并

- frontmatter：`current_upstream_version` / `current_upstream_commit` / `last_merge_date`
- 失效条目状态改 `needs-migration` 或 `deprecated`；已被上游原生支持的改 `merged-upstream`

```bash
git add -A
git commit -m "merge(upstream): merge upstream <version> into custom/main

- Upstream version: <version>
- Merge date: <date>
- Conflicts resolved: <list>
- Custom changes preserved: <change-ids>"

git switch custom/main
git merge --no-ff merge/upstream-<version>-<date> -m "merge(upstream): integrate upstream <version>"
git branch -d merge/upstream-<version>-<date>
git push origin custom/main vendor/main
```

---

## 跨大版本升级（如 0.1 → 0.2 结构性升级）

上游发生仓库结构重构时，merge 可能整体不可行：

1. 评估：`git diff --stat vendor/<old> <new-target>` 差异过大且总览条目多为 merge-manual 时，向用户建议 **cherry-pick 重建**：
   - 基于新 vendor 分支创建 `custom/main-v<new>`
   - `git log --oneline --reverse vendor/<old>..custom/main` 逐个 cherry-pick 自定义提交，冲突按标记块处理
   - 旧 `custom/main` 重命名为 `custom/main-v<old>-archive`，新分支顶替为 `custom/main`
2. 每个适配修复更新 registry.md 对应条目
3. 推送 `--force-with-lease`

本仓库自定义提交很少且集中在少数文件，通常 **merge 就够**，不必走 cherry-pick 重建。

---

## 合并后收尾

1. 输出合并报告：目标版本 / 冲突文件数 / 自动·手动解决数 / 需人工决策数 / 构建验证结果 / active 条目保留数 / 推送状态
2. 跑 `sh CUSTOMIZATIONS/scripts/manager.sh test` 并对比基线（pitfalls #9）
3. 若 custom 版本已发布过，提醒用户本次合并后需要 bump 自定义版本号并发布（`ccgui-release` → `ccgui-publish`）

## 紧急回滚

```bash
git reflog show custom/main     # 找合并前 commit
git reset --hard <commit-before-merge>
git push origin custom/main --force-with-lease
```

## 重要约束

1. **永远不要在 custom/main 上直接 merge**：必须经临时 `merge/upstream-*` 分支
2. **永远不要用 rebase 处理上游合并**：会改写自定义历史，破坏 CUSTOMIZATIONS/registry.md 的追踪
3. **vendor 分支上不做任何自定义修改**：只接受来自 upstream 的 merge
4. **三份 `package-lock.json` 冲突**：接受上游后在各目录重新 `npm install`，不手编
5. **不删除 CUSTOMIZATIONS/registry.md 中的任何历史条目**
6. **`.vscodeignore` 冲突按 keep-ours 处理**：它是承重改动，被上游冲掉会把 fork 文档打进 VSIX（pitfalls #4）；`.gitignore` 同理（pitfalls #1）
7. **合并后必须重跑一次 `manager.sh package` 并检查内容断言**——上游若改了 `.vscodeignore` 或新增目录，漏包/混入都会在这里暴露
8. **本 skill 各步骤中的 commit / push 仅在用户明确发起合并请求时执行**——合并流程本身就是用户触发的操作，流程内按步骤提交推送是预期行为；但流程中止（冲突需要人工决策、验证失败）时停在未提交状态，先报告再等指示
