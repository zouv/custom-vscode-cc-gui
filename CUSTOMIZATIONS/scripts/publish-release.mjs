#!/usr/bin/env node
/**
 * publish-release.mjs —— 把 release notes / VSIX 产物发布到 GitHub Release
 *
 * 配套 skill：.agents/skills/ccgui-publish/SKILL.md
 *
 * 凭据：从 Git Credential Manager 取（`git credential fill`），只在运行时读取、
 *       不落盘、不回显。全程幂等：release 已存在则复用，同名资产先删后传，
 *       正文按 notes 文件覆盖，可反复重跑。
 *
 * 与参考项目（custom-marktext / custom-chatbox）的关键差异：
 *   本仓库上游 **没有 .github/，即零 CI**。参考脚本里的 `--body-only` / `--wait`
 *   及其轮询循环，唯一目的是对付「上游 CI 先用模板创建 release 并覆盖正文」。
 *   这里不存在该问题，故整段不移植——release 由本脚本一次创建到位。
 *
 * 用法（在仓库根目录执行）：
 *   # 仅校验，不发网络请求
 *   node CUSTOMIZATIONS/scripts/publish-release.mjs v0.1.5-custom.1 --dry-run
 *
 *   # 正式发布（默认上传 dist/vsix/<name>-<version>.vsix + SHA256SUMS.txt）
 *   node CUSTOMIZATIONS/scripts/publish-release.mjs v0.1.5-custom.1 --prerelease
 *
 *   # 显式指定产物（可重复 --asset）
 *   node CUSTOMIZATIONS/scripts/publish-release.mjs v0.1.5-custom.1 --asset dist/vsix/foo.vsix
 *
 * 默认值：
 *   --notes   CUSTOMIZATIONS/release-notes/<version>.md
 *   --repo    从 `git remote get-url origin` 推导
 *   --asset   dist/vsix/<name>-<version去掉v前缀>.vsix + dist/vsix/SHA256SUMS.txt
 *
 * 退出码：0 成功；1 失败；2 参数错误
 */
import fs from 'node:fs'
import path from 'node:path'
import { createHash } from 'node:crypto'
import { execFileSync } from 'node:child_process'

const REPO_ROOT = execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim()

function die (msg, code = 1) {
  console.error(`[err ] ${msg}`)
  process.exit(code)
}
const info = (m) => console.log(`[info] ${m}`)
const ok = (m) => console.log(`[ ok ] ${m}`)

// ---------- 参数解析 ----------
const argv = process.argv.slice(2)
const version = argv.find((a) => !a.startsWith('--') && /^v?\d/.test(a))
if (!version) die('缺少版本号，例：node publish-release.mjs v0.1.5-custom.1', 2)

const flags = {}
const assets = []
for (let i = 0; i < argv.length; i++) {
  const a = argv[i]
  if (a === '--asset') {
    assets.push(argv[++i])
  } else if (a.startsWith('--')) {
    flags[a.slice(2)] = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : true
  }
}
const dryRun = Boolean(flags['dry-run'])
const noBody = Boolean(flags['no-body'])
const isPrerelease = Boolean(flags.prerelease)
const isDraft = Boolean(flags.draft)
const refreshSums = Boolean(flags.sha256)

const pkg = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'package.json'), 'utf8'))
// package.json 的 version 必须是无 v 前缀的合法 semver；tag 才用 v 前缀
const appVersion = version.replace(/^v/, '')

function resolveRepo () {
  if (typeof flags.repo === 'string') return flags.repo
  const url = execFileSync('git', ['remote', 'get-url', 'origin'], { encoding: 'utf8' }).trim()
  const m = url.match(/github\.com[:/]([^/]+\/[^/]+?)(?:\.git)?$/)
  if (!m) die(`无法从 origin（${url}）解析出 owner/repo，请用 --repo 指定`)
  return m[1]
}
const repo = resolveRepo()
const targetCommitish = typeof flags.target === 'string' ? flags.target : 'custom/main'

const notesFile = path.resolve(
  REPO_ROOT,
  typeof flags.notes === 'string' ? flags.notes : `CUSTOMIZATIONS/release-notes/${version}.md`
)

// 默认产物集：VSIX + 校验和清单（随版本推导）
const defaultAssetRel = [
  `dist/vsix/${pkg.name}-${appVersion}.vsix`,
  'dist/vsix/SHA256SUMS.txt',
]
const assetPaths = (assets.length ? assets : defaultAssetRel).map((p) => path.resolve(REPO_ROOT, p))

// ---------- 前置校验 ----------
info(`仓库         : ${repo}`)
info(`版本         : ${version}（产物版本号 ${appVersion}）`)
info(`release notes: ${notesFile}`)
for (const p of assetPaths) info(`产物         : ${p}`)

if (!fs.existsSync(notesFile)) {
  die(`release notes 不存在：${notesFile}（先写 CUSTOMIZATIONS/release-notes/${version}.md）`)
}

// --sha256：上传前重算校验和，保证不会发出过期的散列
if (refreshSums) {
  const vsixDir = path.join(REPO_ROOT, 'dist', 'vsix')
  const targets = fs.readdirSync(vsixDir).filter((f) => f.endsWith('.vsix'))
  if (!targets.length) die(`--sha256 但 ${vsixDir} 下没有 .vsix`)
  const lines = []
  for (const f of targets) {
    const buf = fs.readFileSync(path.join(vsixDir, f))
    lines.push(`${createHash('sha256').update(buf).digest('hex')}  ${f}`)
  }
  fs.writeFileSync(path.join(vsixDir, 'SHA256SUMS.txt'), lines.join('\n') + '\n')
  ok(`已重算 ${targets.length} 个 VSIX 的 SHA256SUMS.txt`)
}

