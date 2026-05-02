> 自用 Skills 备份

## 环境初始化

在新机器上恢复技能环境：

### 1. 手动添加的插件市场

`claude-plugins-official` 为系统内置官方市场，无需手动注册。以下为额外添加的市场：

| 市场 | 注册命令 |
|------|----------|
| `anthropic-agent-skills` | `/plugin marketplace add anthropics/skills` |

### 2. 已安装插件

| 插件 | 来源市场 | 安装命令 | 用途 |
|------|----------|----------|------|
| `document-skills` | anthropic-agent-skills | `/plugin install document-skills@anthropic-agent-skills` | 文档套件（xlsx/docx/pptx/pdf/skill-creator 等 17 个技能） |
| `claude-md-management` | claude-plugins-official | `/plugin install claude-md-management@claude-plugins-official` | CLAUDE.md 审计与改进 |
| `superpowers` | claude-plugins-official | `/plugin install superpowers@claude-plugins-official` | 核心技能库（TDD/调试/协作/计划 14 个技能） |

### 3. 一键安装

```bash
# 1. 克隆本仓库并链接
git clone <this-repo> ~/.agents/skills
ln -s ~/.agents/skills ~/.claude/skills

# 2. 注册第三方市场
/plugin marketplace add anthropics/skills

# 3. 安装插件
/plugin install document-skills@anthropic-agent-skills
/plugin install claude-md-management@claude-plugins-official
/plugin install superpowers@claude-plugins-official

# 4. 重新加载
/reload-plugins
```
