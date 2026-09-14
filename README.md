> 自用 Skills 备份

## 环境初始化

在新机器上恢复技能环境：

### 1. 克隆仓库

```bash
git clone <this-repo> ~/.agents/skills
cd ~/.agents/skills
```

### 2. 初始化子模块并链接技能

```bash
# 初始化所有子模块
git submodule update --init

# 运行所有 link 脚本，创建技能软链接（自动更新 .gitignore）
for f in scripts/link-*.sh; do [ -f "$f" ] && bash "$f"; done
```

每个 `scripts/link-*.sh` 对应一个技能子模块，负责：
- 检查对应子模块是否就绪
- 在项目根目录创建技能软链接
- 更新 `.gitignore`（所有脚本共用同一个托管区块，互不干扰）

`mattpocock-skills` 的 `.sh` 是兼容入口和虚拟环境启动器，实际实现位于
`scripts/link-mattpocock-skills.py`。它会优先通过 `uv venv .venv` 创建当前仓库的
Python 3 虚拟环境；没有 `uv`（或创建失败）时，回退到 `python3 -m venv .venv`，再使用
`.venv/bin/python` 执行实现。该 Python 脚本遵循子模块上游安装器的技能发现规则：递归发现
`SKILL.md`，并排除 `deprecated`、`misc`、`node_modules`；本仓库额外排除
`in-progress`。

它不会直接执行 `submodules/mattpocock-skills/scripts/link-skills.sh`：上游脚本同时管理
`~/.agents/skills` 和 `~/.claude/skills`，而本仓库允许后者软链接到前者。包装层只管理当前
仓库根目录中的技能链接及本仓库的 `.gitignore`，因此不会与该目录结构冲突。

无参数运行时，它是与上游一致的全量安装器：刷新每个上游“已推广”技能的链接，并重建
`.gitignore` 中 `mattpocock-skills` 的托管区块。除不安装 `in-progress` 技能外，其链接
发现规则与上游一致。全量安装不会覆盖任何已有同名路径；请先运行 `--unlink`，再重新创建
所有链接。

`--unlink` 会反向删除当前仓库根目录中、确实指向 `submodules/mattpocock-skills` 的所有
技能软链接；它不会读取、删除或修改 `.gitignore`。这样可以移除已安装技能，但保留忽略
规则供下次全量安装继续使用。

`agent-toolkit` 使用同样的 Python 3 虚拟环境启动方式和安全重建流程：无参数全量链接全部
`SKILL.md` 技能，`--unlink` 仅删除指向 `submodules/agent-toolkit` 的软链接且不修改
`.gitignore`。全量链接不会覆盖已有同名路径，请先运行 `--unlink`。

### 3. 链接到 Claude Code

```bash
ln -s ~/.agents/skills ~/.claude/skills
```

### 4. 手动添加的插件市场

`claude-plugins-official` 为系统内置官方市场，无需手动注册。以下为额外添加的市场：

| 市场 | 注册命令 |
|------|----------|
| `anthropic-agent-skills` | `/plugin marketplace add anthropics/skills` |

### 5. 已安装插件

| 插件 | 来源市场 | 安装命令 | 用途 |
|------|----------|----------|------|
| `document-skills` | anthropic-agent-skills | `/plugin install document-skills@anthropic-agent-skills` | 文档套件（xlsx/docx/pptx/pdf/skill-creator 等 17 个技能） |
| `claude-md-management` | claude-plugins-official | `/plugin install claude-md-management@claude-plugins-official` | CLAUDE.md 审计与改进 |
| `superpowers` | claude-plugins-official | `/plugin install superpowers@claude-plugins-official` | 核心技能库（TDD/调试/协作/计划 14 个技能） |

### 6. 一键安装

```bash
# 1. 克隆本仓库
git clone <this-repo> ~/.agents/skills
cd ~/.agents/skills

# 2. 初始化子模块
git submodule update --init
# 3. 创建软链接（自动更新 .gitignore）
for f in scripts/link-*.sh; do [ -f "$f" ] && bash "$f"; done

# 4. 链接到 Claude Code
ln -s ~/.agents/skills ~/.claude/skills

# 5. 注册第三方市场
/plugin marketplace add anthropics/skills

# 6. 安装插件
/plugin install document-skills@anthropic-agent-skills
/plugin install claude-md-management@claude-plugins-official
/plugin install superpowers@claude-plugins-official

# 7. 重新加载
/reload-plugins
```
