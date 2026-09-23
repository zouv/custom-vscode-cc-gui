#!/usr/bin/env bash
# =============================================================================
# manager.sh — custom-vscode-cc-gui 项目统一入口
# Windows 使用 Git Bash 执行：sh CUSTOMIZATIONS/scripts/manager.sh <command>
#
# 常用快捷写法（在仓库根目录）：
#   sh CUSTOMIZATIONS/scripts/manager.sh help
#   sh CUSTOMIZATIONS/scripts/manager.sh install
#   sh CUSTOMIZATIONS/scripts/manager.sh package
# =============================================================================
set -euo pipefail

# 项目根目录：脚本位于 <repo>/CUSTOMIZATIONS/scripts/ 下
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"
SCRIPTS_DIR="${PROJECT_ROOT}/CUSTOMIZATIONS/scripts"
DIST_DIR="${PROJECT_ROOT}/dist"
VSIX_DIR="${DIST_DIR}/vsix"

log()  { printf "\033[1;34m[manager]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[ ok  ]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn ]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[err  ]\033[0m %s\n" "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "缺少命令：$1"
    exit 1
  }
}

# 进入项目根目录执行所有命令，避免相对路径歧义
cd "${PROJECT_ROOT}"

# -----------------------------------------------------------------------------
# 依赖预检（CUSTOM-20260923-001）
# 本仓库是【三个独立 npm 包】：根 / webview / ai-bridge，没有 workspace 根，
# 根目录 npm install 不会装子包。漏装 ai-bridge 会打出缺 sql.js 的 VSIX，
# 运行期 daemon 崩在 read-cc-switch-db.js 的顶层 import。故构建/打包前一律预检。
# -----------------------------------------------------------------------------
missing_deps() {
  local missing=()
  [ -d "${PROJECT_ROOT}/node_modules/.bin" ]   || missing+=("根")
  [ -d "${PROJECT_ROOT}/webview/node_modules" ] || missing+=("webview")
  [ -d "${PROJECT_ROOT}/ai-bridge/node_modules/sql.js" ] || missing+=("ai-bridge")
  printf '%s' "${missing[*]:-}"
}

