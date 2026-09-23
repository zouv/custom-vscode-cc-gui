#!/usr/bin/env bash
# =============================================================================
# check-registry.sh — 代码 CUSTOM 标记 ↔ registry.md 改动总览 一致性自检
# 用法（Git Bash）：sh CUSTOMIZATIONS/scripts/check-registry.sh
# 退出码：0 一致；1 有差异（按提示修文档或补标记）
#
# 适配 custom-vscode-cc-gui 三包布局：扫描 src/（扩展宿主）、ai-bridge/、
# webview/src/、scripts/、CUSTOMIZATIONS/，外加 .gitignore/.vscodeignore/package.json。
# 刻意**不扫 *.md**：README.md / registry.md / pitfalls.md 会自我命中
# （它们正文里就写着 [CUSTOM-BEGIN] 这个字面量）。
# =============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"
REGISTRY="${PROJECT_ROOT}/CUSTOMIZATIONS/registry.md"

# 关键：用【相对路径】调 grep。
# 绝对路径在两种调用环境下写法不同——Git Bash 的 pwd 给 /d/Git/...，而 pwsh 调起的
# sh（C:\Program Files\Git\usr\bin\sh.exe）pwd 给 D:/Git/...。后者带盘符冒号，
# 会让下面 `file="${line%%:*}"` 只取到 "D"，产生 [MISSING-IN-DOC] D 的假失败
# （真实踩过：init-repo.ps1 调本脚本时复现）。
# 因此 cd 到仓库根后用相对路径扫描，并用 `grep -v '^\./'` 兜底去掉可能的 ./ 前缀。
cd "${PROJECT_ROOT}"

# 收集代码中的 CUSTOM 标记：file -> 排序去重的 change-id 集合
# 排除：registry.md 自身、测试文件（测试不强制标记）、node_modules、构建产物
declare -A CODE_MARKERS=()
while IFS= read -r line; do
  file="${line%%:*}"
  rest="${line#*:}"
  id=""
  if [[ "$rest" =~ CUSTOM-([0-9]{8}-[0-9]{3}) ]]; then
    id="CUSTOM-${BASH_REMATCH[1]}"
  else
    continue
  fi
  code_file="${file//\\//}"
  CODE_MARKERS["$code_file"]+="$id "
done < <(grep -rn "CUSTOM-BEGIN" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.mjs" --include="*.cjs" \
  --include="*.mts" --include="*.json" --include="*.yml" --include="*.yaml" \
  --include="*.sh" --include="*.ps1" --include="*.css" --include="*.less" \
  --include=".gitignore" --include=".vscodeignore" \
  src ai-bridge webview/src scripts CUSTOMIZATIONS \
  .gitignore .vscodeignore package.json 2>/dev/null \
  | sed 's|^\./||' \
  | grep -v node_modules | grep -v "/dist/" | grep -v "/out/" \
  | grep -v "\.test\." | grep -v "\.spec\." | grep -v "registry.md" || true)

# 从 registry.md 改动总览表收集已登记文件
# 总览表以「## 改动总览」开头、「## 变更日志」结尾
# DOC_FILES: 精确文件路径（参与 §2 严格校验）
# DOC_PREFIXES: 目录前缀（聚合行/通配行，仅参与 §1 前缀匹配）
declare -A DOC_FILES=()
declare -A DOC_PREFIXES=()
in_table=false
while IFS= read -r line; do
  if [[ "$line" == "## 改动总览"* ]]; then in_table=true; continue; fi
  if [[ "$line" == "## 变更日志"* ]]; then break; fi
  if $in_table && [[ "$line" == \|* ]]; then
    file="$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/, "", $2); print $2}')"
    [[ "$file" == "" || "$file" == 文件* || "$file" == --* ]] && continue
    # 聚合行「DIR/（a、b、c）」或通配「DIR/*」：登记目录前缀
    if [[ "$file" == *"（"* || "$file" == *"*"* ]]; then
      prefix="${file%%（*}"; prefix="${prefix%%\**}"
      prefix="$(echo "$prefix" | sed 's/^ *//;s/ *$//')"
      [[ "$prefix" == */ || "$prefix" == "" ]] && DOC_PREFIXES["${prefix%/}"]=1 || DOC_PREFIXES["$prefix"]=1
      continue
    fi
    # 一行聚合多个文件（、分隔）时拆开逐个登记
    IFS='、' read -r -a parts <<< "$file"
    for p in "${parts[@]}"; do
      p="$(echo "$p" | sed 's/^ *//;s/ *$//')"
      [[ "$p" == "" ]] && continue
      DOC_FILES["$p"]=1
    done
  fi
done < "${REGISTRY}"

errors=0
echo "== 1) 代码里有 CUSTOM 标记但总览表未登记（或路径写法对不上）=="
for file in "${!CODE_MARKERS[@]}"; do
  rel="$file"   # 上面已 cd 到仓库根并用相对路径扫描，file 本身即仓库根相对路径
  found=0
  for doc in "${!DOC_FILES[@]}"; do
    [[ "$rel" == "$doc" ]] && { found=1; break; }
    # 相对通配行（如 static/locales/*/translation.json）
    if [[ "$doc" == *"*"* ]]; then
      wprefix="${doc%%\**}"
      [[ "$rel" == "${wprefix}"* ]] && { found=1; break; }
    fi
  done
  if [[ $found -eq 0 ]]; then
    for prefix in "${!DOC_PREFIXES[@]}"; do
      [[ "$rel" == "${prefix}"/* || "$rel" == "$prefix" ]] && { found=1; break; }
    done
  fi
  if [[ $found -eq 0 ]]; then
    echo "  [MISSING-IN-DOC] $rel  (标记: $(echo "${CODE_MARKERS[$file]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))"
    errors=$((errors+1))
  fi
done
[[ $errors -eq 0 ]] && echo "  (全部已登记)"

echo ""
echo "== 2) 总览表登记的上游文件但代码里找不到对应标记 =="
# 仅校验精确路径行；纯自定义路径（上游不存在）与测试文件不要求标记
is_custom_only() {
  case "$1" in
    CUSTOMIZATIONS/*|.agents/*|AGENTS.md|.gitattributes|.gitignore|*.json|*.test.*|*.spec.*|webview/src/version/version.ts|webview/src/version/changelog.ts) return 0 ;;
    *) return 1 ;;
  esac
}
for doc in "${!DOC_FILES[@]}"; do
  is_custom_only "$doc" && continue
  abs="${PROJECT_ROOT}/${doc}"
  if [[ ! -f "$abs" ]]; then
    echo "  [FILE-NOT-FOUND] $doc"
    errors=$((errors+1))
    continue
  fi
  if ! grep -q "CUSTOM-BEGIN" "$abs" 2>/dev/null; then
    echo "  [NO-MARKER] $doc（若确属无标记的已知缺口，请在总览标注「无标记」）"
    errors=$((errors+1))
  fi
done

echo ""
if [[ $errors -eq 0 ]]; then
  echo "[OK] 代码标记与改动总览一致（${#CODE_MARKERS[@]} 个含标记文件均已登记）"
  exit 0
else
  echo "[DIFF] 发现 $errors 处不一致——修文档（路径写法对齐）或补代码标记后重跑"
  exit 1
fi
