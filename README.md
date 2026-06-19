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