require_deps() {
  local missing
  missing="$(missing_deps)"
  if [ -n "${missing}" ]; then
    err "依赖缺失：${missing}"
    err "请先执行：sh CUSTOMIZATIONS/scripts/manager.sh install"
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# 测试执行器（CUSTOM-20260923-001）
# 不要用 `npm run test:ext`！npm 在 Windows 上经 cmd.exe 执行脚本，而单引号在
# cmd.exe 里不是引号字符，node 收到的是字面量 'src/__tests__/**/*.test.mts'
# （带引号），glob 匹配 0 个文件 → 输出 1..0 并以 0 退出，是**静默假绿**。
# 这里直接调 node 并用双引号传 glob：bash 不做展开、node 自己 glob，实测 236 用例。
# -----------------------------------------------------------------------------
run_node_tests() {
  node --experimental-strip-types --no-warnings --test "$@"
}

cmd_install() {
  require_cmd npm
  local ci=""
  [ "${1:-}" = "--ci" ] && ci="ci" || ci="install"
  log "安装根依赖（npm ${ci}）"
  npm ${ci}
  log "安装 webview 依赖（npm ${ci}）——依赖较重，首次数分钟"
  ( cd webview && npm ${ci} )
  log "安装 ai-bridge 依赖（npm ${ci}）——打包 VSIX 必需（sql.js）"
  ( cd ai-bridge && npm ${ci} )
  ok "三个包的依赖安装完成"
}

cmd_build() {
  require_cmd npm
  require_deps
  log "构建扩展 + webview（tsc && vite build）"
  npm run build "$@"
  ok "构建完成（产物 dist/extension.js 与 webview/dist/）"
}

cmd_build_ext() {
  require_cmd npm
  log "仅构建扩展宿主（esbuild，跳过 webview）"
  npm run build:ext "$@"
  ok "扩展构建完成（dist/extension.js）"
}

cmd_watch() {
  require_cmd npm
  log "esbuild --watch（只监听扩展宿主；真实开发请用 VS Code 按 F5 走 .vscode/launch.json）"
  npm run watch "$@"
}

cmd_typecheck() {
  require_cmd npx
  log "typecheck（tsc --noEmit）——上游无 linter，这是唯一的静态门"
  warn "上游基线本身有 8 个 tsc 错误（见 CUSTOMIZATIONS/docs/pitfalls.md #9），非本仓库引入"
  npx --yes tsc --noEmit -p tsconfig.json "$@"
}

cmd_test_ext() {
  log "扩展宿主测试（src/__tests__）"
  run_node_tests "src/__tests__/**/*.test.mts"
}

cmd_test_bridge() {
  log "ai-bridge 测试"
  run_node_tests "ai-bridge/**/*.test.js" "ai-bridge/**/*.test.mjs"
}

cmd_test_webview() {
  require_cmd npm
  require_deps
  log "webview 测试（vitest + tsconfig.test.json 类型检查）"
  ( cd webview && npm test )
}

# 全量测试：把上游 glob 漏掉的套件也跑上，并分开报告，便于区分基线
cmd_test() {
  log "全量测试（分套件，便于区分既有基线）"
  cmd_test_ext
  ok "src/__tests__ 通过"
  log "补充：上游 glob 漏掉的 src/**/*.test.mts"
  run_node_tests "src/**/*.test.mts"
  log "scripts/ 测试"
  run_node_tests "scripts/**/*.test.mjs"
  cmd_test_bridge
  ok "全部 node:test 套件完成（webview 请用 test:webview）"
}

cmd_check() {
  cmd_typecheck || warn "typecheck 非全绿（上游基线，见 pitfalls #9）"
  cmd_test
  ok "检查完成"
}

cmd_package() {
  require_deps
  log "打包 VSIX（delegate → package-vsix.sh）"
  sh "${SCRIPTS_DIR}/package-vsix.sh" "$@"
}

cmd_artifacts() {
  if [ ! -d "${VSIX_DIR}" ]; then
    warn "尚无打包产物（${VSIX_DIR} 不存在）"
    return 0
  fi
  log "当前打包产物（${VSIX_DIR}）："
  local found=0
  for f in "${VSIX_DIR}"/*.vsix "${VSIX_DIR}"/SHA256SUMS.txt; do
    [ -f "$f" ] || continue
    found=1
    printf "  %s  (%s bytes)\n" "$(basename "$f")" "$(stat -c %s "$f" 2>/dev/null || wc -c < "$f" | tr -d ' ')"
  done
  [ "$found" = 0 ] && warn "产物目录为空"
}

cmd_sums() {
  [ -d "${VSIX_DIR}" ] || { err "产物目录不存在：${VSIX_DIR}"; exit 1; }
  ( cd "${VSIX_DIR}" && sha256sum ./*.vsix > SHA256SUMS.txt )
  ok "已生成 ${VSIX_DIR}/SHA256SUMS.txt"
  cat "${VSIX_DIR}/SHA256SUMS.txt"
}

cmd_registry() {
  sh "${SCRIPTS_DIR}/check-registry.sh" "$@"
}

cmd_clean() {
  log "清理构建与打包产物"
  rm -rf "${DIST_DIR}" "${PROJECT_ROOT}/webview/dist"
  find "${PROJECT_ROOT}" -maxdepth 2 -name "*.tsbuildinfo" -not -path "*/node_modules/*" -delete 2>/dev/null || true
  warn "已删除 dist/ 与 webview/dist/，重新打包前需先 build"
  ok "清理完成"
}

cmd_help() {
  cat <<'EOF'
custom-vscode-cc-gui — manager.sh

用法：
  sh CUSTOMIZATIONS/scripts/manager.sh <command> [args]

命令：
  install [--ci]  安装三个 npm 包依赖（根 / webview / ai-bridge）
  build   [args]  构建扩展 + webview（npm run build）
  build:ext       仅构建扩展宿主（跳过 webview）
  watch            esbuild --watch（真实开发用 VS Code F5）
  typecheck       tsc --noEmit（上游无 linter）
  test            全量 node:test 套件（分套件报告）
  test:ext        仅 src/__tests__ 扩展宿主测试
  test:bridge     仅 ai-bridge 测试
  test:webview    仅 webview（vitest + 类型检查）
  check           typecheck + test
  package         打包 VSIX（走 package-vsix.sh，含内容断言 + SHA256SUMS）
  artifacts       列出当前 VSIX 产物
  sums            重新生成 SHA256SUMS.txt
  registry        运行 check-registry.sh 一致性自检
  clean           清理 dist/ 与 webview/dist/
  help            显示帮助

说明：
  - 本仓库是三个独立 npm 包，install 必须装全，否则 package 打出的 VSIX 会缺 sql.js。
  - 测试刻意**不**走 `npm run test:ext`：Windows 下 cmd.exe 吃掉单引号会让它静默跑 0 个用例。
  - 正式发布（版本号、release notes、GitHub Release）请用 ccgui-release / ccgui-publish skill，
    本脚本只负责本地构建与打包。
EOF
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "${cmd}" in
    install) cmd_install "$@" ;;
    build) cmd_build "$@" ;;
    build:ext|build-ext) cmd_build_ext "$@" ;;
    watch|dev|start) cmd_watch "$@" ;;
    typecheck) cmd_typecheck "$@" ;;
    test) cmd_test "$@" ;;
    test:ext|test-ext) cmd_test_ext "$@" ;;
    test:bridge|test-bridge) cmd_test_bridge "$@" ;;
    test:webview|test-webview) cmd_test_webview "$@" ;;
    check) cmd_check "$@" ;;
    package|pack|vsix) cmd_package "$@" ;;
    artifacts|ls) cmd_artifacts ;;
    sums) cmd_sums ;;
    registry) cmd_registry "$@" ;;
    clean) cmd_clean ;;
    help|-h|--help) cmd_help ;;
    *) err "未知命令：${cmd}"; cmd_help; exit 2 ;;
  esac
}

main "$@"
