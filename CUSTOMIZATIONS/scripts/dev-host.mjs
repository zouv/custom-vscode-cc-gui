#!/usr/bin/env node
// =============================================================================
// dev-host.mjs — 一条命令启动 Extension Development Host（供手动验收）
//
//   npm run dev:host                          # 先构建，再启动宿主窗口（工作区 = 本仓库）
//   npm run dev:host -- --no-build            # 跳过构建，直接启动
//   npm run dev:host -- <别的目录>             # 用别的目录当工作区（如某个真实项目）
//   npm run dev:host -- --no-isolate <目录>    # 加载本机全部扩展（默认只加载本扩展）
//
// 为什么用 Node 而不是把命令直接写进 package.json 的 scripts：
//   npm 在 Windows 上默认走 cmd.exe、在 macOS/Linux 上走 sh，%CD% 与 $PWD 互不通用，
//   而 --extensionDevelopmentPath 需要**绝对路径**。本仓库 manager.sh 用 `cd` 规避，
//   但这里还要支持「换成任意目录 + 相对路径解析」，写在 shell 里就会变成两套方言。
//
// 与 F5 的关系：宿主环境刻意与 .vscode/launch.json 对齐（同一个 .vscode-dev 隔离
//   profile、同样 --disable-extensions），**唯一区别是不附加调试器**——手工点击验收
//   用它最快；要下断点请回仓库窗口按 F5。--no-isolate 可关掉隔离（加载平时那套扩展 +
//   默认 user-data），只在排查「是不是别的扩展在干扰」时才需要。
//
// 参照实现：custom-vscode-acp 的 CUSTOMIZATIONS/scripts/dev-host.mjs（同一套设计）。
// =============================================================================
import { spawnSync, spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(SCRIPT_DIR, '..', '..');
const DEV_PROFILE = join(PROJECT_ROOT, '.vscode-dev');

const args = process.argv.slice(2);

if (args.includes('--help') || args.includes('-h')) {
  console.log('用法：npm run dev:host [-- --no-build] [--no-isolate] [<工作区目录>]');
  process.exit(0);
}

const skipBuild = args.includes('--no-build');
const isolate = !args.includes('--no-isolate');
const positional = args.filter((a) => !a.startsWith('--'));

if (positional.length > 1) {
  console.error(`[dev-host] 只接受一个工作区目录，收到 ${positional.length} 个：${positional.join(', ')}`);
  process.exit(1);
}

const workspace = positional[0] ? resolve(positional[0]) : PROJECT_ROOT;
if (!existsSync(workspace)) {
  console.error(`[dev-host] 工作区目录不存在：${workspace}`);
  process.exit(1);
}

/**
 * Locate the VS Code CLI. `code` is normally on PATH; the explicit candidates
 * cover an install that was never added to PATH (common on Windows).
 */
function findCodeCli() {
  const candidates = [];
  if (process.platform === 'win32') {
    if (process.env.LOCALAPPDATA) {
      candidates.push(join(process.env.LOCALAPPDATA, 'Programs', 'Microsoft VS Code', 'bin', 'code.cmd'));
    }
    candidates.push('C:\\Program Files\\Microsoft VS Code\\bin\\code.cmd');
  }
  for (const candidate of candidates) {
    if (existsSync(candidate)) { return candidate; }
  }
  return 'code';
}

/**
 * `shell: true` is required to run `code.cmd` on Windows, but Node does NOT
 * quote the command for us — an install path containing spaces
 * (`C:\Program Files\…`) would be split into separate argv entries.
 */
function shellQuote(command) {
  return /\s/.test(command) ? `"${command}"` : command;
}

function codeWorks(cli) {
  const probe = spawnSync(shellQuote(cli), ['--version'], { shell: true, encoding: 'utf8' });
  return probe.status === 0;
}

if (!skipBuild) {
  console.log('[dev-host] 构建中…（npm run build:debug = 宿主 sourcemap + webview）');
  const build = spawnSync('npm', ['run', 'build:debug'], { cwd: PROJECT_ROOT, shell: true, stdio: 'inherit' });
  if (build.status !== 0) {
    console.error('[dev-host] 构建失败，已中止。');
    process.exit(build.status ?? 1);
  }
}

let cli = findCodeCli();
if (!codeWorks(cli)) {
  if (cli !== 'code' && codeWorks('code')) {
    cli = 'code';
  } else {
    console.error(
      '[dev-host] 找不到 VS Code 的 `code` 命令。\n'
      + '  请确认已安装 VS Code，并在命令面板执行一次\n'
      + '  "Shell Command: Install \'code\' command in PATH"，或把 code 的 bin 目录加进 PATH。',
    );
    process.exit(1);
  }
}

const spawnArgs = ['--new-window', `--extensionDevelopmentPath=${PROJECT_ROOT}`];

if (isolate) {
  spawnArgs.push(
    '--disable-extensions',
    // 无 capabilities.untrustedWorkspaces 声明的扩展在「不受信任」工作区会被禁用，
    // 于是打开一个新目录（如别的项目）时扩展会静默不激活 —— 开发宿主里直接关掉信任门。
    '--disable-workspace-trust',
    `--user-data-dir=${join(DEV_PROFILE, 'user-data')}`,
    `--extensions-dir=${join(DEV_PROFILE, 'extensions')}`,
  );
}

spawnArgs.push(workspace);

console.log(
  '[dev-host] 启动 Extension Development Host\n'
  + `  扩展路径: ${PROJECT_ROOT}\n`
  + `  工作区:   ${workspace}\n`
  + `  隔离:     ${isolate ? '开（只加载本扩展，profile 在 .vscode-dev/）' : '关（加载本机全部扩展）'}`,
);

// Detached: the host window must outlive this script, so `npm run dev:host` returns
// immediately instead of holding the terminal open.
const child = spawn(shellQuote(cli), spawnArgs, { detached: true, stdio: 'ignore', shell: true });
child.unref();

console.log('[dev-host] 已发出启动请求。窗口出现后：');
console.log('  · 改了代码后：npm run build（或更快的 build:ext），再在宿主窗口按 Ctrl+R 重载，不必关掉重开');
console.log('  · webview 客户端报错：命令面板 → "Developer: Open Webview Developer Tools"');
console.log('  · 扩展宿主日志：输出面板 → "CC GUI (Custom)"（需开启 ccgc.enableDebugLog）');
