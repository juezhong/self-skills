# Skills 仓库

个人技能备份仓库。所有技能以「单一事实源」形式放在 `~/.agents/skills`，通过软链接分发给各个 AI 编码工具；Claude Code 另有一条插件市场路径。

## 先做决定：你只用一个工具，还是多个

```
你用哪些 AI 编码工具？
│
├─ 只用 Claude Code
│   └─ 走「路径 B：Claude 插件」→ 跳到这里
│
└─ 用两个及以上（Claude + Codex + DSH + Cursor …）
    └─ 走「路径 A：软链接」→ 跳到这里
```

两条路径**互斥**。同时使用会在 Claude Code 里出现同名技能两份（一份来自 `~/.claude/skills`，一份来自插件），选择困难且易混淆。

如果你不确定：选路径 A。它覆盖所有工具，Claude Code 也能用。

---

## 路径 A：软链接（所有工具）

适合用两个及以上工具的人。技能实体在本仓库，根目录的 27 个技能目录都是指向 `submodules/mattpocock-skills/skills/...` 的软链接。

### 1. 克隆并初始化

```bash
git clone <this-repo> ~/.agents/skills
cd ~/.agents/skills
git submodule update --init --recursive
```

约 2 分钟。

### 2. 生成软链接

```bash
bash scripts/link-mattpocock-skills.sh
```

脚本会：
- 递归发现子模块里的 `SKILL.md`，排除 `deprecated`、`misc`、`node_modules`、`in-progress`
- 在仓库根目录创建技能软链接
- 重建 `.gitignore` 里 `mattpocock-skills` 的托管区块

全量安装**不会覆盖**已有同名路径。要重装先跑 `bash scripts/link-mattpocock-skills.sh --unlink`，再跑一次安装。

`--unlink` 只删除指向 `submodules/` 的软链接，不改 `.gitignore`。

约 10 秒。

### 3. 确认排除 Claude Code 的旧链接

Claude Code 若已有 `~/.claude/skills` 指向本仓库，要删掉它，否则会和插件重复：

```bash
# 先确认它确实是指向本仓库的软链接
ls -ld ~/.claude/skills

# 确认后再删
rm ~/.claude/skills
```

其他工具改用下面的入口：

| 工具 | 入口 |
|------|------|
| Codex / DSH / 通用 | `~/.agents/skills` |
| Claude Code | 走路径 B 的插件，不要软链接 |

---

## 路径 B：Claude 插件（只用 Claude Code）

适合只用 Claude Code 的人。技能通过 Claude 官方插件机制安装，不依赖本仓库的软链接。

本项目自带 `.claude-plugin/marketplace.json`，可以作为一个本地插件市场注册。

### 1. 克隆并初始化

```bash
git clone <this-repo> ~/.agents/skills
cd ~/.agents/skills
git submodule update --init --recursive
```

和路径 A 完全一样。

### 2. 注册为插件市场

```
/plugin marketplace add ~/.agents/skills/submodules/mattpocock-skills
```

这是**本地目录**方式（不是 GitHub URL），Claude 原地读取该目录，改动能立刻生效，不需要重新安装。

### 3. 安装

```
/plugin install mattpocock-skills@mattpocock-skills
/reload-plugins
```

装完后技能以 `/mattpocock-skills:skill-name` 的形式出现，共 27 个，与路径 A 的软链接集合完全一致。

### 4. 不要建立 `~/.claude/skills`

路径 B 依赖 Claude 只从插件读取技能。如果 `~/.claude/skills` 还指向本仓库，同名技能会出现两次。

检查：

```bash
ls -ld ~/.claude/skills 2>/dev/null || echo "不存在，正确"
```

---

## 更新技能

一条命令把所有子模块拉到上游 `main` 的最新提交，并自动提交父仓库的指针变化：

```bash
bash scripts/update-submodules.sh
```

| 参数 | 作用 |
|------|------|
| 无 | 拉 `origin/main`，有变化就自动提交 |
| `--branch <name>` | 改成拉 `origin/<name>` |
| `--dry-run` | 只报告哪些子模块可更新，不做任何改动 |

脚本先跑 `git submodule sync` 和 `git submodule update --init --recursive`，所以以后新增的子模块会自动覆盖，不需要改脚本。

拉取后：
- 路径 A：软链接指向 `submodules/` 内部的文件，天然生效，无需重跑 link 脚本（除非上游新增或删除了技能）
- 路径 B：本地目录市场原地读取，`/reload-plugins` 即可

约 30 秒（取决于网络）。

上游新增或删除技能后，路径 A 需要重新生成链接：

```bash
bash scripts/link-mattpocock-skills.sh --unlink
bash scripts/link-mattpocock-skills.sh
```

---

## 目录结构

```
~/.agents/skills/
├── AGENTS.md                  # 给 AI 代理的仓库约定
├── README.md                  # 本文件
├── docs/agents/               # issue tracker / triage 标签 / domain 文档约定
├── scripts/
│   ├── link-mattpocock-skills.sh   # 入口，负责建 venv 后调用 .py
│   ├── link-mattpocock-skills.py   # 实际实现
│   └── update-submodules.sh        # 拉取所有子模块并自动提交
├── submodules/
│   └── mattpocock-skills/     # 上游 github.com/mattpocock/skills
├── code-review -> submodules/...  # 27 个软链接，由 link 脚本生成，已 gitignore
└── ...
```

根目录的技能目录**都是软链接**，不要在其中提交改动；真实内容在 `submodules/`。

---

## 常见问题

**为什么根目录技能目录被 gitignore？**
它们是生成物。删掉可以随时用 `scripts/link-mattpocock-skills.sh` 重建。放进 git 会导致「软链接」和「真实文件」两套并存。

**路径 A 和 B 能同时用吗？**
不能。在 Claude Code 里会看到两份同名技能。选一个。

**`git submodule update --remote` 和 `scripts/update-submodules.sh` 的区别？**
前者只更新工作区，不动父仓库提交；后者会顺手 `git add` 并提交指针变化，让「拉取」变成一次完整的操作。

**换新机器怎么恢复？**
按路径 A 或 B 的第一步克隆，然后执行对应步骤。软链接不需要克隆，脚本会重建。

**上游有 tag，能锁定版本吗？**
可以。在子模块里 `git checkout v1.3.1`，然后 `git add submodules/mattpocock-skills && git commit`。`update-submodules.sh` 会把它重新拉到 `main`，所以锁定版本时不要跑该脚本。
