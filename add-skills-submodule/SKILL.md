---
name: add-skills-submodule
description: Add a new git submodule for skills and create its link script. Use when user asks to add a skills repository as a submodule, or says "新增子模块", "加入子模块", "引入技能仓库", "add submodule".
---

# Add skills submodule

将新的技能仓库添加为 git 子模块，并创建对应的 link 脚本。

## 流程

### 1. 添加子模块

```bash
git submodule add <url> submodules/<name>
```

### 2. 查看 skills 结构

确认 `submodules/<name>/skills/` 下的目录结构：

| 结构 | 特征 | 遍历方式 |
|------|------|----------|
| **扁平** | `skills/` 下直接是技能目录 | `for dir in submodules/<name>/skills/*/` |
| **分类** | `skills/engineering/`、`skills/productivity/` 等 | `scripts/skill_links.py` 按分类遍历 |

### 3. 复制模板脚本

```bash
cp add-skills-submodule/scripts/link-submodule-template.sh scripts/link-<name>.sh
```

链接逻辑只有一份：仓库 `scripts/skill_links.py`。目标仓库还没有它时一并复制：

```bash
cp add-skills-submodule/scripts/skill_links.py scripts/skill_links.py
```

### 4. 适配脚本

**全局替换** `__SUBMODULE_NAME__` → 实际子模块名。

**布局**：分类结构（`skills/engineering/...`）保留 `CATEGORIES="engineering,productivity"`；扁平结构把它改成空字符串 `CATEGORIES=""`。

不要在脚本里重写链接逻辑——Windows junction 兜底和路径规范化都在 `skill_links.py` 里。

### 5. 运行脚本

三种模式：

```bash
./scripts/link-<name>.sh              # 全量刷新：链接子模块所有技能
./scripts/link-<name>.sh skill-a      # 增量追加：只链接指定技能
./scripts/link-<name>.sh --unlink     # 反向：取消所有软链接（不动 gitignore）
```

| 模式 | 触发 | 行为 | gitignore |
|------|------|------|-----------|
| 全量 | 无参数 | 扫描子模块全部技能，全量重建 | 整个子区块重写为本子模块的全部技能 |
| 增量 | 带参数 | 仅重建指定技能（不存在则报错跳过） | 与原有登记取并集后重写 |
| 反向 | `--unlink` | 只删除本子模块的链接 | 不修改 |

脚本会自动：
- 检查子模块是否已初始化（未初始化则报错提示，`--unlink` 除外）
- 在项目根目录建立链接（Windows 上先试符号链接，建不了或解析不了就退回 junction）
- 更新 `.gitignore`（只重写本子模块的子区块，不影响其他子模块）

### 6. 验证

```bash
git status   # 软链接应被 gitignore 忽略，不出现
```

## .gitignore 结构

所有 `link-*.sh` 共用同一个托管区块，互不干扰：

```gitignore
# === 技能软链接 begin ===
# --- mattpocock-skills begin ---
ask-matt
codebase-design
...
# --- mattpocock-skills end ---
# --- agent-toolkit begin ---
agent-md-refactor
...
# --- agent-toolkit end ---
# === 技能软链接 end ===
```

每个脚本只管理自己的 inner block（`# --- <name> begin ---` 到 `# --- <name> end ---`），运行时删除旧 block、插入新 block，其他子模块的条目不受影响。

## 注意事项

- 子模块初始化 `git submodule update --init` 由用户单独执行，脚本只检查、不自动 init
- 新技能名称如与已有软链接同名，脚本会用新链接覆盖旧链接（先 rm 再 ln）
- 脚本基于 bash 3.2（macOS 默认），不要用 `declare -A` 等 bash 4+ 特性
