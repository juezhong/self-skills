## Agent skills

### Issue tracker

Issues and specs live as markdown files under `.scratch/<feature-slug>/` in this repo. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical roles, label string equal to role name (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `GLOSSARY.md` plus `docs/adr/`. See `docs/agents/domain.md`.

## 工作区

仓库根目录是本仓库的顶层目录（下称 `$WS`）。代码、依赖、缓存、临时文件、下载的工具全部落在 `$WS` 以内，`$WS` 以外只读。

## 开 shell

```bash
. ./env.sh
```

`env.sh` 不存在时，按下面内容创建：

```bash
WS="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
mkdir -p "$WS/.tmp"

export UV_CACHE_DIR="$WS/.uv/cache"
export UV_TOOL_DIR="$WS/.uv/tools"
export UV_TOOL_BIN_DIR="$WS/.uv/bin"
export NVM_DIR="$WS/.nvm"
export npm_config_cache="$WS/.npm-cache"
export npm_config_store_dir="$WS/.pnpm"
export TMPDIR="$WS/.tmp"
export PATH="$UV_TOOL_BIN_DIR:$WS/tools/bin:$PATH"
```

## Python

```bash
. ./env.sh
uv venv .venv
. .venv/bin/activate
uv pip install <pkg>
```

本仓库已有 `.venv/`（由 `scripts/link-mattpocock-skills.sh` 创建）。

## Node

node / npm 已在 PATH，直接用，不要装。

## 放哪

- Python 环境与包：`.venv/`
- uv 缓存与全局工具：`.uv/`
- npm / pnpm 缓存：`.npm-cache/`、`.pnpm/`
- 第三方工具：`tools/<name>/`
- 临时文件：`$TMPDIR`
- 任务产出：根目录下该任务自己的文件夹
- 议题与规格：`.scratch/<feature-slug>/`（见 `docs/agents/issue-tracker.md`）

其他工具装到 `$WS` 子目录，路径写进 `env.sh`。

## 根目录外只读

不写 `~`、`/opt/homebrew`、`/usr/local`、`/etc`、系统 Python。系统级安装先问用户。

## 技能链接

根目录下的技能目录是软链接，由 `scripts/link-*.sh` 生成，已在 `.gitignore` 中。改真身要去 `submodules/` 下对应的上游仓库，不要在软链接位置提交。