const assetStats = assetPaths.map((p) => {
  if (!fs.existsSync(p)) die(`产物不存在：${p}\n先执行：sh CUSTOMIZATIONS/scripts/manager.sh package`)
  return { path: p, name: path.basename(p), size: fs.statSync(p).size }
})

// 本地 tag 存在性与历史归属自检——发布事故多出于此
try {
  const tagCommit = execFileSync('git', ['rev-parse', `${version}^{commit}`], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
  }).trim()
  info(`本地 tag     : ${tagCommit.slice(0, 8)}`)
  try {
    execFileSync('git', ['merge-base', '--is-ancestor', version, 'HEAD'], { stdio: 'ignore' })
  } catch {
    console.warn(`[warn] ${version} 不是 HEAD 的祖先——tag 可能打在被 amend/改写过的提交上`)
  }
  try {
    execFileSync('git', ['ls-remote', '--exit-code', '--tags', 'origin', version], { stdio: 'ignore' })
    ok('tag 已推送到 origin')
  } catch {
    console.warn(`[warn] origin 上还没有 tag ${version}，别忘了：git push origin ${version}`)
  }
} catch {
  console.warn(`[warn] 本地不存在 tag ${version}，先执行：git tag -a ${version} -m "Release ${version}"`)
}

if (dryRun) {
  console.log('\n[dry-run] 校验完成，未对 GitHub API 发起任何请求')
  process.exit(0)
}

// ---------- 取 token（GCM，不落盘） ----------
function getToken () {
  let out
  try {
    out = execFileSync('git', ['credential', 'fill'], {
      input: 'protocol=https\nhost=github.com\n\n',
      encoding: 'utf8',
    })
  } catch {
    die('无法从 Git Credential Manager 取到 github.com 凭证；可改用 `gh auth login`')
  }
  const m = out.match(/^password=(.+)$/m)
  if (!m) die('GCM 返回的凭证里没有 password 字段（可能只存了用户名）')
  return m[1].trim()
}
const token = getToken()
ok('已从 Git Credential Manager 取到 token')

const api = `https://api.github.com/repos/${repo}`
const headers = {
  Authorization: `token ${token}`,
  Accept: 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28',
  'User-Agent': 'ccgui-publish-script',
}
const body = fs.readFileSync(notesFile, 'utf8')

async function fetchRelease () {
  const res = await fetch(`${api}/releases/tags/${version}`, { headers })
  if (res.status === 200) return await res.json()
  if (res.status === 404) return null
  die(`查询 release 失败 ${res.status}：${await res.text()}`)
}

// ---------- 创建或复用 release ----------
let release = await fetchRelease()
if (!release) {
  const res = await fetch(`${api}/releases`, {
    method: 'POST',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      tag_name: version,
      target_commitish: targetCommitish,
      name: version,
      body,
      draft: isDraft,
      prerelease: isPrerelease,
    }),
  })
  if (!res.ok) die(`创建 release 失败 ${res.status}：${await res.text()}`)
  release = await res.json()
  ok(`release ${version} 已创建（id=${release.id}）`)
} else {
  info(`release ${version} 已存在（id=${release.id}），复用`)
  if (!noBody) {
    const res = await fetch(`${api}/releases/${release.id}`, {
      method: 'PATCH',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: version, body, prerelease: isPrerelease, draft: isDraft }),
    })
    if (!res.ok) die(`更新 release 正文失败 ${res.status}：${await res.text()}`)
    release = await res.json()
    ok('release 正文已按 release notes 覆盖')
  }
}

// ---------- 上传产物 ----------
for (const asset of assetStats) {
  const dupe = (release.assets || []).find((a) => a.name === asset.name)
  if (dupe) {
    info(`资产 ${asset.name} 已存在（id=${dupe.id}），先删除旧资产再上传`)
    const del = await fetch(`${api}/releases/assets/${dupe.id}`, { method: 'DELETE', headers })
    if (!del.ok) die(`删除旧资产失败 ${del.status}：${await del.text()}`)
  }
  info(`上传 ${asset.name}（${(asset.size / 1024 / 1024).toFixed(1)} MB）...`)
  const up = await fetch(
    `https://uploads.github.com/repos/${repo}/releases/${release.id}/assets?name=${encodeURIComponent(asset.name)}`,
    {
      method: 'POST',
      headers: {
        Authorization: `token ${token}`,
        'Content-Type': 'application/octet-stream',
        'Content-Length': String(asset.size),
        'User-Agent': 'ccgui-publish-script',
      },
      body: fs.createReadStream(asset.path),
      duplex: 'half',
    }
  )
  if (!up.ok) die(`上传 ${asset.name} 失败 ${up.status}：${await up.text()}`)
  const upJson = await up.json()
  if (upJson.size !== asset.size) {
    die(`${asset.name} 上传后字节数不符：本地 ${asset.size}，远端 ${upJson.size}`)
  }
  ok(`${asset.name} 上传完成（${upJson.size} bytes，与本地一致）`)
}

// ---------- 核对最终状态 ----------
const final = await fetchRelease()
console.log('\n=== 远端 release 状态 ===')
console.log(`tag        : ${final.tag_name}`)
console.log(`draft      : ${final.draft}    prerelease: ${final.prerelease}`)
console.log(`assets     : ${(final.assets || []).length} 个`)
for (const a of final.assets || []) {
  console.log(`  - ${a.name}  ${a.size} bytes  ${a.state}`)
}
const notUploaded = (final.assets || []).filter((a) => a.state !== 'uploaded')
if (notUploaded.length) {
  console.warn(`\n[warn] ${notUploaded.length} 个资产不是 uploaded 状态：${notUploaded.map((a) => a.name).join(', ')}`)
}

console.log(`\n[SUCCESS] ${final.html_url}`)
