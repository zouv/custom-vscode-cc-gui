#!/usr/bin/env bash
# =============================================================================
# package-vsix.sh — 打包 VSIX + 内容断言 + SHA256SUMS
# 用法：sh CUSTOMIZATIONS/scripts/package-vsix.sh [--allow-secrets] [--skip-check]
#
# 产物：dist/vsix/<name>-<version>.vsix + dist/vsix/SHA256SUMS.txt
#
# 注意：不要在本脚本外再跑 `npm run build`。`vsce package` 总会先执行
# package.json 的 `vscode:prepublish`（= `npm run build`），外面再跑一次是重复构建。
# =============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"
DIST_DIR="${PROJECT_ROOT}/dist"
OUT_DIR="${DIST_DIR}/vsix"

log()  { printf "\033[1;34m[vsix]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[ ok ]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[err ]\033[0m %s\n" "$*" >&2; }

ALLOW_SECRETS=""
for arg in "$@"; do
  case "${arg}" in
    --allow-secrets) ALLOW_SECRETS="--allow-package-all-secrets" ;;
    --skip-check)    ;;
    *) warn "忽略未知参数：${arg}" ;;
  esac
done

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "缺少命令：$1"; exit 1; }
}

require_cmd node
require_cmd npm
cd "${PROJECT_ROOT}"

NAME="$(node -p "require('./package.json').name")"
VERSION="$(node -p "require('./package.json').version")"
VSIX_NAME="${NAME}-${VERSION}.vsix"
VSIX="${OUT_DIR}/${VSIX_NAME}"

log "包名：${NAME}  版本：${VERSION}"

# -----------------------------------------------------------------------------
# 依赖预检：三个包必须都在。漏装 ai-bridge 会打出缺 sql.js 的 VSIX，
# 运行期 daemon 崩在 read-cc-switch-db.js 的顶层 import（见 pitfalls #3）。
# -----------------------------------------------------------------------------
missing=()
[ -f "${PROJECT_ROOT}/node_modules/.bin/esbuild" ]        || missing+=("根（esbuild）")
[ -f "${PROJECT_ROOT}/webview/node_modules/.bin/vite" ]   || missing+=("webview（vite）")
[ -d "${PROJECT_ROOT}/ai-bridge/node_modules/sql.js" ]    || missing+=("ai-bridge（sql.js）")
if [ ${#missing[@]} -gt 0 ]; then
  err "依赖缺失：$(printf '%s、' "${missing[@]}")"
  err "请先执行：sh CUSTOMIZATIONS/scripts/manager.sh install"
  exit 1
fi
ok "依赖预检通过（根 / webview / ai-bridge）"

mkdir -p "${OUT_DIR}"
rm -f "${VSIX}"

# -----------------------------------------------------------------------------
# 打包。--no-dependencies 是正确的：根 package.json 零运行时依赖（全靠 esbuild
# 打包），而 ai-bridge/node_modules/sql.js 是靠 .vscodeignore 白名单进的包，
# 与依赖检测无关。vscode:prepublish 会自动跑 npm run build。
# -----------------------------------------------------------------------------
log "运行 vsce package（会先自动执行 npm run build）"
if ! npx --yes --package=@vscode/vsce@^3 -- vsce package \
      --no-dependencies ${ALLOW_SECRETS} --out "${VSIX}"; then
  err "vsce package 失败"
  warn "若报 [SECRET_NAME] 一类 secretlint 误报，重跑加 --allow-secrets（优先取具名规则，见 pitfalls #6）"
  exit 1
fi
[ -f "${VSIX}" ] || { err "未生成 VSIX：${VSIX}"; exit 1; }
ok "已生成 $(basename "${VSIX}")  ($(stat -c %s "${VSIX}" 2>/dev/null || wc -c < "${VSIX}" | tr -d ' ') bytes)"

# -----------------------------------------------------------------------------
# 内容断言：这是防止 .vscodeignore 写错导致 fork 文档/脚本外泄的那道闸。
# 用 unzip -Z1（只列文件名）而**不是** unzip -l——后者会在头部打印
# `Archive:  dist/vsix/xxx.vsix`，让 "dist/vsix/" 这类关键字误命中（真实踩过）。
# -----------------------------------------------------------------------------
log "内容断言（unzip -Z1）"
require_cmd unzip
LIST="$(unzip -Z1 "${VSIX}")"

fail=0
must_have=(
  "extension/dist/extension.js"
  "extension/webview/dist/index.html"
  "extension/ai-bridge/daemon.js"
  "extension/ai-bridge/node_modules/sql.js/dist/sql-wasm.wasm"
  "extension/media/icon.png"
  "extension/package.json"
)
must_not_have=(
  "extension/CUSTOMIZATIONS/"
  "extension/.agents/"
  "extension/AGENTS.md"
  "extension/dist/vsix/"
  "extension/src/"
  "extension/node_modules/"
  # vsce 打的是工作树不是 git，本机未跟踪的工具/会话目录会漏进包（真实踩过：.claude/）
  "extension/.claude/"
  "extension/.zcode/"
  "extension/.cursor/"
  "extension/.codex/"
)

for p in "${must_have[@]}"; do
  if grep -qF "${p}" <<<"${LIST}"; then
    ok "  含  ${p}"
  else
    err "  缺  ${p}"
    fail=1
  fi
done
for p in "${must_not_have[@]}"; do
  if grep -qF "${p}" <<<"${LIST}"; then
    err "  混入 ${p}（.vscodeignore 需要修）"
    fail=1
  else
    ok "  无  ${p}"
  fi
done

if [ "${fail}" -ne 0 ]; then
  err "内容断言未通过，VSIX 不可发布"
  exit 1
fi

# -----------------------------------------------------------------------------
# 校验和
# -----------------------------------------------------------------------------
( cd "${OUT_DIR}" && sha256sum "${VSIX_NAME}" > SHA256SUMS.txt )
ok "已生成 ${OUT_DIR}/SHA256SUMS.txt"
cat "${OUT_DIR}/SHA256SUMS.txt"

echo
ok "打包完成：${VSIX}"
